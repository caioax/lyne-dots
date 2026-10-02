pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config

// A screen with four windows in a window layout: Dwindle's spiral of
// splits, Master's main window beside a stack, or Scrolling's columns on a
// strip that runs past the screen edges. The focused window is accented
ClippingRectangle {
    id: root

    // Layout: "dwindle", "master" or "scrolling"
    property string value

    readonly property real gap: Math.max(2, Math.round(Config.padding / 2))
    readonly property real areaWidth: width - gap * 2
    readonly property real areaHeight: height - gap * 2

    // Windows as fractions of the area: [x, y, w, h], the first one focused
    readonly property var windows: ({
            dwindle: [[0, 0, 0.5, 1], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.25, 0.5], [0.75, 0.5, 0.25, 0.5]],
            master: [[0, 0, 0.55, 1], [0.55, 0, 0.45, 1 / 3], [0.55, 1 / 3, 0.45, 1 / 3], [0.55, 2 / 3, 0.45, 1 / 3]],
            // Columns off the edges are cut by the screen
            scrolling: [[0.2, 0, 0.6, 1], [-0.45, 0, 0.6, 1], [0.85, 0, 0.6, 0.5], [0.85, 0.5, 0.6, 0.5]]
        })[value] ?? []

    radius: Config.radius
    color: Config.surface2Color

    Repeater {
        model: root.windows

        Rectangle {
            required property var modelData
            required property int index

            x: root.gap + modelData[0] * root.areaWidth + root.gap / 2
            y: root.gap + modelData[1] * root.areaHeight + root.gap / 2
            width: modelData[2] * root.areaWidth - root.gap
            height: modelData[3] * root.areaHeight - root.gap
            radius: Config.radiusSmall
            color: index === 0 ? Qt.alpha(Config.accentColor, 0.35) : Config.surface3Color
            border.width: index === 0 ? 1 : 0
            border.color: Config.accentColor
        }
    }
}
