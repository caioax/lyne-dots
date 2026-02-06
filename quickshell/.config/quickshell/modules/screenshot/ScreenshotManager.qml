pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    // =========================================================================
    // STATE
    // =========================================================================

    property bool active: false
    property string mode: "region"  // "region", "window", "screen"
    property bool editMode: false
    property string captureTimestamp: ""

    // Selection coordinates
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Confirmation state
    property bool hasSelection: false

    // Window info
    property string selectedWindowTitle: ""
    property string selectedWindowClass: ""

    // Monitor tracking
    property var hyprlandMonitor: Hyprland.focusedMonitor
    property var activeScreen: null

    // IPC data (fresh on each capture)
    property var windowsFromIpc: []
    property var monitorsFromIpc: []

    readonly property var modes: ["region", "window", "screen"]
    readonly property var modeIcons: ({
            region: "󰩭",
            window: "󰖯",
            screen: "󰍹"
        })

    // =========================================================================
    // ANIMATIONS
    // =========================================================================

    Behavior on selectionX {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionY {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionWidth {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionHeight {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }

    // =========================================================================
    // IPC PROCESSES
    // =========================================================================

    Process {
        id: hyprctlMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.monitorsFromIpc = JSON.parse(data);
                } catch (e) {
                    root.monitorsFromIpc = [];
                }
            }
        }
        onExited: hyprctlClients.running = true
    }

    Process {
        id: hyprctlClients
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.windowsFromIpc = JSON.parse(data);
                } catch (e) {
                    root.windowsFromIpc = [];
                }
            }
        }
        onExited: root.startGrimCapture()
    }

    Process {
        id: grimCapture
        onExited: root.active = true
    }

    // =========================================================================
    // PUBLIC FUNCTIONS
    // =========================================================================

    function startCapture() {
        prepareCapture();
        hyprctlMonitors.running = true;
    }

    function tempPathForScreen(screenName: string): string {
        if (root.captureTimestamp === "")
            return "";
        return Quickshell.cachePath(`screenshot-${root.captureTimestamp}-${screenName}.png`);
    }

    function cleanupTempFiles() {
        const paths = [];
        for (let i = 0; i < root.monitorsFromIpc.length; i++) {
            paths.push("'" + tempPathForScreen(root.monitorsFromIpc[i].name) + "'");
        }
        if (paths.length > 0) {
            Quickshell.execDetached(["sh", "-c", "rm -f " + paths.join(" ")]);
        }
        root.captureTimestamp = "";
    }

    function cancelCapture() {
        root.active = false;
        root.hasSelection = false;
        cleanupTempFiles();
    }

    function resetSelection() {
        root.editMode = false;
        root.hasSelection = false;
        root.selectionX = 0;
        root.selectionY = 0;
        root.selectionWidth = 0;
        root.selectionHeight = 0;
        root.selectedWindowTitle = "";
        root.selectedWindowClass = "";
    }

    function setMode(newMode: string) {
        resetSelection();
        root.mode = newMode;

        if (newMode === "screen") {
            root.selectionX = 0;
            root.selectionY = 0;
            root.selectionWidth = root.activeScreen?.width || 1920;
            root.selectionHeight = root.activeScreen?.height || 1080;
            root.hasSelection = true;
            root.selectedWindowTitle = root.hyprlandMonitor?.name || "Monitor";
        }
    }

    function confirmSelection() {
        root.editMode = false;
        saveScreenshot(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
    }

    function editSelection() {
        root.editMode = true;
        saveScreenshot(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
    }

    function checkWindowAt(mouseX: real, mouseY: real, screenName: string) {
        const monitorIpc = root.monitorsFromIpc.find(m => m.name === screenName);
        if (!monitorIpc)
            return;

        const monitorX = monitorIpc.x;
        const monitorY = monitorIpc.y;
        const monitorId = monitorIpc.id;
        const activeWorkspaceId = monitorIpc.activeWorkspace?.id;

        const windows = root.windowsFromIpc;
        if (!windows || windows.length === 0) {
            resetSelection();
            return;
        }

        for (let i = windows.length - 1; i >= 0; i--) {
            let win = windows[i];
            if (!win)
                continue;
            if (win.monitor !== monitorId)
                continue;
            if (win.workspace?.id !== activeWorkspaceId)
                continue;
            if (!win.at || !win.size || win.at.length < 2 || win.size.length < 2)
                continue;
            if ((win.title === "" && win.class === "") || win.hidden)
                continue;

            let winX = win.at[0] - monitorX;
            let winY = win.at[1] - monitorY;
            let winW = win.size[0];
            let winH = win.size[1];

            if (mouseX >= winX && mouseX <= winX + winW && mouseY >= winY && mouseY <= winY + winH) {
                root.selectionX = winX;
                root.selectionY = winY;
                root.selectionWidth = winW;
                root.selectionHeight = winH;
                root.selectedWindowTitle = win.title || win.class || "Window";
                root.selectedWindowClass = win.class || "";
                return;
            }
        }
        resetSelection();
    }

    // =========================================================================
    // PRIVATE FUNCTIONS
    // =========================================================================

    function prepareCapture() {
        root.mode = "region";
        resetSelection();
        root.activeScreen = null;

        const monitor = Hyprland.focusedMonitor;
        if (monitor) {
            for (const screen of Quickshell.screens) {
                if (screen.name === monitor.name) {
                    root.activeScreen = screen;
                    root.hyprlandMonitor = monitor;
                    break;
                }
            }
        }

        root.captureTimestamp = String(Date.now());
    }

    function startGrimCapture() {
        const commands = [];
        for (const monitor of root.monitorsFromIpc) {
            const path = tempPathForScreen(monitor.name);
            commands.push(`grim -o '${monitor.name}' '${path}'`);
        }
        grimCapture.command = ["sh", "-c", commands.join(" & ") + " & wait"];
        grimCapture.running = true;
    }

    function saveScreenshot(x: real, y: real, width: real, height: real) {
        if (width < 5 || height < 5)
            return;

        const scale = root.hyprlandMonitor?.scale || 1;
        const monitorName = root.hyprlandMonitor?.name || "";
        const sourcePath = tempPathForScreen(monitorName);

        // Per-monitor image: no monitor offset needed
        const scaledX = Math.round(x * scale);
        const scaledY = Math.round(y * scale);
        const scaledWidth = Math.round(width * scale);
        const scaledHeight = Math.round(height * scale);

        const picturesDir = Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots");
        const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        const outputPath = `${picturesDir}/screenshot-${timestamp}.png`;

        // Commands
        const createDir = `mkdir -p "${picturesDir}"`;
        const cropImage = `magick "${sourcePath}" -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} +repage "${outputPath}"`;
        const checkAndCopy = `[ -f "${outputPath}" ] && wl-copy < "${outputPath}"`;
        const checkAndNotify = `[ -f "${outputPath}" ] && notify-send -i accessories-screenshot -a "Screenshot" "Screenshot Saved!" "Path: ${outputPath}"`;
        const sattyAction = `magick "${sourcePath}" -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} png:- | satty --filename - --output-filename "${outputPath}" --early-exit --init-tool brush --disable-notifications`;

        // Cleanup all per-monitor temp files
        let cleanPaths = [];
        for (let i = 0; i < root.monitorsFromIpc.length; i++)
            cleanPaths.push("'" + tempPathForScreen(root.monitorsFromIpc[i].name) + "'");
        const cleanTemp = "rm -f " + cleanPaths.join(" ");

        // Steps
        const defaultCmd = [createDir, cropImage, checkAndCopy, cleanTemp, checkAndNotify];
        const sattyCmd = `trap '${cleanTemp}' EXIT; ` + [createDir, sattyAction, checkAndCopy, checkAndNotify].join(" && ");

        const cmd = root.editMode ? sattyCmd : defaultCmd.join(" && ");

        root.active = false;
        root.hasSelection = false;
        root.editMode = false;
        root.captureTimestamp = "";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // =========================================================================
    // OVERLAY (loaded only when active)
    // =========================================================================

    Loader {
        active: root.active
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens

                delegate: ScreenshotOverlay {
                    required property var modelData
                    screen: modelData
                    screenshot: root
                }
            }
        }
    }
}
