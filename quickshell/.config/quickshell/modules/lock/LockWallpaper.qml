pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../power/"

// Template "wallpaper": the wallpaper stays sharp with the clock in the top
// left corner; typing raises the password bar from the bottom and blurs
// the background (`typing`, read by LockScreen)
Item {
    id: root

    property bool shown: false

    readonly property bool typing: LockService.buffer !== "" || LockService.authenticating || LockService.failed || PowerService.pendingId !== ""

    opacity: shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    LockClock {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Config.spacing * 6
        alignment: Qt.AlignLeft
        size: Config.fontSizeIconLarge * 4.5
    }

    LockStatus {
        visible: LockService.showStatus
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Config.spacing * 6
    }

    // Hint while idle
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.spacing * 6
        implicitWidth: hint.implicitWidth + Config.padding * 6
        implicitHeight: Config.fontSizeNormal * 2.4
        radius: height / 2
        color: Config.cardColor
        opacity: root.typing ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Text {
            id: hint

            anchors.centerIn: parent
            text: "\u{f030c}  Type your password to unlock"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.textColor
        }
    }

    // Password bar: rises from below the edge while typing
    Rectangle {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.typing ? parent.height - height - Config.spacing * 6 : parent.height
        width: barRow.implicitWidth + Config.padding * 8
        height: barRow.implicitHeight + Config.padding * 6
        radius: Config.radiusLarge * 1.5
        color: Config.backgroundTransparentColor
        opacity: root.typing ? 1 : 0

        Behavior on y {
            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Config.animPopupEasing
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        RowLayout {
            id: barRow

            anchors.centerIn: parent
            spacing: Config.spacing * 2

            PowerAvatar {
                Layout.alignment: Qt.AlignTop
                size: Config.fontSizeNormal * 3.4
            }

            LockInput {}

            LockPower {
                visible: LockService.showPower
                Layout.alignment: Qt.AlignTop
            }
        }
    }

    LockPlayer {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Config.spacing * 6
    }

    // Power buttons stay reachable in the corner while idle
    LockPower {
        visible: LockService.showPower && !root.typing
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Config.spacing * 6
    }
}
