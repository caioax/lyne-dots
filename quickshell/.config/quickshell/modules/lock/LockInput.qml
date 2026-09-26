pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Password pill: a dot per typed character (from LockService.buffer, typed
// into the surface's hidden input) followed by a blinking caret, a spinner
// while PAM checks, a shake on failure, and the Caps Lock / error line
// below. The arrow submits
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
        // Accent while ready: typing goes here without clicking
        border.color: LockService.failed ? Config.errorColor : Qt.alpha(Config.accentColor, LockService.buffer !== "" ? 0.8 : 0.45)

        transform: Translate {
            x: field.shakeX
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        // The dots: a fixed row where only the one just typed pops (a
        // Repeater over the length rebuilt every dot on each key). Past
        // what fits, the last dot pops again for each new character
        Row {
            id: dots

            readonly property real dotSize: Config.fontSizeSmall * 0.8
            readonly property int capacity: Math.max(1, Math.floor((width - Config.spacing + spacing) / (dotSize + spacing)))
            readonly property int shownCount: Math.min(LockService.buffer.length, capacity)

            anchors.left: parent.left
            anchors.right: submit.left
            anchors.leftMargin: field.height / 2
            anchors.rightMargin: Config.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Config.padding

            property int lastLength: 0

            Connections {
                target: LockService

                function onBufferChanged() {
                    const length = LockService.buffer.length;
                    if (length > dots.lastLength && length > 0) {
                        const dot = dotRepeater.itemAt(dots.shownCount - 1);
                        if (dot)
                            dot.pop();
                    }
                    dots.lastLength = length;
                }
            }

            Repeater {
                id: dotRepeater

                model: dots.capacity

                Rectangle {
                    id: dot

                    required property int index

                    function pop() {
                        popAnim.restart();
                    }

                    visible: index < dots.shownCount
                    width: dots.dotSize
                    height: width
                    radius: width / 2
                    color: Config.textColor

                    SequentialAnimation {
                        id: popAnim

                        NumberAnimation {
                            target: dot
                            property: "scale"
                            from: 0.4
                            to: 1.25
                            duration: Config.animDurationShort
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: dot
                            property: "scale"
                            to: 1
                            duration: Config.animDurationShort
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
            }

            // Blinking caret after the dots: the field is always taking input
            Rectangle {
                visible: !LockService.authenticating
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, Config.padding / 3)
                height: Config.fontSizeNormal * 1.3
                radius: width / 2
                color: Config.accentColor

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: true

                    NumberAnimation {
                        to: 1
                        duration: 0
                    }
                    PauseAnimation {
                        duration: Config.animDurationLong + Config.animDuration
                    }
                    NumberAnimation {
                        to: 0
                        duration: Config.animDuration
                    }
                    PauseAnimation {
                        duration: Config.animDurationLong
                    }
                }
            }

            Text {
                visible: LockService.buffer === ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Config.padding
                text: LockService.authenticating ? "Checking…" : "Type your password"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: LockService.authenticating ? Config.accentColor : Config.mutedColor
            }
        }

        // Clicking the field doesn't need to do anything (it's always
        // focused), so it answers with a glow and puts the keyboard back
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: {
                glow.restart();
                LockService.focusRequested();
            }
        }

        Rectangle {
            id: glowRing

            anchors.fill: parent
            anchors.margins: -Config.padding / 2
            radius: height / 2
            color: Qt.alpha(Config.accentColor, 0)
            border.width: Config.padding / 2
            border.color: Config.accentColor
            opacity: 0

            NumberAnimation {
                id: glow

                target: glowRing
                property: "opacity"
                from: 0.6
                to: 0
                duration: Config.animDurationLong
                easing.type: Easing.OutCubic
            }
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
