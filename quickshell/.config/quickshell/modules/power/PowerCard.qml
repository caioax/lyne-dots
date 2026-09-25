pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Template "card": centered panel with who/uptime on top, a row of tiles
// and the key hints
Rectangle {
    id: root

    property bool shown: false

    implicitWidth: content.implicitWidth + Config.padding * 6
    implicitHeight: content.implicitHeight + Config.padding * 6
    radius: Config.radiusLarge
    color: Config.backgroundTransparentColor
    border.width: 1
    border.color: Config.surface2Color

    opacity: shown ? 1 : 0
    scale: shown ? 1 : Config.animPopupFromScale

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Config.animDurationLong : Config.animDuration
            easing.type: Config.animPopupEasing
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? Config.animDurationLong : Config.animDuration
            easing.type: Config.animPopupEasing
        }
    }

    // Swallows clicks so they don't reach the backdrop (which closes)
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Config.spacing * 2

        // ========== WHO ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing + Config.padding

            PowerAvatar {}

            ColumnLayout {
                spacing: 0

                Text {
                    text: PowerService.user + (PowerService.host !== "" ? "@" + PowerService.host : "")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    text: TimeService.format("dddd, d MMM · HH:mm")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StatChip {
                icon: "\u{f0150}"
                text: "up " + PowerService.uptime
            }

            StatChip {
                visible: BatteryService.hasBattery
                icon: BatteryService.isCharging ? "\u{f0084}" : "\u{f0079}"
                text: BatteryService.percentage + "%"
                accent: BatteryService.percentage <= 20 && !BatteryService.isCharging ? Config.errorColor : Config.subtextColor
            }
        }

        InhibitorNote {
            Layout.fillWidth: true
        }

        // ========== ACTIONS ==========
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Config.spacing

            Repeater {
                model: PowerService.actions

                PowerButton {
                    required property var modelData

                    action: modelData
                    variant: "tile"
                }
            }
        }

        PowerStatus {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
