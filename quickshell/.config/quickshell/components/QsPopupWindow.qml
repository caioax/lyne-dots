pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Popup opened from a bar button (Quick Settings, calendar, system monitor).
// Floats a gap away from the bar, or with bar.attachPopups grows out of it
// (AttachedPanel), flush against the screen side too when the button is
// close to it
PanelWindow {
    id: root

    property int popupWidth: 380
    property int popupMaxHeight: 700
    property string anchorSide: "left"
    // Bar button to open under: the popup centers on it, kept inside the screen
    property Item anchorItem: null
    property string moduleName: ""
    property real contentImplicitHeight: 0

    default property alias content: contentContainer.data

    signal closing

    readonly property int screenMargin: 5

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    readonly property bool anchored: anchorItem !== null

    // Horizontal center of anchorItem on the screen. Re-evaluated whenever the
    // popup opens (mapToItem isn't reactive to the bar layout moving)
    readonly property real anchorCenterX: {
        visible;
        if (!anchorItem)
            return 0;
        return anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    // Opens toward the middle of the screen from the bar's edge
    readonly property bool upward: Config.barOnBottom

    // --- Attached look ---
    readonly property bool attached: StateService.get("bar.attachPopups", false)
    // Docked bars: just below the bar; islands and floating bars have no
    // continuous edge, so the popup grows out of the screen edge
    readonly property real attachLine: Config.barIslands || Config.barFloating ? 0 : Config.barHeight
    readonly property real filletSize: Config.radiusLarge

    readonly property real screenWidth: screen?.width ?? implicitWidth
    // Room around the popup inside the window: the scale animation's
    // overshoot, or the fillets when attached
    readonly property real sidePad: attached ? filletSize : screenMargin

    // Left edge of the popup on the screen. Floating popups keep
    // Config.spacing from the screen sides, the gap the bar islands use;
    // attached ones close to a side go flush against it
    readonly property real bodyX: {
        const x = anchored ? anchorCenterX - popupWidth / 2 : anchorSide === "left" ? 0 : screenWidth - popupWidth;
        if (attached) {
            if (x < filletSize)
                return 0;
            if (x + popupWidth > screenWidth - filletSize)
                return screenWidth - popupWidth;
            return x;
        }
        return Math.max(Config.spacing, Math.min(x, screenWidth - popupWidth - Config.spacing));
    }
    readonly property real windowLeft: Math.max(0, Math.min(bodyX - sidePad, screenWidth - implicitWidth))

    // Flush sides of the attached popup, the bar's first (it slides out of it)
    readonly property var attachedEdges: {
        const edges = [upward ? "bottom" : "top"];
        if (bodyX <= 0)
            edges.push("left");
        if (bodyX >= screenWidth - popupWidth)
            edges.push("right");
        return edges;
    }

    anchors {
        top: !upward
        bottom: upward
        left: true
    }

    margins {
        readonly property real fromBar: root.attached ? root.attachLine : Config.barReservedHeight + Config.spacing

        top: root.upward ? 0 : fromBar
        bottom: root.upward ? fromBar : 0
        left: root.windowLeft
    }

    implicitWidth: popupWidth + sidePad * 2
    implicitHeight: popupMaxHeight
    color: "transparent"

    property bool isClosing: false
    property bool isOpening: false
    readonly property bool showState: visible && !isClosing && isOpening

    function closeWindow() {
        if (!visible)
            return;
        isClosing = true;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration
        onTriggered: {
            root.closing();
            root.visible = false;
            root.isClosing = false;
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: root.closeWindow()
    }

    Timer {
        id: grabTimer
        interval: 10
        onTriggered: {
            focusGrab.active = true;
            frame.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            isClosing = false;
            isOpening = true;
            if (moduleName !== "")
                WindowManagerService.registerOpen(moduleName);
            grabTimer.restart();
        } else {
            focusGrab.active = false;
            isOpening = false;
            if (moduleName !== "")
                WindowManagerService.registerClose(moduleName);
        }
    }

    // Click on background closes or clears selection
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeWindow()
    }

    // Place and size of the popup in the window
    Item {
        id: frame

        x: root.bodyX - root.windowLeft
        y: root.upward ? parent.height - height : 0
        width: root.popupWidth
        height: Math.min(root.popupMaxHeight, root.contentImplicitHeight + 32)

        Behavior on height {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
        }

        Keys.onEscapePressed: root.closeWindow()
    }

    Rectangle {
        id: background

        visible: !root.attached
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        color: Config.backgroundTransparentColor
        radius: Config.radiusLarge
        border.width: 1.0
        border.color: Config.surface2Color

        transformOrigin: {
            if (root.anchored)
                return root.upward ? Item.Bottom : Item.Top;
            if (root.anchorSide === "left")
                return root.upward ? Item.BottomLeft : Item.TopLeft;
            return root.upward ? Item.BottomRight : Item.TopRight;
        }

        scale: root.showState ? 1.0 : 0.9
        opacity: root.showState ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    AttachedPanel {
        id: attachedPanel

        visible: root.attached
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        edges: root.attachedEdges
        shown: root.showState && root.attached
    }

    // The content, inside whichever panel is in use
    Item {
        parent: root.attached ? attachedPanel.body : background
        anchors.fill: parent
        clip: true

        // just to capture the click and prevent it from closing
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.margins: 16
        }
    }
}
