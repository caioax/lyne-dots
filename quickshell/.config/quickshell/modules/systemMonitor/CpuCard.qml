pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

HeroCard {
    id: root

    icon: SystemMonitorService.cpuIcon
    label: "CPU"
    subLabel: SystemMonitorService.cpuName
    usage: SystemMonitorService.cpuUsage
    history: SystemMonitorService.cpuHistory

    // Per-thread usage bars
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Config.fontSizeIcon
        spacing: Config.padding / 2

        Repeater {
            model: SystemMonitorService.coreUsages

            Rectangle {
                id: core
                required property int modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Config.radiusSmall
                color: Config.surface2Color

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.height * core.modelData / 100)
                    radius: Config.radiusSmall
                    color: SystemMonitorService.usageColor(core.modelData)

                    Behavior on height {
                        NumberAnimation {
                            duration: Config.animDurationLong
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.padding

        StatChip {
            icon: "󰔏"
            text: SystemMonitorService.cpuTemp + "°C"
            accent: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
        }

        StatChip {
            icon: "󰓅"
            text: SystemMonitorService.cpuFreq.toFixed(2) + " GHz"
        }

        StatChip {
            icon: "󰊚"
            text: SystemMonitorService.loadAvg.toFixed(2)
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
