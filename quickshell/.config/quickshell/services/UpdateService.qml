pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// lyne-dots updates: `lyne update status` for Settings › About, and one check
// a minute after the shell starts (again 10 minutes later when GitHub wasn't
// reachable) that notifies once per new version: the release on Stable, the
// commit on Latest. Off main (dev, a fork's branch) it never notifies
Singleton {
    id: root

    // `lyne update status --json`
    property var status: ({})
    property bool checking: false

    readonly property string channel: StateService.get("update.channel", "stable")
    readonly property bool notifyEnabled: StateService.get("update.notify", true)
    // Off main the update follows the branch instead of the channel
    readonly property bool followsChannel: status.follows !== "branch"
    readonly property int behind: status.behind ?? -1
    readonly property int dirty: status.dirty ?? 0

    // Checked again once the running check ends
    property bool _recheck: false
    // Whether the running check fetches; one that doesn't (a channel switch)
    // keeps the last fetch's result
    property bool _fetching: false
    // The running check is the startup one, which may notify
    property bool _startup: false
    property bool _retried: false

    function check(fetch = true) {
        if (statusProc.running) {
            _recheck = true;
            return;
        }
        checking = true;
        _fetching = fetch;
        statusProc.command = ["lyne", "update", "status", "--json", "--channel", channel].concat(fetch ? ["--fetch"] : []);
        statusProc.running = true;
    }

    // In the default terminal, so the output (and any sudo prompt from
    // migrations) is visible; it stays open until a key is pressed
    function runUpdate() {
        Quickshell.execDetached(AppsService.terminalArgv(["bash", "-c", `lyne update --channel ${channel}; echo; read -rsn1 -p "Press any key to close"`]));
    }

    function _startupCheck() {
        _startup = true;
        check(true);
    }

    // Once per version: the key is the channel and the commit it would go to
    function _maybeNotify() {
        if (!notifyEnabled || !followsChannel || behind <= 0 || !status.targetCommit)
            return;
        const key = channel + ":" + status.targetCommit;
        if (StateService.get("update.notified", "") === key)
            return;
        StateService.set("update.notified", key);
        const stable = channel === "stable";
        const title = stable ? "Lyne " + status.target + " is available" : "Lyne: " + behind + (behind === 1 ? " update" : " updates") + " available";
        const body = (stable ? "New release" : "Latest channel, up to " + status.targetCommit) + ". Update from here or Settings › About";
        notifyProc.command = ["timeout", "1h", "notify-send", "-a", "Lyne", "-i", "lyne-dots", "-A", "default=Details", "-A", "update=Update", "-A", "about=Details", title, body];
        notifyProc.running = true;
    }

    // A channel switch changes what an update brings
    onChannelChanged: {
        if (status.commit !== undefined)
            check(false);
    }

    Timer {
        running: true
        interval: 60 * 1000
        onTriggered: root._startupCheck()
    }

    Timer {
        id: retryTimer
        interval: 10 * 60 * 1000
        onTriggered: root._startupCheck()
    }

    Process {
        id: statusProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!root._fetching)
                        result.fetched = root.status.fetched ?? false;
                    root.status = result;
                } catch (e) {
                    root.status = {};
                }
                root.checking = false;
                if (root._startup) {
                    root._startup = false;
                    if (root.status.fetched)
                        root._maybeNotify();
                    else if (!root._retried) {
                        root._retried = true;
                        retryTimer.start();
                    }
                }
                if (root._recheck) {
                    root._recheck = false;
                    root.check(false);
                }
            }
        }
    }

    // notify-send prints the chosen action; it waits while the notification
    // lives (also in the history), up to an hour
    Process {
        id: notifyProc

        stdout: StdioCollector {
            onStreamFinished: {
                const action = text.trim();
                if (action === "update")
                    root.runUpdate();
                else if (action === "about" || action === "default")
                    SettingsService.open("about");
            }
        }
    }
}
