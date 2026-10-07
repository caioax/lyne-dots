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

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property string currentWallpaper: getState("wallpaper.current", "")
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

    readonly property string generatorPath: Quickshell.env("HOME") + "/.lyne-dots/.data/wallpapers/generator/generate.py"
    readonly property var generatorScenes: ["lake", "waves", "contour"]
    // Theme whose lyne-dots wallpapers are being rendered ("" when idle)
    property string generatingFor: ""
    property int generatedCount: 0
    // Last error of the generator, per theme
    property var generateErrors: ({})

    signal themeWallpapersGenerated(string themeName, bool ok)

    // Available transitions in awww
    readonly property var transitions: ["wipe", "wave", "grow", "center", "outer", "any"]

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        refreshWallpapers();
        getCurrentWallpaper();
    }

    Connections {
        target: StateService

        function onStateLoaded() {
            root.currentWallpaper = getState("wallpaper.current", "");
            root.favorites = getState("wallpaper.favorites", []);
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

    // Renders lake, waves and contour in the theme's colors into its folder,
    // at the size of the largest screen. The contour one becomes the theme's
    // wallpaper when makeActive, or when the theme has none
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
        generatedCount = 0;
        generatingFor = themeName;
        generateProc._makeActive = makeActive;
        generateProc._error = "";
        // ~3 GB of RAM per 4K render: one at a time above 1440p
        generateProc.command = ["python3", generatorPath, "--theme-file", themesConfigDir + "/" + themeName + ".json", "--out", themeWallpaperDir, "--size", w + "x" + h, "--jobs", w * h > 2560 * 1440 ? "1" : "3"];
        generateProc.running = true;
    }

    // Apply wallpaper. A missing file is skipped and leaves the current one.
    // transition: an awww transition type, random when empty
    function setWallpaper(path: string, transition = "") {
        const type = transition || transitions[Math.floor(Math.random() * transitions.length)];
        const duration = transition ? "1" : (Math.random() * 1.5 + 0.5).toFixed(1);

        setWallpaperProc.run(["sh", "-c", "[ -f \"$1\" ] || { echo \"not found: $1\" >&2; exit 3; }; " + "awww img \"$1\" --transition-type \"$2\" --transition-duration \"$3\" --transition-fps 60 --transition-step 90", "sh", path, type, duration], path);
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

    // Add
    function addWallpapers() {
        if (!addWallpapersProc.running)
            addWallpapersProc.running = true;
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
        onExited: root.wallpapers = listWallpapersProc._buffer
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
        command: ["bash", "-c", `
            if command -v zenity >/dev/null; then
                files=$(zenity --file-selection --multiple --separator=$'\\n' --title="Add Wallpapers" --filename="$HOME/" --file-filter="Image Files | *.png *.jpg *.jpeg *.webp *.gif")
            else
                notify-send "Wallpaper" "Install zenity to add wallpapers"
                files=""
            fi
            if [ -n "$files" ]; then
                mkdir -p "${root.wallpaperDir}"
                echo "$files" | while read -r file; do
                    if [ -f "$file" ]; then
                        cp "$file" "${root.wallpaperDir}/"
                    fi
                done
                echo "done"
            else
                echo "cancelled"
            fi
        `]
        stdout: SplitParser {
            onRead: data => {
                const result = data.trim();
                if (result === "done")
                    root.refreshWallpapers();
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
                        root.setWallpaper(dest, "grow");
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

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().endsWith(".jpg"))
                    root.generatedCount++;
            }
        }
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
                console.log("[Wallpaper] Generated the lyne-dots wallpapers of", theme);
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
                errors[theme] = _error.includes("No module named") ? "Missing Python modules: run lyne update (python-numpy, python-pillow)" : _error.includes("rsvg-convert") ? "rsvg-convert not found: run lyne update (librsvg)" : (_error || "The generator failed");
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
