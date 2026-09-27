pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// OSD capsule standing on a screen side: percentage on top, a level bar
// that fills upwards and the icon badge at the bottom
Rectangle {
    id: root

    property real value: 0
    // Level at the end of the scale (above 1: volume boost)
    property real max: 1
    property bool muted: false
    property string icon: ""

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor
    readonly property bool boosted: value > 1.005
    readonly property color textTone: muted ? Config.mutedColor : boosted ? Config.warningColor : Config.textColor

    implicitWidth: Config.fontSizeIcon + Config.padding * 4
    implicitHeight: Config.fontSizeNormal * 14
    radius: width / 2
    color: Config.backgroundTransparentColor
    border.width: 1
    border.color: Config.surface2Color

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Config.padding * 3
        anchors.bottomMargin: Config.padding
        spacing: Config.spacing * 1.5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(root.value * 100)
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.weight: Font.DemiBold
            color: root.textTone

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        LevelBar {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.preferredWidth: Config.padding
            vertical: true
            value: root.value
            max: root.max
            tone: root.tone
        }

        // Icon badge, concentric with the capsule
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.width - Config.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: Qt.alpha(root.tone, 0.15)

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: root.tone

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }
        }
    }
}
