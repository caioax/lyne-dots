pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import "../../components/"

// Size buttons of the Settings window: "extend vertically" cycles between
// the default size and the full usable height (a window resized by hand
// goes back to the default), "fill" covers the usable area of the monitor
// and toggles back. Their state comes from the window size and Hyprland, so
// a border drag or Super+Shift+F shows up too. The last mode (default, tall,
// fill) is saved in settings.windowSize and applied again on open
RowLayout {
    id: root

    required property FloatingWindow window
    // Same as the size of the window rule in hypr/conf/rules.lua
    required property size defaultSize
    property int buttonSize: Config.fontSizeIconSmall * 2

    spacing: Config.spacing

    // This window in Hyprland: address for the dispatches, fullscreen state
    readonly property HyprlandToplevel toplevel: Hyprland.toplevels.values.find(t => t.lastIpcObject?.pid === Quickshell.processId && t.title === root.window.title) ?? null
    readonly property HyprlandMonitor monitor: root.window.screen ? Hyprland.monitorFor(root.window.screen) : null
    // 0 none, 1 maximized, 2 fullscreen (Hyprland's own states)
    readonly property int hyprFullscreen: toplevel?.lastIpcObject?.fullscreen ?? 0
    readonly property bool ready: toplevel !== null && monitor?.lastIpcObject?.reserved !== undefined

    // Outer gaps as [top, right, bottom, left] (a number or a CSS-like list)
    readonly property var gaps: {
        const v = String(StateService.get("hyprland.general.gaps_out", 5)).trim().split(/[\s,]+/).map(Number);
        const top = v[0] || 0;
        const right = v[1] ?? top;
        const bottom = v[2] ?? top;
        return [top, right, bottom, v[3] ?? right];
    }
    readonly property int border: StateService.get("hyprland.general.border_size", 2)

    // Where a window fits on this monitor: without the bar (reserved), the
    // outer gaps and its border, like a tiled window
    readonly property rect workArea: {
        const s = root.window.screen;
        const r = monitor?.lastIpcObject?.reserved ?? [0, 0, 0, 0]; // left top right bottom
        if (!s)
            return Qt.rect(0, 0, 0, 0);
        const x = s.x + r[0] + gaps[3] + border;
        const y = s.y + r[1] + gaps[0] + border;
        return Qt.rect(x, y, s.width - r[0] - r[2] - gaps[1] - gaps[3] - border * 2, s.height - r[1] - r[3] - gaps[0] - gaps[2] - border * 2);
    }

    // default | tall | fill | custom, or maximized / fullscreen by Hyprland
    readonly property string mode: {
        if (hyprFullscreen === 1)
            return "maximized";
        if (hyprFullscreen === 2 || root.window.fullscreen)
            return "fullscreen";
        // Hyprland rounds sizes by a pixel here and there
        const near = (a, b) => Math.abs(a - b) <= 2;
        const w = root.window.width;
        const h = root.window.height;
        if (near(w, workArea.width) && near(h, workArea.height))
            return "fill";
        if (near(h, workArea.height))
            return "tall";
        if (near(w, defaultSize.width) && near(h, defaultSize.height))
            return "default";
        return "custom";
    }
    readonly property bool filled: mode === "fill" || mode === "maximized" || mode === "fullscreen"

    property bool _restored: false

    onReadyChanged: {
        if (!ready || _restored)
            return;
        _restored = true;
        const saved = StateService.get("settings.windowSize", "default");
        if (saved === "tall" || saved === "fill")
            apply(saved);
    }

    onModeChanged: {
        if (_restored)
            saveTimer.restart();
    }

    // Saved once the mode settles: Hyprland resizes a window it maximizes
    // before its fullscreen state is refreshed, which reads as "custom"
    Timer {
        id: saveTimer

        interval: Config.animDurationLong
        onTriggered: {
            const m = root.mode;
            if (m === "default" || m === "tall" || m === "fill")
                StateService.set("settings.windowSize", m);
            else if (m === "custom")
                StateService.set("settings.windowSize", "default");
        }
    }

    function toggleTall() {
        apply(mode === "default" ? "tall" : "default");
    }

    function toggleFill() {
        if (hyprFullscreen > 0)
            Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "${hyprFullscreen === 1 ? "maximized" : "fullscreen"}", window = "address:0x${toplevel.address}" })`);
        else
            apply(mode === "fill" ? "unfill" : "fill");
    }

    // Resizes and moves the window in one dispatch (resize alone keeps the
    // center). The position is read inside Hyprland, so it's always current:
    // x is kept (clamped to the monitor), and the geometry before "fill" is
    // stored there to go back to
    function apply(target: string) {
        if (!ready)
            return;
        const a = workArea;
        Hyprland.dispatch([
            "function()",
            `local sel, target = "address:0x${toplevel.address}", "${target}"`,
            `local a = { x = ${a.x}, y = ${a.y}, w = ${a.width}, h = ${a.height} }`,
            "local win = hl.get_window(sel)",
            "if not win then return end",
            "lyne_settings_prev = lyne_settings_prev or {}",
            "local x, y, w, h = win.at.x, win.at.y, win.size.x, win.size.y",
            "local prev = lyne_settings_prev[sel]",
            "if target == 'fill' then",
            "  lyne_settings_prev[sel] = { x = x, y = y, w = w, h = h }",
            "  x, y, w, h = a.x, a.y, a.w, a.h",
            "elseif target == 'tall' then",
            "  y, h = a.y, a.h",
            "elseif target == 'unfill' and prev then",
            "  x, y, w, h = prev.x, prev.y, prev.w, prev.h",
            "else",
            `  w, h = ${defaultSize.width}, ${defaultSize.height}`,
            "  y = a.y + (a.h - math.min(h, a.h)) // 2",
            "end",
            "w, h = math.min(w, a.w), math.min(h, a.h)",
            "x = math.max(a.x, math.min(x, a.x + a.w - w))",
            "y = math.max(a.y, math.min(y, a.y + a.h - h))",
            "hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = sel }))",
            "hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = sel }))",
            "end"
        ].join(" "));
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "fullscreen" || event.name === "openwindow")
                Hyprland.refreshToplevels();
            else if (event.name.startsWith("monitor") || event.name === "configreloaded")
                Hyprland.refreshMonitors();
        }
    }

    Connections {
        target: root.window

        function onScreenChanged() {
            Hyprland.refreshMonitors();
        }
    }

    // md-arrow_expand_vertical / md-arrow_collapse_vertical / md-restore
    SizeButton {
        icon: root.mode === "tall" ? "\u{f084d}" : root.mode === "custom" ? "\u{f099b}" : "\u{f084f}"
        tip: root.mode === "tall" ? "Default size" : root.mode === "custom" ? "Restore size" : "Extend vertically"
        active: root.mode === "tall"
        enabled: root.ready && !root.filled
        onClicked: root.toggleTall()
    }

    // md-fullscreen / md-fullscreen_exit
    SizeButton {
        icon: root.filled ? "\u{f0294}" : "\u{f0293}"
        tip: root.mode === "maximized" ? "Leave maximized" : root.mode === "fullscreen" ? "Leave fullscreen" : root.filled ? "Restore" : "Fill the screen"
        active: root.filled
        enabled: root.ready
        onClicked: root.toggleFill()
    }

    component SizeButton: Rectangle {
        id: button

        property string icon
        property string tip
        property bool active

        signal clicked

        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        radius: Config.radiusLarge
        opacity: enabled ? 1 : 0.4
        color: active ? Qt.alpha(Config.accentColor, mouse.containsMouse ? 0.25 : 0.15) : mouse.containsMouse ? Config.surface2Color : Config.surface1Color

        Behavior on color {
            enabled: !Config.themeTransitioning
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            color: button.active ? Config.accentColor : Config.textColor
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }

        QsToolTip {
            text: button.tip
            shown: mouse.containsMouse
        }
    }
}
