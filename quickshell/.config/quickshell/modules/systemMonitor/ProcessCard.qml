pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    readonly property string sortKey: SystemMonitorService.processSort
    readonly property real maxValue: {
        const top = SystemMonitorService.processes[0];
        // CPU bars use a 10% floor so an idle system doesn't show full bars
        return top ? Math.max(top[sortKey], sortKey === "cpu" ? 10 : 1) : 1;
    }

    // Column widths shared by the titles and the rows
    readonly property int barWidth: Config.fontSizeIcon * 2
    readonly property int cpuWidth: cpuRef.advanceWidth
    readonly property int memWidth: memRef.advanceWidth

    spacing: Config.padding

    TextMetrics {
        id: cpuRef
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        text: "100.0%"
    }

    TextMetrics {
        id: memRef
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        text: "1023 MiB"
    }

    CardHeader {
        icon: "󰉹"
        title: "Top processes"

        SortButton {
            text: "CPU"
            key: "cpu"
        }

        SortButton {
            text: "MEM"
            key: "mem"
        }
    }

    // Column titles
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Config.padding
        Layout.rightMargin: Config.padding
        spacing: Config.spacing

        ColumnTitle {
            Layout.fillWidth: true
            text: "Name"
        }

        ColumnTitle {
            Layout.preferredWidth: root.cpuWidth
            horizontalAlignment: Text.AlignRight
            text: "CPU"
        }

        ColumnTitle {
            Layout.preferredWidth: root.memWidth
            horizontalAlignment: Text.AlignRight
            text: "Memory"
        }
    }

    Repeater {
        model: SystemMonitorService.processes

        Rectangle {
            id: row
            required property var modelData
            required property int index

            readonly property real fraction: Math.min(1, modelData[root.sortKey] / root.maxValue)

            Layout.fillWidth: true
            implicitHeight: Config.fontSizeNormal + Config.padding * 2
            radius: Config.radius
            color: index % 2 === 0 ? Qt.alpha(Config.surface1Color, 0.5) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.padding
                anchors.rightMargin: Config.padding
                spacing: Config.spacing

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.textColor
                    elide: Text.ElideRight
                }

                Text {
                    visible: row.modelData.count > 1
                    text: "×" + row.modelData.count
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                // Relative weight of this process for the current sort key
                Rectangle {
                    Layout.preferredWidth: root.barWidth
                    Layout.preferredHeight: Config.padding - 2
                    radius: height / 2
                    color: Config.surface2Color

                    Rectangle {
                        width: Math.max(parent.height, parent.width * row.fraction)
                        height: parent.height
                        radius: height / 2
                        color: Config.accentColor

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animDurationLong
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: root.cpuWidth
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.cpu.toFixed(1) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: root.sortKey === "cpu"
                    color: root.sortKey === "cpu" ? Config.textColor : Config.subtextColor
                }

                Text {
                    Layout.preferredWidth: root.memWidth
                    horizontalAlignment: Text.AlignRight
                    text: SystemMonitorService.formatBytes(row.modelData.mem)
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: root.sortKey === "mem"
                    color: root.sortKey === "mem" ? Config.textColor : Config.subtextColor
                }
            }
        }
    }

    component ColumnTitle: Text {
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.mutedColor
    }

    component SortButton: Rectangle {
        id: sortButton

        required property string text
        required property string key
        readonly property bool active: SystemMonitorService.processSort === key

        implicitWidth: sortLabel.implicitWidth + Config.padding * 2 + Config.padding / 2
        implicitHeight: Config.fontSizeSmall * 2
        radius: height / 2
        color: active ? Config.accentColor : (sortMouse.containsMouse ? Config.surface2Color : Config.surface1Color)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            id: sortLabel
            anchors.centerIn: parent
            text: sortButton.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: sortButton.active ? Config.textReverseColor : Config.subtextColor
        }

        MouseArea {
            id: sortMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemMonitorService.processSort = sortButton.key
        }
    }
}
