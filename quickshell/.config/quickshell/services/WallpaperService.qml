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
    property bool dynamicWallpaper: getState("wallpaper.dynamic", true)
    property var favorites: getState("wallpaper.favorites", [])

    // Files inside themes/{themeWallpapersFor}/ (see refreshThemeWallpapers)
    property var themeWallpapers: []
    property string themeWallpapersFor: ""

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"
    readonly property string themeWallpaperDir: wallpaperDir + "/themes"
    readonly property string themesConfigDir: Quickshell.env("HOME") + "/.local/themes"

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
            root.dynamicWallpaper = getState("wallpaper.dynamic", true);
            root.favorites = getState("wallpaper.favorites", []);
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

    // Theme wallpaper detection (old theme-{name}.jpg in root dir)
    function isThemeWallpaper(path: string): bool {
        return fileName(path).startsWith("theme-");
    }

    function themeNameFromPath(path: string): string {
        const name = fileName(path);
        const match = name.match(/^theme-(.+)\.\w+$/);
        return match ? match[1] : "";
    }

    // Theme wallpaper folder operations
    function addToTheme(sourcePath: string, themeName: string) {
        const dest = themeWallpaperDir + "/" + themeName + "/";
        // Prints "missing" when the theme's wallpaper is unset or its file is
        // gone, so the copy becomes the theme's wallpaper
        const current = themeWallpaperPath(themeName);
        // One process per call, so quick successive adds don't overwrite each other
        addToThemeComponent.createObject(root, {
            command: ["bash", "-c", "mkdir -p '" + dest + "' && cp '" + sourcePath + "' '" + dest + "' && { [ -n '" + current + "' ] && [ -f '" + current + "' ] || echo missing; }"],
            themeName: themeName,
            dest: dest + fileName(sourcePath)
        });
    }

    function setActiveThemeWallpaper(wallpaperPath: string, themeName: string) {
        // Get the relative path from wallpaperDir
        const relativePath = wallpaperPath.replace(wallpaperDir + "/", "");

        // Update theme JSON using jq
        const jsonPath = themesConfigDir + "/" + themeName + ".json";
        setActiveThemeProc.command = ["bash", "-c", "jq '.wallpaper = \"" + relativePath + "\"' '" + jsonPath + "' > '" + jsonPath + ".tmp' && mv '" + jsonPath + ".tmp' '" + jsonPath + "'"];
        setActiveThemeProc._wallpaperPath = wallpaperPath;
        setActiveThemeProc.running = true;
    }

    function refreshThemeWallpapers(themeName: string) {
        themeWallpapersFor = themeName;
        if (!themeName) {
            themeWallpapers = [];
            return;
        }
        listThemeWallpapersProc._themeName = themeName;
        listThemeWallpapersProc.command = ["bash", "-c", "mkdir -p '" + themeWallpaperDir + "/" + themeName + "' && " + "ls -1 '" + themeWallpaperDir + "/" + themeName + "'/*.{png,jpg,jpeg,webp,gif} 2>/dev/null | sort"];
        listThemeWallpapersProc.running = true;
    }

    // Get the active wallpaper filename for a theme from its JSON
    // Get which theme a wallpaper is active for (from overview list)
    function themeForActiveWallpaper(wallpaperPath: string): string {
        const relativePath = wallpaperPath.replace(wallpaperDir + "/", "");
        const themes = ThemeService.availableThemes;
        const previews = ThemeService.themePreviews;
        for (let i = 0; i < themes.length; i++) {
            const preview = previews[themes[i]];
            if (preview && preview.wallpaper === relativePath)
                return themes[i];
        }
        return "";
    }

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

    function isActiveThemeWallpaper(wallpaperPath: string, themeName: string): bool {
        const relativePath = wallpaperPath.replace(wallpaperDir + "/", "");
        const activeWallpaper = getThemeActiveWallpaper(themeName);
        return relativePath === activeWallpaper;
    }

    function toggleDynamicWallpaper() {
        dynamicWallpaper = !dynamicWallpaper;
        setState("wallpaper.dynamic", dynamicWallpaper);
    }

    // Apply wallpaper
    function setWallpaper(path: string) {
        const transition = transitions[Math.floor(Math.random() * transitions.length)];
        const duration = (Math.random() * 1.5 + 0.5).toFixed(1);

        setWallpaperProc.command = ["awww", "img", path, "--transition-type", transition, "--transition-duration", duration, "--transition-fps", "60", "--transition-step", "90"];
        setWallpaperProc.running = true;

        currentWallpaper = path;

        root.setState("wallpaper.current", path);

        // Persist for boot script
        writeCurrentProc.command = ["sh", "-c", "echo '" + path + "' > '" + wallpaperDir + "/.current'"];
        writeCurrentProc.running = true;

        // In auto mode, regenerate colors from the new wallpaper
        if (ThemeService.isAutoMode) {
            ThemeService.runMatugen(path);
        }
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

    Process {
        id: listThemeWallpapersProc
        property string _themeName: ""
        property var _buffer: []

        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim();
                if (trimmed && !trimmed.includes("*"))
                    listThemeWallpapersProc._buffer.push(trimmed);
            }
        }
        onStarted: listThemeWallpapersProc._buffer = []
        onExited: root.themeWallpapers = listThemeWallpapersProc._buffer
    }

    Process {
        id: setWallpaperProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("[Wallpaper] Wallpaper changed successfully");
            } else {
                console.error("[Wallpaper] Failed to change wallpaper");
            }
        }
    }

    Process {
        id: getCurrentProc
        command: ["awww", "query"]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/image:\s*(.+)/);
                if (match) {
                    root.currentWallpaper = match[1].trim();
                    root.setState("wallpaper.current", root.currentWallpaper);
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
        property string _wallpaperPath: ""

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
        id: deleteWallpaperProc
    }
}
