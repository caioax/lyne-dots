pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// OSD level track with a fill for value (0–1). Horizontal fills from the
// left, vertical from the bottom
Rectangle {
    id: root

    property real value: 0
    property color tone: Config.accentColor
    property bool vertical: false

    readonly property real level: Math.max(0, Math.min(1, value))

    radius: (vertical ? width : height) / 2
    color: Config.surface1Color

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.vertical ? parent.width : parent.width * root.level
        height: root.vertical ? parent.height * root.level : parent.height
        radius: root.radius
        color: root.tone

        Behavior on width {
            enabled: !root.vertical

            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: root.vertical

            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }
}
