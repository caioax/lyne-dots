pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Rectangle {
    id: root

    required property var screenshot

    // A round button and the room around it
    readonly property int buttonSize: Config.fontSizeIcon + Config.padding * 2
    readonly property int cellSize: buttonSize + Config.spacing

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Config.spacing * 5

    height: cellSize + Config.padding
    width: barContent.implicitWidth + Config.spacing * 2
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

    // Round action button that folds away while `shown` is false
    component ActionButton: Item {
        id: action

        property bool shown: true
        property string icon
        property color iconColor
        signal clicked

        width: shown ? root.cellSize : 0
        height: root.cellSize
        visible: width > 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.buttonSize
            height: root.buttonSize
            radius: width / 2
            color: actionArea.containsMouse ? Config.surface2Color : Config.surface1Color

            Text {
                anchors.centerIn: parent
                text: action.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: actionArea.containsMouse ? Config.textColor : action.iconColor
            }

            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: action.clicked()
            }
        }
    }

    component Separator: Rectangle {
        width: 1
        height: root.buttonSize * 2 / 3
        color: Config.surface2Color
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: barContent
        anchors.centerIn: parent
        spacing: 0

        // Mode selector
        Item {
            width: root.cellSize * root.screenshot.modes.length
            height: root.cellSize

            // Sliding highlight
            Rectangle {
                width: root.buttonSize
                height: root.buttonSize
                y: (parent.height - height) / 2
                radius: height / 2
                color: Config.accentColor
                x: (root.cellSize - root.buttonSize) / 2 + root.screenshot.modes.indexOf(root.screenshot.mode) * root.cellSize

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
                        id: modeItem

                        required property string modelData

                        width: root.cellSize
                        height: root.cellSize

                        Text {
                            anchors.centerIn: parent
                            text: root.screenshot.modeIcons[modeItem.modelData]
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIcon
                            color: root.screenshot.mode === modeItem.modelData ? Config.textReverseColor : Config.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.screenshot.setMode(modeItem.modelData)
                        }
                    }
                }
            }
        }

        Separator {}

        // Action buttons
        Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            ActionButton {
                shown: root.screenshot.hasSelection
                icon: "\u{f012c}"
                iconColor: Config.successColor
                onClicked: root.screenshot.confirmSelection()
            }

            ActionButton {
                shown: root.screenshot.hasSelection
                icon: "\u{f03eb}"
                iconColor: Config.warningColor
                onClicked: root.screenshot.editSelection()
            }

            ActionButton {
                shown: root.screenshot.hasSelection && root.screenshot.mode !== "screen"
                icon: "\u{f054c}"
                iconColor: Config.errorColor
                onClicked: root.screenshot.resetSelection()
            }

            Separator {
                width: root.screenshot.hasSelection ? 1 : 0

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }

            // Cancel
            Item {
                width: root.cellSize
                height: root.cellSize

                Text {
                    anchors.centerIn: parent
                    text: "\u{f0156}"
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
