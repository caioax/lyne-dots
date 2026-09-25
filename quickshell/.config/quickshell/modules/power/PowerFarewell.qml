pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Template "farewell": no panel, a big avatar and greeting in the middle of
// the dimmed screen with round buttons below. Rises into place when shown
ColumnLayout {
    id: root

    property bool shown: false

    spacing: Config.spacing * 2

    opacity: shown ? 1 : 0
    transform: Translate {
        y: root.shown ? 0 : Config.fontSizeIconLarge * 2

        Behavior on y {
            NumberAnimation {
                duration: root.shown ? Config.animDurationLong : Config.animDuration
                easing.type: Config.animPopupEasing
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Config.animDurationLong : Config.animDuration
            easing.type: Config.animPopupEasing
        }
    }

    PowerAvatar {
        Layout.alignment: Qt.AlignHCenter
        size: Config.fontSizeIconLarge * 4
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Config.padding

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "See you, " + PowerService.user
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                const parts = [TimeService.format("dddd, d MMM · HH:mm"), "up " + PowerService.uptime];
                if (BatteryService.hasBattery)
                    parts.push(BatteryService.percentage + "%" + (BatteryService.isCharging ? " charging" : ""));
                return parts.join("  ·  ");
            }
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }

    InhibitorNote {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Config.fontSizeNormal * 40
    }

    Item {
        implicitHeight: Config.spacing
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Config.spacing * 3

        Repeater {
            model: PowerService.actions

            PowerButton {
                required property var modelData

                action: modelData
                variant: "round"
            }
        }
    }

    Item {
        implicitHeight: Config.spacing
    }

    PowerStatus {
        Layout.alignment: Qt.AlignHCenter
    }
}
