pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Notification history card: app groups split by dividers, scrolling once
// taller than maxHeight. `preview` (Quick Settings dashboard) shows only the
// newest groups plus "See all", which asks for the notifications page.
Card {
    id: root

    property bool preview: false
    property int previewGroups: 2
    // The page has its own header with these controls
    property bool showHeader: true
    // 0 = no limit
    property real maxHeight: 0

    signal actionTriggered
    signal openPageRequested

    readonly property var shownGroups: preview ? NotificationService.groupNames.slice(0, previewGroups) : NotificationService.groupNames
    readonly property int hiddenGroups: NotificationService.groupNames.length - shownGroups.length
    readonly property real listMaxHeight: maxHeight > 0 ? maxHeight - padding * 2 - (showHeader ? header.implicitHeight + spacing : 0) : Infinity

    spacing: Config.spacing * 2

    CardHeader {
        id: header

        visible: root.showHeader
        // md-bell_off / md-bell
        icon: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
        title: "Notifications"
        subtitle: NotificationService.count + (NotificationService.dndEnabled ? " · Do not disturb" : "")

        ActionButton {
            visible: root.preview
            size: Config.fontSizeSmall + Config.padding * 3
            iconSize: Config.fontSizeNormal
            // md-format_list_bulleted
            icon: "\u{f0279}"
            text: root.hiddenGroups > 0 ? "See all " + NotificationService.groupNames.length : "See all"
            onClicked: root.openPageRequested()
        }

        MenuButton {
            id: menuButton
            onClicked: menu.openAt(menuButton, null)
        }
    }

    Flickable {
        id: flick

        // Wider than the card content so row highlights can bleed into the
        // padding without being clipped
        Layout.fillWidth: true
        Layout.leftMargin: -Config.padding
        Layout.rightMargin: -Config.padding
        Layout.preferredHeight: Math.min(groups.implicitHeight, root.listMaxHeight)
        contentHeight: groups.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: QsScrollBar {}

        // Flickable + Column (not ListView): groups change height when rows
        // expand, and a Column always relayouts for that
        Column {
            id: groups

            x: Config.padding
            width: flick.width - Config.padding * 2
            topPadding: Config.padding
            bottomPadding: Config.padding
            spacing: Config.spacing * 2

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
                        visible: entry.index > 0
                        width: parent.width
                        height: 1
                        color: Config.surface1Color
                    }

                    NotificationGroup {
                        width: parent.width
                        appName: entry.modelData
                        preview: root.preview
                        onActionTriggered: root.actionTriggered()
                        onOpenRequested: root.openPageRequested()
                    }
                }
            }
        }
    }

    ContextMenu {
        id: menu

        items: [
            {
                label: NotificationService.dndEnabled ? "Turn off do not disturb" : "Do not disturb",
                // md-bell / md-bell_sleep
                icon: NotificationService.dndEnabled ? "\u{f009a}" : "\u{f00a0}",
                action: "dnd"
            },
            {
                label: "Clear all",
                // md-notification_clear_all
                icon: "\u{f039f}",
                action: "clear",
                danger: true
            }
        ]

        onTriggered: action => {
            if (action === "dnd")
                NotificationService.toggleDnd();
            else if (action === "clear")
                NotificationService.clearAll();
        }
    }
}
