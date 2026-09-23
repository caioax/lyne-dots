pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// CPU / GPU card: usage ring, name, big percentage and a history graph.
// Extra rows (chips, per-core bars) go into the default slot.
MonitorCard {
    id: root

    required property string icon
    required property string label
    property string subLabel: ""
    property int usage: 0
    property var history: []
    property bool idle: false // e.g. dGPU suspended
    default property alias extra: extraSlot.data

    readonly property color accent: idle ? Config.mutedColor : SystemMonitorService.usageColor(usage)

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing + Config.padding / 2

        // Sized from the icon so it follows the typography scale
        ProgressRing {
            Layout.preferredWidth: Config.fontSizeIconSmall * 2 + Config.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
            value: root.idle ? 0 : root.usage
            strokeWidth: 5
            color: root.accent

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: root.accent

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDuration
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.label
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
            }

            Text {
                Layout.fillWidth: true
                text: root.subLabel
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                elide: Text.ElideRight
            }
        }

        Text {
            text: root.idle ? "Idle" : root.usage + "%"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: root.accent

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }

    Sparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: Config.fontSizeIconSmall * 2 + Config.padding
        values: root.history
        gridLines: 3
        capacity: SystemMonitorService.historyLength
        color: root.accent
    }

    ColumnLayout {
        id: extraSlot
        Layout.fillWidth: true
        spacing: Config.spacing
    }
}
