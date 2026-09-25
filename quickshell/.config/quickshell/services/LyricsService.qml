pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics of the active track from LRCLIB (lrclib.net, no key needed), synced
// when available. Only looks them up while something shows them
// (acquire/release) and the track changed; found lyrics are cached on disk.
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
        _readCache(_key, MprisService.artist, MprisService.title, MprisService.album, MprisService.length);
    }

    function _cacheFile(key: string): string {
        return cacheDir + "/" + Qt.md5(key) + ".json";
    }

    // --- Disk cache ---
    function _readCache(key, artist, title, album, length) {
        cacheReader.request = {
            key: key,
            artist: artist,
            title: title,
            album: album,
            length: length
        };
        cacheReader.command = ["cat", _cacheFile(key)];
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

    // --- LRCLIB ---
    function _get(url, onDone) {
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
        xhr.setRequestHeader("Lrclib-Client", "lyne-dots quickshell (https://github.com/caioax/lyne-dots)");
        xhr.send();
    }

    // Exact match first (artist + title, and the length when known), then a
    // search, preferring synced lyrics of about the same length
    function _fetch(r) {
        const base = "https://lrclib.net/api/";
        const q = "artist_name=" + encodeURIComponent(r.artist) + "&track_name=" + encodeURIComponent(r.title);
        const duration = r.length > 0 ? "&duration=" + Math.round(r.length) : "";
        _get(base + "get?" + q + duration, (code, data) => {
            if (r.key !== root._loadedKey)
                return;
            if (code === 200 && data) {
                root._found(r.key, data);
                return;
            }
            if (code !== 404) {
                root.status = "error";
                // Allows a retry the next time the tab opens
                root._loadedKey = "";
                return;
            }
            root._get(base + "search?" + q, (code2, results) => {
                if (r.key !== root._loadedKey)
                    return;
                if (code2 !== 200 || !Array.isArray(results)) {
                    root.status = code2 === 404 ? "none" : "error";
                    if (root.status === "error")
                        root._loadedKey = "";
                    return;
                }
                const near = results.filter(x => !(r.length > 0) || Math.abs((x.duration ?? 0) - r.length) <= 5);
                const pick = near.find(x => x.syncedLyrics) ?? near.find(x => x.plainLyrics || x.instrumental) ?? null;
                if (pick)
                    root._found(r.key, pick);
                else
                    root.status = "none";
            });
        });
    }

    function _found(key, data) {
        const record = {
            synced: data.syncedLyrics ?? "",
            plain: data.plainLyrics ?? "",
            instrumental: data.instrumental === true
        };
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

    // "[mm:ss.xx] text" lines, possibly with several stamps each
    function _parseLrc(lrc) {
        const out = [];
        const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of lrc.split("\n")) {
            const times = [];
            let m;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(raw)) !== null)
                times.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            if (times.length === 0)
                continue;
            const text = raw.replace(/\[[^\]]*\]/g, "").trim();
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
