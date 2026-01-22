pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.services

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 24
    radius: Config.radiusLarge
    color: Config.surface0Color

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰍛"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
            }

            Text {
                text: "Monitor do Sistema"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
                Layout.fillWidth: true
            }
        }

        // Monitors Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // CPU Monitor
            MonitorCard {
                Layout.fillWidth: true
                title: "CPU"
                icon: SystemMonitorService.cpuIcon
                usage: SystemMonitorService.cpuUsage
                temp: SystemMonitorService.cpuTemp
                usageColor: SystemMonitorService.getUsageColor(SystemMonitorService.cpuUsage)
                tempColor: SystemMonitorService.getTempColor(SystemMonitorService.cpuTemp)
            }

            // GPU Monitor
            MonitorCard {
                Layout.fillWidth: true
                title: "GPU"
                icon: SystemMonitorService.gpuIcon
                usage: SystemMonitorService.gpuUsage
                temp: SystemMonitorService.gpuTemp
                usageColor: SystemMonitorService.getUsageColor(SystemMonitorService.gpuUsage)
                tempColor: SystemMonitorService.getTempColor(SystemMonitorService.gpuTemp)
                subtitle: SystemMonitorService.gpuType !== "unknown" ? SystemMonitorService.gpuType.toUpperCase() : ""
            }
        }
    }

    // MonitorCard Component
    component MonitorCard: Rectangle {
        id: card

        required property string title
        required property string icon
        required property int usage
        required property int temp
        required property color usageColor
        required property color tempColor
        property string subtitle: ""

        implicitHeight: cardContent.implicitHeight + 20
        radius: Config.radius
        color: Config.surface1Color

        ColumnLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Card Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: card.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.accentColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: card.title
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        visible: card.subtitle !== ""
                        text: card.subtitle
                        font.family: Config.font
                        font.pixelSize: 10
                        color: Config.subtextColor
                    }
                }
            }

            // Usage Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Uso"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: card.usage + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: card.usageColor
                    }
                }

                // Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Config.surface2Color

                    Rectangle {
                        width: parent.width * (card.usage / 100)
                        height: parent.height
                        radius: 3
                        color: card.usageColor

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuad
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }
                }
            }

            // Temperature
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰔏"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: card.tempColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }
                }

                Text {
                    text: "Temp"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: tempText.implicitWidth + 12
                    Layout.preferredHeight: 22
                    radius: 6
                    color: Qt.rgba(card.tempColor.r, card.tempColor.g, card.tempColor.b, 0.15)

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }

                    Text {
                        id: tempText
                        anchors.centerIn: parent
                        text: card.temp + "°C"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: card.tempColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }
                }
            }
        }
    }
}
