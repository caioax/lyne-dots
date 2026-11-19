pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// One listener on logind's manager object for the whole shell: IdleService
// follows BlockInhibited, LockService locks on PrepareForSleep. Each used to
// run its own gdbus monitor on the same signals
Singleton {
    id: root

    // Colon-separated operations held by block inhibitors ("sleep:idle")
    property string blockInhibited: ""

    // start = true right before suspend, false on wake
    signal prepareForSleep(bool start)

    Process {
        id: readProc
        running: true
        command: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "BlockInhibited"]
        // s "sleep:idle"
        stdout: StdioCollector {
            onStreamFinished: root.blockInhibited = text.trim().replace(/^s "(.*)"$/, "$1")
        }
    }

    // setpriv --pdeathsig ends it with the shell (killed, it was left
    // running as an orphan)
    Process {
        id: monitorProc
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                const inhibited = line.match(/'BlockInhibited': <'([^']*)'>/);
                if (inhibited) {
                    root.blockInhibited = inhibited[1];
                    return;
                }
                // ...Manager.PrepareForSleep (true,)
                const sleep = line.match(/\.PrepareForSleep \((true|false),?\)/);
                if (sleep)
                    root.prepareForSleep(sleep[1] === "true");
            }
        }
        // logind restarted: read again and listen again
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 5000
        onTriggered: {
            monitorProc.running = true;
            readProc.running = true;
        }
    }
}
