pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.services

Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }

    // ========================================================================
    // PALETTE (from ThemeService — defined in .data/themes/<name>.json)
    // ========================================================================
    readonly property color backgroundColor: ThemeService.color("background", "#1a1b26")
    readonly property real backgroundOpacity: getState("opacity.background", 0.9)
    readonly property color backgroundTransparentColor: Qt.alpha(backgroundColor, backgroundOpacity)
    readonly property color surface0Color: ThemeService.color("surface0", "#24283b")
    readonly property color surface1Color: ThemeService.color("surface1", "#292e42")
    readonly property color surface2Color: ThemeService.color("surface2", "#414868")
    readonly property color surface3Color: ThemeService.color("surface3", "#565f89")
    // Cards and panels inside the shell surfaces follow the background opacity
    readonly property color cardColor: Qt.alpha(surface0Color, backgroundOpacity)
    readonly property color cardHoverColor: Qt.alpha(surface1Color, backgroundOpacity)

    readonly property color textColor: ThemeService.color("text", "#c0caf5")
    readonly property color textReverseColor: ThemeService.color("textReverse", "#1a1b26")
    readonly property color subtextColor: ThemeService.color("subtext", "#a9b1d6")
    readonly property color subtextReverseColor: ThemeService.color("subtextReverse", "#565f89")

    readonly property color accentColor: ThemeService.color("accent", "#7aa2f7")
    readonly property color successColor: ThemeService.color("success", "#9ece6a")
    readonly property color warningColor: ThemeService.color("warning", "#e0af68")
    readonly property color errorColor: ThemeService.color("error", "#f7768e")

    readonly property color mutedColor: ThemeService.color("muted", "#545c7e")
    readonly property color greyBlueColor: ThemeService.color("greyBlue", "#283457")
    readonly property color blueDarkColor: ThemeService.color("blueDark", "#16161e")

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

    readonly property bool screenshotAnimations: getState("animations.screenshot", true)

    // ========================================================================
    // NOTIFICATIONS
    // ========================================================================
    readonly property int notifWidth: getState("notifications.width", 350)
    readonly property int notifImageSize: getState("notifications.imageSize", 40)
    readonly property int notifTimeout: getState("notifications.timeout", 5000)
    readonly property int notifSpacing: getState("notifications.spacing", 10)
    readonly property int notifMaxPopups: getState("notifications.maxPopups", 4)
}
