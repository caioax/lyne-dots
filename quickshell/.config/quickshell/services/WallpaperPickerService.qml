pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "fuzzy.js" as Fuzzy

// State of the wallpaper picker (SUPER+B): which wallpapers it shows, in
// what order, and the one selected. Picking applies it and closes; the
// files and the applying itself are WallpaperService's
Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    // Screen edge it opens against: "bottom" or "top" (Settings › Wallpaper)
    readonly property string position: StateService.get("wallpaper.pickerPosition", "bottom")
    property string query: ""
    // Index into `items`
    property int selectedIndex: 0

    // "all" (the library, favorites first), "favorites" or "theme" (the
    // current theme's wallpapers). Back to "all" on each open
    property string filter: "all"
    readonly property var filters: [
        {
            id: "all",
            label: "All",
            icon: "\u{f02f9}"
        },
        {
            id: "favorites",
            label: "Favorites",
            icon: "\u{f02d1}"
        },
        {
            id: "theme",
            label: "Theme",
            icon: "\u{f03d8}"
        }
    ]

    // Themes made from the wallpaper (auto mode) have no folder of their own
    readonly property string themeName: ThemeService.isAutoMode ? "" : ThemeService.currentThemeName
    // Files in themes/{themeName}/, listed on each open. Its own list, not
    // WallpaperService.themeWallpapers, which follows the theme open in
    // Settings › Theme
    property var themeWallpapers: []

    readonly property var source: {
        switch (filter) {
        case "favorites":
            return WallpaperService.wallpapers.filter(w => WallpaperService.isFavorite(w));
        case "theme":
            return themeWallpapers;
        default:
            {
                const favorites = WallpaperService.wallpapers.filter(w => WallpaperService.isFavorite(w));
                return [...favorites, ...WallpaperService.wallpapers.filter(w => !WallpaperService.isFavorite(w))];
            }
        }
    }

    // Prepared names for the search (see fuzzy.js)
    readonly property var index: source.map(path => ({
                path: path,
                target: Fuzzy.prepare(displayName(path))
            }))

    // Search results as [{ path, positions }], best first; positions are the
    // matched chars of the name. Empty without a search
    readonly property var matches: {
        const terms = Fuzzy.normalize(query.trim()).text.split(/\s+/).filter(t => t !== "");
        if (terms.length === 0)
            return [];
        const results = [];
        for (const entry of index) {
            let total = 0;
            let positions = [];
            for (const t of terms) {
                const result = Fuzzy.score(t, entry.target, true);
                if (!result) {
                    total = -1;
                    break;
                }
                total += result.score;
                positions = positions.concat(result.positions);
            }
            if (total < 0)
                continue;
            // Favorites break ties
            results.push({
                path: entry.path,
                score: total + (WallpaperService.isFavorite(entry.path) ? 1 : 0),
                positions: positions
            });
        }
        return results.sort((a, b) => b.score - a.score || a.path.localeCompare(b.path));
    }

    // The wallpaper paths shown, in order
    readonly property var items: query.trim() === "" ? source : matches.map(m => m.path)

    readonly property string selectedPath: items[selectedIndex] ?? ""

    // Matched name chars per path, for highlighting
    readonly property var namePositions: matches.reduce((map, m) => {
        map[m.path] = m.positions;
        return map;
    }, {})

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    // File name without the extension
    function displayName(path: string): string {
        const name = WallpaperService.fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    // Name as styled text with the chars matched by the search in `color`
    function highlightedName(path: string, color): string {
        const name = displayName(path);
        const positions = new Set(namePositions[path] ?? []);
        const escape = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
        let out = "";
        for (let i = 0; i < name.length; i++)
            out += positions.has(i) ? "<b><font color=\"" + color + "\">" + escape(name[i]) + "</font></b>" : escape(name[i]);
        return out;
    }

    function show() {
        query = "";
        filter = "all";
        WallpaperService.refreshWallpapers();
        _listThemeWallpapers();
        visible = true;
        selectCurrent();
        _centerOnLoad = true;
    }

    function hide() {
        visible = false;
        query = "";
        _centerOnLoad = false;
    }

    function toggle() {
        if (visible)
            hide();
        else
            show();
    }

    function setFilter(id: string) {
        if (id === "theme" && themeName === "")
            return;
        filter = id;
        selectCurrent();
    }

    // Applies the wallpaper and closes
    function apply(path: string) {
        if (!path)
            return;
        console.log("[WallpaperPicker] Applying:", path);
        WallpaperService.setWallpaper(path);
        hide();
    }

    function applySelected() {
        apply(selectedPath);
    }

    // Makes it the current theme's wallpaper (copied into its folder) and
    // applies it. WallpaperService shows the theme's copy itself when the
    // theme brings its wallpaper
    function useForTheme(path: string) {
        if (!path || themeName === "")
            return;
        WallpaperService.setThemeWallpaper(path, themeName);
        if (WallpaperService.dynamicWallpaper)
            hide();
        else
            apply(path);
    }

    // The file dialog would open under the picker: close it first
    function addWallpapers() {
        hide();
        WallpaperService.addWallpapers();
    }

    function openSettings() {
        hide();
        SettingsService.open("wallpaper");
    }

    // --- Navigation ---

    function move(delta: int) {
        select(selectedIndex + delta);
    }

    function select(index: int) {
        _centerOnLoad = false;
        _clamp(index);
    }

    function selectFirst() {
        _centerOnLoad = false;
        selectedIndex = 0;
    }

    function selectLast() {
        select(items.length - 1);
    }

    // The wallpaper in use when it's shown, else the first one
    function selectCurrent() {
        selectedIndex = Math.max(0, items.indexOf(WallpaperService.currentWallpaper));
    }

    // ========================================================================
    // INTERNALS
    // ========================================================================

    function _clamp(index: int) {
        selectedIndex = Math.max(0, Math.min(items.length - 1, index));
    }

    function _listThemeWallpapers() {
        if (themeName === "") {
            themeWallpapers = [];
            return;
        }
        listThemeProc._buffer = [];
        listThemeProc.command = ["sh", "-c", "ls -1 \"$1\"/*.png \"$1\"/*.jpg \"$1\"/*.jpeg \"$1\"/*.webp \"$1\"/*.gif 2>/dev/null | sort", "sh", WallpaperService.themeWallpaperDir + "/" + themeName];
        listThemeProc.running = true;
    }

    Process {
        id: listThemeProc

        property var _buffer: []

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "")
                    listThemeProc._buffer.push(data.trim());
            }
        }
        onExited: {
            root.themeWallpapers = _buffer;
            if (root._centerOnLoad && root.filter === "theme")
                root.selectCurrent();
        }
    }

    // Set on open until the selection is moved: the lists are read again
    // then, and the wallpaper in use gets centered once it's in them
    property bool _centerOnLoad: false

    // A new search starts at the best match
    onQueryChanged: {
        _centerOnLoad = false;
        selectedIndex = 0;
    }

    // The path selected last, so the selection follows it when the list
    // changes under it (a favorite moving to the front, files added)
    property string _heldPath: ""

    onSelectedIndexChanged: _heldPath = items[selectedIndex] ?? ""

    onItemsChanged: {
        const index = items.indexOf(_heldPath);
        if (index >= 0)
            selectedIndex = index;
        else
            _clamp(selectedIndex);
    }

    Connections {
        target: WallpaperService

        function onWallpapersChanged() {
            if (root._centerOnLoad && root.filter !== "theme")
                root.selectCurrent();
        }
    }

    // Wallpapers generated for the theme (from the empty Theme filter)
    Connections {
        target: WallpaperService

        function onThemeWallpapersGenerated(themeName: string, ok: bool) {
            if (themeName === root.themeName)
                root._listThemeWallpapers();
        }
    }

    // A theme switch while open lists its wallpapers
    onThemeNameChanged: {
        if (visible)
            _listThemeWallpapers();
        if (themeName === "" && filter === "theme")
            filter = "all";
    }

    // ========================================================================
    // IPC — qs ipc call wallpapers toggle|open|close
    // ========================================================================

    IpcHandler {
        target: "wallpapers"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            root.toggle();
        }
    }
}
