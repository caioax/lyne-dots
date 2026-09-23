pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

HeroCard {
    id: root

    readonly property bool sleeping: SystemMonitorService.gpuSleeping

    icon: SystemMonitorService.gpuIcon
    label: "GPU"
    subLabel: SystemMonitorService.gpuName || SystemMonitorService.gpuType.toUpperCase()
    usage: SystemMonitorService.gpuUsage
    history: SystemMonitorService.gpuHistory
    idle: sleeping

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.padding

        StatChip {
            visible: root.sleeping
            icon: "󰒲"
            text: "Suspended"
            accent: Config.mutedColor
        }

        StatChip {
            visible: !root.sleeping && SystemMonitorService.gpuTemp > 0
            icon: "󰔏"
            text: SystemMonitorService.gpuTemp + "°C"
            accent: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
        }

        StatChip {
            visible: !root.sleeping && SystemMonitorService.gpuMemTotal > 0
            icon: "󰘚"
            text: SystemMonitorService.formatGiB(SystemMonitorService.gpuMemUsed) + " / " + SystemMonitorService.formatGiB(SystemMonitorService.gpuMemTotal) + " GiB"
        }

        StatChip {
            visible: !root.sleeping && SystemMonitorService.gpuPower >= 0
            icon: "󱐋"
            text: SystemMonitorService.gpuPower.toFixed(0) + " W"
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
