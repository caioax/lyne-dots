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

    readonly property string themesDir: Quickshell.env("HOME") + "/.local/themes"
    readonly property string kittyThemePath: Quickshell.env("HOME") + "/.config/kitty/current-theme.conf"
    readonly property string nvimThemePath: Quickshell.env("HOME") + "/.config/nvim/current-theme.txt"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"

    // GTK/Qt paths
    readonly property string gtkColorsPath3: Quickshell.env("HOME") + "/.config/gtk-3.0/colors.css"
    readonly property string gtkColorsPath4: Quickshell.env("HOME") + "/.config/gtk-4.0/colors.css"
    readonly property string qtColorSchemePath: Quickshell.env("HOME") + "/.local/share/color-schemes/Lyne.colors"
    readonly property string matugenConfigPath: Quickshell.env("HOME") + "/.lyne-dots/.data/matugen/config.toml"
    readonly property string matugenCachePath: Quickshell.env("HOME") + "/.cache/matugen"

    property string currentThemeName: getState("theme.name", "tokyonight")
    property string themeMode: getState("theme.mode", "preset") // "preset" | "auto"
    property string colorScheme: getState("theme.scheme", "dark") // "dark" | "light"
    readonly property bool isAutoMode: themeMode === "auto"
    readonly property bool isDarkMode: colorScheme === "dark"
    readonly property string gtkThemeName: isDarkMode ? "adw-gtk3-dark" : "adw-gtk3"
    property var availableThemes: []

    // Themes filtered by current color scheme (dark shows dark, light shows light)
    readonly property var displayThemes: {
        var result = [];
        var themes = availableThemes;
        var previews = themePreviews;
        var scheme = colorScheme;
        for (var i = 0; i < themes.length; i++) {
            var name = themes[i];
            var preview = previews[name];
            var variant = (preview && preview.variant) ? preview.variant : "dark";
            if (variant === scheme)
                result.push(name);
        }
        // If no themes match (e.g. no light presets yet), show all
        if (result.length === 0)
            return themes;
        return result;
    }

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
            root.themeMode = root.getState("theme.mode", "preset");
            root.colorScheme = root.getState("theme.scheme", "dark");
            root.currentThemeName = root.getState("theme.name", "tokyonight");
            if (root.isAutoMode) {
                const wallpaper = root.getState("wallpaper.current", "");
                if (wallpaper) {
                    root.runMatugen(wallpaper);
                } else {
                    // Fallback to preset if no wallpaper
                    root.applyTheme(root.currentThemeName);
                }
            } else {
                root.applyTheme(root.currentThemeName);
            }
        }
    }

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    function applyTheme(themeName) {
        console.log("[Theme] Loading theme:", themeName);
        loadThemeProc._themeName = themeName;
        loadThemeProc._buffer = "";
        loadThemeProc.command = ["cat", themesDir + "/" + themeName + ".json"];
        loadThemeProc.running = true;
    }

    function setPresetMode(themeName) {
        console.log("[Theme] Switching to preset mode:", themeName);
        themeMode = "preset";
        setState("theme.mode", "preset");
        applyTheme(themeName);
    }

    function setAutoMode() {
        console.log("[Theme] Switching to auto (Material You) mode");
        themeMode = "auto";
        setState("theme.mode", "auto");
        const wallpaper = getState("wallpaper.current", "");
        if (wallpaper) {
            runMatugen(wallpaper);
        }
    }

    function setColorScheme(scheme: string) {
        console.log("[Theme] Switching color scheme to:", scheme);
        colorScheme = scheme;
        setState("theme.scheme", scheme);

        // Update GTK theme name and gsettings
        _applyGtkThemeSwitch();

        // Re-apply current colors with new scheme
        if (isAutoMode) {
            const wallpaper = getState("wallpaper.current", "");
            if (wallpaper)
                runMatugen(wallpaper);
        } else {
            // Load current theme JSON to find the pair for the new scheme
            _schemeSwitchProc._targetScheme = scheme;
            _schemeSwitchProc._buffer = "";
            _schemeSwitchProc.command = ["cat", themesDir + "/" + currentThemeName + ".json"];
            _schemeSwitchProc.running = true;
        }
    }

    function runMatugen(wallpaperPath: string) {
        console.log("[Theme] Running matugen on:", wallpaperPath);
        matugenProc._buffer = "";
        matugenProc.command = ["matugen", "image", wallpaperPath, "-m", colorScheme, "-c", matugenConfigPath];
        matugenProc.running = true;
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

        // 7. Apply theme wallpaper
        _applyWallpaper(data.wallpaper);

        // 8. Apply GTK/Qt colors from palette
        _applyGtkFromPalette(data.palette);
        _applyQtFromPalette(data.palette);

        console.log("[Theme] Theme applied:", data.name || themeName);
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

        wallpaperProc.command = ["bash", "-c", "[ -f '" + path + "' ] && swww img '" + path + "'" + " --transition-type grow --transition-duration 1 --transition-fps 60 --transition-step 90" + " || echo '[ThemeService] Wallpaper not found: " + wallpaperFile + "' >&2"];
        wallpaperProc.running = true;
    }

    function _clearGtkColors() {
        // Remove colors.css so adw-gtk3 uses its default light/dark colors
        gtkProc.command = ["bash", "-c", "rm -f " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4)];
        gtkProc.running = true;
    }

    function _clearQtColors() {
        // Remove custom Lyne.colors so Qt falls back to the Breeze scheme
        qtProc.command = ["bash", "-c", "rm -f " + shellEscape(qtColorSchemePath)];
        qtProc.running = true;
    }

    function _applyGtkThemeSwitch() {
        const theme = gtkThemeName;
        const scheme = isDarkMode ? "prefer-dark" : "prefer-light";
        gtkThemeSwitchProc.command = ["bash", "-c", "gsettings set org.gnome.desktop.interface gtk-theme " + shellEscape(theme) + " 2>/dev/null; " + "gsettings set org.gnome.desktop.interface color-scheme " + shellEscape(scheme) + " 2>/dev/null; true"];
        gtkThemeSwitchProc.running = true;
    }

    function _applyGtkFromPalette(pal) {
        if (!pal)
            return;

        var lines = [];
        lines.push("/* Auto-generated by ThemeService - Do not edit manually */");
        lines.push("");
        lines.push("@define-color accent_bg_color " + pal.accent + ";");
        lines.push("@define-color accent_color " + pal.accent + ";");
        lines.push("@define-color accent_fg_color " + pal.textReverse + ";");
        lines.push("");
        lines.push("@define-color window_bg_color " + pal.background + ";");
        lines.push("@define-color window_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color view_bg_color " + pal.background + ";");
        lines.push("@define-color view_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color headerbar_bg_color " + pal.surface0 + ";");
        lines.push("@define-color headerbar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color card_bg_color " + pal.surface0 + ";");
        lines.push("@define-color card_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color popover_bg_color " + pal.surface0 + ";");
        lines.push("@define-color popover_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color dialog_bg_color " + pal.surface1 + ";");
        lines.push("@define-color dialog_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color sidebar_bg_color " + pal.surface1 + ";");
        lines.push("@define-color sidebar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color destructive_bg_color " + pal.error + ";");
        lines.push("@define-color destructive_fg_color " + pal.textReverse + ";");
        lines.push("@define-color destructive_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color error_bg_color " + pal.error + ";");
        lines.push("@define-color error_fg_color " + pal.textReverse + ";");
        lines.push("@define-color error_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color success_bg_color " + pal.success + ";");
        lines.push("@define-color success_fg_color " + pal.textReverse + ";");
        lines.push("@define-color success_color " + pal.success + ";");
        lines.push("");
        lines.push("@define-color warning_bg_color " + pal.warning + ";");
        lines.push("@define-color warning_fg_color " + pal.textReverse + ";");
        lines.push("@define-color warning_color " + pal.warning + ";");
        lines.push("");

        const content = lines.join("\n");

        gtkProc.command = ["bash", "-c", "cat > " + shellEscape(gtkColorsPath3) + " << 'GTK_EOF'\n" + content + "GTK_EOF\n" + "cp " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4)];
        gtkProc.running = true;

        // Also update GTK base theme to match scheme
        _applyGtkThemeSwitch();
    }

    function _applyQtFromPalette(pal) {
        if (!pal)
            return;

        const bg = hexToRgb(pal.background);
        const s0 = hexToRgb(pal.surface0);
        const s1 = hexToRgb(pal.surface1);
        const fg = hexToRgb(pal.text);
        const ac = hexToRgb(pal.accent);
        const fgR = hexToRgb(pal.textReverse);
        const sub = hexToRgb(pal.subtext);
        const err = hexToRgb(pal.error);
        const warn = hexToRgb(pal.warning);
        const succ = hexToRgb(pal.success);
        const muted = hexToRgb(pal.muted);

        var lines = [];
        lines.push("[ColorEffects:Disabled]");
        lines.push("Color=56,56,56");
        lines.push("ColorAmount=0");
        lines.push("ColorEffect=0");
        lines.push("ContrastAmount=0.65");
        lines.push("ContrastEffect=1");
        lines.push("IntensityAmount=0.1");
        lines.push("IntensityEffect=2");
        lines.push("");
        lines.push("[ColorEffects:Inactive]");
        lines.push("ChangeSelectionColor=true");
        lines.push("Color=112,111,110");
        lines.push("ColorAmount=0.025");
        lines.push("ColorEffect=2");
        lines.push("ContrastAmount=0.1");
        lines.push("ContrastEffect=2");
        lines.push("Enable=false");
        lines.push("IntensityAmount=0");
        lines.push("IntensityEffect=0");
        lines.push("");

        // Helper: generate a color group
        var groups = ["Button", "Header", "Selection", "Tooltip", "View", "Window"];
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i];
            var bgColor = s0;
            var fgColor = fg;

            if (group === "View")
                bgColor = bg;
            if (group === "Header")
                bgColor = s1;
            if (group === "Window")
                bgColor = s0;
            if (group === "Tooltip")
                bgColor = s0;
            if (group === "Selection") {
                bgColor = ac;
                fgColor = fgR;
            }

            lines.push("[Colors:" + group + "]");
            lines.push("BackgroundAlternate=" + (group === "Selection" ? ac : s1));
            lines.push("BackgroundNormal=" + bgColor);
            lines.push("DecorationFocus=" + ac);
            lines.push("DecorationHover=" + ac);
            lines.push("ForegroundActive=" + ac);
            lines.push("ForegroundInactive=" + muted);
            lines.push("ForegroundLink=" + ac);
            lines.push("ForegroundNegative=" + err);
            lines.push("ForegroundNeutral=" + warn);
            lines.push("ForegroundNormal=" + fgColor);
            lines.push("ForegroundPositive=" + succ);
            lines.push("ForegroundVisited=" + sub);
            lines.push("");
        }

        lines.push("[General]");
        lines.push("ColorScheme=Lyne");
        lines.push("Name=Lyne");
        lines.push("");
        lines.push("[WM]");
        lines.push("activeBackground=" + s0);
        lines.push("activeBlend=" + bg);
        lines.push("activeForeground=" + fg);
        lines.push("inactiveBackground=" + bg);
        lines.push("inactiveBlend=" + bg);
        lines.push("inactiveForeground=" + muted);
        lines.push("");

        const content = lines.join("\n");

        qtProc.command = ["bash", "-c", "mkdir -p " + shellEscape(Quickshell.env("HOME") + "/.local/share/color-schemes") + " && " + "cat > " + shellEscape(qtColorSchemePath) + " << 'QT_EOF'\n" + content + "QT_EOF"];
        qtProc.running = true;
    }

    function hexToRgb(hex: string): string {
        if (!hex || hex.length < 7)
            return "0,0,0";
        var r = parseInt(hex.substring(1, 3), 16);
        var g = parseInt(hex.substring(3, 5), 16);
        var b = parseInt(hex.substring(5, 7), 16);
        return r + "," + g + "," + b;
    }

    function _loadAndApplyHyprlandColors() {
        loadHyprColorsProc._buffer = "";
        loadHyprColorsProc.command = ["cat", matugenCachePath + "/hyprland-colors.json"];
        loadHyprColorsProc.running = true;
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
            onRead: data => console.error("[Theme] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    root._applyThemeData(_themeName, data);
                } catch (e) {
                    console.error("[Theme] Failed to parse theme:", e);
                }
            } else {
                console.error("[Theme] Theme file not found:", _themeName);
            }
            _buffer = "";
        }
    }

    // Reads the current theme JSON to find its light/dark pair
    Process {
        id: _schemeSwitchProc
        property string _targetScheme: ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => _schemeSwitchProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:SchemeSwitch] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    var pairName = "";
                    if (_targetScheme === "light" && data.lightPair)
                        pairName = data.lightPair;
                    else if (_targetScheme === "dark" && data.darkPair)
                        pairName = data.darkPair;

                    if (pairName) {
                        console.log("[Theme] Switching to pair theme:", pairName);
                        root.applyTheme(pairName);
                    } else {
                        // No pair found — re-apply current theme (fallback)
                        console.log("[Theme] No pair for scheme, re-applying current theme");
                        root.applyTheme(root.currentThemeName);
                    }
                } catch (e) {
                    console.error("[Theme] Failed to read pair:", e);
                    root.applyTheme(root.currentThemeName);
                }
            } else {
                root.applyTheme(root.currentThemeName);
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
            console.log("[Theme] Available themes:", root.availableThemes.join(", "));
            root.loadPreviews();
        }
    }

    // Load all theme JSONs to extract preview palettes
    Process {
        id: previewProc
        command: ["bash", "-c", "for f in '" + root.themesDir + "'/*.json; do echo \"---THEME_NAME:$(basename \"$f\" .json)---\"; cat \"$f\"; echo '---THEME_SEP---'; done"]
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => previewProc._buffer += data + "\n"
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            const chunks = _buffer.split("---THEME_SEP---");
            var previews = {};

            for (var i = 0; i < chunks.length; i++) {
                var chunk = chunks[i].trim();
                if (!chunk)
                    continue;

                // Extract theme name from the header line
                var nameMatch = chunk.indexOf("---THEME_NAME:");
                if (nameMatch === -1)
                    continue;
                var nameEnd = chunk.indexOf("---", nameMatch + 14);
                if (nameEnd === -1)
                    continue;
                var themeName = chunk.substring(nameMatch + 14, nameEnd).trim();
                var jsonStr = chunk.substring(nameEnd + 3).trim();

                try {
                    var data = JSON.parse(jsonStr);
                    previews[themeName] = {
                        name: data.name || themeName,
                        palette: data.palette || {},
                        wallpaper: data.wallpaper || "",
                        variant: data.variant || "dark",
                        lightPair: data.lightPair || "",
                        darkPair: data.darkPair || ""
                    };
                } catch (e) {
                    console.error("[Theme] Preview parse error for " + themeName + ":", e);
                }
            }

            root.themePreviews = previews;
            console.log("[Theme] Loaded previews for", Object.keys(previews).length, "themes");
            _buffer = "";
        }
    }

    Process {
        id: hyprProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Hyprland] " + data)
        }
    }

    Process {
        id: nvimProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Neovim] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Neovim theme updated");
        }
    }

    Process {
        id: kittyProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Kitty] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Kitty theme updated");
        }
    }

    Process {
        id: wallpaperProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Wallpaper] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Theme] Theme wallpaper applied");
                WallpaperService.getCurrentWallpaper();
            }
        }
    }

    // GTK colors.css writer (preset mode)
    Process {
        id: gtkProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:GTK] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] GTK colors updated");
        }
    }

    // GTK theme switcher (gsettings)
    Process {
        id: gtkThemeSwitchProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:GtkSwitch] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] GTK theme switched to:", root.gtkThemeName);
        }
    }

    // Qt .colors writer (preset mode)
    Process {
        id: qtProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Qt] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Qt color scheme updated");
        }
    }

    // Matugen process (auto mode)
    Process {
        id: matugenProc
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => matugenProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.log("[Theme:Matugen] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Theme] Matugen finished, loading palette...");
                // Matugen has written all template outputs (gtk, kitty, qt, hyprland, palette)
                // Now load the QuickShell palette JSON
                loadMatugenPaletteProc._buffer = "";
                loadMatugenPaletteProc.command = ["cat", root.matugenCachePath + "/quickshell-palette.json"];
                loadMatugenPaletteProc.running = true;
            } else {
                console.error("[Theme] Matugen failed with exit code:", exitCode);
            }
            _buffer = "";
        }
    }

    // Load matugen-generated palette JSON
    Process {
        id: loadMatugenPaletteProc
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadMatugenPaletteProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:MatugenPalette] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const pal = JSON.parse(_buffer.trim());
                    root.palette = pal;
                    console.log("[Theme] Auto palette applied");

                    // Load and apply hyprland colors
                    root._loadAndApplyHyprlandColors();

                    // Reload kitty (matugen already wrote the theme file)
                    kittyReloadProc.running = true;
                } catch (e) {
                    console.error("[Theme] Failed to parse matugen palette:", e);
                }
            }
            _buffer = "";
        }
    }

    // Load hyprland colors from matugen output
    Process {
        id: loadHyprColorsProc
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadHyprColorsProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:HyprColors] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const colors = JSON.parse(_buffer.trim());
                    root._applyHyprland(colors);
                } catch (e) {
                    console.error("[Theme] Failed to parse hyprland colors:", e);
                }
            }
            _buffer = "";
        }
    }

    // Reload kitty after matugen writes the theme file
    Process {
        id: kittyReloadProc
        command: ["bash", "-c", "pkill -USR1 -x kitty 2>/dev/null; true"]
        stderr: SplitParser {
            onRead: data => console.error("[Theme:KittyReload] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Kitty reloaded (auto mode)");
        }
    }
}
