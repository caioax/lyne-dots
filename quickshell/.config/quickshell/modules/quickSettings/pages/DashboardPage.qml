pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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

    signal closeWindow

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight + (hasNotifications ? notifList.anchors.topMargin + notifList.implicitHeight : 0)

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        ProfileCard {
            Layout.fillWidth: true
            onCloseWindow: root.closeWindow()
        }

        MediaWidget {
            Layout.fillWidth: true
        }

        // ========== TOGGLES ==========
        Card {
            Layout.fillWidth: true

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Config.spacing
                rowSpacing: Config.spacing

                QuickSettingsTile {
                    icon: NetworkService.systemIcon
                    label: "Wi-Fi"
                    subLabel: NetworkService.statusText
                    active: NetworkService.wifiEnabled
                    hasDetails: true
                    onToggled: NetworkService.toggleWifi()
                    onOpenDetails: pageStack.currentIndex = 1
                }

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

                QuickSettingsTile {
                    icon: BrightnessService.nightLightIcon
                    label: "Night light"
                    subLabel: BrightnessService.nightLightEnabled ? BrightnessService.nightLightTemperature + "K" : "Off"
                    active: BrightnessService.nightLightEnabled
                    hasDetails: true
                    onToggled: BrightnessService.toggleNightLight()
                    onOpenDetails: pageStack.currentIndex = 4
                }

                QuickSettingsTile {
                    icon: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                    label: "Do not disturb"
                    subLabel: NotificationService.dndEnabled ? "On" : "Off"
                    active: NotificationService.dndEnabled
                    onToggled: NotificationService.toggleDnd()
                }

                QuickSettingsTile {
                    icon: IdleService.caffeineEnabled ? "󰛊" : "󰾪"
                    label: "Caffeine"
                    subLabel: IdleService.caffeineEnabled ? "Awake" : "Off"
                    active: IdleService.caffeineEnabled
                    onToggled: IdleService.toggleCaffeine()
                }

                QuickSettingsTile {
                    icon: AudioService.sourceIcon
                    label: "Microphone"
                    subLabel: AudioService.sourceMuted ? "Muted" : "On"
                    active: AudioService.sourceReady && !AudioService.sourceMuted
                    onToggled: AudioService.toggleSourceMute()
                }
            }
        }

        // ========== SOUND & DISPLAY ==========
        Card {
            Layout.fillWidth: true

            CardHeader {
                icon: "󰓃"
                title: "Output"
                subtitle: AudioService.deviceName(AudioService.sink)

                ActionButton {
                    size: Config.fontSizeNormal + Config.padding * 2
                    icon: "󰅂"
                    iconSize: Config.fontSizeNormal
                    textColor: Config.subtextColor
                    hoverTextColor: Config.accentColor
                    onClicked: pageStack.currentIndex = 5
                }
            }

            QsSlider {
                icon: AudioService.systemIcon
                value: AudioService.volume
                fillColor: AudioService.muted ? Config.surface3Color : Config.accentColor
                onMoved: val => AudioService.setVolume(val)
                onIconClicked: AudioService.toggleMute()
            }

            QsSlider {
                visible: AudioService.sourceReady
                icon: AudioService.sourceIcon
                value: AudioService.sourceVolume
                fillColor: AudioService.sourceMuted ? Config.surface3Color : Config.accentColor
                onMoved: val => AudioService.setSourceVolume(val)
                onIconClicked: AudioService.toggleSourceMute()
            }

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
    NotificationList {
        id: notifList
        visible: root.hasNotifications
        anchors.top: main.bottom
        anchors.topMargin: Config.padding * 2
        width: parent.width
        maxHeight: root.availableHeight - main.implicitHeight - anchors.topMargin
        onActionTriggered: root.closeWindow()
    }
}
