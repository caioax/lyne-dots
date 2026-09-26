pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics of the active track from LRCLIB (lrclib.net, no key needed), with
// NetEase as a fallback when LRCLIB has no synced ones. Only looks them up
// while something shows them (acquire/release) and the track changed; found
// lyrics are cached on disk.
//
// status: "idle", "loading", "synced", "plain", "instrumental", "none",
// "error"
Singleton {
    id: root

    property string status: "idle"
    // Synced: [{ time (s), text }], sorted. Plain: one entry per line, time -1
    property var lines: []
    readonly property bool synced: status === "synced"

    // Line being sung (-1 before the first one)
    readonly property int currentIndex: {
        if (!synced)
            return -1;
        const t = position;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].time <= t; k++)
            i = k;
        return i;
    }

    // Player position, advanced between the player's own updates
    property real position: 0

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/lyrics"

    // Found versions may differ this much in length (s) from the playing one
    readonly property real durationTolerance: 5

    property int _watchers: 0
    readonly property bool _wanted: _watchers > 0
    // Track currently loaded, or being loaded ("" = nothing)
    property string _loadedKey: ""
    property real _positionStamp: Date.now()

    readonly property string _artist: MprisService.hasPlayer ? MprisService.artist : ""
    readonly property string _title: MprisService.hasPlayer ? MprisService.title : ""
    readonly property string _key: _title !== "" && _title !== "Unknown" ? (_artist + "\u0001" + _title).toLowerCase() : ""

    function acquire() {
        _watchers++;
    }

    function release() {
        _watchers = Math.max(0, _watchers - 1);
    }

    // Jumps the player to a synced line
    function seekTo(index: int) {
        const line = lines[index];
        if (line && line.time >= 0)
            MprisService.setPosition(line.time);
    }

    // Tracks change their metadata in bursts: wait for it to settle
    on_KeyChanged: keyDebounce.restart()
    on_WantedChanged: keyDebounce.restart()

    Timer {
        id: keyDebounce
        interval: 400
        onTriggered: root._load()
    }

    function _load() {
        if (!_wanted || _key === _loadedKey)
            return;
        _loadedKey = _key;
        lines = [];
        if (_key === "") {
            status = "idle";
            return;
        }
        status = "loading";
        _readCache({
            key: _key,
            artist: MprisService.artist,
            title: MprisService.title,
            length: MprisService.length,
            error: false
        });
    }

    function _cacheFile(key: string): string {
        return cacheDir + "/" + Qt.md5(key) + ".json";
    }

    // --- Disk cache ---
    function _readCache(r) {
        cacheReader.request = r;
        cacheReader.command = ["cat", _cacheFile(r.key)];
        cacheReader.running = true;
    }

    Process {
        id: cacheReader

        property var request: null

        stdout: StdioCollector {
            id: cacheOut
        }

        onExited: code => {
            const r = request;
            if (!r || r.key !== root._loadedKey)
                return;
            if (code === 0) {
                try {
                    root._apply(r.key, JSON.parse(cacheOut.text));
                    return;
                } catch (e) {}
            }
            root._fetch(r);
        }
    }

    function _saveCache(key, record) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh", cacheDir, JSON.stringify(record), _cacheFile(key)]);
    }

    // --- Lookup ---
    // LRCLIB first; NetEase when it has nothing synced. Synced lyrics from
    // either win over plain ones
    function _fetch(r) {
        _lrclib(r, found => {
            if (r.key !== root._loadedKey)
                return;
            if (found && (found.synced || found.instrumental)) {
                root._found(r.key, found);
                return;
            }
            root._netease(r, other => {
                if (r.key !== root._loadedKey)
                    return;
                const pick = other ?? found;
                if (pick) {
                    root._found(r.key, pick);
                    return;
                }
                root.status = r.error ? "error" : "none";
                // Allows a retry the next time the lyrics show up
                if (r.error)
                    root._loadedKey = "";
            });
        });
    }

    function _get(url, headers, onDone) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            onDone(xhr.status, data);
        };
        xhr.open("GET", url);
        for (const name in headers)
            xhr.setRequestHeader(name, headers[name]);
        xhr.send();
    }

    // Close enough in length to be the same version (unknown lengths pass)
    function _near(r, seconds) {
        return !(r.length > 0) || !(seconds > 0) || Math.abs(seconds - r.length) <= durationTolerance;
    }

    // Title without the "(feat. X)", "- Remastered 2011", "(Official Video)"
    // kind of extras that keep searches from matching
    function _cleanTitle(title) {
        const extras = "feat|ft\\.|with |remaster|live|version|edit|mix|mono|stereo|deluxe|bonus|explicit|official|video|audio|lyric|visualizer|single|radio";
        const clean = title.replace(new RegExp("\\s*[(\\[][^)\\]]*(" + extras + ")[^)\\]]*[)\\]]", "gi"), "").replace(new RegExp("\\s+-\\s+[^-]*(" + extras + ")[^-]*$", "i"), "").trim();
        return clean !== "" ? clean : title;
    }

    // --- LRCLIB ---
    // Exact match (with the length when known), then searches that get
    // looser, preferring synced lyrics of about the same length. Calls back
    // with a record or null
    function _lrclib(r, done) {
        const base = "https://lrclib.net/api/";
        const headers = {
            "Lrclib-Client": "lyne-dots quickshell (https://github.com/caioax/lyne-dots)"
        };
        const title = _cleanTitle(r.title);
        const exact = "artist_name=" + encodeURIComponent(r.artist) + "&track_name=" + encodeURIComponent(r.title) + (r.length > 0 ? "&duration=" + Math.round(r.length) : "");
        const searches = ["artist_name=" + encodeURIComponent(r.artist) + "&track_name=" + encodeURIComponent(title), "q=" + encodeURIComponent(r.artist + " " + title)];
        // Browser tabs often hold "Artist - Title" with a channel as artist
        if (title.includes(" - "))
            searches.push("q=" + encodeURIComponent(title));

        let plain = null;
        const search = i => {
            if (r.key !== root._loadedKey)
                return;
            if (i >= searches.length) {
                done(plain);
                return;
            }
            root._get(base + "search?" + searches[i], headers, (code, results) => {
                if (code !== 200 && code !== 404)
                    r.error = true;
                const near = Array.isArray(results) ? results.filter(x => root._near(r, x.duration)) : [];
                const hit = near.find(x => x.syncedLyrics);
                if (hit) {
                    done(root._record(hit.syncedLyrics, hit.plainLyrics, false));
                    return;
                }
                const other = near.find(x => x.plainLyrics || x.instrumental);
                if (other && !plain)
                    plain = root._record("", other.plainLyrics, other.instrumental === true);
                search(i + 1);
            });
        };

        _get(base + "get?" + exact, headers, (code, data) => {
            if (code === 200 && data && (data.syncedLyrics || data.instrumental)) {
                done(root._record(data.syncedLyrics, data.plainLyrics, data.instrumental === true));
                return;
            }
            if (code === 200 && data?.plainLyrics)
                plain = root._record("", data.plainLyrics, false);
            else if (code !== 404)
                r.error = true;
            search(0);
        });
    }

    // --- NetEase ---
    // Unofficial API: search by title and artist, take the first song by the
    // same artist and length, then its lyrics. Calls back with a synced
    // record or null
    function _netease(r, done) {
        const base = "https://music.163.com/api/";
        const title = _cleanTitle(r.title);
        const artist = r.artist.toLowerCase();
        _get(base + "search/get?type=1&limit=10&s=" + encodeURIComponent(title + " " + r.artist), {}, (code, data) => {
            if (code !== 200) {
                r.error = true;
                done(null);
                return;
            }
            const songs = data?.result?.songs ?? [];
            const song = songs.find(s => root._near(r, (s.duration ?? 0) / 1000) && (s.artists ?? []).some(a => {
                    const name = (a.name ?? "").toLowerCase();
                    return name !== "" && (artist.includes(name) || name.includes(artist));
                }));
            if (!song || r.key !== root._loadedKey) {
                done(null);
                return;
            }
            root._get(base + "song/lyric?lv=1&id=" + song.id, {}, (code2, lyric) => {
                if (code2 !== 200)
                    r.error = true;
                const lrc = lyric?.lrc?.lyric ?? "";
                done(root._parseLrc(lrc).length > 0 ? root._record(lrc, "", false) : null);
            });
        });
    }

    function _record(synced, plain, instrumental) {
        return {
            synced: synced ?? "",
            plain: plain ?? "",
            instrumental: instrumental
        };
    }

    function _found(key, record) {
        _saveCache(key, record);
        _apply(key, record);
    }

    function _apply(key, record) {
        if (key !== _loadedKey)
            return;
        if (record.synced) {
            lines = _parseLrc(record.synced);
            status = lines.length > 0 ? "synced" : "none";
        } else if (record.plain) {
            lines = record.plain.split("\n").map(text => ({
                        time: -1,
                        text: text.trim()
                    }));
            status = "plain";
        } else {
            status = record.instrumental ? "instrumental" : "none";
        }
    }

    // "[mm:ss.xx] text" lines, possibly with several stamps each. Drops the
    // credit lines NetEase puts first ("作词 : X")
    function _parseLrc(lrc) {
        const out = [];
        const stamp = /\[(\d+):(\d+)(?:[.:](\d+))?\]/g;
        const credit = /^(作词|作曲|编曲|制作|监制|混音|母带|录音|和声|出品|词|曲)[^:：]{0,8}[:：]/;
        for (const raw of lrc.split("\n")) {
            const times = [];
            let m;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(raw)) !== null)
                times.push(parseInt(m[1]) * 60 + parseInt(m[2]) + (m[3] ? parseInt(m[3]) / Math.pow(10, m[3].length) : 0));
            if (times.length === 0)
                continue;
            const text = raw.replace(/\[[^\]]*\]/g, "").trim();
            if (credit.test(text))
                continue;
            for (const t of times)
                out.push({
                    time: t,
                    text: text
                });
        }
        return out.sort((a, b) => a.time - b.time);
    }

    // --- Position ---
    Connections {
        target: MprisService

        function onPositionChanged() {
            root._positionStamp = Date.now();
            root.position = MprisService.position;
        }
    }

    Timer {
        running: root._wanted && root.synced && MprisService.isPlaying
        interval: 100
        repeat: true
        onTriggered: root.position = MprisService.position + (Date.now() - root._positionStamp) / 1000
    }
}
