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
import "./modules/notifications/"
import "./modules/settings/"
import "./modules/launcher/"
import qs.config

ShellRoot {
    id: root

    // =========================================================================
    // GLOBAL MODULE STATE
    // =========================================================================

    property bool screenshotActive: false

    // Ensure IdleService singleton loads
    property bool _idleReady: IdleService.caffeineEnabled

    // Keeps hypr/local/settings.lua in sync with state.json
    property string _hyprlandSettings: HyprlandSettingsService.lua

    // Recording a shortcut in Settings puts Hyprland in the empty
    // "lyne_capture" submap. If the shell reloaded or crashed mid-recording,
    // Hyprland would be left without binds: always leave it on (re)load
    Component.onCompleted: Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("reset")'])

    // Idle Monitors
    IdleMonitor {
        timeout: IdleService.lockTimeout
        enabled: IdleService.lockTimeout > 0 && !IdleService.caffeineEnabled && !IdleService.mediaPlaying && !IdleService.systemInhibited && !StateService.isLoading
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
        enabled: IdleService.dpmsTimeout > 0 && !IdleService.caffeineEnabled && !IdleService.mediaPlaying && !IdleService.systemInhibited && IdleService.dpmsEnabled && !StateService.isLoading
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

    // Notifications (the window only maps while there are popups)
    NotificationOverlay {}

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
        sourceComponent: Launcher {}

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

    // Settings window (imported statically: Quickshell only resolves the
    // pages/ and rows/ directories through static imports)
    Loader {
        active: SettingsService.visible
        sourceComponent: SettingsWindow {}
    }

    // Actions requested from the UI (Quick Settings shortcuts)
    Connections {
        target: ShortcutService

        function onScreenshotRequested() {
            root.screenshotActive = true;
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
        description: "Wallpaper settings"

        onPressed: SettingsService.open("wallpaper")
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

    // Shortcut: Settings
    GlobalShortcut {
        name: "settings"
        description: "Settings"

        onPressed: SettingsService.toggle()
    }

    // Shortcut: Keybinds (settings page)
    GlobalShortcut {
        name: "keybinds_help"
        description: "Keybinds settings"

        onPressed: SettingsService.open("keybinds")
    }
}
