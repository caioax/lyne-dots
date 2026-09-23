pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Compact history card with the notifications of one app (newest first).
// Shows the latest `previewCount` rows until expanded.
Rectangle {
    id: root

    required property string appName
    readonly property var notifs: NotificationService.notificationsOf(appName)
    readonly property string appIconSource: notifs.length > 0 ? NotificationService.iconSource(notifs[0].appIcon) : ""
    readonly property int previewCount: 3
    property bool expanded: false

    signal actionTriggered

    implicitHeight: column.implicitHeight + Config.spacing * 2
    radius: Config.radius
    color: Config.surface0Color

    Column {
        id: column

        anchors.fill: parent
        anchors.margins: Config.spacing
        anchors.leftMargin: Config.spacing + Config.padding
        anchors.rightMargin: Config.spacing + Config.padding
        spacing: Config.spacing

        // ========== HEADER ==========
        RowLayout {
            width: column.width
            spacing: Config.padding

            IconImage {
                visible: root.appIconSource !== "" && status !== Image.Error
                implicitSize: Config.fontSizeNormal
                source: root.appIconSource
            }

            Text {
                Layout.maximumWidth: column.width / 2
                text: root.appName
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
                elide: Text.ElideRight
            }

            Text {
                visible: root.notifs.length > 1
                text: "· " + root.notifs.length
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }

            Item {
                Layout.fillWidth: true
            }

            NotificationIconButton {
                id: clearGroup
                icon: "󰅖"
                iconColor: clearGroup.hovered ? Config.errorColor : Config.subtextColor
                onClicked: NotificationService.dismissGroup(root.appName)
            }
        }

        // ========== ROWS ==========
        Repeater {
            model: ScriptModel {
                values: root.expanded ? root.notifs : root.notifs.slice(0, root.previewCount)
            }

            NotificationRow {
                required property var modelData
                width: column.width
                notif: modelData
                onActionTriggered: root.actionTriggered()
            }
        }

        // ========== MORE / LESS ==========
        Text {
            visible: root.notifs.length > root.previewCount
            text: root.expanded ? "Show less" : "+" + (root.notifs.length - root.previewCount) + " more"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: moreMouse.containsMouse ? Config.accentColor : Config.subtextColor

            MouseArea {
                id: moreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
