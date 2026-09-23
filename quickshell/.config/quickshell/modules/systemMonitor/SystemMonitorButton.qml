pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    readonly property int cpu: SystemMonitorService.cpuUsage
    readonly property int temp: SystemMonitorService.cpuTemp
    readonly property bool hot: temp >= 80
    readonly property color accent: SystemMonitorService.usageColor(cpu)

    // Recent CPU samples shown in the bar (40s at 2s interval)
    readonly property int samples: 20

    active: monitorWindow.visible
    contentItem: buttonContent
    onClicked: monitorWindow.visible = !monitorWindow.visible

    RowLayout {
        id: buttonContent
        anchors.centerIn: parent
        spacing: Config.padding

        Text {
            text: "󰍛"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: root.active || root.cpu >= 70 ? root.accent : Config.subtextColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }

        Sparkline {
            Layout.preferredWidth: Config.fontSizeIcon * 2
            Layout.preferredHeight: root.implicitHeight - Config.padding / 2
            values: SystemMonitorService.cpuHistory.slice(-root.samples)
            capacity: root.samples
            // Auto-scale with a 20% floor: light loads still show shape,
            // while the color carries the actual severity
            maxValue: 0
            minAutoMax: 20
            color: root.accent
        }

        // Exact numbers on hover (temperature stays visible while hot)
        Item {
            Layout.preferredWidth: root.hovered || root.active || root.hot ? details.implicitWidth : 0
            Layout.preferredHeight: details.implicitHeight
            // Drops out of the layout (and its spacing) once collapsed
            visible: Layout.preferredWidth > 0
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: details
                anchors.verticalCenter: parent.verticalCenter
                text: root.cpu + "%" + (root.hot ? "  󰔏 " + root.temp + "°" : "")
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: root.hot ? SystemMonitorService.tempColor(root.temp) : Config.textColor
            }
        }
    }

    SystemMonitorWindow {
        id: monitorWindow
        visible: false
    }
}
