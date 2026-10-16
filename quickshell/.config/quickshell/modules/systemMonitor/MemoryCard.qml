pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    CardHeader {
        icon: "󰘚"
        title: I18n.tr("Memory")
        iconColor: SystemMonitorService.usageColor(SystemMonitorService.memUsage)
    }

    UsageArc {
        value: SystemMonitorService.memUsage
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: SystemMonitorService.formatGiB(SystemMonitorService.memUsed) + " / " + SystemMonitorService.formatGiB(SystemMonitorService.memTotal) + " GiB"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: SystemMonitorService.swapTotal > 0
            text: I18n.tr("Swap %1 / %2 GiB", SystemMonitorService.formatGiB(SystemMonitorService.swapUsed), SystemMonitorService.formatGiB(SystemMonitorService.swapTotal))
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
