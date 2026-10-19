pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Quick Settings state: which screen it is open on, the page it shows and
// the toggle tiles. Each bar has its own QuickSettingsWindow that shows
// itself while `screen` names it
Singleton {
    id: root

    // Screen name it is open on ("" = closed) and the page shown ("" = main)
    property string screen: ""
    property string page: ""

    signal shown

    // Sub-pages, how deep each sits (the slide direction follows it) and
    // the page "back" leads to
    readonly property var pages: ({
            "": {
                depth: 0,
                back: ""
            },
            wifi: {
                depth: 1,
                back: ""
            },
            wifiPassword: {
                depth: 2,
                back: "wifi"
            },
            bluetooth: {
                depth: 1,
                back: ""
            },
            nightLight: {
                depth: 1,
                back: ""
            },
            sound: {
                depth: 1,
                back: ""
            },
            notifications: {
                depth: 1,
                back: ""
            },
            powerProfile: {
                depth: 1,
                back: ""
            }
        })

    function hasPage(id: string): bool {
        return pages[id] !== undefined;
    }

    function depth(id: string): int {
        return pages[id]?.depth ?? 0;
    }

    function showPage(id: string): void {
        if (hasPage(id))
            page = id;
    }

    function back(): void {
        page = pages[page]?.back ?? "";
    }

    // Opens on `pageId` ("" = the main page)
    function open(pageId: string, screenName: string): void {
        page = hasPage(pageId) ? pageId : "";
        screen = screenName;
        shown();
    }

    function close(): void {
        screen = "";
    }

    // Closes when already open on that screen (and page, when one is
    // given), otherwise opens or switches to it
    function toggle(pageId: string, screenName: string): void {
        if (screen === screenName && (pageId === "" || pageId === page))
            close();
        else
            open(pageId, screenName);
    }

    function focusedScreen(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    // ========================================================================
    // SHORTCUTS
    // ========================================================================

    // Closes the popup, then runs a shortcut (screenshot, clipboard, lock,
    // power menu, settings with `settingsPage`, "" for its first page) once
    // the popup is gone: a window created in the same frame (Settings, the
    // launcher, the power menu) stalls the closing animation for ~100 ms, and the page that asked is
    // destroyed with the popup, timers and all
    function runShortcut(action: string, settingsPage: string): void {
        close();
        _shortcut = action;
        _settingsPage = settingsPage;
        // The screenshot also waits for the popup's scale animation, so it
        // isn't captured
        shortcutTimer.interval = action === "screenshot" ? Config.animDurationLong : Config.animDuration;
        shortcutTimer.restart();
    }

    property string _shortcut: ""
    property string _settingsPage: ""

    Timer {
        id: shortcutTimer

        onTriggered: {
            switch (root._shortcut) {
            case "screenshot":
                ShortcutService.screenshotRequested();
                break;
            case "clipboard":
                LauncherService.showMode("clipboard");
                break;
            case "lock":
                IdleService.lock();
                break;
            case "power":
                PowerService.show();
                break;
            case "settings":
                SettingsService.open(root._settingsPage);
                break;
            }
        }
    }

    // ========================================================================
    // TILES
    // ========================================================================

    // A toggle tile: `toggle` runs on click, `page` (if any) holds its details
    component Tile: QtObject {
        required property string tileId
        property string label
        property string icon
        property string status
        property bool active
        property bool available: true
        property string page: ""
        property var toggle: () => {}
    }

    // Every tile, in the default order
    readonly property list<Tile> allTiles: [
        Tile {
            tileId: "wifi"
            label: I18n.tr("Wi-Fi")
            icon: NetworkService.systemIcon
            status: NetworkService.statusText
            active: NetworkService.wifiEnabled
            page: "wifi"
            toggle: () => NetworkService.toggleWifi()
        },
        Tile {
            tileId: "bluetooth"
            label: I18n.tr("Bluetooth")
            icon: BluetoothService.systemIcon
            status: BluetoothService.statusText
            active: BluetoothService.isPowered
            available: BluetoothService.adapter !== null
            page: "bluetooth"
            toggle: () => BluetoothService.togglePower()
        },
        Tile {
            tileId: "nightLight"
            label: I18n.tr("Night light")
            icon: BrightnessService.nightLightIcon
            status: BrightnessService.nightLightEnabled ? BrightnessService.nightLightTemperature + "K" : I18n.tr("Off")
            active: BrightnessService.nightLightEnabled
            page: "nightLight"
            toggle: () => BrightnessService.toggleNightLight()
        },
        Tile {
            tileId: "dnd"
            label: I18n.tr("Do not disturb")
            // md-bell_off / md-bell
            icon: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
            status: NotificationService.dndEnabled ? I18n.tr("On") : I18n.tr("Off")
            active: NotificationService.dndEnabled
            toggle: () => NotificationService.toggleDnd()
        },
        Tile {
            tileId: "caffeine"
            label: I18n.tr("Caffeine")
            // md-coffee / md-coffee_outline
            icon: IdleService.caffeineEnabled ? "\u{f06ca}" : "\u{f0faa}"
            status: IdleService.caffeineEnabled ? I18n.tr("Awake") : I18n.tr("Off")
            active: IdleService.caffeineEnabled
            toggle: () => IdleService.toggleCaffeine()
        },
        Tile {
            tileId: "powerProfile"
            label: I18n.tr("Power profile")
            icon: PowerProfileService.icon(PowerProfileService.profile)
            status: PowerProfileService.label(PowerProfileService.profile)
            // Lit away from the default
            active: PowerProfileService.profile !== "balanced"
            available: PowerProfileService.available && PowerProfileService.showTile
            page: "powerProfile"
            toggle: () => PowerProfileService.cycle()
        },
        Tile {
            tileId: "mic"
            label: I18n.tr("Microphone")
            icon: AudioService.sourceIcon
            status: AudioService.sourceMuted ? I18n.tr("Muted") : I18n.tr("On")
            active: AudioService.sourceReady && !AudioService.sourceMuted
            toggle: () => AudioService.toggleSourceMute()
        }
    ]

    // Tiles the panel shows, in order
    readonly property var tiles: {
        const out = [];
        for (let i = 0; i < allTiles.length; i++) {
            if (allTiles[i].available)
                out.push(allTiles[i]);
        }
        return out;
    }

    // `qs ipc call notifications toggleWindow` opens it too
    Connections {
        target: NotificationService

        function onWindowToggleRequested() {
            root.toggle("", root.focusedScreen());
        }
    }

    // ========================================================================
    // IPC — qs ipc call quicksettings <function> [page]
    // ========================================================================

    IpcHandler {
        target: "quicksettings"

        // Pages: wifi, bluetooth, nightLight, sound, notifications, powerProfile
        function toggle(page: string): void {
            root.toggle(page, root.focusedScreen());
        }

        function open(page: string): void {
            root.open(page, root.focusedScreen());
        }

        function close(): void {
            root.close();
        }
    }
}
