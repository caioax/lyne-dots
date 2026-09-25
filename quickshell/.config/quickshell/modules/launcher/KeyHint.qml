import QtQuick
import QtQuick.Layouts
import qs.config

// Keycap + what it does, for the launcher footer
RowLayout {
    id: root

    property string keys
    property string label
    // Whether the footer should show it, room permitting
    property bool wanted: true

    spacing: Config.padding

    Rectangle {
        implicitWidth: Math.max(implicitHeight, keyText.implicitWidth + Config.padding * 2)
        implicitHeight: keyText.implicitHeight + Config.padding
        radius: Config.radiusSmall
        color: Config.surface1Color

        Text {
            id: keyText
            anchors.centerIn: parent
            text: root.keys
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.subtextColor
        }
    }

    Text {
        text: root.label
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.mutedColor
    }
}
