pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// OSD level track with a fill for value (0–max). Horizontal fills from the
// left, vertical from the bottom. With max above 1 (volume boost) a notch
// marks 100% and the part past it is drawn in the warning color
Rectangle {
    id: root

    property real value: 0
    property real max: 1
    property color tone: Config.accentColor
    property bool vertical: false

    readonly property real length: vertical ? height : width
    readonly property real level: Math.max(0, Math.min(max, value)) / max
    readonly property real normalLevel: Math.min(1, level * max) / max

    radius: (vertical ? width : height) / 2
    color: Config.surface1Color

    component Fill: Rectangle {
        property real fraction: 0

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.vertical ? parent.width : root.length * fraction
        height: root.vertical ? root.length * fraction : parent.height
        radius: root.radius

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

    // Boost, under the normal fill so only the part past 100% shows
    Fill {
        visible: root.level > root.normalLevel
        fraction: root.level
        color: Config.warningColor
    }

    Fill {
        fraction: root.normalLevel
        color: root.tone
    }

    // 100% notch
    Rectangle {
        readonly property real thickness: Math.max(1, Math.round(Config.padding / 3))
        readonly property real offset: root.length / root.max - thickness / 2

        visible: root.max > 1
        x: root.vertical ? 0 : offset
        y: root.vertical ? root.height - offset - thickness : 0
        width: root.vertical ? parent.width : thickness
        height: root.vertical ? thickness : parent.height
        color: Config.backgroundColor
    }
}
