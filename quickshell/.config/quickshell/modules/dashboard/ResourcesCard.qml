pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// CPU, memory, GPU and root disk usage as rings, plus the uptime.
// Clicking it opens the System tab
Rectangle {
    id: root

    readonly property var rootDisk: SystemMonitorService.disks.find(d => d.mount === "/") ?? null
    readonly property bool hasGpu: SystemMonitorService.gpuType !== "unknown"

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Config.padding * 4
    radius: Config.radiusLarge
    color: mouse.containsMouse ? Config.cardHoverColor : Config.cardColor

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: DashboardService.tab = "system"
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Config.padding * 2
        spacing: Config.spacing

        Resource {
            label: "CPU"
            value: SystemMonitorService.cpuUsage
            detail: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : ""
        }

        Resource {
            label: "Memory"
            value: SystemMonitorService.memUsage
            detail: SystemMonitorService.formatGiB(SystemMonitorService.memUsed) + " GiB"
        }

        Resource {
            visible: root.hasGpu
            label: "GPU"
            value: SystemMonitorService.gpuSleeping ? 0 : SystemMonitorService.gpuUsage
            detail: SystemMonitorService.gpuSleeping ? "Asleep" : SystemMonitorService.gpuTemp > 0 ? SystemMonitorService.gpuTemp + "°C" : ""
        }

        Resource {
            label: "Disk"
            value: root.rootDisk?.usage ?? 0
            detail: root.rootDisk ? SystemMonitorService.formatBytes(root.rootDisk.total - root.rootDisk.used) + " free" : ""
        }

        StatChip {
            Layout.alignment: Qt.AlignVCenter
            icon: "\u{f0150}"
            text: SystemMonitorService.uptime
            accent: Config.accentColor
        }
    }

    component Resource: RowLayout {
        id: resource

        required property string label
        required property real value
        property string detail: ""
        readonly property color color: SystemMonitorService.usageColor(value)

        Layout.fillWidth: true
        spacing: Config.spacing

        ProgressRing {
            implicitWidth: Config.fontSizeIcon * 2
            implicitHeight: Config.fontSizeIcon * 2
            value: resource.value
            strokeWidth: Config.padding - 2
            color: resource.color

            Text {
                anchors.centerIn: parent
                text: Math.round(resource.value)
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: resource.label
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: resource.detail
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall - 2
                color: Config.subtextColor
                elide: Text.ElideRight
            }
        }
    }
}
