pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// CPU, memory, GPU and root disk usage as rings, plus the uptime, in equal
// columns. Clicking it opens the System tab
Rectangle {
    id: root

    readonly property var rootDisk: SystemMonitorService.disks.find(d => d.mount === "/") ?? null
    readonly property bool hasGpu: SystemMonitorService.gpuType !== "unknown"

    // Free space in few characters ("830G free", "1.2T free"): the columns
    // are narrow beside the player
    function shortFree(bytes: real): string {
        const gib = bytes / 1073741824;
        return (gib >= 1024 ? (gib / 1024).toFixed(1) + "T" : Math.round(gib) + "G") + " free";
    }

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
        uniformCellSizes: true

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
            detail: root.rootDisk ? root.shortFree(root.rootDisk.total - root.rootDisk.used) : ""
        }

        Resource {
            label: "Uptime"
            detail: SystemMonitorService.uptime
            icon: "\u{f0150}"
        }
    }

    // A ring with the usage, or an icon in a circle of the same size when
    // `icon` is set (no usage to show), and a label over a detail. Centered
    // in its column
    component Resource: Item {
        id: resource

        required property string label
        property real value: 0
        property string detail: ""
        property string icon: ""
        readonly property color color: SystemMonitorService.usageColor(value)
        readonly property real ringSize: Config.fontSizeIcon * 2

        Layout.fillWidth: true
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        RowLayout {
            id: content
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: Config.spacing

            ProgressRing {
                visible: resource.icon === ""
                implicitWidth: resource.ringSize
                implicitHeight: resource.ringSize
                value: resource.value
                strokeWidth: Config.padding - 2
                color: resource.color

                Text {
                    anchors.centerIn: parent
                    text: Math.round(resource.value) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall - 1
                    font.bold: true
                    color: Config.textColor
                }
            }

            Rectangle {
                visible: resource.icon !== ""
                implicitWidth: resource.ringSize
                implicitHeight: resource.ringSize
                radius: width / 2
                color: Qt.alpha(Config.accentColor, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: resource.icon
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    color: Config.accentColor
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
}
