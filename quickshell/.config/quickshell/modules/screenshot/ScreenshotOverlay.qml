pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config

PanelWindow {
    id: root

    required property var screenshot

    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Hyprland rule qs_screenshot turns off the open animation: the frozen
    // screen sliding in over the live one shows both
    WlrLayershell.namespace: "qs_screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    // Monitor info
    property var hyprMonitor: Hyprland.monitorFor(modelData)
    property bool isActiveMonitor: screen === root.screenshot.activeScreen

    // =================================================================
    // FROZEN SCREEN CAPTURE - using grim captured image
    // =================================================================

    Image {
        anchors.fill: parent
        source: root.screenshot.captureTimestamp ? "file://" + root.screenshot.tempPathForScreen(root.screen.name) : ""
        fillMode: Image.PreserveAspectCrop
        z: 0
        cache: false
    }

    // =================================================================
    // DIMMING SHADER
    // =================================================================

    ShaderEffect {
        anchors.fill: parent
        z: 1
        visible: root.isActiveMonitor

        property vector4d selectionRect: Qt.vector4d(root.screenshot.selectionX, root.screenshot.selectionY, root.screenshot.selectionWidth, root.screenshot.selectionHeight)
        property color dimColor: Config.scrimColor
        property color outlineColor: Config.accentColor
        property real dimOpacity: Config.screenshotDim
        property vector2d screenSize: Qt.vector2d(width, height)
        property real borderRadius: root.screenshot.selectionRadius
        property real outlineThickness: root.screenshot.hyprBorderSize

        fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")
    }

    // Dim inactive monitors
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Config.scrimColor, Config.screenshotDim)
        visible: !root.isActiveMonitor
        z: 1
    }

    // =================================================================
    // REGION SELECTOR
    // =================================================================

    // Above the overlay's MouseArea: its handles and inside take the
    // presses they cover
    RegionSelector {
        id: regionSelector
        anchors.fill: parent
        visible: root.isActiveMonitor && root.screenshot.mode === "region"
        screenshot: root.screenshot
        guideMouseX: root.screenshot.cursorFromIpc.x - root.screen.x
        guideMouseY: root.screenshot.cursorFromIpc.y - root.screen.y
        z: 7
    }

    // =================================================================
    // WINDOW SELECTOR
    // =================================================================

    WindowSelector {
        anchors.fill: parent
        visible: root.isActiveMonitor && root.screenshot.mode === "window"
        screenshot: root.screenshot
        monitorScreen: root.screen
        z: 3
    }

    // =================================================================
    // MOUSE INTERACTION
    // =================================================================

    MouseArea {
        id: mainMouse
        anchors.fill: parent
        z: 5
        hoverEnabled: true

        cursorShape: {
            if (root.screenshot.mode === "window")
                return Qt.PointingHandCursor;
            if (root.screenshot.mode === "screen")
                return Qt.ArrowCursor;
            return Qt.CrossCursor;
        }

        property real startX: 0
        property real startY: 0
        property bool dragging: false

        onEntered: {
            root.screenshot.activeScreen = root.screen;
            root.screenshot.hyprlandMonitor = root.hyprMonitor;

            if (root.screenshot.mode === "screen") {
                root.screenshot.setMode("screen");
            }
        }

        onPositionChanged: mouse => {
            regionSelector.guideMouseX = mouse.x;
            regionSelector.guideMouseY = mouse.y;
            if (root.screenshot.mode === "window" && !root.screenshot.hasSelection) {
                root.screenshot.checkWindowAt(mouse.x, mouse.y, root.screen.name);
            }

            if (root.screenshot.activeScreen !== root.screen) {
                root.screenshot.activeScreen = root.screen;
                root.screenshot.hyprlandMonitor = root.hyprMonitor;
                if (root.screenshot.mode === "screen") {
                    root.screenshot.setMode("screen");
                }
            }

            if (dragging)
                root.screenshot.setRegion(startX, startY, mouse.x, mouse.y);
        }

        // Region: a press outside the current region (the handles and the
        // inside are above) starts a new one. Window: a click picks the
        // window under the cursor, even with another one picked
        onPressed: mouse => {
            if (root.screenshot.mode === "region") {
                root.screenshot.resetSelection();
                startX = mouse.x;
                startY = mouse.y;
                root.screenshot.setRegion(mouse.x, mouse.y, mouse.x, mouse.y);
                dragging = true;
            } else if (root.screenshot.mode === "window") {
                root.screenshot.checkWindowAt(mouse.x, mouse.y, root.screen.name);
                root.screenshot.hasSelection = root.screenshot.selectionWidth > 0;
            }
        }

        onReleased: {
            if (!dragging)
                return;
            dragging = false;
            // A click without a drag leaves the crosshair
            if (root.screenshot.selectionWidth > Config.spacing && root.screenshot.selectionHeight > Config.spacing)
                root.screenshot.hasSelection = true;
            else
                root.screenshot.resetSelection();
        }

        onDoubleClicked: {
            if (root.screenshot.mode === "window" && root.screenshot.canConfirm)
                root.screenshot.confirmSelection();
        }
    }

    // =================================================================
    // SHORTCUTS
    // =================================================================

    Shortcut {
        sequence: "Escape"
        onActivated: root.screenshot.cancelCapture()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.screenshot.canConfirm
        onActivated: root.screenshot.confirmSelection()
    }

    // Arrows move the region 1px, Shift 10px; with Ctrl they resize it
    Instantiator {
        model: {
            const keys = [];
            for (const [key, dx, dy] of [["Left", -1, 0], ["Right", 1, 0], ["Up", 0, -1], ["Down", 0, 1]])
                for (const [prefix, step, resize] of [["", 1, false], ["Shift+", 10, false], ["Ctrl+", 1, true], ["Ctrl+Shift+", 10, true]])
                    keys.push({
                        sequence: prefix + key,
                        dx: dx * step,
                        dy: dy * step,
                        resize: resize
                    });
            return keys;
        }

        delegate: Shortcut {
            required property var modelData

            sequence: modelData.sequence
            enabled: root.isActiveMonitor && root.screenshot.mode === "region" && root.screenshot.hasSelection
            autoRepeat: true
            onActivated: root.screenshot.nudge(modelData.dx, modelData.dy, modelData.resize)
        }
    }

    Shortcut {
        sequence: "r"
        onActivated: root.screenshot.setMode("region")
    }

    Shortcut {
        sequence: "w"
        onActivated: root.screenshot.setMode("window")
    }

    Shortcut {
        sequence: "s"
        onActivated: root.screenshot.setMode("screen")
    }

    // =================================================================
    // CONTROL BAR
    // =================================================================

    ControlBar {
        visible: root.isActiveMonitor
        screenshot: root.screenshot
        z: 10
    }

    // =================================================================
    // DIMENSION INDICATOR
    // =================================================================

    // Only while it fits inside the selection
    Rectangle {
        visible: root.isActiveMonitor && root.screenshot.selectionWidth > width + Config.spacing * 2 && root.screenshot.selectionHeight > height + Config.spacing * 2 && root.screenshot.mode !== "screen"
        z: 6

        x: root.screenshot.selectionX + root.screenshot.selectionWidth / 2 - width / 2
        y: root.screenshot.selectionY + root.screenshot.selectionHeight / 2 - height / 2

        width: dimLabel.implicitWidth + Config.spacing * 2
        height: dimLabel.implicitHeight + Config.spacing
        radius: Config.radiusSmall
        color: Qt.alpha(Config.surface0Color, 0.9)

        Text {
            id: dimLabel
            anchors.centerIn: parent
            text: root.screenshot.realWidth + " × " + root.screenshot.realHeight
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }
    }

    // =================================================================
    // WINDOW/MONITOR INFO
    // =================================================================

    Rectangle {
        visible: root.isActiveMonitor && (root.screenshot.mode === "window" || root.screenshot.mode === "screen") && root.screenshot.selectedWindowTitle !== ""
        z: 6

        x: root.screenshot.selectionX + Config.spacing * 1.5
        y: root.screenshot.selectionY + Config.spacing * 1.5

        width: infoRow.implicitWidth + Config.spacing * 2.5
        height: infoRow.implicitHeight + Config.spacing * 1.5
        radius: Config.radius
        color: Qt.alpha(Config.surface0Color, 0.95)
        border.width: root.screenshot.hyprBorderSize
        border.color: Config.accentColor

        Row {
            id: infoRow
            anchors.centerIn: parent
            spacing: Config.spacing

            Text {
                text: root.screenshot.modeIcons[root.screenshot.mode] ?? ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: root.screenshot.selectedWindowTitle
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.textColor
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Config.fontSizeSmall * 20)
                }

                Text {
                    visible: root.screenshot.selectedWindowClass !== "" && root.screenshot.selectedWindowClass !== root.screenshot.selectedWindowTitle
                    text: root.screenshot.selectedWindowClass
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }
        }
    }

    // =================================================================
    // USAGE HINT
    // =================================================================

    Rectangle {
        visible: root.isActiveMonitor && !root.screenshot.hasSelection && root.screenshot.mode === "region"
        z: 10

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.spacing * 2.5
        anchors.bottomMargin: Config.spacing * 5

        width: hintRow.implicitWidth + Config.spacing * 2
        height: hintRow.implicitHeight + Config.spacing * 1.5
        radius: Config.radius
        color: Qt.alpha(Config.surface0Color, 0.9)

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: Config.spacing

            Rectangle {
                width: escLabel.implicitWidth + Config.spacing
                height: escLabel.implicitHeight + Config.padding / 1.5
                radius: Config.radiusSmall
                color: Config.surface1Color
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: escLabel
                    anchors.centerIn: parent
                    text: "ESC"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.subtextColor
                }
            }

            Text {
                text: "Drag to select region"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
