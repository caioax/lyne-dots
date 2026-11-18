pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../components/"

// The bell: opens the notification history, with a badge counting the
// conversations not seen yet. Optional (bar.showNotifications); its popup
// stays, for the IPC, when it is off
BarButton {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property int unseen: NotificationService.unseenCount

    visible: Config.barShowNotifications
    active: NotificationService.historyScreen !== "" && NotificationService.historyScreen === screenName
    contentItem: bell
    onClicked: NotificationService.toggleHistory(screenName)

    Text {
        id: bell

        anchors.centerIn: parent
        // md-bell_off / md-bell
        text: NotificationService.dndEnabled ? "\u{f009b}" : "\u{f009a}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true
        color: root.active ? Config.accentColor : Config.textColor

        Behavior on color {
            enabled: !Config.themeTransitioning
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        // Red on the bell's top-right corner without taking layout space;
        // dimmer under do not disturb
        Rectangle {
            readonly property int textSize: Math.round(Config.fontSizeSmall * 0.7)

            visible: root.unseen > 0
            anchors.horizontalCenter: parent.right
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: Math.round(Config.padding / 2)
            height: textSize + Math.round(Config.padding * 2 / 3)
            width: Math.max(height, badgeText.implicitWidth + Config.padding)
            radius: height / 2
            color: NotificationService.dndEnabled ? Config.surface2Color : Config.errorColor

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.unseen > 99 ? "99+" : root.unseen
                font.family: Config.font
                font.pixelSize: parent.textSize
                font.bold: true
                color: Config.textColor
            }
        }
    }

    NotificationsWindow {
        screen: root.QsWindow.window?.screen ?? null
        // Bell off: at the screen's right side instead
        anchorItem: root.visible ? root : null
    }
}
