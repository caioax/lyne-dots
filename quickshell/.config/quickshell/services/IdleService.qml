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

    // Active "idle" block inhibitors in logind (systemd-inhibit, D-Bus
    // bridges): read once, then followed through BlockInhibited's
    // PropertiesChanged
    function _setInhibited(value: string): void {
        const val = value.split(":").includes("idle");
        if (root.systemInhibited === val)
            return;
        root.systemInhibited = val;
        console.log(val ? "[Idle] System idle inhibitor active" : "[Idle] System idle inhibitor released");
    }

    Process {
        id: inhibitReadProc
        running: true
        command: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "BlockInhibited"]
        // s "sleep:idle"
        stdout: StdioCollector {
            onStreamFinished: root._setInhibited(text.trim().replace(/^s "(.*)"$/, "$1"))
        }
    }

    Process {
        id: inhibitMonitorProc
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                const match = line.match(/'BlockInhibited': <'([^']*)'>/);
                if (match)
                    root._setInhibited(match[1]);
            }
        }
        // logind restarted: read again and listen again
        onExited: inhibitRestart.start()
    }

    Timer {
        id: inhibitRestart
        interval: 5000
        onTriggered: {
            inhibitMonitorProc.running = true;
            inhibitReadProc.running = true;
        }
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
