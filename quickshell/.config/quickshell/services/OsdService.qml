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
    // "volume" | "brightness" | "mic" | "device" (the output changed: its
    // name and volume)
    property string kind: "volume"
    // Monitor focused when the OSD opened (osd.monitor "focused")
    property string screenName: ""

    // Positions each style offers (osd.position), the first is the fallback
    readonly property var positions: ({
            pill: ["bottom", "top"],
            vertical: ["right", "left"],
            card: ["center", "bottom"],
            attached: ["bar", "opposite"]
        })
    readonly property string style: positions[Config.osdStyle] ? Config.osdStyle : "attached"
    readonly property string position: positionFor(style)

    readonly property bool isOutput: kind === "volume" || kind === "device"
    readonly property real value: kind === "brightness" ? (BrightnessService.current?.brightness ?? 0) : kind === "mic" ? AudioService.sourceVolume : AudioService.volume
    readonly property bool muted: kind === "mic" ? AudioService.sourceMuted : isOutput && AudioService.muted
    // End of the scale: the volume boost limit, or more when an app set more
    readonly property real max: isOutput ? Math.max(AudioService.maxVolume, value) : Math.max(1, value)
    // Pointer on the OSD (osd.interactive): it stays until the pointer leaves
    property bool held: false

    readonly property string deviceName: AudioService.deviceName(AudioService.sink)
    // Which monitor, when more than one can be dimmed
    readonly property string monitorName: BrightnessService.controllable.length > 1 ? (BrightnessService.current?.label ?? "") : ""
    readonly property string label: {
        if (kind === "brightness")
            return monitorName || "Brightness";
        if (kind === "mic")
            return muted ? "Mic muted" : "Microphone";
        if (kind === "device")
            return deviceName;
        return muted ? "Muted" : "Volume";
    }
    // Line of text above the level bar (pill and attached styles)
    readonly property string caption: kind === "device" ? deviceName : kind === "brightness" ? monitorName : ""

    readonly property string icon: {
        if (kind === "mic")
            return AudioService.sourceIcon;
        if (kind === "device")
            return AudioService.deviceIcon(AudioService.sink, true);
        if (kind === "brightness")
            return BrightnessService.iconFor(value);
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
        onTriggered: {
            if (AudioService.sink)
                root._lastSink = AudioService.deviceName(AudioService.sink);
        }
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function show(kind: string) {
        if ((kind === "mic" && !Config.osdMic) || (kind === "device" && !Config.osdDevice))
            return;
        root.kind = kind;
        if (!root.shown)
            root.screenName = Hyprland.focusedMonitor?.name ?? "";
        root.shown = true;
        exitTimer.stop();
        if (root.held)
            hideTimer.stop();
        else
            hideTimer.restart();
    }

    function hold(held: bool) {
        root.held = held;
        if (held)
            hideTimer.stop();
        else if (root.shown)
            hideTimer.restart();
    }

    // Wheel on the OSD: steps the level it shows
    function adjust(steps: int) {
        if (root.kind === "brightness")
            BrightnessService.current?.set(BrightnessService.current.brightness + Config.brightnessStep * steps);
        else if (root.kind === "mic")
            AudioService.setSourceVolume(AudioService.sourceVolume + AudioService.volumeStep * steps);
        else
            AudioService.changeVolume(steps);
        show(root.kind);
    }

    function toggleMute() {
        if (root.kind === "mic")
            AudioService.toggleSourceMute();
        else if (root.isOutput)
            AudioService.toggleMute();
        else
            return;
        show(root.kind);
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
        root.held = false;
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
        if (_panelOpen())
            return;
        // The new output's volume shows in the device OSD already
        if (kind === "volume" && root.shown && root.kind === "device")
            kind = "device";
        show(kind);
    }

    function _panelOpen(): bool {
        const open = WindowManagerService.activeModules;
        return open["QuickSettings"] || open["Dashboard"];
    }

    // Default output switched (osd.device), whatever the trigger setting.
    // The name is compared since the sink object can be replaced for the
    // same device
    property string _lastSink: ""

    function _sinkChanged() {
        if (!AudioService.sink)
            return;
        const name = AudioService.deviceName(AudioService.sink);
        if (name === root._lastSink)
            return;
        const first = root._lastSink === "";
        root._lastSink = name;
        if (first || armTimer.running || _panelOpen())
            return;
        show("device");
    }

    Connections {
        target: AudioService

        function onVolumeChanged() {
            root._changed("volume");
        }

        function onMutedChanged() {
            root._changed("volume");
        }

        // Mic volume isn't watched: apps with auto gain move it all the time
        function onSourceMutedChanged() {
            root._changed("mic");
        }

        function onSinkChanged() {
            root._sinkChanged();
        }
    }

    Connections {
        target: BrightnessService

        // Keys and sliders set lastChanged themselves; this catches reads
        function onLevelChanged(monitor) {
            BrightnessService.lastChanged = monitor;
            root._changed("brightness");
        }
    }
}
