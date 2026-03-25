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

    property bool pickerVisible: false
    property string currentWallpaper: getState("wallpaper.current", "")
    property var wallpapers: []
    property var selectedWallpapers: []
    property bool confirmDelete: false
    property bool dynamicWallpaper: getState("wallpaper.dynamic", true)

    // Search and filtering
    property string searchQuery: ""
    property string currentCategory: "all" // "all" | "favorites" | "themes"
    property string themeFilter: "" // specific theme name when browsing theme wallpapers
    property var favorites: getState("wallpaper.favorites", [])

    // Theme wallpapers (files inside themes/{themeName}/)
    property var themeWallpapers: []

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"
    readonly property string themeWallpaperDir: wallpaperDir + "/themes"
    readonly property string themesConfigDir: Quickshell.env("HOME") + "/.local/themes"
    readonly property int selectedCount: selectedWallpapers.length

    // Active wallpaper paths per theme (for the Themes overview)
    readonly property var activeThemeWallpapers: {
        const result = [];
        const themes = ThemeService.availableThemes;
        const previews = ThemeService.themePreviews;
        for (let i = 0; i < themes.length; i++) {
            const name = themes[i];
            const preview = previews[name];
            if (preview && preview.wallpaper) {
                result.push(wallpaperDir + "/" + preview.wallpaper);
            }
        }
        return result;
    }

    // Filtered wallpaper list based on search + category
    readonly property var filteredWallpapers: {
        let list;

        if (currentCategory === "themes" && themeFilter) {
            // Show wallpapers from the theme's folder
            list = root.themeWallpapers;
        } else if (currentCategory === "themes") {
            // Overview: return theme names (delegate resolves to wallpaper paths)
            const themes = ThemeService.availableThemes;
            const previews = ThemeService.themePreviews;
            list = [];
            for (let i = 0; i < themes.length; i++) {
                const preview = previews[themes[i]];
                if (preview && preview.wallpaper)
                    list.push(themes[i]);
            }
        } else {
            list = root.wallpapers;

            if (currentCategory === "favorites")
                list = list.filter(w => favorites.includes(relativePath(w)));
        }

        // Search filter
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            if (currentCategory === "themes" && !themeFilter)
                list = list.filter(t => t.toLowerCase().includes(q));
            else
                list = list.filter(w => fileName(w).toLowerCase().includes(q));
        }

        return list;
    }

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
        addToThemeProc.command = ["bash", "-c", "mkdir -p '" + dest + "' && cp '" + sourcePath + "' '" + dest + "'"];
        addToThemeProc._themeName = themeName;
        addToThemeProc.running = true;
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

    function show() {
        refreshWallpapers();
        selectedWallpapers = [];
        confirmDelete = false;
        searchQuery = "";
        currentCategory = "all";
        themeFilter = "";
        themeWallpapers = [];
        pickerVisible = true;
    }

    function hide() {
        pickerVisible = false;
        selectedWallpapers = [];
        confirmDelete = false;
    }

    function toggle() {
        if (pickerVisible)
            hide();
        else
            show();
    }

    // Selection
    function isSelected(path: string): bool {
        return selectedWallpapers.includes(path);
    }

    function toggleSelection(path: string) {
        if (isSelected(path)) {
            selectedWallpapers = selectedWallpapers.filter(w => w !== path);
        } else {
            selectedWallpapers = [...selectedWallpapers, path];
        }
        confirmDelete = false;
    }

    function selectOnly(path: string) {
        selectedWallpapers = [path];
        confirmDelete = false;
    }

    function clearSelection() {
        selectedWallpapers = [];
        confirmDelete = false;
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

        hide();
    }

    function applySelected() {
        if (selectedWallpapers.length === 1) {
            setWallpaper(selectedWallpapers[0]);
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

    // Delete
    function requestDelete() {
        if (selectedWallpapers.length === 0)
            return;

        if (selectedWallpapers.length === 1) {
            // Delete directly if only one
            deleteSelected();
        } else {
            // Ask for confirmation if more than one
            confirmDelete = true;
        }
    }

    function deleteSelected() {
        if (selectedWallpapers.length === 0)
            return;

        let rmPaths = [];
        for (let i = 0; i < selectedWallpapers.length; i++) {
            const path = selectedWallpapers[i];
            rmPaths.push("'" + path + "'");
            root.wallpapers = root.wallpapers.filter(w => w !== path);
            root.themeWallpapers = root.themeWallpapers.filter(w => w !== path);
            if (currentWallpaper === path)
                currentWallpaper = "";
        }
        deleteWallpaperProc.command = ["sh", "-c", "rm " + rmPaths.join(" ")];
        deleteWallpaperProc.running = true;

        selectedWallpapers = [];
        confirmDelete = false;
    }

    function cancelDelete() {
        confirmDelete = false;
    }

    // Add
    function addWallpapers() {
        hide();
        addWallpapersProc.running = true;
    }

    function refreshWallpapers() {
        listWallpapersProc.running = true;
    }

    function getCurrentWallpaper() {
        getCurrentProc.running = true;
    }

    // ========================================================================
    // WATCHERS
    // ========================================================================

    // Refresh theme wallpapers when themeFilter changes
    onThemeFilterChanged: {
        if (themeFilter) {
            refreshThemeWallpapers(themeFilter);
        } else {
            themeWallpapers = [];
        }
        clearSelection();
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
            files=$(kdialog --multiple --getopenfilename ~ "Image Files (*.png *.jpg *.jpeg *.webp *.gif)")
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
                if (result === "done" || result === "cancelled") {
                    root.refreshWallpapers();
                    root.show();
                }
            }
        }
    }

    Process {
        id: addToThemeProc
        property string _themeName: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Wallpaper] Added wallpaper to theme:", _themeName);
                if (root.themeFilter === _themeName)
                    root.refreshThemeWallpapers(_themeName);
            } else {
                console.error("[Wallpaper] Failed to add wallpaper to theme");
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
