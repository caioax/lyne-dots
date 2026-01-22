pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../quickSettings/"
import "../../../components/"

Item {
    id: root

    signal closeWindow

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 16

        // HEADER (Perfil e Info)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Avatar / Ícone do Sistema
            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 16
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

            // Texto de Boas-vindas
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Quickshell.env("USER")
                    color: Config.textColor
                    font.family: Config.font
                    font.bold: true
                    font.pixelSize: Config.fontSizeLarge
                }
                Text {
                    text: TimeService.format("ddd, dd MMM")
                    color: Config.subtextColor
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }

            // Espaçador
            Item {
                Layout.fillWidth: true
            }

            // Indicador de Bateria (só aparece se tiver bateria)
            Rectangle {
                visible: BatteryService.hasBattery
                Layout.preferredHeight: 36
                Layout.preferredWidth: batteryContent.implicitWidth + 16
                radius: Config.radius
                color: Config.surface1Color

                RowLayout {
                    id: batteryContent
                    anchors.centerIn: parent
                    spacing: 6

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

            // Botão Power
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Config.radius
                color: powerBtnHover.containsMouse ? Qt.rgba(Config.errorColor.r, Config.errorColor.g, Config.errorColor.b, 0.2) : "transparent"
                border.width: 1
                border.color: powerBtnHover.containsMouse ? Config.errorColor : Config.surface2Color

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.errorColor
                }

                MouseArea {
                    id: powerBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeWindow();
                        PowerService.showOverlay();
                    }
                }
            }
        }

        MediaWidget {
            Layout.fillWidth: true
        }

        // GRID DE BOTÕES (Estilo ToggleButton grande)
        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Layout.fillWidth: true

            // WI-FI BUTTON
            QuickSettingsTile {
                icon: NetworkService.systemIcon
                label: "Wi-Fi"
                subLabel: NetworkService.statusText
                property string ssid: NetworkService.accessPoints.find(ap => ap.active)?.ssid || "Conectado"
                active: NetworkService.wifiEnabled
                hasDetails: true
                onToggled: NetworkService.toggleWifi()
                onOpenDetails: pageStack.currentIndex = 1
            }

            // BLUETOOTH BUTTON
            QuickSettingsTile {
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
                label: "Luz noturna"
                subLabel: BrightnessService.nightLightEnabled ? (BrightnessService.nightLightTemperature + "K") : "Desligado"
                active: BrightnessService.nightLightEnabled
                hasDetails: true
                onToggled: BrightnessService.toggleNightLight()
                onOpenDetails: pageStack.currentIndex = 4
            }

            // DND (Do Not Disturb)
            QuickSettingsTile {
                icon: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                label: "Não perturbe"
                subLabel: NotificationService.dndEnabled ? "Ativado" : "Desativado"
                active: NotificationService.dndEnabled
                hasDetails: false
                onToggled: NotificationService.toggleDnd()
            }
        }

        // SLIDERS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.topMargin: 4

            QsSlider {
                icon: AudioService.systemIcon
                value: AudioService.volume
                onMoved: val => AudioService.setVolume(val)
                onIconClicked: AudioService.toggleMute()
            }

            // Brilho (só aparece se disponível)
            QsSlider {
                visible: BrightnessService.available
                icon: BrightnessService.icon
                value: BrightnessService.brightness
                onMoved: val => BrightnessService.setBrightness(val)
                onIconClicked: BrightnessService.toggleBrightness()
            }
        }

        SystemMonitorWidget {}
    }
}
