pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // ========================================================================
    // CENTRALIZED SHORTCUT CONFIGURATION
    // ========================================================================

    // Here you define all system shortcuts
    // Format: { name: string, description: string }

    readonly property var shortcuts: ({
            screenshot: {
                name: "take_screenshot",
                description: "Screenshot (region/window/screen)"
            },
            power: {
                name: "power_menu",
                description: "Power menu (shutdown/reboot/etc)"
            },
            quickSettings: {
                name: "quick_settings",
                description: "Quick settings"
            },
            notifications: {
                name: "notifications",
                description: "Notification center"
            },
            clipboard: {
                name: "clipboard_history",
                description: "Clipboard history"
            }
        })

    // ========================================================================
    // SIGNALS FOR ACTIONS
    // ========================================================================

    signal screenshotRequested
    signal powerMenuRequested
    signal quickSettingsRequested
    signal notificationsRequested
    signal clipboardRequested

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function triggerAction(shortcutName: string) {
        console.log("[Shortcuts] Triggered:", shortcutName);

        switch (shortcutName) {
        case "take_screenshot":
            screenshotRequested();
            break;
        case "power_menu":
            powerMenuRequested();
            break;
        case "quick_settings":
            quickSettingsRequested();
            break;
        case "notifications":
            notificationsRequested();
            break;
        case "clipboard_history":
            clipboardRequested();
            break;
        default:
            console.warn("[Shortcuts] Unknown shortcut:", shortcutName);
        }
    }

    function getShortcutName(key: string): string {
        if (shortcuts.hasOwnProperty(key)) {
            return shortcuts[key].name;
        }
        return "";
    }

    function getDescription(key: string): string {
        if (shortcuts.hasOwnProperty(key)) {
            return shortcuts[key].description;
        }
        return "";
    }
}
