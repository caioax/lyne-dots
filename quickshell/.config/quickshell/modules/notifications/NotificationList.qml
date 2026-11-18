pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Notification history: one card per conversation, scrolling once taller
// than maxHeight (the bell's popup)
Item {
    id: root

    // 0 = no limit
    property real maxHeight: 0

    signal actionTriggered

    // Room inside each card, as a Card has
    readonly property int inset: Config.padding * 2

    implicitHeight: maxHeight > 0 ? Math.min(cards.implicitHeight, maxHeight) : cards.implicitHeight

    // Waits for the card's expand animation, then scrolls it into view
    Timer {
        id: scrollTimer

        property Item target

        interval: Config.animDuration
        onTriggered: {
            if (target)
                flick.contentY = Math.max(0, Math.min(target.y, flick.contentHeight - flick.height));
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentHeight: cards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: QsScrollBar {}

        // Flickable + Column (not ListView): cards change height when they
        // expand, and a Column always relayouts for that
        Column {
            id: cards

            width: flick.width
            spacing: Config.spacing

            Repeater {
                model: ScriptModel {
                    values: NotificationService.conversationKeys
                }

                Rectangle {
                    id: card

                    required property string modelData

                    // Opened on this conversation: expand it and bring it
                    // into view once it has grown
                    function focusIfAsked(): void {
                        if (modelData !== NotificationService.focusKey)
                            return;
                        conversation.expanded = true;
                        scrollTimer.target = card;
                        scrollTimer.restart();
                    }

                    Component.onCompleted: focusIfAsked()

                    Connections {
                        target: NotificationService

                        function onFocusKeyChanged(): void {
                            card.focusIfAsked();
                        }
                    }

                    width: cards.width
                    height: conversation.implicitHeight + root.inset * 2
                    radius: Config.radiusLarge
                    color: Config.cardColor

                    NotificationConversation {
                        id: conversation
                        x: root.inset
                        y: root.inset
                        width: parent.width - root.inset * 2
                        key: card.modelData
                        onActionTriggered: root.actionTriggered()
                    }
                }
            }
        }
    }
}
