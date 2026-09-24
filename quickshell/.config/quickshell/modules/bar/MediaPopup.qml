pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
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

    anchors {
        top: true
        left: true
    }

    margins {
        top: Config.barReservedHeight
        left: {
            const maxLeft = (screen?.width ?? implicitWidth) - implicitWidth - Config.spacing;
            return Math.max(Config.spacing, Math.min(anchorCenterX - implicitWidth / 2, maxLeft));
        }
    }

    implicitWidth: popupWidth
    implicitHeight: card.implicitHeight + Config.spacing
    color: "transparent"

    HoverHandler {
        id: hover
    }

    // Same player as the Quick Settings dashboard
    MediaWidget {
        id: card

        width: parent.width
        dismissible: false
        y: root.open ? Config.spacing : 0
        opacity: root.open ? 1 : 0
        border.width: 1
        border.color: Config.surface2Color

        Behavior on y {
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
