pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import "../../components/"
import "../quickSettings/"

// Player that drops down under the bar's media island while it's hovered
PanelWindow {
    id: root

    required property Item anchorItem
    property bool open: false
    readonly property bool hovered: hover.hovered
    readonly property int popupWidth: Config.fontSizeNormal * 26

    // Stays mapped until the closing animation ends
    visible: open || closeTimer.running
    onOpenChanged: {
        if (!open)
            closeTimer.restart();
        // Keeps the auto-hiding bar down while the player is shown
        if (open)
            WindowManagerService.registerOpen("MediaPopup");
        else
            WindowManagerService.registerClose("MediaPopup");
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration
    }

    // Center of the island on screen, taken when the popup opens
    readonly property real anchorCenterX: {
        open;
        return anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // --- Attached look (bar.attachPopups): grows out of the bar, holding
    // the card, like the other bar popups (see QsPopupWindow) ---
    readonly property bool attached: StateService.get("bar.attachPopups", false)
    readonly property real attachLine: Config.barIslands || Config.barFloating ? 0 : Config.barHeight
    readonly property real filletSize: Config.radiusLarge
    // Space between the attached panel and the card
    readonly property real inset: Config.padding
    readonly property real sidePad: attached ? filletSize : 0
    readonly property real screenWidth: screen?.width ?? implicitWidth

    // Left edge of the player on the screen: attached ones close to a screen
    // side go flush against it, floating ones keep Config.spacing from it
    readonly property real bodyX: {
        const x = anchorCenterX - popupWidth / 2;
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

    anchors {
        top: !Config.barOnBottom
        bottom: Config.barOnBottom
        left: true
    }

    margins {
        readonly property real fromBar: root.attached ? root.attachLine : Config.barReservedHeight

        top: Config.barOnBottom ? 0 : fromBar
        bottom: Config.barOnBottom ? fromBar : 0
        left: root.windowLeft
    }

    implicitWidth: popupWidth + sidePad * 2
    // Attached: room below the panel for the fillet of a flush side
    implicitHeight: attached ? card.implicitHeight + inset * 2 + filletSize : card.implicitHeight + Config.spacing
    color: "transparent"

    HoverHandler {
        id: hover
    }

    AttachedPanel {
        id: attachedPanel

        visible: root.attached
        x: root.bodyX - root.windowLeft
        y: Config.barOnBottom ? root.height - height : 0
        width: root.popupWidth
        height: card.implicitHeight + root.inset * 2
        edges: {
            const edges = [Config.barOnBottom ? "bottom" : "top"];
            if (root.bodyX <= 0)
                edges.push("left");
            if (root.bodyX >= root.screenWidth - root.popupWidth)
                edges.push("right");
            return edges;
        }
        shown: root.open && root.attached
    }

    // Same player as the Quick Settings dashboard
    MediaWidget {
        id: card

        parent: root.attached ? attachedPanel.body : root.contentItem
        x: root.attached ? root.inset : root.bodyX - root.windowLeft
        width: root.popupWidth - (root.attached ? root.inset * 2 : 0)
        dismissible: false
        // Floating: slides away from the bar while opening (the attached
        // panel slides by itself)
        y: {
            if (root.attached)
                return root.inset;
            if (Config.barOnBottom)
                return root.open ? 0 : Config.spacing;
            return root.open ? Config.spacing : 0;
        }
        opacity: root.open || root.attached ? 1 : 0
        border.width: root.attached ? 0 : 1
        border.color: Config.surface2Color

        Behavior on y {
            enabled: !root.attached

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }
    }
}
