pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Occupied groups: numbered slots with no gaps, where neighbouring
// workspaces that have windows share one rounded background; the active
// number sits on an accent circle inside it.
WorkspaceStrip {
    id: root

    itemWidth: Math.round(Config.fontSizeSmall * 1.8)
    activeWidth: itemWidth
    // No gaps, so neighbouring backgrounds join into one shape
    itemSpacing: 0

    readonly property int groupHeight: itemWidth
    indicatorInset: Math.round(Config.padding / 4)
    indicatorHeight: groupHeight - indicatorInset * 2
    indicatorRadius: indicatorHeight / 2

    function occupiedAt(index) {
        return index >= 0 && index < total && model.isOccupied(model.monitorOffset + index + 1);
    }

    // One background per slot: it rounds only the sides whose neighbour is
    // empty, so a run of occupied slots reads as a single pill
    underlay: Component {
        Item {
            property Item strip

            Repeater {
                model: root.total
                delegate: Rectangle {
                    id: cell
                    required property int index
                    readonly property bool occupied: root.occupiedAt(index)
                    readonly property real leftRadius: root.occupiedAt(index - 1) ? 0 : height / 2
                    readonly property real rightRadius: root.occupiedAt(index + 1) ? 0 : height / 2

                    x: root.slotX(index)
                    width: root.slotEnd(index) - x
                    height: root.groupHeight
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.surface2Color
                    opacity: occupied ? 1 : 0

                    topLeftRadius: leftRadius
                    bottomLeftRadius: leftRadius
                    topRightRadius: rightRadius
                    bottomRightRadius: rightRadius

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }
                    Behavior on topLeftRadius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on bottomLeftRadius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on topRightRadius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on bottomRightRadius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    slotContent: Component {
        Text {
            required property Item slot

            anchors.centerIn: parent
            text: slot.index + 1
            font {
                family: Config.font
                pixelSize: Config.fontSizeSmall
                bold: slot.isActive
            }
            color: slot.isActive ? Config.textReverseColor : slot.isEmpty ? Config.mutedColor : Config.textColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
