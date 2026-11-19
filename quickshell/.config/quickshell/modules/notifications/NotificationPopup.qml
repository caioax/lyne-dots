pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Toast shown at the top right. Click runs the default action, right/middle
// click dismisses, swiping right sends it to the history.
Item {
    id: root

    required property var modelData
    readonly property var notif: modelData
    readonly property color tint: notif.isCritical ? Config.errorColor : Config.accentColor
    readonly property bool wantsKeyboard: content.replyWantsKeyboard

    // 1 = off screen to the right, 0 = in place. Slides in on creation and
    // out while the service plays the exit (notif.exiting)
    property real slide: 1
    property bool entered: false
    Component.onCompleted: {
        slide = 0;
        entered = true;
    }

    implicitWidth: Config.notifWidth
    // Grows in and collapses out, so the cards below move smoothly
    implicitHeight: entered && !notif.exiting ? card.height + Config.notifSpacing : 0
    // Only while growing in or collapsing out: at rest the shadow spills
    clip: height < card.height + Config.notifSpacing

    Behavior on implicitHeight {
        // The card's own easing already moves it while opening or closing
        enabled: !cardHeightAnim.running
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuad
        }
    }

    states: State {
        when: root.notif.exiting
        PropertyChanges {
            root.slide: 1
        }
    }

    Behavior on slide {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutExpo
        }
    }

    Binding {
        target: root.notif
        property: "held"
        // Opened (expanded), it stays until closed or collapsed
        value: hover.hovered || content.replyFocused || dragArea.drag.active || content.expanded
    }

    // The card clips its children: its shadow follows it from outside
    Item {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        opacity: card.opacity
        transform: Translate {
            x: root.slide * card.width
        }

        PanelShadow {
            radius: card.radius
        }
    }

    ClippingRectangle {
        id: card

        width: parent.width
        height: content.implicitHeight + Config.padding * 4

        // Opening and closing the conversation ease the card
        Behavior on height {
            enabled: root.entered
            NumberAnimation {
                id: cardHeightAnim
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        radius: Config.radiusLarge
        color: Config.backgroundTransparentColor
        // Only a critical notification has a border, in the error color
        border.width: root.notif.isCritical ? 1 : 0
        border.color: Config.errorColor
        opacity: 1 - Math.min(1, Math.abs(x) / width + root.slide)
        transform: Translate {
            x: root.slide * card.width
        }

        Behavior on x {
            enabled: !dragArea.drag.active
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            id: dragArea

            property bool dragged: false

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: card.width
            drag.threshold: Config.spacing

            onPressed: dragged = false
            onPositionChanged: {
                if (drag.active)
                    dragged = true;
            }
            onReleased: {
                if (card.x > card.width * 0.3)
                    root.notif.hidePopup();
                else
                    card.x = 0;
            }
            onClicked: mouse => {
                if (dragged)
                    return;
                // Left: the history, open on this conversation (its actions,
                // the default one included, are there)
                if (mouse.button === Qt.LeftButton) {
                    const key = NotificationService.conversationKey(root.notif);
                    const screen = root.QsWindow.window?.screen?.name ?? "";
                    WindowManagerService.openAfterClose("Notifications", () => NotificationService.showConversation(key, screen), 0);
                } else
                    NotificationService.dismissConversation(NotificationService.conversationKey(root.notif));
            }
        }

        NotificationContent {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Config.padding * 2
            notif: root.notif
            closeShown: hover.hovered
            onCloseClicked: NotificationService.dismissConversation(NotificationService.conversationKey(root.notif))
        }

        // Time left before the popup goes to the history
        Rectangle {
            visible: root.notif.timeout > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * root.notif.timeLeft
            height: 2
            color: Qt.alpha(root.tint, 0.8)
        }
    }
}
