pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Dashboard state: which screen it is open on and the current tab. Each bar
// has its own DashboardWindow that shows itself while `screen` names it
Singleton {
    id: root

    // Tab bar entries, in order. Each id needs a component in DashboardWindow
    readonly property var tabs: [
        {
            id: "overview",
            label: "Overview",
            icon: "\u{f056e}"
        },
        {
            id: "system",
            label: "System",
            icon: "\u{f035b}"
        }
    ]
    readonly property string defaultTab: "overview"

    // Screen name the dashboard is open on ("" = closed)
    property string screen: ""
    property string tab: defaultTab
    readonly property bool visible: screen !== ""
    readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.id === tab))

    // Asks the window on `screen` to show itself, even while it is closing
    signal shown

    function hasTab(id: string): bool {
        return tabs.some(t => t.id === id);
    }

    // Opens on `tabId` ("" keeps the current tab, or the default one when
    // closed)
    function open(tabId: string, screenName: string): void {
        if (tabId !== "" && hasTab(tabId))
            tab = tabId;
        else if (!visible)
            tab = defaultTab;
        screen = screenName;
        shown();
    }

    function close(): void {
        screen = "";
    }

    // Closes when already open on that screen and tab ("" = any tab),
    // otherwise opens or switches to it
    function toggle(tabId: string, screenName: string): void {
        if (screen === screenName && (tabId === "" || tabId === tab))
            close();
        else
            open(tabId, screenName);
    }

    function cycleTab(step: int): void {
        const i = (tabIndex + step + tabs.length) % tabs.length;
        tab = tabs[i].id;
    }

    function focusedScreen(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    // ========================================================================
    // IPC — qs ipc call dashboard <function> [tab]
    // ========================================================================

    IpcHandler {
        target: "dashboard"

        function toggle(tab: string): void {
            root.toggle(tab, root.focusedScreen());
        }

        function open(tab: string): void {
            root.open(tab, root.focusedScreen());
        }

        function close(): void {
            root.close();
        }
    }
}
