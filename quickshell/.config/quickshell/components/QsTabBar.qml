pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Row of equal-width tabs ({ label, icon }) over a divider, with an
// indicator line sliding under the current one. The wheel steps through them
Item {
    id: root

    required property var tabs
    property int currentIndex: 0

    signal selected(int index)

    readonly property real tabWidth: width / Math.max(1, tabs.length)
    readonly property int indicatorHeight: 3

    Layout.fillWidth: true
    implicitHeight: Config.fontSizeIcon * 2 + indicatorHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = event.angleDelta.y < 0 ? 1 : event.angleDelta.y > 0 ? -1 : 0;
            const i = root.currentIndex + step;
            if (step !== 0 && i >= 0 && i < root.tabs.length)
                root.selected(i);
        }
    }

    Row {
        id: row
        width: parent.width
        height: parent.height - root.indicatorHeight

        Repeater {
            id: repeater
            model: root.tabs

            Item {
                id: tab

                required property var modelData
                required property int index
                readonly property bool current: index === root.currentIndex
                readonly property real contentWidth: label.implicitWidth

                width: root.tabWidth
                height: row.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Config.padding / 2
                    radius: Config.radius
                    color: mouse.containsMouse && !tab.current ? Config.cardHoverColor : Qt.alpha(Config.cardHoverColor, 0)

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                }

                RowLayout {
                    id: label
                    anchors.centerIn: parent
                    spacing: Config.padding

                    Text {
                        text: tab.modelData.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: tab.current ? Config.accentColor : Config.subtextColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }

                    Text {
                        text: tab.modelData.label
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: tab.current
                        color: tab.current ? Config.textColor : Config.subtextColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(tab.index)
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Config.surface1Color
    }

    // Indicator: as wide as the current tab's icon and label. Quicker than
    // the pages it points at, so the selection never trails behind them
    Rectangle {
        readonly property Item tab: repeater.count, repeater.itemAt(root.currentIndex)
        readonly property real tabContentWidth: tab?.contentWidth ?? root.tabWidth / 2

        anchors.bottom: parent.bottom
        x: root.tabWidth * root.currentIndex + (root.tabWidth - width) / 2
        width: tabContentWidth + Config.padding * 2
        height: root.indicatorHeight
        radius: height / 2
        color: Config.accentColor

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
    }
}
