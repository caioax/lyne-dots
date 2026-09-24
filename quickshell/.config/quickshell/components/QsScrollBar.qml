import QtQuick
import QtQuick.Controls
import qs.config

// Themed vertical scrollbar: a thin visible handle at rest that gets
// stronger on hover and while dragging
ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    padding: Math.round(Config.padding / 3)

    background: Item {}

    // The style fades the handle out when idle through these
    states: []
    transitions: []

    contentItem: Rectangle {
        implicitWidth: Math.round(Config.padding * 2 / 3)
        implicitHeight: implicitWidth
        radius: width / 2
        color: root.pressed ? Config.surface3Color : root.hovered ? Config.surface2Color : Qt.alpha(Config.surface2Color, 0.7)
        visible: root.size < 1

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }
}
