pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Session and power actions, shared by the power menu and the launcher.
// Destructive actions go through a countdown (power.countdown seconds, 0 =
// none) shown in the menu; everything else runs right away. Actions the
// system can't do (logind Can* ≠ "yes") are left out
Singleton {
    id: root

    // Every action, in menu order. `key` is its letter in the menu; `tone`
    // picks the color: "accent", "warning" (ends the session) or "error"
    readonly property var allActions: [
        {
            id: "lock",
            label: "Lock",
            name: "Lock screen",
            comment: "Lock the session",
            glyph: "\u{f033e}",
            key: "L",
            tone: "accent",
            keywords: ["lock"]
        },
        {
            id: "suspend",
            label: "Suspend",
            name: "Suspend",
            comment: "Sleep, keeping the session in memory",
            glyph: "\u{f0904}",
            key: "S",
            tone: "accent",
            keywords: ["sleep"],
            capability: "CanSuspend"
        },
        {
            id: "hibernate",
            label: "Hibernate",
            name: "Hibernate",
            comment: "Save the session to disk and power off",
            glyph: "\u{f0717}",
            key: "H",
            tone: "accent",
            keywords: ["sleep", "disk"],
            capability: "CanHibernate",
            optional: true
        },
        {
            id: "logout",
            label: "Log out",
            name: "Log out",
            comment: "End the Hyprland session",
            glyph: "\u{f0343}",
            key: "E",
            tone: "warning",
            keywords: ["exit", "sign out"],
            destructive: true,
            progress: "Logging out"
        },
        {
            id: "reboot",
            label: "Reboot",
            name: "Reboot",
            comment: "Restart the computer",
            glyph: "\u{f0709}",
            key: "R",
            tone: "warning",
            keywords: ["restart"],
            destructive: true,
            progress: "Rebooting",
            capability: "CanReboot"
        },
        {
            id: "firmware",
            label: "UEFI",
            name: "Reboot to UEFI",
            comment: "Restart into the firmware setup",
            glyph: "\u{f061a}",
            key: "U",
            tone: "warning",
            keywords: ["bios", "firmware", "setup"],
            destructive: true,
            progress: "Rebooting to UEFI",
            capability: "CanRebootToFirmwareSetup",
            optional: true
        },
        {
            id: "shutdown",
            label: "Shut down",
            name: "Shut down",
            comment: "Power off the computer",
            glyph: "\u{f0425}",
            key: "P",
            tone: "error",
            keywords: ["power off", "poweroff"],
            destructive: true,
            progress: "Shutting down",
            capability: "CanPowerOff"
        }
    ]

    // logind answers ("yes", "no", "na", "challenge"), filled on startup.
    // Until then the common actions count as available and the `optional`
    // ones (hibernate, firmware) don't
    property var capabilities: ({})
    readonly property var hiddenActions: StateService.get("power.hiddenActions", [])
    // What the system can do (hidden in Settings or not)
    readonly property var availableActions: allActions.filter(a => {
        const answer = a.capability ? capabilities[a.capability] ?? (a.optional ? "na" : "yes") : "yes";
        // "inhibited": an app blocks it for now (the menu warns about it)
        return ["yes", "challenge", "inhibited"].includes(answer);
    })
    // What the menu shows
    readonly property var actions: {
        const shown = availableActions.filter(a => !hiddenActions.includes(a.id));
        return shown.length > 0 ? shown : availableActions.slice(0, 1);
    }

    readonly property string style: StateService.get("power.style", "card")
    readonly property string side: StateService.get("power.side", "right")
    readonly property int countdownSeconds: StateService.get("power.countdown", 5)

    // ========================================================================
    // MENU STATE
    // ========================================================================

    // The overlay exists while `visible`; `open` drives its animations and
    // turns false first when closing
    property bool visible: false
    property bool open: false
    // Monitor showing the menu (the others are only dimmed)
    property string screen: ""
    property string selectedId: "lock"

    // Countdown: the action waiting and the time left, in ms
    property string pendingId: ""
    property int remaining: 0
    readonly property var pendingAction: find(pendingId)
    readonly property real pendingProgress: pendingId !== "" && countdownSeconds > 0 ? remaining / (countdownSeconds * 1000) : 0

    // Context for the header, read on open
    readonly property string user: Quickshell.env("USER") ?? ""
    property string host: ""
    property string uptime: ""
    // Apps blocking sleep or shutdown: [{ who, why, what }]
    property var inhibitors: []

    function find(id: string): var {
        return allActions.find(a => a.id === id) ?? null;
    }

    // Shows or hides an action in the menu (Settings › Power)
    function setShown(id: string, shown: bool): void {
        const hidden = hiddenActions.filter(a => a !== id);
        if (!shown)
            hidden.push(id);
        StateService.set("power.hiddenActions", hidden);
    }

    function isAvailable(id: string): bool {
        return availableActions.some(a => a.id === id);
    }

    function show(): void {
        cancel();
        selectedId = actions.some(a => a.id === "lock") ? "lock" : actions[0].id;
        screen = Hyprland.focusedMonitor?.name ?? "";
        refresh();
        closeTimer.stop();
        visible = true;
        open = true;
    }

    // Rereads the uptime and the blocking apps (on open, and by the lock screen)
    function refresh(): void {
        uptimeFile.reload();
        if (!inhibitorProc.running)
            inhibitorProc.running = true;
    }

    function hide(): void {
        cancel();
        if (!visible)
            return;
        open = false;
        closeTimer.restart();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    // Moves the selection through the shown actions (wraps around)
    function move(delta: int): void {
        const index = actions.findIndex(a => a.id === selectedId);
        selectedId = actions[(index + delta + actions.length) % actions.length].id;
    }

    // Asks for an action: destructive ones start the countdown (opening the
    // menu if needed), the rest run. Asking again during the countdown runs
    // it now. `inPlace` keeps the menu closed: the caller shows the
    // countdown itself (the lock screen)
    function request(id: string, inPlace): void {
        const action = find(id);
        if (!action || !isAvailable(id))
            return;
        if (pendingId === id) {
            run(id);
            return;
        }
        if (!action.destructive || countdownSeconds <= 0) {
            run(id);
            return;
        }
        if (!open && !inPlace)
            show();
        selectedId = id;
        pendingId = id;
        remaining = countdownSeconds * 1000;
        countdown.restart();
    }

    function cancel(): void {
        countdown.stop();
        pendingId = "";
        remaining = 0;
    }

    // Closes the menu, then runs the action once it's gone (so the lock
    // screen or a suspend don't catch it mid-animation)
    function run(id: string): void {
        cancel();
        console.log("[Power] Running:", id);
        if (open) {
            _pendingRun = id;
            hide();
        } else {
            execute(id);
        }
    }

    property string _pendingRun: ""

    function execute(id: string): void {
        // The menu showed the blocking apps and the user went ahead
        const systemctl = args => Quickshell.execDetached(["systemctl"].concat(args, inhibitors.length > 0 ? ["-i"] : []));
        switch (id) {
        case "lock":
            IdleService.lock();
            break;
        case "logout":
            Quickshell.execDetached(["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()' || loginctl terminate-user \"$USER\""]);
            break;
        case "suspend":
            systemctl(["suspend"]);
            break;
        case "hibernate":
            systemctl(["hibernate"]);
            break;
        case "reboot":
            systemctl(["reboot"]);
            break;
        case "firmware":
            systemctl(["reboot", "--firmware-setup"]);
            break;
        case "shutdown":
            systemctl(["poweroff"]);
            break;
        }
    }

    // Shortcuts for other modules
    function lock() {
        request("lock");
    }
    function suspend() {
        request("suspend");
    }
    function logout() {
        request("logout");
    }
    function reboot() {
        request("reboot");
    }
    function shutdown() {
        request("shutdown");
    }

    Timer {
        id: countdown

        interval: 50
        repeat: true
        onTriggered: {
            root.remaining = Math.max(0, root.remaining - interval);
            if (root.remaining === 0)
                root.run(root.pendingId);
        }
    }

    Timer {
        id: closeTimer

        interval: Config.animDuration
        onTriggered: {
            root.visible = false;
            if (root._pendingRun !== "") {
                const id = root._pendingRun;
                root._pendingRun = "";
                root.execute(id);
            }
        }
    }

    // ========================================================================
    // SYSTEM INFO
    // ========================================================================

    Process {
        running: true
        command: ["sh", "-c", `
            for m in CanSuspend CanHibernate CanReboot CanRebootToFirmwareSetup CanPowerOff; do
                printf '%s %s\\n' "$m" "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $m 2>/dev/null | cut -d'"' -f2)"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const caps = {};
                for (const line of text.trim().split("\n")) {
                    const [name, value] = line.split(" ");
                    if (name)
                        caps[name] = value || "na";
                }
                root.capabilities = caps;
            }
        }
    }

    // Blocking inhibitors only ("delay" ones just hold the action briefly)
    Process {
        id: inhibitorProc
        command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).data[0];
                    root.inhibitors = list.filter(i => i[3] === "block" && /sleep|shutdown/.test(i[0])).map(i => ({
                                what: i[0],
                                who: i[1],
                                why: i[2]
                            }));
                } catch (e) {
                    root.inhibitors = [];
                }
            }
        }
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: {
            const total = parseInt(text());
            if (isNaN(total))
                return;
            const days = Math.floor(total / 86400);
            const hours = Math.floor(total % 86400 / 3600);
            const minutes = Math.floor(total % 3600 / 60);
            if (days > 0)
                root.uptime = days + "d " + hours + "h";
            else if (hours > 0)
                root.uptime = hours + "h " + minutes + "m";
            else
                root.uptime = minutes + "m";
        }
    }

    // ========================================================================
    // IPC — qs ipc call power <function> [action]
    // ========================================================================

    IpcHandler {
        target: "power"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            root.toggle();
        }

        // Same as picking it in the menu (destructive ones count down)
        function request(action: string): void {
            root.request(action);
        }
    }
}
