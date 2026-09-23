pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Small pill with an icon and a value (temperature, frequency, VRAM...)
Rectangle {
    id: root

    required property string icon
    required property string text
    property color accent: Config.subtextColor

    implicitWidth: row.implicitWidth + Config.padding * 2 + 2
    implicitHeight: Config.fontSizeSmall * 2
    radius: height / 2
    color: Qt.alpha(accent, 0.12)

    Behavior on color {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Config.padding - 1

        Text {
            text: root.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: root.accent
        }

        Text {
            text: root.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }
    }
}
