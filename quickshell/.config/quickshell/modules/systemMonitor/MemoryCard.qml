pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

MonitorCard {
    id: root

    CardHeader {
        icon: "󰘚"
        title: "Memory"
        iconColor: SystemMonitorService.usageColor(SystemMonitorService.memUsage)
    }

    UsageArc {
        value: SystemMonitorService.memUsage
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: SystemMonitorService.formatGiB(SystemMonitorService.memUsed) + " / " + SystemMonitorService.formatGiB(SystemMonitorService.memTotal) + " GiB"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: SystemMonitorService.swapTotal > 0
            text: "Swap " + SystemMonitorService.formatGiB(SystemMonitorService.swapUsed) + " / " + SystemMonitorService.formatGiB(SystemMonitorService.swapTotal) + " GiB"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
