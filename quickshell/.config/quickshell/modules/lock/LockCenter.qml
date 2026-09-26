pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../power/"

// Template "center": big clock, avatar and the password in the middle; the
// status pills bottom left and the power buttons bottom right
Item {
    id: root

    property bool shown: false

    opacity: shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.shown ? -Config.fontSizeIconLarge : 0
        spacing: Config.spacing * 2

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Config.animPopupEasing
            }
        }

        LockClock {
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            implicitHeight: Config.spacing * 2
        }

        PowerAvatar {
            Layout.alignment: Qt.AlignHCenter
            size: Config.fontSizeIconLarge * 3
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: PowerService.user
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        LockInput {
            Layout.alignment: Qt.AlignHCenter
        }
    }

    LockStatus {
        visible: LockService.showStatus
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Config.spacing * 4
    }

    LockPower {
        visible: LockService.showPower
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Config.spacing * 4
    }
}
