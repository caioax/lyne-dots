pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Keeps the objects alive in memory
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Capture streams (apps recording). Their properties need a bound node
    readonly property var _captureNodes: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink)
    PwObjectTracker {
        objects: root._captureNodes
    }

    // Apps recording from a microphone: capture streams minus the ones
    // reading a sink's monitor (cava, peak meters)
    readonly property var micStreams: _captureNodes.filter(n => n.properties["stream.capture.sink"] !== "true" && n.properties["media.class"] === "Stream/Input/Audio")
    readonly property bool micInUse: micStreams.length > 0
    readonly property var micApps: [...new Set(micStreams.map(n => n.properties["application.name"] || n.name))]

    // Hardware devices (streams from apps are left out)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    function deviceName(node): string {
        return node?.description || node?.nickname || node?.name || "Unknown";
    }

    // Glyph for an output (by its name) or input device
    function deviceIcon(node, isSink: bool): string {
        // Description plus node name: Bluetooth sinks only say "bluez" there
        const name = (deviceName(node) + " " + (node?.name ?? "")).toLowerCase();
        if (!isSink)
            return "\u{f036c}"; // md-microphone
        if (name.includes("hdmi") || name.includes("displayport"))
            return "\u{f0379}"; // md-monitor
        if (name.includes("headphone") || name.includes("headset") || name.includes("bluez"))
            return "\u{f02cb}"; // md-headphones
        return "\u{f04c3}"; // md-speaker
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    readonly property string sourceIcon: !sourceReady || sourceMuted ? "\u{f036d}" : "\u{f036c}" // md-microphone(_off)

    // Check if the sink is ready to operate
    readonly property bool sinkReady: sink !== null && sink.audio !== null
    readonly property bool sourceReady: source !== null && source.audio !== null

    // Optional chaining, not sinkReady: when the sink goes away these can be
    // reevaluated before sinkReady is
    readonly property bool muted: sink?.audio?.muted ?? false
    // Highest volume the shell sets (audio.maxVolume, above 1 amplifies)
    readonly property real maxVolume: Config.audioMaxVolume
    readonly property real volumeStep: 0.05
    // Not capped at maxVolume: other apps can set more
    readonly property real volume: Math.max(0, sink?.audio?.volume ?? 0)
    readonly property int percentage: Math.round(volume * 100)

    readonly property bool sourceMuted: source?.audio?.muted ?? false
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property string systemIcon: {
        if (!sinkReady || muted || volume <= 0)
            return "";

        if (volume < 0.33)
            return "";

        if (volume < 0.67)
            return "";

        return "";
    }

    function setVolume(newVolume) {
        if (sinkReady) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(maxVolume, newVolume));
        }
    }

    function toggleMute() {
        if (sinkReady) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    // Steps the volume; going up never lowers one already above maxVolume
    function changeVolume(steps: int) {
        if (steps > 0 && volume >= maxVolume)
            return;
        setVolume(volume + volumeStep * steps);
    }

    function increaseVolume() {
        changeVolume(1);
    }

    function decreaseVolume() {
        changeVolume(-1);
    }

    function setSourceVolume(newVolume) {
        if (sourceReady && source.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.5, newVolume));
        }
    }

    function toggleSourceMute() {
        if (sourceReady && source.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }
}
