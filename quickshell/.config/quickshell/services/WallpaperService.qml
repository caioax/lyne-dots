pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.services
import "videoRules.js" as VideoRules

Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }
    function setState(path, value) {
        StateService.set(path, value);
    }

    function expandHome(path: string): string {
        return path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    // defaults.json names it as ~/.local/wallpapers/...: every user of it
    // (Image sources, sddm.sh) needs the absolute path
    property string currentWallpaper: expandHome(getState("wallpaper.current", ""))
    property var wallpapers: []
    // Switching theme also switches to the theme's wallpaper
    readonly property bool dynamicWallpaper: getState("wallpaper.dynamic", true)
    property var favorites: getState("wallpaper.favorites", [])

    // Files inside themes/{themeWallpapersFor}/ (see refreshThemeWallpapers)
    property var themeWallpapers: []
    property string themeWallpapersFor: ""

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"
    readonly property string themeWallpaperDir: wallpaperDir + "/themes"
    readonly property string themesConfigDir: Quickshell.env("HOME") + "/.local/themes"

    readonly property string generatorPath: Paths.dots + "/.data/wallpapers/generator/generate.py"
    // Theme whose lyne-dots wallpaper is being rendered ("" when idle)
    property string generatingFor: ""
    // Last error of the generator, per theme
    property var generateErrors: ({})

    signal themeWallpapersGenerated(string themeName, bool ok)
    // A library file got a new name (renameWallpaper)
    signal wallpaperRenamed(string from, string to)
    // Files Add copied into the library, once the list shows them
    signal wallpapersAdded(var paths)
    // Copied by the running Add, announced after the next listing
    property var _added: []
    // How many the running Add brought in, and the videos it couldn't use
    // (for its notification)
    property int _addedCount: 0
    property int _failed: 0
    // Images the running Add found already in the library
    property int _skipped: 0
    // Videos the running Add is scaling down to the screen (wallpapers-add.sh
    // --fit): the copy's path -> { poster (the source's), progress 0-100 }.
    // Settings shows a tile for each until the list has the copy
    property var fitting: ({})
    readonly property string _cancelFile: Quickshell.env("XDG_RUNTIME_DIR") + "/lyne-wallpapers-add.cancel"
    readonly property string _addScript: Qt.resolvedUrl("../scripts/wallpapers-add.sh").toString().replace("file://", "")

    // Wallpapers are images or videos (mp4, webm, mkv; wallpaper-set.sh plays
    // these through mpvpaper). A video stands as its poster, a frame of it,
    // wherever a still image is needed: posterOf/stillSource
    readonly property var videoExtensions: ["mp4", "webm", "mkv"]
    // Brace list for the ls listings (every case the Add script takes)
    readonly property string listGlob: "png,jpg,jpeg,webp,mp4,webm,mkv,PNG,JPG,JPEG,WEBP,MP4,WEBM,MKV"
    readonly property string posterScript: Qt.resolvedUrl("../scripts/wallpaper-poster.sh").toString().replace("file://", "")
    // video path -> its poster, filled as tiles ask for them
    property var posters: ({})
    property var _posterQueue: []
    // Small cached JPEGs for tiles (wallpaper-thumb.sh), so a list doesn't
    // decode every full-size image: path -> its thumbnail, "" when none
    // could be made, filled as tiles ask for them
    readonly property string thumbScript: Qt.resolvedUrl("../scripts/wallpaper-thumb.sh").toString().replace("file://", "")
    property var thumbs: ({})
    property var _thumbQueue: []

    readonly property string _setScript: Qt.resolvedUrl("../scripts/wallpaper-set.sh").toString().replace("file://", "")
    // Transition of every wallpaper change (Settings › Wallpaper): none, fade,
    // grow, wipe, wave or random, and fast, normal or slow. Its rows store
    // them in the state and set these
    property string transition: getState("wallpaper.transition", "fade")
    property string transitionSpeed: getState("wallpaper.transitionSpeed", "normal")

    // Pause rules of a video wallpaper (Settings › Wallpaper › Animated
    // wallpapers): every screen covered by a fullscreen window, the session
    // locked, on battery. Its rows store them in the state and set these.
    // On battery is unset (null) until chosen: on where there is a battery
    property bool pauseCovered: getState("wallpaper.pauseCovered", true)
    property bool pauseLocked: getState("wallpaper.pauseLocked", true)
    property var pauseOnBatteryStored: getState("wallpaper.pauseOnBattery", null)
    readonly property bool pauseOnBattery: VideoRules.batteryRule(pauseOnBatteryStored, BatteryService.hasBattery)
    // Frame rate cap of a video wallpaper (Settings › Wallpaper › Animated
    // wallpapers): 30, 15 or 0 for the video's own. Fewer frames, less work
    // for Hyprland redrawing every screen
    property int videoFps: getState("wallpaper.videoFps", 30)
    readonly property bool videoPlaying: isVideo(currentWallpaper)
    readonly property bool videoPaused: videoPlaying && VideoRules.shouldPause({
        covered: pauseCovered,
        locked: pauseLocked,
        battery: pauseOnBattery
    }, {
        screens: Quickshell.screens.map(s => s.name),
        coveredScreens: BarService.coveredScreens,
        locked: LockService.locked,
        onBattery: UPower.onBattery
    })
    readonly property string _videoScript: Qt.resolvedUrl("../scripts/wallpaper-video.sh").toString().replace("file://", "")

    // Sent on each change, and again once a new video has started
    onVideoPausedChanged: _sendPause()
    function _sendPause() {
        if (videoPlaying)
            pauseProc.run([_videoScript, "pause", videoPaused ? "yes" : "no"], null);
    }

    // Sent on each change, and again once a new video has started
    onVideoFpsChanged: _sendFps()
    function _sendFps() {
        if (videoPlaying)
            fpsProc.run([_videoScript, "fps", String(videoFps)], null);
    }

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        refreshWallpapers();
        getCurrentWallpaper();
        // A video kept playing across a shell restart, or started by the
        // boot script: it gets the state of the rules and the cap now
        Qt.callLater(_sendPause);
        Qt.callLater(_sendFps);
    }

    Connections {
        target: StateService

        function onStateLoaded(keys) {
            if (!keys.includes("wallpaper"))
                return;
            root.currentWallpaper = root.expandHome(getState("wallpaper.current", ""));
            root.favorites = getState("wallpaper.favorites", []);
            root.transition = getState("wallpaper.transition", "fade");
            root.transitionSpeed = getState("wallpaper.transitionSpeed", "normal");
            root.pauseCovered = getState("wallpaper.pauseCovered", true);
            root.pauseLocked = getState("wallpaper.pauseLocked", true);
            root.pauseOnBatteryStored = getState("wallpaper.pauseOnBattery", null);
            root.videoFps = getState("wallpaper.videoFps", 30);
            // What awww shows wins over the saved path
            root.getCurrentWallpaper();
        }
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    // Utility
    function fileName(path: string): string {
        return path.split("/").pop();
    }

    function isVideo(path: string): bool {
        const dot = path.lastIndexOf(".");
        return dot > 0 && videoExtensions.includes(path.substring(dot + 1).toLowerCase());
    }

    // The still image of a wallpaper: the path itself, or a video's poster
    // ("" until it's made; asking for it starts that)
    function posterOf(path: string): string {
        if (!path || !isVideo(path))
            return path;
        const poster = posters[path];
        if (poster === undefined)
            requestPoster(path);
        return poster ?? "";
    }

    // posterOf as an Image source
    function stillSource(path: string): string {
        const still = posterOf(path);
        return still ? "file://" + still : "";
    }

    // A tile's image source: the cached thumbnail ("" while it's made,
    // asking for it starts that), or the still image when none could be made
    function thumbSource(path: string): string {
        if (!path)
            return "";
        const thumb = thumbs[path];
        if (thumb === undefined) {
            requestThumb(path);
            return "";
        }
        return thumb ? "file://" + thumb : stillSource(path);
    }

    function requestThumb(path: string) {
        if (_thumbQueue.includes(path))
            return;
        _thumbQueue.push(path);
        // Tiles of a whole list ask in the same tick: one run for them all
        Qt.callLater(_makeThumbs);
    }

    function _makeThumbs() {
        if (thumbProc.running || _thumbQueue.length === 0)
            return;
        const batch = _thumbQueue;
        _thumbQueue = [];
        const size = Config.wallpaperThumbSize;
        thumbProc.command = [thumbScript, size.width + "x" + size.height, ...batch];
        thumbProc.running = true;
    }

    function requestPoster(path: string) {
        if (_posterQueue.includes(path))
            return;
        _posterQueue.push(path);
        // Tiles of a whole list ask in the same tick: one run for them all
        Qt.callLater(_makePosters);
    }

    function _makePosters() {
        if (posterProc.running || _posterQueue.length === 0)
            return;
        const batch = _posterQueue;
        _posterQueue = [];
        posterProc.command = ["sh", "-c", "s=$1; shift; for v; do p=$(\"$s\" \"$v\") && printf '%s\\t%s\\n' \"$v\" \"$p\"; done", "sh", posterScript, ...batch];
        posterProc.running = true;
    }

    function relativePath(path: string): string {
        return path.replace(wallpaperDir + "/", "");
    }

    // Favorites
    function toggleFavorite(path: string) {
        const rel = relativePath(path);
        let favs = [...favorites];
        const idx = favs.indexOf(rel);
        if (idx >= 0)
            favs.splice(idx, 1);
        else
            favs.push(rel);
        favorites = favs;
        setState("wallpaper.favorites", favs);
    }

    function isFavorite(path: string): bool {
        return favorites.includes(relativePath(path));
    }

    // Theme wallpaper folder operations. Copies the file into the theme's
    // folder; makeActive makes it the theme's wallpaper, otherwise it only
    // becomes that when the theme has none (or its file is gone)
    function addToTheme(sourcePath: string, themeName: string, makeActive = false) {
        const dir = themeWallpaperDir + "/" + themeName;
        const dest = dir + "/" + fileName(sourcePath);
        const current = themeWallpaperPath(themeName);
        // One process per call, so quick successive adds don't overwrite each other
        addToThemeComponent.createObject(root, {
            command: ["bash", "-c", "mkdir -p \"$1\" && { [ \"$2\" -ef \"$3\" ] || cp -f \"$2\" \"$3\"; } && " + "{ [ -n \"$4\" ] && [ -f \"$4\" ] || echo missing; }", "bash", dir, sourcePath, dest, current],
            themeName: themeName,
            dest: dest,
            adopt: makeActive
        });
    }

    // Makes the file the theme's wallpaper (copied into its folder) and shows
    // it right away when that theme is in use and brings its wallpaper
    function setThemeWallpaper(sourcePath: string, themeName: string) {
        const dest = themeWallpaperDir + "/" + themeName + "/" + fileName(sourcePath);
        addToTheme(sourcePath, themeName, true);
        if (themeName === ThemeService.currentThemeName && !ThemeService.isAutoMode && dynamicWallpaper && currentWallpaper !== dest)
            _applyWhenCopied[dest] = true;
    }

    // Theme wallpapers waiting for their copy before being shown
    property var _applyWhenCopied: ({})

    function setActiveThemeWallpaper(wallpaperPath: string, themeName: string) {
        // Get the relative path from wallpaperDir
        const relativePath = wallpaperPath.replace(wallpaperDir + "/", "");

        // Update theme JSON using jq
        const jsonPath = themesConfigDir + "/" + themeName + ".json";
        setActiveThemeProc.command = ["sh", "-c", "jq --arg w \"$1\" '.wallpaper = $w' \"$2\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh", relativePath, jsonPath];
        setActiveThemeProc.running = true;
    }

    function refreshThemeWallpapers(themeName: string) {
        themeWallpapersFor = themeName;
        if (!themeName) {
            themeWallpapers = [];
            return;
        }
        listThemeWallpapersProc.run(["bash", "-c", "mkdir -p '" + themeWallpaperDir + "/" + themeName + "' && " + "ls -1 '" + themeWallpaperDir + "/" + themeName + "'/*.{" + listGlob + "} 2>/dev/null | sort"]);
    }

    // The active wallpaper of a theme, from its JSON
    function getThemeActiveWallpaper(themeName: string): string {
        // This is read from the theme previews loaded by ThemeService
        const preview = ThemeService.themePreviews[themeName];
        if (preview && preview.wallpaper)
            return preview.wallpaper;
        return "";
    }

    function themeWallpaperPath(themeName: string): string {
        const rel = getThemeActiveWallpaper(themeName);
        return rel ? wallpaperDir + "/" + rel : "";
    }

    // Renders the contour scene in the theme's colors into its folder, at the
    // size of the largest screen. It becomes the theme's wallpaper when
    // makeActive, or when the theme has none
    function generateThemeWallpapers(themeName: string, makeActive = false) {
        if (generatingFor !== "")
            return;
        const size = largestScreen();
        const w = size.width, h = size.height;
        const errors = Object.assign({}, generateErrors);
        delete errors[themeName];
        generateErrors = errors;
        generatingFor = themeName;
        generateProc._makeActive = makeActive;
        generateProc._error = "";
        // ~3 GB of RAM per 4K render: one at a time above 1440p
        generateProc.command = ["python3", generatorPath, "--theme-file", themesConfigDir + "/" + themeName + ".json", "--out", themeWallpaperDir, "--size", w + "x" + h, "--jobs", w * h > 2560 * 1440 ? "1" : "3"];
        generateProc.running = true;
    }

    // The largest screen (1920x1080 at least), in logical pixels
    function largestScreen() {
        let w = 1920, h = 1080;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            if (screen.width * screen.height > w * h) {
                w = screen.width;
                h = screen.height;
            }
        }
        return Qt.size(w, h);
    }

    // The largest screen in device pixels: videos larger than that are
    // scaled down when added (wallpapers-add.sh --fit)
    function largestScreenPixels(): string {
        let w = 0, h = 0;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            const dpr = screen.devicePixelRatio || 1;
            const sw = Math.round(screen.width * dpr), sh = Math.round(screen.height * dpr);
            if (sw * sh > w * h) {
                w = sw;
                h = sh;
            }
        }
        return w > 0 ? w + "x" + h : "1920x1080";
    }

    // Apply wallpaper, with the transition set in Settings (wallpaper-set.sh).
    // A missing file is skipped and leaves the current one.
    function setWallpaper(path: string) {
        setWallpaperProc.run([_setScript, path, transition, transitionSpeed], path);
    }

    function _wallpaperApplied(path: string) {
        currentWallpaper = path;
        root.setState("wallpaper.current", path);

        // Persist for the boot script
        writeCurrentProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" > \"$2/.current\"", "sh", path, wallpaperDir];
        writeCurrentProc.running = true;

        // A video starts playing: paused at once when a rule says so, and
        // capped
        if (isVideo(path)) {
            if (videoPaused)
                _sendPause();
            _sendFps();
        }

        // In auto mode, regenerate colors from the new wallpaper
        if (ThemeService.isAutoMode)
            ThemeService.runMatugen(path);
    }

    function setRandomWallpaper() {
        if (wallpapers.length === 0)
            return;

        const available = wallpapers.filter(w => w !== currentWallpaper);
        if (available.length === 0)
            return;

        const randomIndex = Math.floor(Math.random() * available.length);
        setWallpaper(available[randomIndex]);
    }

    // Delete image files (library or theme folders)
    // The one in use is never deleted: it would stay on screen (a video
    // playing on without its pause rules) and come back on the next start
    function deleteWallpapers(paths) {
        paths = paths.filter(p => p !== currentWallpaper);
        if (paths.length === 0)
            return;

        wallpapers = wallpapers.filter(w => !paths.includes(w));
        // A new file under the same name gets its own poster
        const posters = Object.assign({}, root.posters);
        paths.forEach(p => delete posters[p]);
        root.posters = posters;
        const thumbs = Object.assign({}, root.thumbs);
        paths.forEach(p => delete thumbs[p]);
        root.thumbs = thumbs;
        themeWallpapers = themeWallpapers.filter(w => !paths.includes(w));

        const favs = favorites.filter(f => !paths.includes(wallpaperDir + "/" + f));
        if (favs.length !== favorites.length) {
            favorites = favs;
            setState("wallpaper.favorites", favs);
        }

        deleteWallpaperProc.command = ["rm", "-f", "--", ...paths];
        deleteWallpaperProc.running = true;
    }

    // Rename: a file of the library to NAME, its extension kept. Returns
    // why it can't be done ("" when it goes ahead, or there's nothing to do).
    // The new path takes the old one's place everywhere: the list, the
    // favorites, the thumbnail and poster already made, and the wallpaper in
    // use (saved, and in awww; a video keeps playing the file it opened)
    function renameError(path: string, name: string): string {
        name = name.trim();
        if (name.startsWith("."))
            return I18n.tr("A name can't start with a dot");
        if (name.includes("/"))
            return I18n.tr("A name can't have a slash");
        const target = _renamedPath(path, name);
        if (target !== path && wallpapers.includes(target))
            return I18n.tr("Another wallpaper has this name");
        return "";
    }

    function _renamedPath(path: string, name: string): string {
        const file = fileName(path);
        const dot = file.lastIndexOf(".");
        return path.substring(0, path.length - file.length) + name.trim() + (dot > 0 ? file.substring(dot) : "");
    }

    function renameWallpaper(path: string, name: string): string {
        const error = renameError(path, name);
        if (error !== "")
            return error;
        const target = _renamedPath(path, name);
        if (name.trim() === "" || target === path || !wallpapers.includes(path) || fitting[path] !== undefined)
            return "";
        renameComponent.createObject(root, {
            from: path,
            to: target
        });
        return "";
    }

    function _wallpaperRenamed(from: string, to: string) {
        wallpapers = wallpapers.map(w => w === from ? to : w);
        // The files made for it still show the same picture
        const thumbs = Object.assign({}, root.thumbs);
        if (thumbs[from] !== undefined)
            thumbs[to] = thumbs[from];
        delete thumbs[from];
        root.thumbs = thumbs;
        const posters = Object.assign({}, root.posters);
        if (posters[from] !== undefined)
            posters[to] = posters[from];
        delete posters[from];
        root.posters = posters;

        const rel = relativePath(from);
        if (favorites.includes(rel)) {
            const favs = favorites.map(f => f === rel ? relativePath(to) : f);
            favorites = favs;
            setState("wallpaper.favorites", favs);
        }

        if (currentWallpaper === from) {
            currentWallpaper = to;
            setState("wallpaper.current", to);
            writeCurrentProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" > \"$2/.current\"", "sh", to, wallpaperDir];
            writeCurrentProc.running = true;
            // awww reports the path it was given (getCurrentWallpaper): the
            // same picture again under its new name, without a transition
            if (!isVideo(to))
                Quickshell.execDetached(["awww", "img", to, "--transition-type", "none"]);
        }
        wallpaperRenamed(from, to);
        // Back in name order
        refreshWallpapers();
    }

    // Add: images (folder false) or every image in a folder and its
    // subfolders (folder true), picked in a dialog
    function addWallpapers(folder: bool) {
        if (addWallpapersProc.running)
            return;
        addWallpapersProc.folder = folder === true;
        addWallpapersProc.running = true;
    }

    // Stops scaling that video; the rest of the Add goes on
    function cancelFit(path: string) {
        if (fitting[path] === undefined)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" >> \"$2\"", "sh", path, _cancelFile]);
    }

    function _setFitting(path: string, entry) {
        const next = Object.assign({}, fitting);
        if (entry)
            next[path] = entry;
        else
            delete next[path];
        fitting = next;
    }

    // After a folder: how many came in; after images: only when none did
    // Videos that couldn't be read or scaled count too (cancelled ones don't)
    function _notifyAdded(folder: bool) {
        const added = _addedCount;
        if (!folder && _failed === 0 && (added > 0 || _skipped === 0))
            return;
        let title = I18n.trn("%n wallpaper added", "%n wallpapers added", added);
        if (!folder && added === 0)
            title = _failed > 0 ? I18n.trn("%n video couldn't be used", "%n videos couldn't be used", _failed) : I18n.tr("Already in the library");
        else if (folder && added === 0)
            title = _skipped > 0 || _failed > 0 ? I18n.tr("Nothing new in that folder") : I18n.tr("No wallpapers in that folder");
        const lines = [];
        if (folder && _skipped > 0)
            lines.push(I18n.trn("%n already in the library was skipped", "%n already in the library were skipped", _skipped));
        if (_failed > 0 && (folder || added > 0))
            lines.push(I18n.trn("%n video couldn't be used", "%n videos couldn't be used", _failed));
        Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "preferences-desktop-wallpaper", title, lines.join("\n")]);
    }

    // Asked while a listing runs (an Add copying many files): once more
    // after it, so the newest files are in
    function refreshWallpapers() {
        if (listWallpapersProc.running)
            _relist = true;
        else
            listWallpapersProc.running = true;
    }
    property bool _relist: false

    function getCurrentWallpaper() {
        getCurrentProc.running = true;
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    Process {
        id: listWallpapersProc
        property var _buffer: []
        command: ["bash", "-c", "ls -1 '" + root.wallpaperDir + "'/*.{" + root.listGlob + "} 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim();
                if (trimmed && !trimmed.includes("*"))
                    listWallpapersProc._buffer.push(trimmed);
            }
        }
        onStarted: listWallpapersProc._buffer = []
        onExited: {
            root.wallpapers = listWallpapersProc._buffer;
            // Scaled copies now listed lose their progress tile
            const done = Object.keys(root.fitting).filter(p => root.fitting[p].progress >= 100 && root.wallpapers.includes(p));
            done.forEach(p => root._setFitting(p, null));
            // Announced once listed; the rest wait for the next listing
            const added = root._added.filter(p => root.wallpapers.includes(p));
            root._added = root._added.filter(p => !added.includes(p));
            if (added.length > 0)
                root.wallpapersAdded(added);
            if (root._relist) {
                root._relist = false;
                Qt.callLater(root.refreshWallpapers);
            }
        }
    }

    QueuedProcess {
        id: listThemeWallpapersProc
        property var _buffer: []

        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim();
                if (trimmed && !trimmed.includes("*"))
                    listThemeWallpapersProc._buffer.push(trimmed);
            }
        }
        onStarted: listThemeWallpapersProc._buffer = []
        // Another theme's list was asked for meanwhile
        onExited: {
            if (!superseded)
                root.themeWallpapers = listThemeWallpapersProc._buffer;
        }
    }

    QueuedProcess {
        id: setWallpaperProc

        stderr: SplitParser {
            onRead: data => console.error("[Wallpaper] " + data)
        }
        onExited: (exitCode, exitStatus) => {
            // Wallpapers applied one after another: only the newest is saved
            // (state, .current, matugen)
            if (superseded)
                return;
            if (exitCode === 0) {
                console.log("[Wallpaper] Wallpaper changed successfully");
                root._wallpaperApplied(request);
            } else {
                console.error("[Wallpaper] Failed to change wallpaper");
            }
        }
    }

    // Pause or resume of the video wallpaper; only the newest one matters
    QueuedProcess {
        id: pauseProc
    }

    // Frame rate cap of the video wallpaper; only the newest one matters
    QueuedProcess {
        id: fpsProc
    }

    // "video<TAB>poster" lines from wallpaper-poster.sh, one per video
    Process {
        id: posterProc

        property var _found: ({})

        stdout: SplitParser {
            onRead: data => {
                const tab = data.indexOf("\t");
                if (tab > 0)
                    posterProc._found[data.substring(0, tab)] = data.substring(tab + 1);
            }
        }
        onStarted: _found = {}
        onExited: {
            // A video without a frame stays "" (asked once)
            const posters = Object.assign({}, root.posters);
            // ["sh", "-c", script, "sh", posterScript, ...videos]
            const asked = command.slice(5);
            for (const v of asked)
                posters[v] = _found[v] ?? "";
            root.posters = posters;
            Qt.callLater(root._makePosters);
        }
    }

    // "path<TAB>thumbnail" lines from wallpaper-thumb.sh
    Process {
        id: thumbProc

        property var _found: ({})

        stdout: SplitParser {
            onRead: data => {
                const tab = data.indexOf("\t");
                if (tab > 0)
                    thumbProc._found[data.substring(0, tab)] = data.substring(tab + 1);
            }
        }
        onStarted: _found = {}
        onExited: {
            // A file without a thumbnail stays "" (asked once)
            const thumbs = Object.assign({}, root.thumbs);
            // [script, size, ...paths]
            for (const p of command.slice(2))
                thumbs[p] = _found[p] ?? "";
            root.thumbs = thumbs;
            Qt.callLater(root._makeThumbs);
        }
    }

    // awww reports the resolved path; ~/.local/wallpapers is usually a
    // symlink, so map it back or relativePath() and the markers stop matching.
    // Under a video awww shows its poster or a frame of it
    // (wallpaper-set.sh): the saved path stays
    Process {
        id: getCurrentProc
        command: ["sh", "-c", "real=$(realpath \"$1\" 2>/dev/null); awww query | sed -n 's/.*image: //p' | head -n 1 | " + "while IFS= read -r p; do case \"$p\" in \"$real\"/*) p=\"$1/${p#\"$real\"/}\";; " + "*/lyne/wallpaper-posters/* | */lyne-wallpaper-frame.jpg) continue;; esac; printf '%s\\n' \"$p\"; done", "sh", root.wallpaperDir]
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path) {
                    root.currentWallpaper = path;
                    root.setState("wallpaper.current", path);
                }
            }
        }
    }

    Process {
        id: addWallpapersProc

        property bool folder: false

        onStarted: {
            root.fitting = {};
            root._added = [];
            root._addedCount = 0;
            root._failed = 0;
            root._skipped = 0;
        }
        // The dialog's texts come translated as $3..$7, the screen size to
        // fit videos to as $8; zenity prints one path per line, handed to the
        // script as its arguments
        command: ["bash", "-c", `
            if ! command -v zenity >/dev/null; then
                notify-send "$6" "$7"
                echo "cancelled"
                exit 0
            fi
            if [ "$2" = folder ]; then
                picked=$(zenity --file-selection --directory --title="$4" --filename="$HOME/")
            else
                picked=$(zenity --file-selection --multiple --separator=$'\\n' --title="$3" --filename="$HOME/" --file-filter="$5 | *.png *.jpg *.jpeg *.webp *.mp4 *.webm *.mkv *.PNG *.JPG *.JPEG *.WEBP *.MP4 *.WEBM *.MKV")
            fi
            if [ -z "$picked" ]; then
                echo "cancelled"
                exit 0
            fi
            mapfile -t paths <<<"$picked"
            rm -f "$LYNE_ADD_CANCEL"
            "$1" --fit "$8" "${root.wallpaperDir}" "\${paths[@]}"
            rm -f "$LYNE_ADD_CANCEL"
            echo "done"
        `, "bash", root._addScript, folder ? "folder" : "files", I18n.tr("Add wallpapers"), I18n.tr("Add a folder of wallpapers"), I18n.tr("Images and videos"), I18n.tr("Wallpaper"), I18n.tr("Install zenity to add wallpapers"), root.largestScreenPixels()]
        // Where cancelFit asks the script to stop a scaling
        environment: ({
                LYNE_ADD_CANCEL: root._cancelFile
            })
        stdout: SplitParser {
            onRead: data => {
                const result = data.trim();
                const tab = result.indexOf("\t");
                if (result.startsWith("added:")) {
                    const path = result.slice(6);
                    root._added = [...root._added, path];
                    root._addedCount++;
                    // A scaled video takes its place in the library now,
                    // not after the rest of the Add: its tile stays full
                    // until the list shows it
                    if (root.fitting[path] !== undefined) {
                        root._setFitting(path, Object.assign({}, root.fitting[path], {
                            progress: 100
                        }));
                        root.refreshWallpapers();
                    }
                } else if (result.startsWith("fitting:") && tab > 0) {
                    root._setFitting(result.substring(8, tab), {
                        poster: result.substring(tab + 1),
                        progress: 0
                    });
                } else if (result.startsWith("progress:") && tab > 0) {
                    const path = result.substring(9, tab);
                    if (root.fitting[path] !== undefined)
                        root._setFitting(path, Object.assign({}, root.fitting[path], {
                            progress: Number(result.substring(tab + 1))
                        }));
                } else if (result.startsWith("failed:") || result.startsWith("cancelled:")) {
                    if (result.startsWith("failed:"))
                        root._failed++;
                    root._setFitting(result.substring(result.indexOf(":") + 1), null);
                } else if (result.startsWith("skipped:")) {
                    root._skipped++;
                } else if (result === "done") {
                    root._notifyAdded(addWallpapersProc.folder);
                    root.refreshWallpapers();
                }
            }
        }
    }

    Component {
        id: addToThemeComponent

        Process {
            id: proc

            property string themeName
            property string dest
            property bool adopt: false

            running: true
            stdout: SplitParser {
                onRead: data => {
                    if (data.trim() === "missing")
                        proc.adopt = true;
                }
            }

            onExited: exitCode => {
                if (exitCode === 0) {
                    console.log("[Wallpaper] Added wallpaper to theme:", themeName);
                    if (adopt)
                        root.setActiveThemeWallpaper(dest, themeName);
                    if (root._applyWhenCopied[dest]) {
                        delete root._applyWhenCopied[dest];
                        root.setWallpaper(dest);
                    }
                    if (root.themeWallpapersFor === themeName)
                        root.refreshThemeWallpapers(themeName);
                } else {
                    console.error("[Wallpaper] Failed to add wallpaper to theme");
                }
                destroy();
            }
        }
    }

    Process {
        id: setActiveThemeProc
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Wallpaper] Theme wallpaper config updated");
                // Reload theme previews so the active marker updates
                ThemeService.loadPreviews();
            } else {
                console.error("[Wallpaper] Failed to update theme config");
            }
        }
    }

    Process {
        id: writeCurrentProc
    }

    Process {
        id: generateProc

        property bool _makeActive: false
        property string _error: ""

        stderr: SplitParser {
            onRead: data => {
                console.error("[Wallpaper:Generate] " + data);
                if (data.trim() !== "")
                    generateProc._error = data.trim();
            }
        }
        onExited: exitCode => {
            const theme = root.generatingFor;
            const ok = exitCode === 0;
            if (ok) {
                console.log("[Wallpaper] Generated the lyne-dots wallpaper of", theme);
                const contour = root.themeWallpaperDir + "/" + theme + "/lyne-" + theme + "-contour.jpg";
                const current = root.themeWallpaperPath(theme);
                if (_makeActive || current === "")
                    root.setThemeWallpaper(contour, theme);
                else
                    // Also adopts it when the configured file is gone
                    root.addToTheme(contour, theme);
                if (root.themeWallpapersFor === theme)
                    root.refreshThemeWallpapers(theme);
            } else {
                const errors = Object.assign({}, root.generateErrors);
                // A missing module is the usual cause: name the package
                // English, shown with I18n.translate (the generator's own output as it is)
                errors[theme] = _error.includes("No module named") ? I18n.noop("Missing Python modules: run lyne update (python-numpy, python-pillow)") : _error.includes("rsvg-convert") ? I18n.noop("rsvg-convert not found: run lyne update (librsvg)") : (_error || I18n.noop("The generator failed"));
                root.generateErrors = errors;
            }
            root.generatingFor = "";
            root.themeWallpapersGenerated(theme, ok);
        }
    }

    Process {
        id: deleteWallpaperProc
    }

    // One per rename: refuses to replace a file that showed up meanwhile
    Component {
        id: renameComponent

        Process {
            id: renameProc

            required property string from
            required property string to

            command: ["sh", "-c", "[ -e \"$2\" ] && exit 3; mv -T -- \"$1\" \"$2\"", "sh", from, to]
            running: true
            onExited: code => {
                if (code === 0)
                    root._wallpaperRenamed(renameProc.from, renameProc.to);
                else {
                    console.error("[Wallpaper] Couldn't rename", renameProc.from, "to", renameProc.to);
                    root.refreshWallpapers();
                }
                renameProc.destroy();
            }
        }
    }
}
