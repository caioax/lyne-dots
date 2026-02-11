pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    // --- Properties ---
    property real value: 0
    property real from: 0
    property real to: 1
    property string icon: ""
    property bool showPercentage: true
    property string fillColor: Config.accentColor

    // SIGNALS
    signal moved(real newValue)
    signal iconClicked

    // Component size
    implicitHeight: 40
    Layout.fillWidth: true

    Behavior on fillColor {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // --- THE ICON BUTTON ---
        Rectangle {
            id: iconBtn

            // Set the size: full component height and width equal to height (square)
            Layout.fillHeight: true
            Layout.preferredWidth: height

            radius: Config.radiusLarge

            // Color changes on hover (button feedback)
            color: iconMouse.containsMouse ? Config.surface2Color : Config.surface1Color

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            // Icon
            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                font.bold: true
                color: Config.textColor

                scale: iconMouse.pressed ? 0.8 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.iconClicked()
            }
        }

        // THE SLIDER BAR
        Item {
            id: sliderContainer

            // Layout magic: Takes up all remaining width
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height - 6

            readonly property real handleGap: 5
            readonly property real visualPos: (root.value - root.from) / (root.to - root.from)

            // Inner container for the scale animation
            Item {
                anchors.fill: parent
                scale: sliderMouse.pressed ? 0.98 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationShort
                        easing.type: Easing.OutQuad
                    }
                }

                // Fill
                Rectangle {
                    id: fill
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left

                    width: Math.max(0, (sliderContainer.visualPos * parent.width) - sliderContainer.handleGap)
                    height: 28
                    color: root.fillColor

                    topLeftRadius: Config.radius
                    bottomLeftRadius: Config.radius
                    topRightRadius: 2
                    bottomRightRadius: 2

                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // Remaining
                Rectangle {
                    id: remainingBar
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right

                    width: Math.max(0, ((1 - sliderContainer.visualPos) * parent.width) - sliderContainer.handleGap)
                    height: 28
                    color: Config.surface2Color

                    topLeftRadius: 2
                    bottomLeftRadius: 2
                    topRightRadius: Config.radius
                    bottomRightRadius: Config.radius

                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // Handle
                Rectangle {
                    id: handle
                    width: 3.5
                    height: parent.height
                    radius: 2
                    color: root.fillColor

                    x: (sliderContainer.visualPos * parent.width) - (width / 2)
                    anchors.verticalCenter: parent.verticalCenter

                    opacity: sliderMouse.containsMouse || sliderMouse.pressed ? 1.0 : 0.8

                    Behavior on x {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // Percentage Text
                Text {
                    visible: root.showPercentage
                    anchors.bottom: handle.top
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: handle.horizontalCenter

                    text: Math.round(((root.value - root.from) / (root.to - root.from)) * 100) + "%"

                    font.family: Config.font
                    font.bold: true
                    font.pixelSize: Config.fontSizeNormal

                    // Smart color
                    property bool isCovered: fill.width > (parent.width / 2)
                    color: Config.textColor

                    opacity: (sliderMouse.containsMouse || sliderMouse.pressed) ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }
                }
            }

            // MouseArea
            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateFromMouse(mouseX) {
                    let percent = mouseX / width;
                    percent = Math.max(0, Math.min(1, percent));
                    let val = root.from + (root.to - root.from) * percent;
                    root.moved(val);
                }

                onPressed: mouse => updateFromMouse(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        updateFromMouse(mouse.x);
                }

                onWheel: wheel => {
                    let step = (root.to - root.from) * 0.05;
                    if (wheel.angleDelta.y > 0)
                        root.moved(Math.min(root.to, root.value + step));
                    else
                        root.moved(Math.max(root.from, root.value - step));
                }
            }
        }
    }
}
