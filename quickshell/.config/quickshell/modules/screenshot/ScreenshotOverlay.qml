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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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
        property real dimOpacity: 0.6
        property vector2d screenSize: Qt.vector2d(width, height)
        property real borderRadius: Config.radius
        property real outlineThickness: 2.0

        fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")
    }

    // Dim inactive monitors
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: !root.isActiveMonitor
        z: 1
    }

    // =================================================================
    // REGION SELECTOR
    // =================================================================

    RegionSelector {
        anchors.fill: parent
        visible: root.isActiveMonitor && root.screenshot.mode === "region"
        screenshot: root.screenshot
        z: 2
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
            return root.screenshot.hasSelection ? Qt.ArrowCursor : Qt.CrossCursor;
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

            if (dragging && root.screenshot.mode === "region" && !root.screenshot.hasSelection) {
                root.screenshot.selectionX = Math.min(startX, mouse.x);
                root.screenshot.selectionY = Math.min(startY, mouse.y);
                root.screenshot.selectionWidth = Math.abs(mouse.x - startX);
                root.screenshot.selectionHeight = Math.abs(mouse.y - startY);
            }
        }

        onPressed: mouse => {
            if (root.screenshot.mode === "region" && !root.screenshot.hasSelection) {
                startX = mouse.x;
                startY = mouse.y;
                root.screenshot.selectionX = mouse.x;
                root.screenshot.selectionY = mouse.y;
                root.screenshot.selectionWidth = 0;
                root.screenshot.selectionHeight = 0;
                dragging = true;
            }
        }

        onReleased: mouse => {
            dragging = false;

            if (root.screenshot.mode === "region" && !root.screenshot.hasSelection) {
                if (root.screenshot.selectionWidth > 10 && root.screenshot.selectionHeight > 10) {
                    root.screenshot.hasSelection = true;
                }
            } else if (root.screenshot.mode === "window" && !root.screenshot.hasSelection) {
                if (mouse.x >= root.screenshot.selectionX && mouse.x <= root.screenshot.selectionX + root.screenshot.selectionWidth && mouse.y >= root.screenshot.selectionY && mouse.y <= root.screenshot.selectionY + root.screenshot.selectionHeight) {
                    root.screenshot.hasSelection = true;
                }
            }
        }
    }

    // =================================================================
    // SHORTCUT
    // =================================================================

    Shortcut {
        sequence: "Escape"
        onActivated: root.screenshot.cancelCapture()
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

    Rectangle {
        visible: root.isActiveMonitor && root.screenshot.selectionWidth > 60 && root.screenshot.selectionHeight > 40 && root.screenshot.mode !== "screen"
        z: 6

        x: root.screenshot.selectionX + root.screenshot.selectionWidth / 2 - width / 2
        y: root.screenshot.selectionY + root.screenshot.selectionHeight / 2 - height / 2

        width: dimLabel.implicitWidth + 16
        height: dimLabel.implicitHeight + 8
        radius: Config.radiusSmall
        color: Qt.alpha(Config.surface0Color, 0.9)

        Text {
            id: dimLabel
            anchors.centerIn: parent
            text: Math.round(root.screenshot.selectionWidth) + " × " + Math.round(root.screenshot.selectionHeight)
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

        x: root.screenshot.selectionX + 12
        y: root.screenshot.selectionY + 12

        width: infoRow.implicitWidth + 20
        height: 40
        radius: Config.radius
        color: Qt.alpha(Config.surface0Color, 0.95)
        border.width: 2
        border.color: Config.accentColor

        Row {
            id: infoRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: root.screenshot.mode === "screen" ? "󰍹" : "󰖯"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.screenshot.selectedWindowTitle
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.textColor
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
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
        anchors.leftMargin: 20
        anchors.bottomMargin: 40

        width: hintRow.implicitWidth + 16
        height: 32
        radius: Config.radius
        color: Qt.alpha(Config.surface0Color, 0.9)

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: escLabel.implicitWidth + 8
                height: escLabel.implicitHeight + 4
                radius: 4
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
