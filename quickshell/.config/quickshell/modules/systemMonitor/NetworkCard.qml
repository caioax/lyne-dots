pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    readonly property color downColor: Config.accentColor
    readonly property color upColor: Config.successColor

    CardHeader {
        icon: "󰛳"
        title: "Network"
        subtitle: SystemMonitorService.netInterface
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Config.fontSizeIconSmall * 2 + Config.padding

        Sparkline {
            anchors.fill: parent
            values: SystemMonitorService.netDownHistory
            values2: SystemMonitorService.netUpHistory
            capacity: SystemMonitorService.historyLength
            maxValue: 0 // auto-scale
            minAutoMax: 10240
            color: root.downColor
            color2: root.upColor
        }

        Text {
            anchors.centerIn: parent
            visible: SystemMonitorService.netDownHistory.length < 2
            text: "Collecting data…"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.mutedColor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        uniformCellSizes: true
        spacing: Config.spacing

        SpeedLabel {
            icon: "󰇚"
            label: "Down"
            speed: SystemMonitorService.netDown
            total: SystemMonitorService.netDownTotal
            accent: root.downColor
        }

        SpeedLabel {
            icon: "󰕒"
            label: "Up"
            speed: SystemMonitorService.netUp
            total: SystemMonitorService.netUpTotal
            accent: root.upColor
        }
    }

    component SpeedLabel: RowLayout {
        id: speedLabel

        required property string icon
        required property string label
        required property real speed
        required property real total
        required property color accent

        Layout.fillWidth: true
        spacing: Config.spacing

        Rectangle {
            Layout.preferredWidth: Config.fontSizeNormal * 2
            Layout.preferredHeight: Config.fontSizeNormal * 2
            radius: Config.radius
            color: Qt.alpha(speedLabel.accent, 0.15)

            Text {
                anchors.centerIn: parent
                text: speedLabel.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: speedLabel.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: SystemMonitorService.formatSpeed(speedLabel.speed)
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }

            Text {
                text: speedLabel.label + " · " + SystemMonitorService.formatBytes(speedLabel.total)
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }
    }
}
