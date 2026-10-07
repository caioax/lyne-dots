pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.config
import "ThemeGenerator.js" as ThemeGenerator

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
    // Read by the Neovim "lyne" colorscheme (nvim/.config/nvim/lua/lyne/)
    readonly property string nvimPalettePath: Quickshell.env("HOME") + "/.cache/lyne/nvim.json"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"

    // GTK/Qt paths
    readonly property string gtkColorsPath3: Quickshell.env("HOME") + "/.config/gtk-3.0/colors.css"
    readonly property string gtkColorsPath4: Quickshell.env("HOME") + "/.config/gtk-4.0/colors.css"
    readonly property string qtColorSchemePath: Quickshell.env("HOME") + "/.local/share/color-schemes/Lyne.colors"
    readonly property string matugenConfigPath: Quickshell.env("HOME") + "/.lyne-dots/.data/matugen/config.toml"
    readonly property string matugenCachePath: Quickshell.env("HOME") + "/.cache/matugen"

    property string currentThemeName: getState("theme.name", "tokyonight")
    property string themeMode: getState("theme.mode", "preset") // "preset" | "auto"
    // The mode picked in Settings: the theme list shows its themes
    property string colorScheme: getState("theme.scheme", "dark") // "dark" | "light"
    readonly property bool isAutoMode: themeMode === "auto"
    // Variant of the preset on screen. GTK and Qt follow it, not
    // colorScheme: picking Light on a theme without a light version keeps
    // it until a light theme is chosen
    property string appliedVariant: "dark"
    readonly property string appliedScheme: isAutoMode ? colorScheme : appliedVariant
    readonly property bool isDarkMode: appliedScheme === "dark"
    // The current preset has no version for the picked mode
    readonly property string schemeHint: {
        if (isAutoMode || appliedVariant === colorScheme)
            return "";
        const name = themePreviews[currentThemeName]?.name ?? currentThemeName;
        return name + " has no " + colorScheme + " version: pick a " + colorScheme + " theme";
    }
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
        function onStateLoaded(keys) {
            // Writes to other keys (brightness, bar...) leave the theme be; in
            // auto mode the wallpaper drives it
            if (!keys.includes("theme") && !(root.isAutoMode && keys.includes("wallpaper")))
                return;
            root.themeMode = root.getState("theme.mode", "preset");
            root.colorScheme = root.getState("theme.scheme", "dark");
            // currentThemeName changes when the theme is applied, so a new
            // name from outside (lyne theme set) counts as another theme
            const name = root.getState("theme.name", "tokyonight");
            if (root.isAutoMode) {
                const wallpaper = root.getState("wallpaper.current", "");
                if (wallpaper) {
                    root.runMatugen(wallpaper);
                } else {
                    // Fallback to preset if no wallpaper
                    root.applyTheme(name, true);
                }
            } else {
                // Reloading the current preset keeps the user's opacity
                // and wallpaper
                root.applyTheme(name, true);
            }
        }
    }

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    // restoring: re-applying the saved preset (startup, state reload) must
    // not replace the opacity or the wallpaper the user picked; only
    // switching presets does
    function applyTheme(themeName, restoring = false) {
        console.log("[Theme] Loading theme:", themeName);
        loadThemeProc.run(["cat", themesDir + "/" + themeName + ".json"], {
            themeName,
            restoring
        });
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

        if (isAutoMode) {
            _applyGtkThemeSwitch();
            const wallpaper = getState("wallpaper.current", "");
            if (wallpaper)
                runMatugen(wallpaper);
            return;
        }
        // The current preset's version for that mode, if it has one;
        // otherwise it stays (schemeHint) until a theme of that mode is picked
        const pair = pairFor(currentThemeName, scheme);
        if (pair && pair !== currentThemeName)
            applyTheme(pair);
    }

    // The theme for `scheme` that goes with `name`: itself, the pair it
    // names, or the theme that names it (dark themes don't name their light
    // version; the light ones name their dark one). "" when there's none
    function pairFor(name: string, scheme: string): string {
        const previews = themePreviews;
        const variant = t => previews[t]?.variant ?? "dark";
        const preview = previews[name];
        if (!preview)
            return "";
        if (variant(name) === scheme)
            return name;
        const named = scheme === "light" ? preview.lightPair : preview.darkPair;
        if (named && previews[named])
            return named;
        return availableThemes.find(t => variant(t) === scheme && (scheme === "light" ? previews[t].darkPair : previews[t].lightPair) === name) ?? "";
    }

    function runMatugen(wallpaperPath: string) {
        console.log("[Theme] Running matugen on:", wallpaperPath);
        matugenProc.run(["matugen", "image", wallpaperPath, "-m", colorScheme, "-c", matugenConfigPath, "--prefer", "saturation"]);
    }

    function listThemes() {
        listThemesProc.run(listThemesProc.command);
    }

    function loadPreviews() {
        previewProc.run(previewProc.command);
    }

    // Writes ~/.local/themes/<slug>.json (atomically) and refreshes the list;
    // apply switches to it once written. wallpaperFrom: an image copied first
    // to ~/.local/wallpapers/<data.wallpaper>. Emits themeSaved or
    // themeSaveFailed
    function saveTheme(slug: string, data, apply: bool, wallpaperFrom = "") {
        const path = themesDir + "/" + slug + ".json";
        const wallpaperTo = wallpaperFrom !== "" && data.wallpaper ? wallpaperDir + "/" + data.wallpaper : "";
        saveThemeComponent.createObject(root, {
            slug: slug,
            apply: apply,
            command: ["sh", "-c", "if [ -n \"$3\" ]; then mkdir -p \"$(dirname \"$4\")\" && { [ \"$3\" -ef \"$4\" ] || cp -f \"$3\" \"$4\"; } || exit 1; fi; " + "mkdir -p \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh", JSON.stringify(data, null, 2), path, wallpaperFrom, wallpaperTo]
        });
    }

    // Removes a custom theme and its wallpaper folder. The theme in use can't
    // be deleted (switch first)
    function deleteTheme(slug: string) {
        const preview = themePreviews[slug];
        if (!preview || !preview.custom || slug === currentThemeName)
            return;
        deleteThemeProc.run(["sh", "-c", "rm -f -- \"$1\" && rm -rf -- \"$2\"", "sh", themesDir + "/" + slug + ".json", wallpaperDir + "/themes/" + slug]);
    }

    signal themeSaved(string slug)
    signal themeSaveFailed(string slug)

    // ========================================================================
    // INTERNAL
    // ========================================================================

    function _applyThemeData(themeName, data, restoring) {
        // 1. Update palette (triggers Config.qml rebinding)
        if (data.palette) {
            root.palette = data.palette;
        }

        // 2. Update opacity in StateService (user preference, not theme-owned)
        if (!restoring && data.opacity && data.opacity.background !== undefined) {
            setState("opacity.background", data.opacity.background);
        }

        // 3. Save theme name. Another theme chosen (not the saved one
        // reloaded) brings the list's mode along with its variant
        const variant = data.variant || "dark";
        if (themeName !== currentThemeName && variant !== colorScheme) {
            colorScheme = variant;
            setState("theme.scheme", variant);
        }
        appliedVariant = variant;
        currentThemeName = themeName;
        setState("theme.name", themeName);

        // 4. Apply to Hyprland
        _applyHyprland(data.hyprland);

        // 5. Apply to Kitty
        _applyKitty(data.terminal);

        // 6. Apply to Neovim
        _applyNeovim(data.palette, data.terminal);

        // 7. Zen Browser (profiles where it's on in Settings)
        ZenService.applyPalette(data.palette);

        // 8. Apply theme wallpaper
        if (!restoring)
            _applyWallpaper(data.wallpaper);

        // 9. Apply GTK/Qt colors from palette
        _applyGtkFromPalette(data.palette);
        _applyQtFromPalette(data.palette);

        console.log("[Theme] Theme applied:", data.name || themeName);
    }

    // Last colors sent to Hyprland; they only live in memory (hyprctl eval),
    // so they are sent again whenever Hyprland reloads its config
    property var _hyprColors: null
    // Border fade in progress, like the shell's (Config.themeTransition): the
    // colors it started from and when (ms)
    property var _hyprFadeFrom: null
    property real _hyprFadeStart: 0
    property int _hyprFadeDuration: 0
    readonly property var _hyprKeys: ["activeBorder", "inactiveBorder", "shadowColor"]

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded" && root._hyprColors)
                root._applyHyprland(root._hyprColors, false);
        }
    }

    // "rrggbbaa" (Hyprland) <-> QML color
    function _hyprToColor(hex: string): color {
        return Qt.color("#" + hex.substr(6, 2) + hex.substr(0, 6));
    }

    function _hyprHex(rgba): string {
        return rgba.map(v => {
            const n = Math.round(Math.min(1, Math.max(0, v)) * 255);
            return (n < 16 ? "0" : "") + n.toString(16);
        }).join("");
    }

    // Colors Hyprland shows now: mid-fade, the point the fade has reached
    function _hyprShown() {
        if (!_hyprFadeFrom || !_hyprColors)
            return _hyprColors;
        const t = (Date.now() - _hyprFadeStart) / _hyprFadeDuration;
        if (t >= 1)
            return _hyprColors;
        const shown = {};
        for (const key of _hyprKeys) {
            if (_hyprColors[key] && _hyprFadeFrom[key])
                shown[key] = _hyprHex(ThemeGenerator.mixOklab(ThemeGenerator.colorToOklab(_hyprToColor(_hyprFadeFrom[key])), ThemeGenerator.colorToOklab(_hyprToColor(_hyprColors[key])), _ease(t)));
            else
                shown[key] = _hyprColors[key];
        }
        return shown;
    }

    // Easing.InOutQuad, as the shell's fade
    function _ease(t: real): real {
        return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    }

    function _hyprLua(colors): string {
        const parts = [];
        const col = [];
        if (colors.activeBorder)
            col.push("active_border = \"rgba(" + colors.activeBorder + ")\"");
        if (colors.inactiveBorder)
            col.push("inactive_border = \"rgba(" + colors.inactiveBorder + ")\"");
        if (col.length > 0)
            parts.push("general = { col = { " + col.join(", ") + " } }");
        if (colors.shadowColor)
            parts.push("decoration = { shadow = { color = \"rgba(" + colors.shadowColor + ")\" } }");
        return "{ " + parts.join(", ") + " }";
    }

    // animate: fade from the colors shown now (theme switches); the first
    // colors since the shell started and config reloads apply at once. The
    // fade runs inside Hyprland (an hl.timer stepping through precomputed
    // colors), so it costs one hyprctl call
    function _applyHyprland(hyprColors, animate = true) {
        if (!hyprColors || !_hyprKeys.some(k => hyprColors[k]))
            return;
        const from = _hyprShown();
        const same = from && _hyprKeys.every(k => String(from[k] ?? "").toLowerCase() === String(hyprColors[k] ?? "").toLowerCase());
        // Re-applying the current theme (state reloads) mustn't cut a fade
        if (animate && same)
            return;
        _hyprColors = hyprColors;

        const steps = [];
        if (animate && from && Config.themeTransition) {
            _hyprFadeFrom = from;
            _hyprFadeStart = Date.now();
            _hyprFadeDuration = Config.themeTransitionDuration;
            const count = Math.max(1, Math.round(_hyprFadeDuration / 30));
            for (let i = 1; i <= count; i++) {
                const step = {};
                for (const key of _hyprKeys) {
                    if (hyprColors[key] && from[key])
                        step[key] = _hyprHex(ThemeGenerator.mixOklab(ThemeGenerator.colorToOklab(_hyprToColor(from[key])), ThemeGenerator.colorToOklab(_hyprToColor(hyprColors[key])), _ease(i / count)));
                    else
                        step[key] = hyprColors[key];
                }
                steps.push(_hyprLua(step));
            }
        } else {
            _hyprFadeFrom = null;
        }

        let lua = "if lyne_border_fade then lyne_border_fade:set_enabled(false); lyne_border_fade = nil end ";
        if (steps.length > 1) {
            lua += "local steps = { " + steps.join(", ") + " } local i = 0 " + "lyne_border_fade = hl.timer(function() i = i + 1 hl.config(steps[i]) " + "if i >= #steps and lyne_border_fade then lyne_border_fade:set_enabled(false); lyne_border_fade = nil end end, " + "{ timeout = " + Math.round(_hyprFadeDuration / steps.length) + ", type = \"repeat\" })";
        } else {
            lua += "hl.config(" + _hyprLua(hyprColors) + ")";
        }
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function _applyKitty(terminal) {
        if (!terminal)
            return;

        const lines = ["# vim:ft=kitty", "# Auto-generated by ThemeService - Do not edit manually", "", "background " + terminal.background, "foreground " + terminal.foreground, "selection_background " + terminal.selectionBackground, "selection_foreground " + terminal.selectionForeground, "url_color " + terminal.urlColor, "cursor " + terminal.cursor, "cursor_text_color " + terminal.cursorTextColor, "", "# Tabs", "active_tab_background " + terminal.activeTabBackground, "active_tab_foreground " + terminal.activeTabForeground, "inactive_tab_background " + terminal.inactiveTabBackground, "inactive_tab_foreground " + terminal.inactiveTabForeground, "", "# Windows", "active_border_color " + terminal.activeBorderColor, "inactive_border_color " + terminal.inactiveBorderColor, "", "# Normal", "color0 " + terminal.color0, "color1 " + terminal.color1, "color2 " + terminal.color2, "color3 " + terminal.color3, "color4 " + terminal.color4, "color5 " + terminal.color5, "color6 " + terminal.color6, "color7 " + terminal.color7, "", "# Bright", "color8  " + terminal.color8, "color9  " + terminal.color9, "color10 " + terminal.color10, "color11 " + terminal.color11, "color12 " + terminal.color12, "color13 " + terminal.color13, "color14 " + terminal.color14, "color15 " + terminal.color15, "", "# Extended", "color16 " + terminal.color16, "color17 " + terminal.color17, ""];

        const content = lines.join("\n");

        kittyProc.run(["bash", "-c", "cat > " + shellEscape(kittyThemePath) + " << 'THEME_EOF'\n" + content + "THEME_EOF\n" + "pkill -USR1 -x kitty 2>/dev/null; true"]);
    }


    // Writes the theme for the "lyne" colorscheme and reloads it in every
    // running Neovim through its server socket
    function _applyNeovim(pal, terminal) {
        if (!pal || !terminal)
            return;
        const content = JSON.stringify({
            palette: pal,
            terminal: terminal
        }, null, 2);
        const path = shellEscape(nvimPalettePath);
        const tmp = shellEscape(nvimPalettePath + ".tmp");

        nvimProc.run(["bash", "-c", "mkdir -p \"$(dirname " + path + ")\" && cat > " + tmp + " << 'THEME_EOF'\n" + content + "\nTHEME_EOF\n" + "mv " + tmp + " " + path + " && " + "for sock in /run/user/$(id -u)/nvim.*.0; do " + "  [ -S \"$sock\" ] && nvim --server \"$sock\" --remote-send '<Cmd>colorscheme lyne<CR>' 2>/dev/null & " + "done; wait"]);
    }

    function _applyWallpaper(wallpaperFile) {
        if (!wallpaperFile || !WallpaperService.dynamicWallpaper)
            return;
        WallpaperService.setWallpaper(wallpaperDir + "/" + wallpaperFile, "grow");
    }

    function _applyGtkThemeSwitch() {
        const theme = gtkThemeName;
        const scheme = isDarkMode ? "prefer-dark" : "prefer-light";
        gtkThemeSwitchProc.run(["bash", "-c", "gsettings set org.gnome.desktop.interface gtk-theme " + shellEscape(theme) + " 2>/dev/null; " + "gsettings set org.gnome.desktop.interface color-scheme " + shellEscape(scheme) + " 2>/dev/null; true"]);
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

        gtkProc.run(["bash", "-c", "cat > " + shellEscape(gtkColorsPath3) + " << 'GTK_EOF'\n" + content + "GTK_EOF\n" + "cp " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4)]);

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

        qtProc.run(["bash", "-c", "mkdir -p " + shellEscape(Quickshell.env("HOME") + "/.local/share/color-schemes") + " && " + "cat > " + shellEscape(qtColorSchemePath) + " << 'QT_EOF'\n" + content + "QT_EOF"]);
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
        loadHyprColorsProc.run(["cat", matugenCachePath + "/hyprland-colors.json"]);
    }

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    QueuedProcess {
        id: loadThemeProc
        property string _buffer: ""
        onStarted: _buffer = ""

        stdout: SplitParser {
            onRead: data => loadThemeProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme] " + data)
        }

        onExited: exitCode => {
            // Another theme was asked for meanwhile: only that one is applied
            if (superseded)
                return;
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    root._applyThemeData(request.themeName, data, request.restoring);
                } catch (e) {
                    console.error("[Theme] Failed to parse theme:", e);
                }
            } else {
                console.error("[Theme] Theme file not found:", request.themeName);
            }
        }
    }

    QueuedProcess {
        id: listThemesProc
        onStarted: _collected = []
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
    QueuedProcess {
        id: previewProc
        onStarted: _buffer = ""
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
                        terminal: data.terminal || {},
                        custom: data.custom === true,
                        seed: data.seed || null,
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
        }
    }

    Component {
        id: saveThemeComponent

        Process {
            id: saveProc

            property string slug
            property bool apply

            running: true
            stderr: SplitParser {
                onRead: data => console.error("[Theme:Save] " + data)
            }
            onExited: exitCode => {
                if (exitCode === 0) {
                    console.log("[Theme] Saved theme:", slug);
                    root.listThemes();
                    // Edits to the theme in use keep the user's opacity and
                    // wallpaper
                    if (apply && slug === root.currentThemeName && !root.isAutoMode)
                        root.applyTheme(slug, true);
                    else if (apply)
                        root.setPresetMode(slug);
                    root.themeSaved(slug);
                } else {
                    root.themeSaveFailed(slug);
                }
                destroy();
            }
        }
    }

    QueuedProcess {
        id: deleteThemeProc
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Theme deleted");
            root.listThemes();
        }
    }

    QueuedProcess {
        id: nvimProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Neovim] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Neovim theme updated");
        }
    }

    QueuedProcess {
        id: kittyProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Kitty] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Kitty theme updated");
        }
    }

    // GTK colors.css writer (preset mode)
    QueuedProcess {
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
    QueuedProcess {
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
    QueuedProcess {
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
    QueuedProcess {
        id: matugenProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => matugenProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.log("[Theme:Matugen] " + data)
        }

        onExited: exitCode => {
            // A newer wallpaper is queued: its palette is the one to load
            if (superseded)
                return;
            if (exitCode === 0) {
                console.log("[Theme] Matugen finished, loading palette...");
                // Matugen has written all template outputs (gtk, kitty, qt, hyprland, palette)
                // Now load the QuickShell palette JSON
                loadMatugenPaletteProc.run(["cat", root.matugenCachePath + "/quickshell-palette.json"]);
            } else {
                console.error("[Theme] Matugen failed with exit code:", exitCode);
            }
        }
    }

    // Load matugen-generated palette JSON
    QueuedProcess {
        id: loadMatugenPaletteProc
        onStarted: _buffer = ""
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
                    kittyReloadProc.run(["bash", "-c", "pkill -USR1 -x kitty 2>/dev/null; true"]);

                    // Neovim needs the terminal colors too
                    loadMatugenTerminalProc.run(["cat", root.matugenCachePath + "/terminal-colors.json"]);

                    ZenService.applyPalette(pal);
                } catch (e) {
                    console.error("[Theme] Failed to parse matugen palette:", e);
                }
            }
        }
    }

    // Load the matugen terminal colors (same as the kitty theme) for Neovim
    QueuedProcess {
        id: loadMatugenTerminalProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadMatugenTerminalProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:MatugenTerminal] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root._applyNeovim(root.palette, JSON.parse(_buffer.trim()));
                } catch (e) {
                    console.error("[Theme] Failed to parse matugen terminal colors:", e);
                }
            }
        }
    }

    // Load hyprland colors from matugen output
    QueuedProcess {
        id: loadHyprColorsProc
        onStarted: _buffer = ""
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
        }
    }

    // Reload kitty after matugen writes the theme file
    QueuedProcess {
        id: kittyReloadProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:KittyReload] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Kitty reloaded (auto mode)");
        }
    }
}
