pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

MonitorCard {
    id: root

    readonly property var primary: SystemMonitorService.disks[0] ?? null

    CardHeader {
        icon: "󰋊"
        title: "Storage"
        subtitle: root.primary?.mount ?? ""
        iconColor: SystemMonitorService.usageColor(root.primary?.usage ?? 0)
    }

    UsageArc {
        value: root.primary?.usage ?? 0
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: SystemMonitorService.disks

            Text {
                id: diskText
                required property var modelData
                required property int index

                Layout.alignment: Qt.AlignHCenter
                text: (index > 0 ? modelData.mount + "  " : "") + SystemMonitorService.formatGiB(modelData.used) + " / " + SystemMonitorService.formatGiB(modelData.total) + " GiB"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: index === 0
                color: index === 0 ? Config.textColor : Config.subtextColor
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: SystemMonitorService.disks.length === 1
            text: SystemMonitorService.formatGiB(root.primary?.total - root.primary?.used) + " GiB free"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
