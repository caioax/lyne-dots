pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Settings window state and page registry
Singleton {
    id: root

    property bool visible: false
    property string currentPage: "theme"

    // Sidebar entries, grouped by category in this order. Each id needs a
    // component in SettingsWindow.pageComponents
    readonly property var categories: ["Appearance", "Shell", "System"]
    readonly property var pages: [
        {
            id: "theme",
            label: "Theme",
            icon: "\u{f03d8}",
            description: "Color palette, light or dark mode and wallpaper",
            category: "Appearance"
        },
        {
            id: "layout",
            label: "Layout",
            icon: "\u{f0607}",
            description: "Corners, spacing, transparency and motion",
            category: "Appearance"
        },
        {
            id: "typography",
            label: "Typography",
            icon: "\u{f06d6}",
            description: "Interface font and text and icon sizes",
            category: "Appearance"
        },
        {
            id: "bar",
            label: "Bar",
            icon: "\u{f1513}",
            description: "Size and behaviour of the top bar",
            category: "Shell"
        },
        {
            id: "notifications",
            label: "Notifications",
            icon: "\u{f009a}",
            description: "Popups, timeout and do not disturb",
            category: "Shell"
        },
        {
            id: "idle",
            label: "Idle",
            icon: "\u{f04b2}",
            description: "Screen lock, screen off and what keeps the system awake",
            category: "System"
        }
    ]

    readonly property var currentEntry: pages.find(p => p.id === currentPage) ?? pages[0]

    function open(page: string) {
        if (page && pages.some(p => p.id === page))
            currentPage = page;
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            root.open(page);
        }

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.close();
        }
    }
}
