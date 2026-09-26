pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config

// App icons: each workspace with windows shows its apps' icons (up to
// `maxIcons` distinct apps) on a soft background, empty ones their number,
// and the accent pill slides behind the active one.
WorkspaceStrip {
    id: root

    property int maxIcons: 3
    readonly property int iconSize: Config.fontSizeNormal
    readonly property int iconGap: Math.round(Config.padding / 2)
    readonly property int groupPadding: Math.round(Config.padding * 3 / 4)

    itemWidth: Math.round(Config.fontSizeSmall * 1.5)
    activeWidth: itemWidth + Config.padding * 2
    itemSpacing: Math.round(Config.padding / 2)

    function appsAt(index) {
        return model.appsOf(model.monitorOffset + index + 1).slice(0, maxIcons);
    }

    slotWidth: (index, active) => {
        const n = appsAt(index).length;
        if (n === 0)
            return active ? activeWidth : itemWidth;
        return n * iconSize + (n - 1) * iconGap + groupPadding * 2;
    }

    // Soft background behind every workspace with windows
    underlay: Component {
        Item {
            property Item strip

            Repeater {
                model: root.total
                delegate: Rectangle {
                    required property int index
                    readonly property bool occupied: root.appsAt(index).length > 0

                    x: root.slotX(index)
                    width: root.slotEnd(index) - x
                    height: root.indicatorHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Config.radius
                    color: Config.surface2Color
                    opacity: occupied ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }
                }
            }
        }
    }

    slotContent: Component {
        Item {
            id: cell
            required property Item slot
            readonly property var apps: root.appsAt(slot.index)

            anchors.fill: parent

            Text {
                anchors.centerIn: parent
                visible: cell.apps.length === 0
                text: cell.slot.index + 1
                font {
                    family: Config.font
                    pixelSize: Config.fontSizeSmall
                    bold: cell.slot.isActive
                }
                color: cell.slot.isActive ? Config.textReverseColor : Config.mutedColor
            }

            Row {
                anchors.centerIn: parent
                spacing: root.iconGap

                Repeater {
                    model: cell.apps
                    delegate: IconImage {
                        required property string modelData
                        implicitSize: root.iconSize
                        source: root.model.iconFor(modelData)
                        opacity: cell.slot.isActive ? 1 : 0.75
                    }
                }
            }
        }
    }
}
