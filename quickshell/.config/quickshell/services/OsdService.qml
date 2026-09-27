pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// State of the on-screen display. show(kind) opens it for osd.timeout ms; the
// value, mute state and icon are read live from the services, so holding a
// key updates the OSD in place
Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    // Target state: the overlay animates in and out following it
    property bool shown: false
    // Shown, or still playing the exit animation: keeps the window alive
    readonly property bool mapped: shown || exitTimer.running
    property string kind: "volume" // "volume" | "brightness"
    // Monitor focused when the OSD opened (osd.monitor "focused")
    property string screenName: ""

    // Positions each style offers (osd.position), the first is the fallback
    readonly property var positions: ({
            pill: ["bottom", "top"],
            vertical: ["right", "left"],
            card: ["center", "bottom"],
            attached: ["bar", "opposite"]
        })
    readonly property string style: positions[Config.osdStyle] ? Config.osdStyle : "pill"
    readonly property string position: positionFor(style)

    readonly property real value: kind === "brightness" ? BrightnessService.brightness : AudioService.volume
    readonly property bool muted: kind === "volume" && AudioService.muted

    readonly property string label: kind === "brightness" ? "Brightness" : muted ? "Muted" : "Volume"

    readonly property string icon: {
        if (kind === "brightness") {
            if (value < 0.3)
                return "\u{f00de}"; // md-brightness_5
            if (value < 0.6)
                return "\u{f00df}"; // md-brightness_6
            return "\u{f00e0}"; // md-brightness_7
        }
        if (muted)
            return "\u{f075f}"; // md-volume_mute
        if (value < 0.01)
            return "\u{f0581}"; // md-volume_off
        if (value < 0.33)
            return "\u{f057f}"; // md-volume_low
        if (value < 0.66)
            return "\u{f0580}"; // md-volume_medium
        return "\u{f057e}"; // md-volume_high
    }

    // ========================================================================
    // TIMERS
    // ========================================================================

    Timer {
        id: hideTimer
        interval: Config.osdTimeout
        onTriggered: root.hide()
    }

    Timer {
        id: exitTimer
        interval: Config.animDurationLong
    }

    // Values settle while the services start (sink binding, first backlight
    // read): changes before this aren't user actions
    Timer {
        id: armTimer
        interval: 3000
        running: true
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function show(kind: string) {
        root.kind = kind;
        if (!root.shown)
            root.screenName = Hyprland.focusedMonitor?.name ?? "";
        root.shown = true;
        exitTimer.stop();
        hideTimer.restart();
    }

    // Saved position if the style offers it, else its first option
    function positionFor(style: string): string {
        const options = positions[style] ?? [];
        return options.includes(Config.osdPosition) ? Config.osdPosition : options[0] ?? "";
    }

    function hide() {
        if (!root.shown)
            return;
        // Before `shown` drops, or `mapped` goes false and unloads the window
        exitTimer.restart();
        hideTimer.stop();
        root.shown = false;
    }

    // ========================================================================
    // "ANY CHANGE" TRIGGER (osd.trigger)
    // ========================================================================

    // Changes made elsewhere (apps, pavucontrol, headset buttons). Panels
    // with their own sliders already show the value
    function _changed(kind: string) {
        if (Config.osdTrigger !== "any" || armTimer.running)
            return;
        const open = WindowManagerService.activeModules;
        if (open["QuickSettings"] || open["Dashboard"])
            return;
        show(kind);
    }

    Connections {
        target: AudioService

        function onVolumeChanged() {
            root._changed("volume");
        }

        function onMutedChanged() {
            root._changed("volume");
        }
    }

    Connections {
        target: BrightnessService

        function onBrightnessChanged() {
            root._changed("brightness");
        }
    }
}
