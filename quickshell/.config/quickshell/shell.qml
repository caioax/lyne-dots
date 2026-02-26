//@ pragma Env QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import "./modules/bar/"
import "./modules/power/"
import "./modules/screenshot/"
import qs.config

ShellRoot {
    id: root

    // =========================================================================
    // GLOBAL MODULE STATE
    // =========================================================================

    property bool screenshotActive: false

    // Ensure IdleService singleton loads
    property bool _idleReady: IdleService.caffeineEnabled

    // Idle Monitors
    IdleMonitor {
        timeout: IdleService.lockTimeout
        enabled: !IdleService.caffeineEnabled && !IdleService.mediaPlaying && !IdleService.systemInhibited && !StateService.isLoading
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                console.log("[Idle] Lock timeout reached");
                IdleService.lock();
            }
        }
    }

    IdleMonitor {
        timeout: IdleService.dpmsTimeout
        enabled: !IdleService.caffeineEnabled && !IdleService.mediaPlaying && !IdleService.systemInhibited && IdleService.dpmsEnabled && !StateService.isLoading
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                console.log("[Idle] DPMS timeout, displays off");
                IdleService.dpmsOff();
            } else {
                console.log("[Idle] User returned, displays on");
                IdleService.dpmsOn();
            }
        }
    }

    // =========================================================================
    // BLUETOOTH AGENT
    // =========================================================================

    readonly property string bluetoothAgentScriptPath: Qt.resolvedUrl("./scripts/bluetooth-agent.py").toString().replace("file://", "")

    Process {
        id: bluetoothAgent
        command: ["python3", root.bluetoothAgentScriptPath]
        running: true

        stdout: SplitParser {
            onRead: data => console.log("[BluetoothAgent]: " + data)
        }
        stderr: SplitParser {
            onRead: data => console.error("[BluetoothAgent]: " + data)
        }
    }

    // =========================================================================
    // UI COMPONENTS - LAZY LOADING
    // =========================================================================

    // Bar - always active (main component)
    Bar {}

    // Notifications
    Loader {
        id: notificationLoader
        active: NotificationService.activePopupCount > 0 || NotificationService.popups.length > 0
        source: "./modules/notifications/NotificationOverlay.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] NotificationOverlay loaded");
        }
    }

    // Lock Screen
    Loader {
        id: lockLoader
        active: LockService.locked
        source: "./modules/lock/LockScreen.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] LockScreen loaded");
        }
    }

    // Power Overlay
    Loader {
        id: powerLoader
        active: PowerService.overlayVisible
        source: "./modules/power/PowerOverlay.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] PowerOverlay loaded");
        }
    }

    // Screenshot Manager
    Loader {
        id: screenshotLoader
        active: root.screenshotActive
        source: "./modules/screenshot/ScreenshotManager.qml"

        onStatusChanged: {
            if (status === Loader.Ready) {
                console.log("[Shell] ScreenshotManager loaded");
                screenshotLoader.item.startCapture();
            }
        }

        // Deactivate when screenshot finishes
        Connections {
            target: screenshotLoader.item
            enabled: screenshotLoader.status === Loader.Ready

            function onActiveChanged() {
                if (screenshotLoader.item && !screenshotLoader.item.active) {
                    root.screenshotActive = false;
                }
            }
        }
    }

    // Launcher — keepAlive lets the exit animation finish before destroying the component
    Loader {
        id: launcherLoader

        property bool _shown: LauncherService.visible
        property bool _keepAlive: false

        active: _shown || _keepAlive
        source: "./modules/launcher/Launcher.qml"

        on_ShownChanged: {
            if (!_shown) {
                _keepAlive = true;
                launcherExitTimer.restart();
            }
        }

        Timer {
            id: launcherExitTimer
            interval: Config.animDurationLong
            onTriggered: launcherLoader._keepAlive = false
        }
    }

    // OSD
    Loader {
        active: OsdService.visible
        source: "./modules/osd/OsdOverlay.qml"
    }

    // Wallpaper Picker — keepAlive lets the exit animation finish before destroying the component
    Loader {
        id: wallpaperLoader

        property bool _shown: WallpaperService.pickerVisible
        property bool _keepAlive: false

        active: _shown || _keepAlive
        source: "./modules/wallpaper/WallpaperPicker.qml"

        on_ShownChanged: {
            if (!_shown) {
                _keepAlive = true;
                wallpaperExitTimer.restart();
            }
        }

        Timer {
            id: wallpaperExitTimer
            interval: Config.animDurationLong
            onTriggered: wallpaperLoader._keepAlive = false
        }
    }

    // Clipboard History — keepAlive lets the exit animation finish before destroying the component
    Loader {
        id: clipboardLoader

        property bool _shown: ClipboardService.visible
        property bool _keepAlive: false

        active: _shown || _keepAlive
        source: "./modules/clipboard/ClipboardHistory.qml"

        on_ShownChanged: {
            if (!_shown) {
                _keepAlive = true;
                clipboardExitTimer.restart();
            }
        }

        Timer {
            id: clipboardExitTimer
            interval: Config.animDurationLong
            onTriggered: clipboardLoader._keepAlive = false
        }
    }

    // Keybinds Overlay
    Loader {
        id: keybindsLoader
        active: false
        source: "./modules/keybinds/KeybindsOverlay.qml"

        function toggle() {
            if (active && item) {
                item.hide();
                active = false;
            } else {
                active = true;
            }
        }

        Connections {
            target: keybindsLoader.item
            enabled: keybindsLoader.status === Loader.Ready

            function onShowingChanged() {
                if (keybindsLoader.item && !keybindsLoader.item.showing)
                    keybindsLoader.active = false;
            }
        }

        onStatusChanged: {
            if (status === Loader.Ready && item)
                item.showing = true;
        }
    }

    // =========================================================================
    // GLOBAL SHORTCUTS
    // =========================================================================

    // Shortcut: Screenshot (Print)
    GlobalShortcut {
        name: "take_screenshot"
        description: "Screenshot capture"

        onPressed: {
            console.log("[Shell] Screenshot requested");
            root.screenshotActive = true;
        }
    }

    // Shortcut: Power Menu
    GlobalShortcut {
        name: "power_menu"
        description: "Power menu"

        onPressed: {
            console.log("[Shell] Power menu requested");
            PowerService.showOverlay();
        }
    }

    // Shortcut: Launcher
    GlobalShortcut {
        name: "app_launcher"
        description: "App Launcher"

        onPressed: LauncherService.show()
    }

    // Shortcut: Volume Up
    GlobalShortcut {
        name: "volume_up"
        description: "Increase volume"

        onPressed: {
            AudioService.increaseVolume();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Volume Down
    GlobalShortcut {
        name: "volume_down"
        description: "Decrease volume"

        onPressed: {
            AudioService.decreaseVolume();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Volume Mute
    GlobalShortcut {
        name: "volume_mute"
        description: "Mute volume"

        onPressed: {
            AudioService.toggleMute();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Brightness Up
    GlobalShortcut {
        name: "brightness_up"
        description: "Increase brightness"

        onPressed: {
            BrightnessService.increaseBrightness();
            OsdService.showBrightness(BrightnessService.brightness);
        }
    }

    // Shortcut: Brightness Down
    GlobalShortcut {
        name: "brightness_down"
        description: "Decrease brightness"

        onPressed: {
            BrightnessService.decreaseBrightness();
            OsdService.showBrightness(BrightnessService.brightness);
        }
    }

    // Shortcut: Wallpaper Picker
    GlobalShortcut {
        name: "wallpaper_picker"
        description: "Wallpaper picker"

        onPressed: WallpaperService.toggle()
    }

    // Shortcut: Clipboard History
    GlobalShortcut {
        name: "clipboard_history"
        description: "Clipboard history"

        onPressed: ClipboardService.toggle()
    }

    // Shortcut: Lock Screen
    GlobalShortcut {
        name: "lock_screen"
        description: "Lock screen"

        onPressed: IdleService.lock()
    }

    // Shortcut: Keybinds Help
    GlobalShortcut {
        name: "keybinds_help"
        description: "Keybinds help"

        onPressed: keybindsLoader.toggle()
    }
}
