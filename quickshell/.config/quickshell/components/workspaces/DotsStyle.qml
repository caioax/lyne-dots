import QtQuick
import qs.config

// Dots: filled dots for workspaces with windows, rings for empty ones, and
// the active one stretched into a short bar.
WorkspaceStrip {
    id: root

    readonly property int dotSize: Math.round(Config.fontSizeSmall / 2)

    itemWidth: dotSize * 2
    activeWidth: dotSize * 4
    itemSpacing: Math.round(Config.padding / 4)

    indicatorHeight: Math.round(dotSize * 4 / 3)
    indicatorRadius: indicatorHeight / 2

    // The bar slides over the dots
    contentOverIndicator: false

    slotContent: Component {
        Rectangle {
            required property Item slot
            readonly property color dotColor: slot.isEmpty ? Config.mutedColor : Config.subtextColor

            anchors.centerIn: parent
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: slot.isEmpty ? Qt.alpha(dotColor, 0) : dotColor
            border.width: 1
            border.color: dotColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
