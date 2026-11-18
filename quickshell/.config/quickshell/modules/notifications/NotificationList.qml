pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Notification history card: conversations split by dividers, scrolling once
// taller than maxHeight. `preview` (Quick Settings dashboard) shows only the
// newest conversations plus "See all", which asks for the notifications page.
// `separate` (the bell's popup) gives each conversation a card of its own.
Card {
    id: root

    property bool preview: false
    property bool separate: false
    property int previewGroups: 2
    // The page has its own header with these controls
    property bool showHeader: true
    // 0 = no limit
    property real maxHeight: 0

    signal actionTriggered
    signal openPageRequested

    readonly property var shownGroups: preview ? NotificationService.conversationKeys.slice(0, previewGroups) : NotificationService.conversationKeys
    readonly property int hiddenGroups: NotificationService.conversationKeys.length - shownGroups.length
    readonly property real listMaxHeight: maxHeight > 0 ? maxHeight - (separate ? 0 : padding * 2) - (showHeader ? header.implicitHeight + spacing : 0) : Infinity

    spacing: Config.spacing * 2
    // Separate: only the conversations' cards show, edge to edge
    color: separate ? Qt.alpha(Config.cardColor, 0) : Config.cardColor

    CardHeader {
        id: header

        visible: root.showHeader
        // md-bell_off / md-bell
        icon: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
        title: I18n.tr("Notifications")
        subtitle: NotificationService.dndEnabled ? I18n.tr("%1 · Do not disturb", NotificationService.count) : String(NotificationService.count)

        ActionButton {
            visible: root.preview
            size: Config.fontSizeSmall + Config.padding * 3
            iconSize: Config.fontSizeNormal
            // md-format_list_bulleted
            icon: "\u{f0279}"
            text: root.hiddenGroups > 0 ? I18n.tr("See all %1", NotificationService.conversationKeys.length) : I18n.tr("See all")
            onClicked: root.openPageRequested()
        }

        // md-trash_can_outline: clears them all (do not disturb has its tile)
        MenuButton {
            visible: NotificationService.count > 0
            icon: "\u{f0a7a}"
            danger: true
            onClicked: NotificationService.clearAll()
        }
    }

    Flickable {
        id: flick

        // Wider than the card content so row highlights can bleed into the
        // padding without being clipped
        Layout.fillWidth: true
        Layout.leftMargin: root.separate ? -root.padding : -Config.padding
        Layout.rightMargin: root.separate ? -root.padding : -Config.padding
        Layout.topMargin: root.separate && !root.showHeader ? -root.padding : 0
        Layout.bottomMargin: root.separate ? -root.padding : 0
        Layout.preferredHeight: Math.min(groups.implicitHeight, root.listMaxHeight)
        contentHeight: groups.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: QsScrollBar {}

        // Flickable + Column (not ListView): groups change height when rows
        // expand, and a Column always relayouts for that
        Column {
            id: groups

            x: root.separate ? 0 : Config.padding
            width: flick.width - x * 2
            topPadding: root.separate ? 0 : Config.padding
            bottomPadding: root.separate ? 0 : Config.padding
            spacing: root.separate ? Config.spacing : Config.spacing * 2

            Repeater {
                model: ScriptModel {
                    values: root.shownGroups
                }

                Column {
                    id: entry

                    required property string modelData
                    required property int index

                    width: groups.width
                    spacing: Config.spacing * 2

                    Rectangle {
                        visible: !root.separate && entry.index > 0
                        width: parent.width
                        height: 1
                        color: Config.surface1Color
                    }

                    // Its own card when separate
                    Rectangle {
                        readonly property int inset: root.separate ? root.padding : 0

                        width: parent.width
                        height: conversation.implicitHeight + inset * 2
                        radius: Config.radiusLarge
                        color: root.separate ? Config.cardColor : Qt.alpha(Config.cardColor, 0)

                        NotificationConversation {
                            id: conversation
                            x: parent.inset
                            y: parent.inset
                            width: parent.width - parent.inset * 2
                            key: entry.modelData
                            preview: root.preview
                            onActionTriggered: root.actionTriggered()
                            onOpenRequested: root.openPageRequested()
                        }
                    }
                }
            }
        }
    }

}
