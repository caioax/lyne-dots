pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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

    property bool caffeineEnabled: getState("idle.caffeine", false)
    property bool dpmsEnabled: getState("idle.dpmsEnabled", true)
    property bool mediaInhibit: getState("idle.mediaInhibit", true)
    property int lockTimeout: getState("idle.lockTimeout", 600)
    property int dpmsTimeout: getState("idle.dpmsTimeout", 300)

    // True when any MPRIS player reports playing state (browser video, mpv, etc.)
    readonly property bool mediaPlaying: mediaInhibit && MprisService.anyPlaying

    // True when systemd-logind reports active "idle" block inhibitors
    property bool systemInhibited: false

    // ========================================================================
    // STATE PERSISTENCE
    // ========================================================================

    Connections {
        target: StateService

        function onStateLoaded() {
            root.caffeineEnabled = root.getState("idle.caffeine", false);
            root.dpmsEnabled = root.getState("idle.dpmsEnabled", true);
            root.mediaInhibit = root.getState("idle.mediaInhibit", true);
            root.lockTimeout = root.getState("idle.lockTimeout", 600);
            root.dpmsTimeout = root.getState("idle.dpmsTimeout", 300);
            console.log("[Idle] Loaded state - caffeine:", root.caffeineEnabled, "dpms:", root.dpmsEnabled, "mediaInhibit:", root.mediaInhibit, "lockTimeout:", root.lockTimeout + "s", "dpmsTimeout:", root.dpmsTimeout + "s");
        }
    }

    // ========================================================================
    // IDLE INHIBITOR (CAFFEINE)
    // ========================================================================

    PanelWindow {
        id: inhibitorWindow
        visible: root.caffeineEnabled
        implicitWidth: 0
        implicitHeight: 0
        color: "transparent"
        mask: Region {}

        IdleInhibitor {
            enabled: root.caffeineEnabled
            window: inhibitorWindow
        }
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    // Poll logind for active idle block inhibitors (covers systemd-inhibit, D-Bus bridges)
    Process {
        id: inhibitCheckProc
        command: ["bash", "-c", "busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager BlockInhibited 2>/dev/null | grep -q idle && echo true || echo false"]

        stdout: SplitParser {
            onRead: data => {
                const val = data.trim() === "true";
                if (root.systemInhibited !== val) {
                    root.systemInhibited = val;
                    if (val) console.log("[Idle] System idle inhibitor active");
                    else console.log("[Idle] System idle inhibitor released");
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: inhibitCheckProc.running = true
    }

    Process {
        id: dpmsOffProc
        command: ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"off\" })"]
    }

    Process {
        id: dpmsOnProc
        command: ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"on\" })"]
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function lock() {
        console.log("[Idle] Locking screen");
        LockService.lock();
    }

    function toggleCaffeine() {
        caffeineEnabled = !caffeineEnabled;
        root.setState("idle.caffeine", caffeineEnabled);
        console.log("[Idle] Caffeine:", caffeineEnabled);
    }

    function dpmsOn() {
        dpmsOnProc.running = true;
    }

    function dpmsOff() {
        dpmsOffProc.running = true;
    }
}
