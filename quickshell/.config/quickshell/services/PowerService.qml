pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool overlayVisible: false
    property string pendingAction: ""

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function showOverlay() {
        overlayVisible = true;
        pendingAction = "";
    }

    function hideOverlay() {
        overlayVisible = false;
        pendingAction = "";
    }

    function executeAction(actionId: string) {
        console.log("[Power] Executing:", actionId);
        
        switch (actionId) {
            case "shutdown":
                shutdownProc.running = true;
                break;
            case "reboot":
                rebootProc.running = true;
                break;
            case "suspend":
                suspendProc.running = true;
                break;
            case "hibernate":
                hibernateProc.running = true;
                break;
            case "lock":
                IdleService.lock();
                break;
            case "logout":
                logoutProc.running = true;
                break;
        }
        
        hideOverlay();
    }

    // Quick shortcuts
    function shutdown() { executeAction("shutdown"); }
    function reboot() { executeAction("reboot"); }
    function suspend() { executeAction("suspend"); }
    function hibernate() { executeAction("hibernate"); }
    function lock() { executeAction("lock"); }
    function logout() { executeAction("logout"); }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    Process {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }

    Process {
        id: hibernateProc
        command: ["systemctl", "hibernate"]
    }

    Process {
        id: logoutProc
        command: ["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()' || loginctl terminate-user $USER"]
    }
}
