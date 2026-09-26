pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam

// Session lock: PAM authentication, the password being typed (shared by the
// lock surfaces of every monitor) and locking before the system sleeps
Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool locked: false
    // The compositor confirmed the lock (set by LockScreen)
    property bool secure: false
    property bool authenticating: false
    property bool failed: false
    property string failMessage: ""
    property int attempts: 0

    // Monitor showing the password field (the others show the clock)
    property string screen: ""
    // Password being typed; every lock surface edits this one
    property string buffer: ""
    property bool capsLock: false

    readonly property string style: StateService.get("lock.style", "center")
    readonly property bool showStatus: StateService.get("lock.showStatus", true)
    readonly property bool showPower: StateService.get("lock.showPower", true)
    readonly property bool lockBeforeSleep: StateService.get("lock.beforeSleep", true)

    signal authSucceeded

    // ========================================================================
    // PAM AUTHENTICATION
    // ========================================================================

    property string _pendingPassword: ""

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: {
            if (responseRequired)
                pam.respond(root._pendingPassword);
        }

        onCompleted: result => {
            root.authenticating = false;
            root._pendingPassword = "";

            if (result === PamResult.Success) {
                console.log("[Lock] Authentication successful");
                root.failed = false;
                root.failMessage = "";
                root.authSucceeded();
            } else {
                console.log("[Lock] Authentication failed:", PamResult.toString(result));
                root.attempts++;
                // PAM's own words when it has them (e.g. faillock's lockout)
                root.failMessage = pam.messageIsError && pam.message !== "" ? pam.message : "Wrong password";
                root.failed = true;
            }
        }

        onError: error => {
            root.authenticating = false;
            root._pendingPassword = "";
            console.log("[Lock] PAM error:", PamError.toString(error));
            root.failMessage = "Authentication error";
            root.failed = true;
        }
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function lock() {
        if (!locked) {
            console.log("[Lock] Locking screen");
            screen = Hyprland.focusedMonitor?.name ?? "";
            buffer = "";
            attempts = 0;
            failed = false;
            failMessage = "";
            authenticating = false;
            _pendingPassword = "";
            locked = true;
            checkCapsLock();
        }
    }

    function unlock() {
        if (locked) {
            console.log("[Lock] Unlocking screen");
            // Only set locked = false here. Do NOT reset failed/failMessage/etc
            // because that triggers signals on the LockScreen which is being
            // destroyed (causes "invalid context" warning). State is reset in lock().
            locked = false;
            secure = false;
        }
    }

    function tryUnlock() {
        if (authenticating || buffer === "")
            return;
        console.log("[Lock] Attempting authentication");
        _pendingPassword = buffer;
        buffer = "";
        authenticating = true;
        failed = false;
        pam.start();
    }

    function checkCapsLock() {
        if (!capsProc.running)
            capsProc.running = true;
    }

    Process {
        id: capsProc
        command: ["sh", "-c", "hyprctl devices -j | jq '[.keyboards[].capsLock] | any'"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() === "true"
        }
    }

    // ========================================================================
    // LOCK BEFORE SLEEP
    // ========================================================================

    // A logind "delay" inhibitor holds suspend (lid close included) for up to
    // InhibitDelayMaxSec after PrepareForSleep(true); it is released once the
    // lock is secure, and taken again on wake. setpriv --pdeathsig ends both
    // helpers with the shell (killed, they were left running as orphans)
    property bool _holdSleep: lockBeforeSleep

    Process {
        running: root._holdSleep
        command: ["setpriv", "--pdeathsig", "TERM", "--", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell", "--why=Lock the screen before sleeping", "sleep", "infinity"]
    }

    Process {
        running: root.lockBeforeSleep
        command: ["setpriv", "--pdeathsig", "TERM", "--", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep"))
                    return;
                if (line.includes("true")) {
                    root.lock();
                    if (root.secure)
                        root._holdSleep = false;
                    else
                        releaseFallback.restart();
                } else {
                    releaseFallback.stop();
                    root._holdSleep = root.lockBeforeSleep;
                }
            }
        }
    }

    onSecureChanged: {
        if (secure && releaseFallback.running) {
            releaseFallback.stop();
            _holdSleep = false;
        }
    }

    onLockBeforeSleepChanged: _holdSleep = lockBeforeSleep

    // Never hold the system awake if the lock surface doesn't come up
    Timer {
        id: releaseFallback
        interval: 2000
        onTriggered: root._holdSleep = false
    }

    // ========================================================================
    // IPC — qs ipc call lock lock
    // ========================================================================

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
    }
}
