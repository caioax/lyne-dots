pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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
            label: "Wi-Fi"
            icon: NetworkService.systemIcon
            status: NetworkService.statusText
            active: NetworkService.wifiEnabled
            page: "wifi"
            toggle: () => NetworkService.toggleWifi()
        },
        Tile {
            tileId: "bluetooth"
            label: "Bluetooth"
            icon: BluetoothService.systemIcon
            status: BluetoothService.statusText
            active: BluetoothService.isPowered
            available: BluetoothService.adapter !== null
            page: "bluetooth"
            toggle: () => BluetoothService.togglePower()
        },
        Tile {
            tileId: "nightLight"
            label: "Night light"
            icon: BrightnessService.nightLightIcon
            status: BrightnessService.nightLightEnabled ? BrightnessService.nightLightTemperature + "K" : "Off"
            active: BrightnessService.nightLightEnabled
            page: "nightLight"
            toggle: () => BrightnessService.toggleNightLight()
        },
        Tile {
            tileId: "dnd"
            label: "Do not disturb"
            // md-bell_off / md-bell
            icon: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
            status: NotificationService.dndEnabled ? "On" : "Off"
            active: NotificationService.dndEnabled
            toggle: () => NotificationService.toggleDnd()
        },
        Tile {
            tileId: "caffeine"
            label: "Caffeine"
            // md-coffee / md-coffee_outline
            icon: IdleService.caffeineEnabled ? "\u{f06ca}" : "\u{f0faa}"
            status: IdleService.caffeineEnabled ? "Awake" : "Off"
            active: IdleService.caffeineEnabled
            toggle: () => IdleService.toggleCaffeine()
        },
        Tile {
            tileId: "mic"
            label: "Microphone"
            icon: AudioService.sourceIcon
            status: AudioService.sourceMuted ? "Muted" : "On"
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

        // Pages: wifi, bluetooth, nightLight, sound, notifications
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
