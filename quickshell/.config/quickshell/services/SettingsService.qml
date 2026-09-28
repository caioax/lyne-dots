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
    readonly property var categories: ["Appearance", "Shell", "Hyprland", "System"]
    readonly property var pages: [
        {
            id: "theme",
            label: "Theme",
            icon: "\u{f03d8}",
            description: "Color palette, light or dark mode, transparency and wallpaper",
            category: "Appearance"
        },
        {
            id: "wallpaper",
            label: "Wallpaper",
            icon: "\u{f0e09}",
            description: "Your wallpaper library and the wallpaper of each theme",
            category: "Appearance"
        },
        {
            id: "layout",
            label: "Layout",
            icon: "\u{f0607}",
            description: "Corners, spacing and motion",
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
            description: "Template, position, size and behaviour of the bar",
            category: "Shell"
        },
        {
            id: "launcher",
            label: "Launcher",
            icon: "\u{f003b}",
            description: "Template, search, favorites, hidden apps and usage ranking",
            category: "Shell"
        },
        {
            id: "clipboard",
            label: "Clipboard",
            icon: "\u{f014d}",
            description: "What the history keeps, and clearing it",
            category: "Shell"
        },
        {
            id: "dashboard",
            label: "Dashboard",
            icon: "\u{f056e}",
            description: "The panel under the bar clock: overview, system and more",
            category: "Shell"
        },
        {
            id: "power",
            label: "Power",
            icon: "\u{f0425}",
            description: "Power menu template, countdown and actions",
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
            id: "osd",
            label: "OSD",
            icon: "\u{f10a9}",
            description: "Volume and brightness indicator: style, position and when it shows",
            category: "Shell"
        },
        {
            id: "screenshot",
            label: "Screenshot",
            icon: "\u{f0e51}",
            description: "Capture overlay: opening mode, dimming and guides. Opens with Print",
            category: "Shell"
        },
        {
            id: "windows",
            label: "Windows",
            icon: "\u{f05b2}",
            description: "Gaps, borders, tiling and effects. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "input",
            label: "Input",
            icon: "\u{f037d}",
            description: "Mouse, keyboard repeat and touchpad. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "specials",
            label: "Specials",
            icon: "\u{f0018}",
            description: "Hidden app workspaces toggled with a shortcut, like WhatsApp and music",
            category: "Hyprland"
        },
        {
            id: "keybinds",
            label: "Keybinds",
            icon: "\u{f030c}",
            description: "Change, disable or add shortcuts. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "lock",
            label: "Lock screen",
            icon: "\u{f033e}",
            description: "Lock screen template, what it shows and locking before sleep",
            category: "System"
        },
        {
            id: "idle",
            label: "Idle",
            icon: "\u{f04b2}",
            description: "Screen lock, screen off and what keeps the system awake",
            category: "System"
        },
        {
            id: "brightness",
            label: "Brightness",
            icon: "\u{f00df}",
            description: "Brightness keys and external monitors over DDC/CI",
            category: "System"
        },
        {
            id: "apps",
            label: "Apps",
            icon: "\u{f003b}",
            description: "Default terminal, file manager, browser and editor, and their shortcuts",
            category: "System"
        },
        {
            id: "profile",
            label: "Profile & Region",
            icon: "\u{f0009}",
            description: "Profile picture, weather location and AUR helper",
            category: "System"
        },
        {
            id: "about",
            label: "About",
            icon: "\u{f02fd}",
            description: "Dotfiles version, updates and system information",
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
