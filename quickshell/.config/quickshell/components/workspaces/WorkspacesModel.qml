pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Workspace state for one monitor, shared by every workspace style: the
// active id, which workspaces hold windows (and which apps), urgency and the
// special workspace. Styles only read this and call focus()/toggleSpecial().
QtObject {
    id: root

    // The screen the widget lives on; falls back to the focused monitor
    property var screen: null
    property int totalWorkspaces: 99
    // false for previews: no Hyprland events, and activeId/workspaces are
    // set by hand
    property bool live: true

    // --- Monitor Logic ---
    readonly property var monitor: {
        if (!Hyprland)
            return null;
        return (screen ? Hyprland.monitorFor(screen) : null) ?? Hyprland.focusedMonitor ?? null;
    }
    readonly property string monitorName: monitor?.name ?? ""
    readonly property var activeWorkspace: monitor?.activeWorkspace ?? null

    // --- Normal Workspace Math ---
    // Each monitor owns a block of 100 ids (1-99, 101-199, ...)
    property int activeId: (activeWorkspace && activeWorkspace.id > 0) ? activeWorkspace.id : 1
    readonly property int monitorOffset: Math.floor((activeId - 1) / 100) * 100
    // Derived from activeId alone: going through monitorOffset, a switch to
    // another monitor's block briefly reads the old offset (105 - 0 -> 99)
    readonly property int relativeActiveId: Math.max(1, Math.min(activeId - Math.floor((activeId - 1) / 100) * 100, totalWorkspaces))

    // --- Per-workspace info ---
    // { <id>: { windows: [appId, ...], urgent: bool } } for every workspace
    // that exists; a missing id means an empty workspace
    property var workspaces: ({})

    function isOccupied(id) {
        return (workspaces[id]?.windows.length ?? 0) > 0;
    }
    function isUrgent(id) {
        return workspaces[id]?.urgent === true;
    }
    function windowsOf(id) {
        return workspaces[id]?.windows ?? [];
    }
    // Distinct apps of a workspace, in window order
    function appsOf(id) {
        return [...new Set(windowsOf(id))];
    }

    // Icon of an app id: its desktop entry's icon when there is one (the
    // class often differs from the icon name), else the id itself
    function iconFor(appId) {
        const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        return Quickshell.iconPath(entry?.icon || appId || "application-x-executable", "application-x-executable");
    }

    function update() {
        if (!live || !Hyprland || !Hyprland.workspaces)
            return;
        let info = {};
        for (const ws of Hyprland.workspaces.values) {
            if (ws && ws.id > 0)
                info[ws.id] = {
                    windows: [],
                    urgent: urgentIds[ws.id] === true
                };
        }
        for (const tl of Hyprland.toplevels.values) {
            const id = tl?.workspace?.id ?? 0;
            if (info[id])
                info[id].windows.push(tl.wayland?.appId || tl.lastIpcObject?.class || "");
        }
        workspaces = info;
    }

    // Workspaces holding a window that asked for attention, kept until the
    // workspace is visited (Quickshell's own urgent flags clear on the next
    // focus change anywhere)
    property var urgentIds: ({})

    function markUrgent(address) {
        const bare = a => String(a).replace(/^0x/, "");
        const tl = Hyprland.toplevels.values.find(t => bare(t.address) === bare(address));
        const id = tl?.workspace?.id ?? 0;
        if (id <= 0 || tl.workspace.active)
            return;
        urgentIds = Object.assign({}, urgentIds, {
            [id]: true
        });
    }

    onActiveIdChanged: {
        if (urgentIds[activeId]) {
            let ids = Object.assign({}, urgentIds);
            delete ids[activeId];
            urgentIds = ids;
        }
    }
    onUrgentIdsChanged: updateTimer.restart()

    // --- Special Workspace ---
    // Name as reported by activespecial ("special:magic"), "" when closed
    property string specialRaw: ""
    readonly property bool specialActive: specialRaw !== ""
    readonly property string specialName: specialRaw.startsWith("special:") ? specialRaw.substring(8) : specialRaw

    readonly property var specialWorkspaces: ({
            "whatsapp": {
                icon: "󰖣",
                color: Config.successColor,
                name: "WhatsApp"
            },
            "spotify": {
                icon: "󰓇",
                color: Config.accentColor,
                name: "Music"
            },
            "magic": {
                icon: "󰀘",
                color: Config.warningColor,
                name: "Magic"
            }
        })

    readonly property var currentSpecialConfig: {
        if (!specialActive)
            return null;
        return specialWorkspaces[specialName] ?? {
            icon: "󰀘",
            color: Config.accentColor,
            name: specialName.charAt(0).toUpperCase() + specialName.slice(1)
        };
    }

    // Last special shown, kept while the badge animates out so it doesn't
    // flash back to the defaults
    property string specialIcon: "󰀘"
    property string specialLabel: ""
    property color specialColor: Config.accentColor

    onCurrentSpecialConfigChanged: {
        if (currentSpecialConfig) {
            specialIcon = currentSpecialConfig.icon;
            specialLabel = currentSpecialConfig.name;
            specialColor = currentSpecialConfig.color;
        }
    }

    // --- Actions ---
    function focus(id) {
        if (id !== activeId)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }
    // Next (1) or previous (-1) workspace of this monitor's block, skipping
    // empty ones when they're hidden
    function step(direction, skipEmpty) {
        const first = monitorOffset + 1;
        const last = monitorOffset + totalWorkspaces;
        let id = activeId + direction;
        while (skipEmpty && id >= first && id <= last && !isOccupied(id))
            id += direction;
        if (id >= first && id <= last)
            focus(id);
    }
    function toggleSpecial() {
        if (specialName)
            Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + specialName + "\")");
    }

    // --- Event Handling ---
    Component.onCompleted: update()

    property Timer updateTimer: Timer {
        interval: 10
        onTriggered: root.update()
    }

    property Connections events: Connections {
        target: Hyprland
        enabled: root.live
        function onRawEvent(event) {
            if (!event)
                return;
            if (event.name === "activespecial") {
                const parts = event.data.split(',');
                const target = parts[1] || "";
                if (target === "" || target === root.monitorName)
                    root.specialRaw = parts[0] || "";
            }
            if (event.name === "workspace")
                root.specialRaw = "";
            if (event.name === "urgent")
                root.markUrgent(event.data);
            const refreshEvents = ["workspace", "createworkspace", "destroyworkspace", "movewindow", "openwindow", "closewindow"];
            if (refreshEvents.includes(event.name))
                root.updateTimer.restart();
        }
    }
}
