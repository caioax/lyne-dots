pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Miniature of one Overview template: the cards as blocks, the player
// highlighted
Rectangle {
    id: root

    // Overview template: "stacked" or "grid"
    property string value

    // Blocks as fractions of the inner area: [x, y, width, height, player]
    readonly property var blocks: value === "grid" ? [[0, 0, 0.28, 0.28], [0, 0.32, 0.28, 0.4], [0.31, 0, 0.41, 0.72], [0.75, 0, 0.25, 0.72, true], [0, 0.76, 1, 0.24]] : [[0, 0, 0.38, 0.22], [0, 0.26, 0.38, 0.29], [0.41, 0, 0.59, 0.55], [0, 0.59, 1, 0.19, true], [0, 0.82, 1, 0.18]]

    radius: Config.radius
    color: Config.surface1Color

    Item {
        id: area
        anchors.fill: parent
        anchors.margins: root.height / 10

        Repeater {
            model: root.blocks

            Rectangle {
                required property var modelData
                readonly property real gap: area.height / 40

                x: modelData[0] * area.width
                y: modelData[1] * area.height
                width: modelData[2] * area.width - (modelData[0] + modelData[2] < 1 ? gap : 0)
                height: modelData[3] * area.height - (modelData[1] + modelData[3] < 1 ? gap : 0)
                radius: Config.radiusSmall / 2
                color: modelData[4] ? Qt.alpha(Config.accentColor, 0.6) : Config.surface3Color

                Behavior on x {
                    NumberAnimation {
                        duration: Config.animDuration
                    }
                }
            }
        }
    }
}
