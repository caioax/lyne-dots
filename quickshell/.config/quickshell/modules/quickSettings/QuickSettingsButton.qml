pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    active: quickSettingsWindow.visible
    contentItem: iconsLayout
    onClicked: quickSettingsWindow.visible = !quickSettingsWindow.visible
    onRightClicked: NotificationService.toggleDnd()

    // `qs ipc call notifications toggleWindow` opens it on the focused monitor only
    Connections {
        target: NotificationService

        function onWindowToggleRequested() {
            if (root.QsWindow.window?.screen?.name === Hyprland.focusedMonitor?.name)
                quickSettingsWindow.visible = !quickSettingsWindow.visible;
        }
    }

    RowLayout {
        id: iconsLayout
        anchors.centerIn: parent
        spacing: Config.spacing

        property color iconColor: root.active ? Config.accentColor : Config.textColor

        Behavior on iconColor {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        WifiIcon {
            color: iconsLayout.iconColor
        }
        BluetoothIcon {
            color: iconsLayout.iconColor
        }
        BatteryIcon {
            color: iconsLayout.iconColor
        }

        // Unread notifications (count badge) / DND
        Text {
            id: bell

            visible: NotificationService.dndEnabled || NotificationService.count > 0
            text: NotificationService.dndEnabled ? "󰂛" : "󰂚"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: NotificationService.dndEnabled ? Config.warningColor : iconsLayout.iconColor

            // Sits on the bell's top-right corner without taking layout space
            Rectangle {
                readonly property int textSize: Math.round(Config.fontSizeSmall * 0.7)

                visible: !NotificationService.dndEnabled
                anchors.horizontalCenter: parent.right
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: Math.round(Config.padding / 2)
                height: textSize + Math.round(Config.padding * 2 / 3)
                width: Math.max(height, badgeText.implicitWidth + Config.padding)
                radius: height / 2
                color: Config.errorColor

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: NotificationService.count > 99 ? "99+" : NotificationService.count
                    font.family: Config.font
                    font.pixelSize: parent.textSize
                    font.bold: true
                    color: Config.textColor
                }
            }
        }
    }

    QuickSettingsWindow {
        id: quickSettingsWindow
        visible: false
    }
}
