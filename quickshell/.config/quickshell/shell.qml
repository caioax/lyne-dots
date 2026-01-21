import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import "./modules/bar/"
import "./modules/notifications/"
import "./modules/power/"
import "./modules/screenshot/"

ShellRoot {
    id: root

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
    // COMPONENTES DA UI
    // =========================================================================

    Loader {
        active: true
        sourceComponent: Bar {}
    }

    NotificationOverlay {}
    PowerOverlay {}

    // Screenshot Manager
    ScreenshotManager {
        id: screenshotManager
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
            screenshotManager.startCapture();
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
}
