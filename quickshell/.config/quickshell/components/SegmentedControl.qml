pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Pill with mutually exclusive options ({ label, icon }); the selection
// indicator slides between them
Rectangle {
    id: root

    required property var options
    property int currentIndex: 0

    signal selected(int index)

    readonly property real segmentWidth: (width - Config.padding) / Math.max(1, options.length)

    Layout.fillWidth: true
    implicitHeight: Config.fontSizeIconSmall * 2
    radius: Config.radiusLarge
    color: Config.surface1Color

    // Selection indicator
    Rectangle {
        x: Config.padding / 2 + root.currentIndex * root.segmentWidth
        y: Config.padding / 2
        width: root.segmentWidth
        height: root.height - Config.padding
        radius: Config.radius
        color: Config.accentColor

        Behavior on x {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Config.padding / 2

        Repeater {
            model: root.options

            Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool active: index === root.currentIndex

                width: root.segmentWidth
                height: parent.height

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Config.padding

                    Text {
                        visible: (segment.modelData.icon ?? "") !== ""
                        text: segment.modelData.icon ?? ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: segment.active ? Config.textReverseColor : Config.subtextColor
                    }

                    Text {
                        text: segment.modelData.label
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: segment.active
                        color: segment.active ? Config.textReverseColor : segmentMouse.containsMouse ? Config.textColor : Config.subtextColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }
                }

                MouseArea {
                    id: segmentMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: segment.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!segment.active)
                            root.selected(segment.index);
                    }
                }
            }
        }
    }
}
