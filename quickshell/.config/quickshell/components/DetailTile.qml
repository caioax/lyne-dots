pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Small labeled value (icon + label over a bold value) for detail grids,
// like the weather's humidity, wind or UV
Rectangle {
    id: tile

    required property string icon
    required property string label
    required property string value
    property color accent: Config.accentColor

    Layout.fillWidth: true
    implicitHeight: tileColumn.implicitHeight + Config.padding * 2
    radius: Config.radius
    color: Qt.alpha(Config.surface1Color, 0.5)

    ColumnLayout {
        id: tileColumn
        anchors.fill: parent
        anchors.margins: Config.padding
        anchors.leftMargin: Config.padding * 2
        spacing: 0

        RowLayout {
            spacing: Config.padding

            Text {
                text: tile.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: tile.accent
            }

            Text {
                text: tile.label
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        Text {
            Layout.fillWidth: true
            text: tile.value
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: Config.textColor
            elide: Text.ElideRight
        }
    }
}
