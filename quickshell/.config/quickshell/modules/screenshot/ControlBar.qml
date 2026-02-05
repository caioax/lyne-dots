pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Rectangle {
    id: root

    required property var screenshot

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40

    height: 50
    width: barContent.implicitWidth + 16
    radius: height / 2
    color: Config.surface0Color
    border.width: 1
    border.color: Config.surface2Color

    scale: screenshot.active ? 1.0 : 0.9
    opacity: screenshot.active ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: barContent
        anchors.centerIn: parent
        spacing: 0

        // Mode selector
        Item {
            width: 132
            height: 42

            // Sliding highlight
            Rectangle {
                height: 36
                width: 36
                y: 3
                radius: height / 2
                color: Config.accentColor
                x: 4 + (root.screenshot.modes.indexOf(root.screenshot.mode) * 44)

                Behavior on x {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.screenshot.modes

                    Item {
                        required property string modelData
                        width: 44
                        height: 42

                        Text {
                            anchors.centerIn: parent
                            text: root.screenshot.modeIcons[modelData]
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIcon
                            color: root.screenshot.mode === modelData ? Config.textReverseColor : Config.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.screenshot.setMode(modelData)
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: 24
            color: Config.surface2Color
            anchors.verticalCenter: parent.verticalCenter
        }

        // Action buttons
        Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            // Confirm button
            Item {
                width: root.screenshot.hasSelection ? 44 : 0
                height: 42
                visible: root.screenshot.hasSelection
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: width / 2
                    color: confirmArea.containsMouse ? Config.surface2Color : Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: confirmArea.containsMouse ? Config.textColor : Config.successColor
                    }

                    MouseArea {
                        id: confirmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.screenshot.confirmSelection()
                    }
                }
            }

            // Edit button
            Item {
                width: root.screenshot.hasSelection ? 44 : 0
                height: 42
                visible: root.screenshot.hasSelection
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: width / 2
                    color: editArea.containsMouse ? Config.surface2Color : Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: editArea.containsMouse ? Config.textColor : Config.warningColor
                    }

                    MouseArea {
                        id: editArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.screenshot.editSelection()
                    }
                }
            }

            // Reset button
            Item {
                width: (root.screenshot.hasSelection && root.screenshot.mode !== "screen") ? 44 : 0
                height: 42
                visible: root.screenshot.hasSelection && root.screenshot.mode !== "screen"
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: width / 2
                    color: resetArea.containsMouse ? Config.surface2Color : Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: resetArea.containsMouse ? Config.textColor : Config.errorColor
                    }

                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.screenshot.resetSelection()
                    }
                }
            }

            // Separator before cancel
            Rectangle {
                width: root.screenshot.hasSelection ? 1 : 0
                height: 24
                color: Config.surface2Color
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }

            // Cancel button
            Item {
                width: 44
                height: 42

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: cancelArea.containsMouse ? Config.errorColor : Config.subtextColor
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.screenshot.cancelCapture()
                }
            }
        }
    }
}
