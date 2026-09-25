pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"
import "../../notifications/"

// Full notification history (the dashboard only previews the newest apps)
Item {
    id: root

    property real availableHeight: 0

    signal backRequested
    signal closeWindow

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            id: header

            Layout.bottomMargin: Config.padding
            // md-bell_off / md-bell
            icon: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
            title: "Notifications"
            subtitle: {
                const count = NotificationService.count;
                const apps = NotificationService.groupNames.length;
                const text = count === 0 ? "Nothing new" : count + (count === 1 ? " notification" : " notifications") + " · " + apps + (apps === 1 ? " app" : " apps");
                return NotificationService.dndEnabled ? text + " · Do not disturb" : text;
            }
            onBackClicked: root.backRequested()

            // md-bell_sleep: do not disturb
            ActionButton {
                size: header.boxSize
                icon: "\u{f00a0}"
                baseColor: NotificationService.dndEnabled ? Config.accentColor : Config.surface1Color
                hoverColor: NotificationService.dndEnabled ? Qt.lighter(Config.accentColor, 1.1) : Config.surface2Color
                textColor: NotificationService.dndEnabled ? Config.textReverseColor : Config.textColor
                onClicked: NotificationService.toggleDnd()
            }

            // md-notification_clear_all
            ClearButton {
                visible: NotificationService.count > 0
                icon: "\u{f039f}"
                text: "Clear"
                implicitHeight: header.boxSize
                onClicked: NotificationService.clearAll()
            }
        }

        NotificationList {
            visible: NotificationService.count > 0
            Layout.fillWidth: true
            showHeader: false
            maxHeight: root.availableHeight - header.implicitHeight - header.Layout.bottomMargin - main.spacing
            onActionTriggered: root.closeWindow()
        }

        Card {
            visible: NotificationService.count === 0
            Layout.fillWidth: true

            // md-bell_outline
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Config.spacing
                text: "\u{f009c}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.subtextColor
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Config.spacing
                text: "No notifications"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }
    }
}
