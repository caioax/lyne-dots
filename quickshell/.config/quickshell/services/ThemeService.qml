pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

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

    readonly property string themesDir: Quickshell.env("HOME") + "/.arch-dots/.data/themes"
    readonly property string kittyThemePath: Quickshell.env("HOME") + "/.config/kitty/current-theme.conf"
    readonly property string nvimThemePath: Quickshell.env("HOME") + "/.config/nvim/current-theme.txt"
    readonly property string fastfetchBaseLogo: Quickshell.env("HOME") + "/.config/fastfetch/arch-base.png"
    readonly property string fastfetchLogo: Quickshell.env("HOME") + "/.config/fastfetch/arch.png"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"

    property string currentThemeName: getState("theme.name", "tokyonight")
    property var availableThemes: []

    // Preview data: { "themeName": { name, palette: { background, accent, ... } } }
    property var themePreviews: ({})

    // The palette is the single source of truth for all colors
    // Config.qml reads from here
    property var palette: ({
            "background": "#1a1b26",
            "surface0": "#24283b",
            "surface1": "#292e42",
            "surface2": "#414868",
            "surface3": "#565f89",
            "text": "#c0caf5",
            "textReverse": "#1a1b26",
            "subtext": "#a9b1d6",
            "subtextReverse": "#565f89",
            "accent": "#7aa2f7",
            "success": "#9ece6a",
            "warning": "#e0af68",
            "error": "#f7768e",
            "muted": "#545c7e",
            "greyBlue": "#283457",
            "blueDark": "#16161e"
        })

    // Helper for Config.qml to read palette with fallback
    function color(key, fallback) {
        return palette[key] ?? fallback;
    }

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        listThemes();
    }

    // Load theme when state is ready
    Connections {
        target: StateService
        function onStateLoaded() {
            const themeName = root.currentThemeName;
            root.applyTheme(themeName);
        }
    }

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    function applyTheme(themeName) {
        console.log("[ThemeService] Loading theme:", themeName);
        loadThemeProc._themeName = themeName;
        loadThemeProc._buffer = "";
        loadThemeProc.command = ["cat", themesDir + "/" + themeName + ".json"];
        loadThemeProc.running = true;
    }

    function listThemes() {
        listThemesProc._collected = [];
        listThemesProc.running = true;
    }

    function loadPreviews() {
        previewProc._buffer = "";
        previewProc.running = true;
    }

    // ========================================================================
    // INTERNAL
    // ========================================================================

    function _applyThemeData(themeName, data) {
        // 1. Update palette (triggers Config.qml rebinding)
        if (data.palette) {
            root.palette = data.palette;
        }

        // 2. Update opacity in StateService (user preference, not theme-owned)
        if (data.opacity && data.opacity.background !== undefined) {
            setState("opacity.background", data.opacity.background);
        }

        // 3. Save theme name
        currentThemeName = themeName;
        setState("theme.name", themeName);

        // 4. Apply to Hyprland
        _applyHyprland(data.hyprland);

        // 5. Apply to Kitty
        _applyKitty(data.terminal);

        // 6. Apply to Neovim
        _applyNeovim(data.neovim);

        // 7. Apply to Fastfetch logo
        _applyFastfetch(data.palette);

        // 8. Apply theme wallpaper
        _applyWallpaper(data.wallpaper);

        console.log("[ThemeService] Theme applied:", data.name || themeName);
    }

    function _applyHyprland(hyprColors) {
        if (!hyprColors)
            return;

        const cmds = [];
        if (hyprColors.activeBorder)
            cmds.push("hyprctl keyword general:col.active_border 'rgba(" + hyprColors.activeBorder + ")'");
        if (hyprColors.inactiveBorder)
            cmds.push("hyprctl keyword general:col.inactive_border 'rgba(" + hyprColors.inactiveBorder + ")'");
        if (hyprColors.shadowColor)
            cmds.push("hyprctl keyword decoration:shadow:color 'rgba(" + hyprColors.shadowColor + ")'");

        if (cmds.length > 0) {
            hyprProc.command = ["bash", "-c", cmds.join(" && ")];
            hyprProc.running = true;
        }
    }

    function _applyKitty(terminal) {
        if (!terminal)
            return;

        const lines = ["# vim:ft=kitty", "# Auto-generated by ThemeService - Do not edit manually", "", "background " + terminal.background, "foreground " + terminal.foreground, "selection_background " + terminal.selectionBackground, "selection_foreground " + terminal.selectionForeground, "url_color " + terminal.urlColor, "cursor " + terminal.cursor, "cursor_text_color " + terminal.cursorTextColor, "", "# Tabs", "active_tab_background " + terminal.activeTabBackground, "active_tab_foreground " + terminal.activeTabForeground, "inactive_tab_background " + terminal.inactiveTabBackground, "inactive_tab_foreground " + terminal.inactiveTabForeground, "", "# Windows", "active_border_color " + terminal.activeBorderColor, "inactive_border_color " + terminal.inactiveBorderColor, "", "# Normal", "color0 " + terminal.color0, "color1 " + terminal.color1, "color2 " + terminal.color2, "color3 " + terminal.color3, "color4 " + terminal.color4, "color5 " + terminal.color5, "color6 " + terminal.color6, "color7 " + terminal.color7, "", "# Bright", "color8  " + terminal.color8, "color9  " + terminal.color9, "color10 " + terminal.color10, "color11 " + terminal.color11, "color12 " + terminal.color12, "color13 " + terminal.color13, "color14 " + terminal.color14, "color15 " + terminal.color15, "", "# Extended", "color16 " + terminal.color16, "color17 " + terminal.color17, ""];

        const content = lines.join("\n");

        kittyProc.command = ["bash", "-c", "cat > " + shellEscape(kittyThemePath) + " << 'THEME_EOF'\n" + content + "THEME_EOF\n" + "pkill -USR1 -x kitty 2>/dev/null; true"];
        kittyProc.running = true;
    }

    function _applyNeovim(neovimConfig) {
        if (!neovimConfig || !neovimConfig.colorscheme)
            return;

        const colorscheme = neovimConfig.colorscheme;

        // Write the colorscheme name to a file that Neovim reads on startup,
        // then send the command to all running Neovim instances via their sockets
        nvimProc.command = ["bash", "-c", "echo '" + colorscheme + "' > " + shellEscape(nvimThemePath) + " && " + "for sock in /run/user/$(id -u)/nvim.*.0; do " + "  [ -S \"$sock\" ] && nvim --server \"$sock\" --remote-send '<Cmd>colorscheme " + colorscheme + "<CR>' 2>/dev/null & " + "done; wait"];
        nvimProc.running = true;
    }

    function _applyWallpaper(wallpaperFile) {
        if (!wallpaperFile || !WallpaperService.dynamicWallpaper)
            return;

        const path = wallpaperDir + "/" + wallpaperFile;

        wallpaperProc.command = ["bash", "-c", "[ -f '" + path + "' ] && swww img '" + path + "'" + " --transition-type grow --transition-duration 1 --transition-fps 60 --transition-step 90" + " && echo '" + path + "' > '" + wallpaperDir + "/.current'" + " || echo '[ThemeService] Wallpaper not found: " + wallpaperFile + "' >&2"];
        wallpaperProc.running = true;
    }

    function _applyFastfetch(palette) {
        if (!palette || !palette.accent)
            return;

        fastfetchProc.command = ["magick", fastfetchBaseLogo, "-fill", palette.accent, "-colorize", "100", fastfetchLogo];
        fastfetchProc.running = true;
    }

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    Process {
        id: loadThemeProc
        property string _themeName: ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadThemeProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[ThemeService] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    root._applyThemeData(_themeName, data);
                } catch (e) {
                    console.error("[ThemeService] Failed to parse theme:", e);
                }
            } else {
                console.error("[ThemeService] Theme file not found:", _themeName);
            }
            _buffer = "";
        }
    }

    Process {
        id: listThemesProc
        command: ["bash", "-c", "ls -1 '" + root.themesDir + "'/*.json 2>/dev/null | sed 's|.*/||;s|\\.json$||' | sort"]
        property var _collected: []

        stdout: SplitParser {
            onRead: data => {
                const name = data.trim();
                if (name)
                    listThemesProc._collected.push(name);
            }
        }

        onExited: {
            root.availableThemes = listThemesProc._collected;
            console.log("[ThemeService] Available themes:", root.availableThemes.join(", "));
            root.loadPreviews();
        }
    }

    // Load all theme JSONs to extract preview palettes
    Process {
        id: previewProc
        command: ["bash", "-c", "for f in '" + root.themesDir + "'/*.json; do cat \"$f\"; echo '---THEME_SEP---'; done"]
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => previewProc._buffer += data + "\n"
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            const chunks = _buffer.split("---THEME_SEP---");
            var previews = {};

            for (let i = 0; i < chunks.length; i++) {
                const chunk = chunks[i].trim();
                if (!chunk)
                    continue;
                try {
                    const data = JSON.parse(chunk);
                    // Derive the file name from the theme list
                    if (i < root.availableThemes.length) {
                        previews[root.availableThemes[i]] = {
                            name: data.name || root.availableThemes[i],
                            palette: data.palette || {},
                            wallpaper: data.wallpaper || ""
                        };
                    }
                } catch (e) {
                    console.error("[ThemeService] Preview parse error:", e);
                }
            }

            root.themePreviews = previews;
            console.log("[ThemeService] Loaded previews for", Object.keys(previews).length, "themes");
            _buffer = "";
        }
    }

    Process {
        id: hyprProc
        stderr: SplitParser {
            onRead: data => console.error("[ThemeService:Hyprland] " + data)
        }
    }

    Process {
        id: nvimProc
        stderr: SplitParser {
            onRead: data => console.error("[ThemeService:Neovim] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[ThemeService] Neovim theme updated");
        }
    }

    Process {
        id: kittyProc
        stderr: SplitParser {
            onRead: data => console.error("[ThemeService:Kitty] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[ThemeService] Kitty theme updated");
        }
    }

    Process {
        id: wallpaperProc
        stderr: SplitParser {
            onRead: data => console.error("[ThemeService:Wallpaper] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[ThemeService] Theme wallpaper applied");
                WallpaperService.getCurrentWallpaper();
            }
        }
    }

    Process {
        id: fastfetchProc
        stderr: SplitParser {
            onRead: data => console.error("[ThemeService:Fastfetch] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[ThemeService] Fastfetch logo updated");
        }
    }
}
