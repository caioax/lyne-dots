pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../quickSettings/"
import "../../../components/"
import "../../notifications/"

Item {
    id: root

    // Height the page may use; the notification list scrolls within what's left
    property real availableHeight: 0
    readonly property bool hasNotifications: NotificationService.count > 0

    // Sizes shared by the header controls
    readonly property int avatarSize: Config.fontSizeLarge * 3
    readonly property int controlSize: Config.fontSizeIconSmall * 2

    signal closeWindow

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight + (hasNotifications ? notifSeparator.anchors.topMargin + 1 + notifList.anchors.topMargin + notifList.implicitHeight : 0)

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.padding * 2

        // HEADER (Profile and Info)
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.padding * 2

            // Avatar / System Icon
            Rectangle {
                Layout.preferredWidth: root.avatarSize
                Layout.preferredHeight: root.avatarSize
                radius: Config.radiusLarge
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Config.surface2Color
                    }
                    GradientStop {
                        position: 1.0
                        color: Config.surface1Color
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.accentColor
                }
            }

            // Welcome Text
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(Config.padding / 3)

                Text {
                    text: Quickshell.env("USER")
                    color: Config.textColor
                    font.family: Config.font
                    font.bold: true
                    font.pixelSize: Config.fontSizeLarge
                }
                Text {
                    text: "󰅐 " + SystemMonitorService.uptime
                    color: Config.subtextColor
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }

            // Battery indicator (only shows if battery is present)
            Rectangle {
                visible: BatteryService.hasBattery
                Layout.preferredHeight: root.controlSize
                Layout.preferredWidth: batteryContent.implicitWidth + Config.spacing * 2
                radius: Config.radius
                color: Config.surface1Color

                RowLayout {
                    id: batteryContent
                    anchors.centerIn: parent
                    spacing: Config.padding

                    Text {
                        text: BatteryService.getBatteryIcon()
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        color: {
                            if (BatteryService.isCharging)
                                return Config.successColor;
                            if (BatteryService.percentage < 20)
                                return Config.errorColor;
                            if (BatteryService.percentage < 40)
                                return Config.warningColor;
                            return Config.textColor;
                        }
                    }

                    Text {
                        text: BatteryService.percentage + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                    }
                }
            }

            // Theme color
            ActionButton {
                size: root.controlSize
                icon: "󰏘"
                textColor: Config.accentColor
                hoverTextColor: Config.accentColor
                onClicked: pageStack.currentIndex = 5
            }

            // Power Menu
            ClearButton {
                icon: "⏻"

                Layout.preferredWidth: root.controlSize
                Layout.preferredHeight: root.controlSize

                onClicked: {
                    root.closeWindow();
                    PowerService.showOverlay();
                }
            }
        }

        // ========== SEPARATOR ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        MediaWidget {
            id: mediaWidget
            Layout.fillWidth: true
        }

        // ========== SEPARATOR ==========
        Rectangle {
            visible: mediaWidget.visible
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // BUTTON GRID
        GridLayout {
            columns: 2
            columnSpacing: Config.spacing
            rowSpacing: Config.spacing
            Layout.fillWidth: true

            // WI-FI BUTTON
            QuickSettingsTile {
                icon: NetworkService.systemIcon
                label: "Wi-Fi"
                subLabel: NetworkService.statusText
                property string ssid: NetworkService.accessPoints.find(ap => ap.active)?.ssid || "Connected"
                active: NetworkService.wifiEnabled
                hasDetails: true
                onToggled: NetworkService.toggleWifi()
                onOpenDetails: pageStack.currentIndex = 1
            }

            // BLUETOOTH BUTTON
            QuickSettingsTile {
                visible: BluetoothService.adapter !== null
                icon: BluetoothService.systemIcon
                label: "Bluetooth"
                subLabel: BluetoothService.statusText
                active: BluetoothService.isPowered
                hasDetails: true
                onToggled: BluetoothService.togglePower()
                onOpenDetails: pageStack.currentIndex = 3
            }

            // Night Light
            QuickSettingsTile {
                icon: BrightnessService.nightLightEnabled ? "󰌵" : "󰌶"
                label: "Night light"
                subLabel: BrightnessService.nightLightEnabled ? (BrightnessService.nightLightTemperature + "K") : "Off"
                active: BrightnessService.nightLightEnabled
                hasDetails: true
                onToggled: BrightnessService.toggleNightLight()
                onOpenDetails: pageStack.currentIndex = 4
            }

            // DND (Do Not Disturb)
            QuickSettingsTile {
                icon: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                label: "Do not disturb"
                subLabel: NotificationService.dndEnabled ? "Enabled" : "Disabled"
                active: NotificationService.dndEnabled
                hasDetails: false
                onToggled: NotificationService.toggleDnd()
            }

            // Caffeine
            QuickSettingsTile {
                icon: IdleService.caffeineEnabled ? "󰛊" : "󰾪"
                label: "Caffeine"
                subLabel: IdleService.caffeineEnabled ? "Active" : "Off"
                active: IdleService.caffeineEnabled
                hasDetails: false
                onToggled: IdleService.toggleCaffeine()
            }
        }

        // ========== SEPARATOR ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // SLIDERS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.padding * 2
            Layout.topMargin: 1

            QsSlider {
                icon: AudioService.systemIcon
                value: AudioService.volume
                fillColor: AudioService.muted ? Config.surface3Color : Config.accentColor

                onMoved: val => AudioService.setVolume(val)
                onIconClicked: AudioService.toggleMute()
            }

            // Brightness (only shows if available)
            QsSlider {
                visible: BrightnessService.available
                icon: BrightnessService.icon
                value: BrightnessService.brightness

                onMoved: val => BrightnessService.setBrightness(val)
                onIconClicked: BrightnessService.toggleBrightness()
            }
        }
    }

    // ========== NOTIFICATIONS ==========
    Rectangle {
        id: notifSeparator
        visible: root.hasNotifications
        anchors.top: main.bottom
        anchors.topMargin: main.spacing
        width: parent.width
        height: 1
        color: Config.surface1Color
    }

    NotificationList {
        id: notifList
        visible: root.hasNotifications
        anchors.top: notifSeparator.bottom
        anchors.topMargin: main.spacing
        width: parent.width
        maxHeight: root.availableHeight - main.implicitHeight - main.spacing * 2 - 1
        onActionTriggered: root.closeWindow()
    }
}
