pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

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
    // Files Add copied into the library, once the list shows them
    signal wallpapersAdded(var paths)
    // Copied by the running Add, announced after the next listing
    property var _added: []
    // Images the running Add found already in the library
    property int _skipped: 0
    readonly property string _addScript: Qt.resolvedUrl("../scripts/wallpapers-add.sh").toString().replace("file://", "")

    readonly property string _setScript: Qt.resolvedUrl("../scripts/wallpaper-set.sh").toString().replace("file://", "")
    // Transition of every wallpaper change (Settings › Wallpaper): none, fade,
    // grow, wipe, wave or random, and fast, normal or slow. Its rows store
    // them in the state and set these
    property string transition: getState("wallpaper.transition", "fade")
    property string transitionSpeed: getState("wallpaper.transitionSpeed", "normal")

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        refreshWallpapers();
        getCurrentWallpaper();
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
        listThemeWallpapersProc.run(["bash", "-c", "mkdir -p '" + themeWallpaperDir + "/" + themeName + "' && " + "ls -1 '" + themeWallpaperDir + "/" + themeName + "'/*.{png,jpg,jpeg,webp,gif} 2>/dev/null | sort"]);
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
        let w = 1920, h = 1080;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            if (screen.width * screen.height > w * h) {
                w = screen.width;
                h = screen.height;
            }
        }
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
    function deleteWallpapers(paths) {
        if (paths.length === 0)
            return;

        wallpapers = wallpapers.filter(w => !paths.includes(w));
        themeWallpapers = themeWallpapers.filter(w => !paths.includes(w));
        if (paths.includes(currentWallpaper))
            currentWallpaper = "";

        const favs = favorites.filter(f => !paths.includes(wallpaperDir + "/" + f));
        if (favs.length !== favorites.length) {
            favorites = favs;
            setState("wallpaper.favorites", favs);
        }

        deleteWallpaperProc.command = ["rm", "-f", "--", ...paths];
        deleteWallpaperProc.running = true;
    }

    // Add: images (folder false) or every image in a folder and its
    // subfolders (folder true), picked in a dialog
    function addWallpapers(folder: bool) {
        if (addWallpapersProc.running)
            return;
        addWallpapersProc.folder = folder === true;
        addWallpapersProc.running = true;
    }

    // After a folder: how many came in; after images: only when none did
    function _notifyAdded(folder: bool) {
        const added = _added.length;
        if (!folder && (added > 0 || _skipped === 0))
            return;
        let title = I18n.trn("%n wallpaper added", "%n wallpapers added", added);
        if (!folder)
            title = I18n.tr("Already in the library");
        else if (added === 0)
            title = _skipped > 0 ? I18n.tr("Nothing new in that folder") : I18n.tr("No images in that folder");
        const body = folder && _skipped > 0 ? I18n.trn("%n already in the library was skipped", "%n already in the library were skipped", _skipped) : "";
        Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "preferences-desktop-wallpaper", title, body]);
    }

    function refreshWallpapers() {
        listWallpapersProc.running = true;
    }

    function getCurrentWallpaper() {
        getCurrentProc.running = true;
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    Process {
        id: listWallpapersProc
        property var _buffer: []
        command: ["bash", "-c", "ls -1 '" + root.wallpaperDir + "'/*.{png,jpg,jpeg,webp,gif} 2>/dev/null | sort"]
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
            const added = root._added.filter(p => root.wallpapers.includes(p));
            root._added = [];
            if (added.length > 0)
                root.wallpapersAdded(added);
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

    // awww reports the resolved path; ~/.local/wallpapers is usually a
    // symlink, so map it back or relativePath() and the markers stop matching
    Process {
        id: getCurrentProc
        command: ["sh", "-c", "real=$(realpath \"$1\" 2>/dev/null); awww query | sed -n 's/.*image: //p' | head -n 1 | " + "while IFS= read -r p; do case \"$p\" in \"$real\"/*) p=\"$1/${p#\"$real\"/}\";; esac; printf '%s\\n' \"$p\"; done", "sh", root.wallpaperDir]
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
            root._added = [];
            root._skipped = 0;
        }
        // The dialog's texts come translated as $3..$7; zenity prints one
        // path per line, handed to the script as its arguments
        command: ["bash", "-c", `
            if ! command -v zenity >/dev/null; then
                notify-send "$6" "$7"
                echo "cancelled"
                exit 0
            fi
            if [ "$2" = folder ]; then
                picked=$(zenity --file-selection --directory --title="$4" --filename="$HOME/")
            else
                picked=$(zenity --file-selection --multiple --separator=$'\\n' --title="$3" --filename="$HOME/" --file-filter="$5 | *.png *.jpg *.jpeg *.webp *.gif")
            fi
            if [ -z "$picked" ]; then
                echo "cancelled"
                exit 0
            fi
            mapfile -t paths <<<"$picked"
            "$1" "${root.wallpaperDir}" "\${paths[@]}"
            echo "done"
        `, "bash", root._addScript, folder ? "folder" : "files", I18n.tr("Add wallpapers"), I18n.tr("Add a folder of wallpapers"), I18n.tr("Images"), I18n.tr("Wallpaper"), I18n.tr("Install zenity to add wallpapers")]
        stdout: SplitParser {
            onRead: data => {
                const result = data.trim();
                if (result.startsWith("added:")) {
                    root._added = [...root._added, result.slice(6)];
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
}
