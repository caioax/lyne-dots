pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Shell actions for the launcher's ">" mode. Each item is
// { id, name, comment, glyph, keywords, run, confirm? }; `confirm` asks for a
// second Enter. Toggles name the state they switch to
Singleton {
    id: root

    // Destructive ones count down in the power menu (PowerService.request)
    readonly property var power: PowerService.availableActions.map(a => ({
                id: a.id,
                name: a.name,
                comment: a.comment,
                glyph: a.glyph,
                keywords: a.keywords,
                run: () => PowerService.request(a.id)
            })).concat([
            {
                id: "power-menu",
                name: "Power menu",
                comment: "Lock, suspend, log out, reboot or shut down",
                glyph: "\u{f0426}",
                keywords: ["session"],
                run: () => PowerService.show()
            }
        ])

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
            // Switches the launcher to its clipboard mode
            stay: true,
            run: () => LauncherService.toggleMode("clipboard")
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
