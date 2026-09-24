pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Shell actions for the launcher's ">" mode. Each item is
// { id, name, comment, glyph, keywords, run, confirm? }; `confirm` asks for a
// second Enter (power actions). Toggles name the state they switch to
Singleton {
    id: root

    readonly property var power: [
        {
            id: "lock",
            name: "Lock screen",
            comment: "Lock the session",
            glyph: "\u{f033e}",
            keywords: ["lock"],
            run: () => PowerService.lock()
        },
        {
            id: "suspend",
            name: "Suspend",
            comment: "Sleep, keeping the session in memory",
            glyph: "\u{f0904}",
            keywords: ["sleep"],
            run: () => PowerService.suspend()
        },
        {
            id: "logout",
            name: "Log out",
            comment: "End the Hyprland session",
            glyph: "\u{f0343}",
            keywords: ["exit", "sign out"],
            confirm: true,
            run: () => PowerService.logout()
        },
        {
            id: "reboot",
            name: "Reboot",
            comment: "Restart the computer",
            glyph: "\u{f0709}",
            keywords: ["restart"],
            confirm: true,
            run: () => PowerService.reboot()
        },
        {
            id: "shutdown",
            name: "Shut down",
            comment: "Power off the computer",
            glyph: "\u{f0425}",
            keywords: ["power off", "poweroff"],
            confirm: true,
            run: () => PowerService.shutdown()
        },
        {
            id: "power-menu",
            name: "Power menu",
            comment: "Open the power overlay",
            glyph: "\u{f0426}",
            keywords: ["session"],
            run: () => PowerService.showOverlay()
        }
    ]

    readonly property var tools: [
        {
            id: "screenshot",
            name: "Take a screenshot",
            comment: "Select a region, a window or the screen",
            glyph: "\u{f0e51}",
            keywords: ["print", "capture"],
            run: () => ShortcutService.screenshotRequested()
        },
        {
            id: "clipboard",
            name: "Clipboard history",
            comment: "Paste something copied earlier",
            glyph: "\u{f014d}",
            keywords: ["paste", "copy"],
            run: () => ClipboardService.show()
        },
        {
            id: "wallpaper",
            name: "Random wallpaper",
            comment: "Pick another wallpaper from your library",
            glyph: "\u{f049f}",
            keywords: ["background", "shuffle"],
            run: () => WallpaperService.setRandomWallpaper()
        }
    ]

    readonly property var toggles: [
        {
            id: "dnd",
            name: NotificationService.dndEnabled ? "Turn off Do not disturb" : "Turn on Do not disturb",
            comment: NotificationService.dndEnabled ? "Notification popups are hidden" : "Hide notification popups",
            glyph: NotificationService.dndEnabled ? "\u{f009a}" : "\u{f009b}",
            keywords: ["dnd", "notifications", "silence"],
            run: () => NotificationService.toggleDnd()
        },
        {
            id: "caffeine",
            name: IdleService.caffeineEnabled ? "Turn off Caffeine" : "Turn on Caffeine",
            comment: IdleService.caffeineEnabled ? "The screen is kept awake" : "Keep the screen awake",
            glyph: IdleService.caffeineEnabled ? "\u{f0faa}" : "\u{f0176}",
            keywords: ["awake", "idle", "inhibit"],
            run: () => IdleService.toggleCaffeine()
        },
        {
            id: "night-light",
            name: BrightnessService.nightLightEnabled ? "Turn off Night light" : "Turn on Night light",
            comment: BrightnessService.nightLightEnabled ? "The screen is warmer" : "Warmer colors for the evening",
            glyph: "\u{f0594}",
            keywords: ["blue light", "warm"],
            run: () => BrightnessService.toggleNightLight()
        }
    ]

    // One action per Settings page
    readonly property var settings: SettingsService.pages.map(page => ({
                id: "settings-" + page.id,
                name: page.label + " settings",
                comment: page.description,
                glyph: page.icon,
                keywords: ["settings", "preferences", page.category],
                run: () => SettingsService.open(page.id)
            }))

    readonly property var items: [...toggles, ...tools, ...settings, ...power]
}
