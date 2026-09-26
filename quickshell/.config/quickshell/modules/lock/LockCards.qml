pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../power/"

// Template "cards": three cards side by side, like the dashboard: the
// weather and status, the clock with the password, and the session with
// the power buttons. The side cards follow the status/power switches
Item {
    id: root

    property bool shown: false

    readonly property var weather: WeatherService.current
    readonly property real sideWidth: Config.fontSizeNormal * 16

    opacity: shown ? 1 : 0
    scale: shown ? 1 : Config.animPopupFromScale

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Config.animPopupEasing
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Config.spacing * 2

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Config.spacing * 2

            // ========== WEATHER + STATUS ==========
            LockCard {
                visible: LockService.showStatus
                Layout.preferredWidth: root.sideWidth

                Text {
                    visible: root.weather !== null
                    text: root.weather ? WeatherService.icon(root.weather.code, root.weather.isDay) : ""
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge * 2
                    color: Config.accentColor
                }

                Text {
                    visible: root.weather !== null
                    text: root.weather ? root.weather.temp + "°" : ""
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge * 1.5
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    visible: root.weather !== null
                    Layout.fillWidth: true
                    text: root.weather ? WeatherService.description(root.weather.code) + " · feels " + root.weather.feelsLike + "°" : ""
                    wrapMode: Text.Wrap
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillHeight: true
                }

                LockStatus {
                    vertical: true
                    showWeather: false
                }
            }

            // ========== CLOCK + PASSWORD ==========
            LockCard {
                LockClock {
                    Layout.alignment: Qt.AlignHCenter
                    size: Config.fontSizeIconLarge * 3.5
                }

                Item {
                    implicitHeight: Config.spacing
                }

                PowerAvatar {
                    Layout.alignment: Qt.AlignHCenter
                    size: Config.fontSizeIconLarge * 2.6
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
                    fieldWidth: Config.fontSizeNormal * 20
                }
            }

            // ========== SESSION + POWER ==========
            LockCard {
                visible: LockService.showPower
                Layout.preferredWidth: root.sideWidth

                Text {
                    text: "Session"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    text: PowerService.user + (PowerService.host !== "" ? "@" + PowerService.host : "")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                Text {
                    text: "up " + PowerService.uptime
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillHeight: true
                }

                LockPower {
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Below the cards while something plays
        LockPlayer {
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Glass card with a column inside; side cards stretch to the middle one
    component LockCard: Rectangle {
        default property alias content: column.data

        Layout.fillHeight: true
        implicitWidth: column.implicitWidth + Config.padding * 8
        implicitHeight: column.implicitHeight + Config.padding * 8
        radius: Config.radiusLarge * 1.5
        color: Config.cardColor
        border.width: 1
        border.color: Qt.alpha(Config.surface2Color, 0.6)

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Config.padding * 4
            spacing: Config.spacing
        }
    }
}
