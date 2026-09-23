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

        // Unread notifications / DND
        RowLayout {
            visible: NotificationService.dndEnabled || NotificationService.count > 0
            spacing: Math.round(Config.padding / 2)

            Text {
                text: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                color: NotificationService.dndEnabled ? Config.warningColor : root.active ? Config.accentColor : Config.textColor
            }

            Text {
                visible: !NotificationService.dndEnabled
                text: NotificationService.count > 99 ? "99+" : NotificationService.count
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: iconsLayout.iconColor
            }
        }
    }

    QuickSettingsWindow {
        id: quickSettingsWindow
        visible: false
    }
}
