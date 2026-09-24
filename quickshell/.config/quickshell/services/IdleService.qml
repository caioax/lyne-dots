pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES (bound to state.json, edited from Quick Settings / Settings)
    // ========================================================================

    readonly property bool caffeineEnabled: StateService.get("idle.caffeine", false)
    readonly property bool dpmsEnabled: StateService.get("idle.dpmsEnabled", true)
    readonly property bool mediaInhibit: StateService.get("idle.mediaInhibit", true)
    // Seconds; 0 disables the automatic lock
    readonly property int lockTimeout: StateService.get("idle.lockTimeout", 600)
    readonly property int dpmsTimeout: StateService.get("idle.dpmsTimeout", 300)

    // True when any MPRIS player reports playing state (browser video, mpv, etc.)
    readonly property bool mediaPlaying: mediaInhibit && MprisService.anyPlaying

    // True when systemd-logind reports active "idle" block inhibitors
    property bool systemInhibited: false

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
        StateService.set("idle.caffeine", !caffeineEnabled);
        console.log("[Idle] Caffeine:", caffeineEnabled);
    }

    function dpmsOn() {
        dpmsOnProc.running = true;
    }

    function dpmsOff() {
        dpmsOffProc.running = true;
    }
}
