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

    // Every tab, in order. Each id needs a component in DashboardWindow
    readonly property var allTabs: [
        {
            id: "overview",
            label: "Overview",
            icon: "\u{f056e}",
            description: "Clock, weather, the month, the player and resource usage"
        },
        {
            id: "media",
            label: "Media",
            icon: "\u{f075a}",
            description: "Full player with the visualizer, lyrics and the players"
        },
        {
            id: "system",
            label: "System",
            icon: "\u{f035b}",
            description: "CPU, GPU, memory, storage, network and top processes"
        },
        {
            id: "weather",
            label: "Weather",
            icon: "\u{f0595}",
            description: "Now, the next 24 hours and the week"
        }
    ]
    // Hidden in Settings (at least one always stays)
    readonly property var hiddenTabs: StateService.get("dashboard.hiddenTabs", [])
    readonly property var tabs: {
        const shown = allTabs.filter(t => !hiddenTabs.includes(t.id));
        return shown.length > 0 ? shown : [allTabs[0]];
    }

    // Tab the dashboard opens on: a tab id, or "last" for the one it was on
    readonly property string openOn: StateService.get("dashboard.defaultTab", "overview")
    readonly property string defaultTab: hasTab(openOn) ? openOn : tabs[0].id

    onTabsChanged: {
        if (!hasTab(tab))
            tab = tabs[0].id;
    }

    function setTabShown(id: string, shown: bool): void {
        const hidden = hiddenTabs.filter(t => t !== id);
        if (!shown)
            hidden.push(id);
        StateService.set("dashboard.hiddenTabs", hidden);
    }

    // Overview template: "stacked" (cards in rows, the Quick Settings player)
    // or "grid" (three columns with a tall player, wider panel)
    readonly property string overviewLayout: StateService.get("dashboard.overviewLayout", "stacked")
    readonly property int panelWidth: overviewLayout === "grid" ? 840 : 720

    // GIF next to the players (animates while something plays). An empty
    // path means the bundled bongocat
    readonly property bool showGif: StateService.get("dashboard.showGif", true)
    readonly property string gifPath: StateService.get("dashboard.gif", "")
    readonly property url gifSource: gifPath !== "" ? "file://" + gifPath : Qt.resolvedUrl("../assets/bongocat.gif")
    readonly property string gifDir: Quickshell.env("HOME") + "/.local/share/quickshell"

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
        else if (!visible && !(openOn === "last" && hasTab(tab)))
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

    function pickGif(): void {
        if (!gifPicker.running)
            gifPicker.running = true;
    }

    function resetGif(): void {
        StateService.set("dashboard.gif", "");
    }

    // The GIF is copied (with a unique name, so the image cache doesn't keep
    // the old one) and survives the original being moved or deleted
    Process {
        id: gifPicker
        command: ["bash", "-c", `
            file=$(zenity --file-selection --title="Choose a GIF" --file-filter="GIF | *.gif" 2>/dev/null) || exit 0
            [ -f "$file" ] || exit 0
            dir="${root.gifDir}"
            mkdir -p "$dir" && rm -f "$dir"/media-gif-*
            dest="$dir/media-gif-$(date +%s).gif"
            cp "$file" "$dest" && echo "$dest"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    StateService.set("dashboard.gif", path);
            }
        }
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
