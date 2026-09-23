pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// 270° gauge with the percentage in the middle (memory, storage)
ProgressRing {
    id: root

    property string caption: "used"

    Layout.alignment: Qt.AlignHCenter
    // Sized from the typography scale so text never outgrows the arc
    Layout.preferredWidth: Config.fontSizeIcon * 4 + Config.spacing
    Layout.preferredHeight: Layout.preferredWidth
    startAngle: 135
    sweepAngle: 270
    strokeWidth: 7
    color: SystemMonitorService.usageColor(value)

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Config.padding / 2
        spacing: -2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(root.value) + "%"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIcon
            font.bold: true
            color: root.color

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.caption
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
