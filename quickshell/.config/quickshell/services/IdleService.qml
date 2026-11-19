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
    readonly property bool systemInhibited: Login1Service.blockInhibited.split(":").includes("idle")

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

    // Active "idle" block inhibitors in logind (systemd-inhibit, D-Bus
    // bridges), followed by Login1Service
    onSystemInhibitedChanged: console.log(systemInhibited ? "[Idle] System idle inhibitor active" : "[Idle] System idle inhibitor released")

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
