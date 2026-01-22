pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import "./modules/bar/"

ShellRoot {
    id: root

    // =========================================================================
    // ESTADO GLOBAL DOS MÓDULOS
    // =========================================================================

    property bool screenshotActive: false

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
    // COMPONENTES DA UI - LAZY LOADING
    // =========================================================================

    // Bar - sempre ativo (componente principal)
    Bar {}

    // Notifications - carrega sob demanda quando há notificações
    Loader {
        id: notificationLoader
        active: NotificationService.activePopupCount > 0 || NotificationService.popups.length > 0
        source: "./modules/notifications/NotificationOverlay.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] NotificationOverlay carregado");
        }
    }

    // Power Overlay - carrega sob demanda quando solicitado
    Loader {
        id: powerLoader
        active: PowerService.overlayVisible
        source: "./modules/power/PowerOverlay.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] PowerOverlay carregado");
        }
    }

    // Screenshot Manager - carrega sob demanda
    Loader {
        id: screenshotLoader
        active: root.screenshotActive
        source: "./modules/screenshot/ScreenshotManager.qml"

        onStatusChanged: {
            if (status === Loader.Ready) {
                console.log("[Shell] ScreenshotManager carregado");
                screenshotLoader.item.startCapture();
            }
        }

        // Desativa quando o screenshot termina
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

    // Launcher
    Loader {
        active: true
        source: "./modules/launcher/Launcher.qml"
    }

    // =========================================================================
    // ATALHOS GLOBAIS
    // =========================================================================

    // Atalho: Screenshot (Print)
    GlobalShortcut {
        name: "take_screenshot"
        description: "Captura de tela"

        onPressed: {
            console.log("[Shell] Screenshot solicitado");
            root.screenshotActive = true;
        }
    }

    // Atalho: Power Menu
    GlobalShortcut {
        name: "power_menu"
        description: "Menu de energia"

        onPressed: {
            console.log("[Shell] Power menu solicitado");
            PowerService.showOverlay();
        }
    }

    // Atalho: Launcher
    GlobalShortcut {
        name: "app_launcher"
        description: "App Launcher"

        onPressed: LauncherService.show()
    }
}
