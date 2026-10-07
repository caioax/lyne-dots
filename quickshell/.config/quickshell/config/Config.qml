pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.services
import "../services/ThemeGenerator.js" as ThemeGenerator

Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }

    // ========================================================================
    // PALETTE (from ThemeService — defined in .data/themes/<name>.json)
    // ========================================================================
    // Colors shown by the shell. A theme switch fades them from the old
    // palette to the new one (mixed in OKLab); the first palette after a
    // (re)load and switches with the transition off apply at once. Colors
    // derived below (Qt.alpha, cards...) follow on their own
    readonly property color backgroundColor: _shown("background", "#1a1b26")
    readonly property real backgroundOpacity: _t >= 1 ? _opacityTarget : _opacityFrom + (_opacityTarget - _opacityFrom) * _t
    readonly property color backgroundTransparentColor: Qt.alpha(backgroundColor, backgroundOpacity)
    readonly property color surface0Color: _shown("surface0", "#24283b")
    readonly property color surface1Color: _shown("surface1", "#292e42")
    readonly property color surface2Color: _shown("surface2", "#414868")
    readonly property color surface3Color: _shown("surface3", "#565f89")
    // Cards and panels inside the shell surfaces follow the background opacity
    readonly property color cardColor: Qt.alpha(surface0Color, backgroundOpacity)
    readonly property color cardHoverColor: Qt.alpha(surface1Color, backgroundOpacity)

    readonly property color textColor: _shown("text", "#c0caf5")
    readonly property color textReverseColor: _shown("textReverse", "#1a1b26")
    readonly property color subtextColor: _shown("subtext", "#a9b1d6")

    readonly property color accentColor: _shown("accent", "#7aa2f7")
    readonly property color successColor: _shown("success", "#9ece6a")
    readonly property color warningColor: _shown("warning", "#e0af68")
    readonly property color errorColor: _shown("error", "#f7768e")

    readonly property color mutedColor: _shown("muted", "#545c7e")

    // Theme switches: fade the colors over animDurationLong times 1, 2 or 3
    readonly property bool themeTransition: getState("animations.themeTransition", true)
    readonly property int themeTransitionDuration: animDurationLong * ({
            "short": 1,
            "medium": 2,
            "long": 3
        }[getState("animations.themeTransitionLength", "medium")] ?? 2)
    // True while the colors fade: color Behaviors skip it and Canvases repaint
    readonly property bool themeTransitioning: paletteFade.running

    // Palette being shown, and the fade towards it: _fromLab/_toLab are
    // colorToOklab() per key, _t goes 0 -> 1
    property var _target: ({})
    property var _fromLab: ({})
    property var _toLab: ({})
    property real _t: 1
    property bool _paletteSeen: false
    property real _opacityFrom: 0.9
    readonly property real _opacityTarget: getState("opacity.background", 0.9)

    function _shown(key, fallback) {
        const to = _target[key] ?? fallback;
        if (_t >= 1 || !_fromLab[key] || !_toLab[key])
            return to;
        const c = ThemeGenerator.mixOklab(_fromLab[key], _toLab[key], _t);
        return Qt.rgba(c[0], c[1], c[2], c[3]);
    }

    function _setPalette(pal) {
        const first = !_paletteSeen;
        _paletteSeen = true;
        const same = Object.keys(pal).length === Object.keys(_target).length && Object.keys(pal).every(k => String(pal[k]).toLowerCase() === String(_target[k]).toLowerCase());
        if (same)
            return;
        if (first || !themeTransition) {
            paletteFade.stop();
            _t = 1;
            _target = pal;
            return;
        }
        // Start from what is on screen now, also mid-fade
        const from = {};
        const to = {};
        for (const key in pal) {
            to[key] = ThemeGenerator.colorToOklab(Qt.color(pal[key]));
            if (_target[key] !== undefined)
                from[key] = _t < 1 && _fromLab[key] && _toLab[key] ? ThemeGenerator.colorToOklab(_shown(key, pal[key])) : ThemeGenerator.colorToOklab(Qt.color(_target[key]));
        }
        _opacityFrom = backgroundOpacity;
        paletteFade.stop();
        _fromLab = from;
        _toLab = to;
        _target = pal;
        _t = 0;
        paletteFade.start();
    }

    Component.onCompleted: _target = ThemeService.palette

    Connections {
        target: ThemeService
        function onPaletteChanged() {
            root._setPalette(ThemeService.palette);
        }
    }

    NumberAnimation {
        id: paletteFade
        target: root
        property: "_t"
        from: 0
        to: 1
        duration: root.themeTransitionDuration
        easing.type: Easing.InOutQuad
    }

    // ========================================================================
    // WALLPAPER
    // ========================================================================
    readonly property bool dynamicWallpaper: getState("wallpaper.dynamic", true)

    // ========================================================================
    // GEOMETRY & LAYOUT
    // ========================================================================
    readonly property int barHeight: getState("bar.height", 32)
    readonly property bool barAutoHide: getState("bar.autoHide", true)
    // Screen edge the bar sits on: "top" or "bottom"
    readonly property bool barOnBottom: getState("bar.position", "top") === "bottom"
    // Layout template: "islands", "docked", "floating" or "docked-corners"
    readonly property string barStyle: getState("bar.style", "docked-corners")
    readonly property bool barIslands: barStyle === "islands"
    readonly property bool barFloating: barStyle === "floating"
    readonly property bool barCorners: barStyle === "docked-corners"
    // Gap between a floating bar and the screen edges
    readonly property int barMargin: barFloating ? getState("bar.margin", 8) : 0
    // Size of the concave corners hanging under a docked bar
    readonly property int barCornerSize: barCorners ? radiusLarge : 0
    // Screen space taken by the bar: popups and the exclusive zone start below it
    readonly property int barReservedHeight: barHeight + barMargin
    // Floating islands inside the bar and the buttons inside them
    readonly property int barIslandHeight: barHeight - padding
    readonly property int barButtonHeight: barIslandHeight - Math.round(padding * 2 / 3)
    // Bar center: "clock" (default: the clock alone, cava faintly behind it) or
    // "buttons" (the clock plus optional buttons, each opening its dashboard tab)
    readonly property bool barCenterClock: getState("bar.centerStyle", "clock") === "clock"
    readonly property bool barShowMedia: !barCenterClock && getState("bar.showMedia", true)
    readonly property bool barShowSystem: !barCenterClock && getState("bar.showSystem", false)
    readonly property bool barShowWeather: !barCenterClock && getState("bar.showWeather", false)
    // Launcher button: style "logo", "pill" or "compact"; icon "lyne" (the
    // lyne-dots logo) or "distro" (Nerd Font glyph from /etc/os-release)
    readonly property string barLauncherStyle: getState("bar.launcher.style", "logo")
    readonly property string barLauncherIcon: getState("bar.launcher.icon", "lyne")
    // The dot hops on hover and grows while the launcher is open
    readonly property bool barLauncherAnimate: getState("bar.launcher.animate", true)
    // Right/middle click: "none", "actions", "clipboard", "settings" or "power"
    readonly property string barLauncherRightClick: getState("bar.launcher.rightClick", "actions")
    readonly property string barLauncherMiddleClick: getState("bar.launcher.middleClick", "clipboard")
    // Workspaces shown in the bar (per monitor); the strip scrolls to reach the others
    readonly property int barWorkspaceCount: getState("bar.workspaces.count", 10)
    // Workspace indicator style: "pills", "numbers", "dots", "groups" or "icons"
    readonly property string barWorkspaceStyle: getState("bar.workspaces.style", "pills")
    // Only workspaces with windows (and the active one) in the strip
    readonly property bool barWorkspaceHideEmpty: getState("bar.workspaces.hideEmpty", false)
    // Mouse wheel over the strip switches workspace
    readonly property bool barWorkspaceScroll: getState("bar.workspaces.scroll", true)
    // Tray style: "row", "drawer", "overflow" or "pinned"
    readonly property string barTrayStyle: getState("bar.tray.style", "drawer")
    // Whether the drawer style is open (remembered across restarts)
    readonly property bool barTrayOpen: getState("bar.tray.open", false)
    // Item ids (StatusNotifierItem id) kept in the bar by the "pinned" style
    readonly property var barTrayPinned: getState("bar.tray.pinned", [])
    // Item ids never shown in the bar, and the user's item order
    readonly property var barTrayHidden: getState("bar.tray.hidden", [])
    readonly property var barTrayOrder: getState("bar.tray.order", [])
    // Red dot on items asking for attention (and on the button hiding them)
    readonly property bool barTrayAttention: getState("bar.tray.attention", true)
    // Icons tinted with the text color instead of their own colors
    readonly property bool barTrayMonochrome: getState("bar.tray.monochrome", false)
    // Title (and app text) on hover over a tray icon
    readonly property bool barTrayTooltips: getState("bar.tray.tooltips", true)
    // Quick Settings button style: "icons", "pill", "chips" or "minimal"
    readonly property string barQsStyle: getState("bar.quickSettings.style", "icons")
    // Keyboard layout button: auto (2+ layouts) | always | never
    readonly property string barKeyboardLayout: getState("bar.keyboardLayout", "auto")
    // Battery percentage next to the battery icon
    readonly property bool barQsBatteryPercent: getState("bar.quickSettings.batteryPercent", true)
    // Indicators the Quick Settings button may show, by id
    readonly property var barQsIndicators: ({
            "network": getState("bar.quickSettings.indicators.network", true),
            "bluetooth": getState("bar.quickSettings.indicators.bluetooth", true),
            "volume": getState("bar.quickSettings.indicators.volume", true),
            "mic": getState("bar.quickSettings.indicators.mic", true),
            "battery": getState("bar.quickSettings.indicators.battery", true),
            "notifications": getState("bar.quickSettings.indicators.notifications", true)
        })

    readonly property int radiusSmall: getState("geometry.radiusSmall", 5)
    readonly property int radius: getState("geometry.radius", 10)
    readonly property int radiusLarge: getState("geometry.radiusLarge", 15)
    readonly property int spacing: getState("geometry.spacing", 8)
    readonly property int padding: getState("geometry.padding", 6)

    // ========================================================================
    // TYPOGRAPHY
    // ========================================================================
    readonly property string font: getState("typography.font", "Caskaydia Cove Nerd Font")

    readonly property int fontSizeSmall: getState("typography.sizeSmall", 12)
    readonly property int fontSizeNormal: getState("typography.sizeNormal", 14)
    readonly property int fontSizeLarge: getState("typography.sizeLarge", 16)
    readonly property int fontSizeIconSmall: getState("typography.iconSmall", 18)
    readonly property int fontSizeIcon: getState("typography.icon", 22)
    readonly property int fontSizeIconLarge: getState("typography.iconLarge", 28)

    // ========================================================================
    // ANIMATIONS
    // ========================================================================
    readonly property int animDurationShort: getState("animations.short", 100)
    readonly property int animDuration: getState("animations.normal", 200)
    readonly property int animDurationLong: getState("animations.long", 400)

    // Popup/overlay entry+exit animation presets (used by AnimatedPopup.qml)
    readonly property real animPopupFromScale: 0.92
    readonly property int animPopupEasing: Easing.OutExpo

    // ========================================================================
    // SCREENSHOT
    // ========================================================================
    // Animates the window and screen selections (animations.screenshot is
    // the key it had before the Screenshot page)
    readonly property bool screenshotAnimations: getState("screenshot.animations", getState("animations.screenshot", true))
    // Darkening outside the selection, 1 = black (screenshot.dim is a percent)
    readonly property real screenshotDim: getState("screenshot.dim", 60) / 100
    // Mode the overlay opens in: "region" | "window" | "screen"
    readonly property string screenshotMode: getState("screenshot.mode", "region")
    // Dashed guides from the cursor / the selection to the screen edges
    readonly property bool screenshotGuides: getState("screenshot.guides", true)
    // Key hints under the control bar
    readonly property bool screenshotHints: getState("screenshot.hints", true)
    // Capture button / Enter: "save" (file + clipboard) | "copy" (clipboard
    // only) | "edit" (satty first)
    readonly property string screenshotAction: getState("screenshot.action", "save")
    // Empty = <XDG pictures dir>/Screenshots; ~ is expanded
    readonly property string screenshotFolder: getState("screenshot.folder", "")
    // date(1) format of the file name, without .png
    readonly property string screenshotFilename: getState("screenshot.filename", "Screenshot_%Y-%m-%d_%H-%M-%S")
    // Color mode: copied as "hex" (#rrggbb) | "rgb" | "hsl"
    readonly property string screenshotColorFormat: getState("screenshot.colorFormat", "hex")
    // Tesseract languages for Copy text, like ["eng", "por"]
    readonly property var screenshotOcrLanguages: getState("screenshot.ocrLanguages", ["eng"])
    // Screen dimming behind overlays: black on every theme
    readonly property color scrimColor: Qt.rgba(0, 0, 0, 1)

    // ========================================================================
    // NOTIFICATIONS
    // ========================================================================
    readonly property int notifWidth: getState("notifications.width", 350)
    readonly property int notifImageSize: getState("notifications.imageSize", 40)
    readonly property int notifTimeout: getState("notifications.timeout", 5000)
    readonly property int notifSpacing: getState("notifications.spacing", 10)
    readonly property int notifMaxPopups: getState("notifications.maxPopups", 4)

    // ========================================================================
    // OSD
    // ========================================================================
    // "pill" | "vertical" | "card" | "attached"
    readonly property string osdStyle: getState("osd.style", "attached")
    // Per style (OsdService.positions): pill bottom|top, vertical right|left,
    // card center|bottom, attached bar|opposite
    readonly property string osdPosition: getState("osd.position", "bottom")
    // "focused" | "all"
    readonly property string osdMonitor: getState("osd.monitor", "focused")
    readonly property int osdTimeout: getState("osd.timeout", 1500)
    // "shortcuts" (only the volume/brightness keys) | "any" (every change)
    readonly property string osdTrigger: getState("osd.trigger", "shortcuts")
    // Hovering keeps it open, the wheel changes the level, a click mutes
    readonly property bool osdInteractive: getState("osd.interactive", true)
    // Microphone mute key, and a switch of the default output
    readonly property bool osdMic: getState("osd.mic", true)
    readonly property bool osdDevice: getState("osd.device", true)
    readonly property bool osdLayout: getState("osd.layout", true)
    readonly property bool osdTiling: getState("osd.tiling", true)

    // ========================================================================
    // BRIGHTNESS
    // ========================================================================
    // "focused" (the focused monitor, or the laptop panel when it has no
    // control) | "all" (every monitor with control)
    readonly property string brightnessTarget: getState("brightness.target", "focused")
    // Brightness key step, 1 = 100% (brightness.step is a percent)
    readonly property real brightnessStep: getState("brightness.step", 5) / 100
    // External monitors over DDC/CI (ddcutil)
    readonly property bool brightnessDdc: getState("brightness.ddc", true)
    // Quick Settings: "focused" (one slider with a monitor switcher) | "all"
    readonly property string brightnessQuickSettings: getState("brightness.quickSettings", "focused")
    // Seconds between re-reads of external monitors, 0 = never
    readonly property int brightnessPollInterval: getState("brightness.pollInterval", 60)

    // ========================================================================
    // AUDIO
    // ========================================================================
    // Highest volume the shell sets, 1 = 100% (audio.maxVolume is a percent)
    readonly property real audioMaxVolume: getState("audio.maxVolume", 100) / 100
}
