pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Password pill: a dot per typed character (from LockService.buffer, typed
// into the surface's hidden input), a spinner while PAM checks, a shake on
// failure, and the Caps Lock / error line below. The arrow submits
ColumnLayout {
    id: root

    property real fieldWidth: Config.fontSizeNormal * 22

    spacing: Config.spacing

    Rectangle {
        id: field

        property real shakeX: 0

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: root.fieldWidth
        implicitHeight: Config.fontSizeNormal * 3.4
        radius: height / 2
        color: Config.cardColor
        border.width: 1
        border.color: LockService.failed ? Config.errorColor : LockService.buffer !== "" ? Qt.alpha(Config.accentColor, 0.6) : Config.surface2Color

        transform: Translate {
            x: field.shakeX
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: submit.left
            anchors.leftMargin: field.height / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Config.padding
            clip: true

            Repeater {
                model: LockService.buffer.length

                Rectangle {
                    required property int index

                    width: Config.fontSizeSmall * 0.8
                    height: width
                    radius: width / 2
                    color: Config.textColor
                    scale: 0.4

                    Component.onCompleted: scale = 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: field.height / 2
            anchors.verticalCenter: parent.verticalCenter
            visible: LockService.buffer === ""
            text: LockService.authenticating ? "Checking…" : "Password"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: LockService.authenticating ? Config.accentColor : Config.mutedColor
        }

        // Submit, or the spinner while PAM works
        Rectangle {
            id: submit

            anchors.right: parent.right
            anchors.rightMargin: Config.padding
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - Config.padding * 2
            height: width
            radius: width / 2
            color: LockService.buffer !== "" ? Config.accentColor : submitMouse.containsMouse ? Config.cardHoverColor : Qt.alpha(Config.cardHoverColor, 0)

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !LockService.authenticating
                text: "\u{f0054}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: LockService.buffer !== "" ? Config.textReverseColor : Config.mutedColor
            }

            Spinner {
                anchors.centerIn: parent
                visible: LockService.authenticating
            }

            MouseArea {
                id: submitMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LockService.tryUnlock()
            }
        }

        SequentialAnimation {
            id: shake

            NumberAnimation {
                target: field
                property: "shakeX"
                to: Config.spacing * 1.5
                duration: Config.animDurationShort / 2
            }
            NumberAnimation {
                target: field
                property: "shakeX"
                to: -Config.spacing * 1.2
                duration: Config.animDurationShort / 2
            }
            NumberAnimation {
                target: field
                property: "shakeX"
                to: Config.spacing * 0.8
                duration: Config.animDurationShort / 2
            }
            NumberAnimation {
                target: field
                property: "shakeX"
                to: 0
                duration: Config.animDurationShort / 2
            }
        }

        Connections {
            target: LockService

            function onFailedChanged() {
                if (LockService.failed)
                    shake.start();
            }
        }
    }

    // Caps Lock and the last error
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Config.fontSizeNormal * 1.5
        spacing: Config.spacing * 2

        Text {
            visible: LockService.capsLock
            text: "\u{f0632}  Caps Lock is on"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.warningColor
        }

        Text {
            visible: LockService.failed
            text: LockService.failMessage + (LockService.attempts > 1 ? " (" + LockService.attempts + " attempts)" : "")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.errorColor
        }
    }
}
