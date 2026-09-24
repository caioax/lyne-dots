pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Row of small color dots previewing a palette
Row {
    id: dots

    property var colors: []

    spacing: Math.round(Config.padding / 2)

    Repeater {
        model: dots.colors.filter(c => c !== undefined && c !== "")

        Rectangle {
            required property var modelData
            width: Config.padding * 2
            height: width
            radius: width / 2
            color: modelData
            border.width: 1
            border.color: Qt.alpha(Config.textColor, 0.15)
        }
    }
}
