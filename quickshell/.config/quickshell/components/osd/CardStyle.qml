pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../"

// Square OSD card: a ring around the icon, the percentage and what it is
Rectangle {
    id: root

    property real value: 0
    // Level at the end of the scale (above 1: volume boost)
    property real max: 1
    property bool muted: false
    property string icon: ""
    property string label: ""

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor
    readonly property bool boosted: value > 1.005
    readonly property color textTone: muted ? Config.mutedColor : boosted ? Config.warningColor : Config.textColor

    implicitWidth: Config.fontSizeNormal * 10
    implicitHeight: implicitWidth
    radius: Config.radiusLarge
    color: Config.backgroundTransparentColor
    border.width: 1
    border.color: Config.surface2Color

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Config.padding

        ProgressRing {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Config.fontSizeIconLarge * 2.5
            Layout.preferredHeight: Layout.preferredWidth
            value: root.value / root.max * 100
            strokeWidth: Config.padding
            color: root.boosted && !root.muted ? Config.warningColor : root.tone
            trackColor: Config.surface1Color

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconLarge
                color: root.tone

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(root.value * 100) + "%"
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.weight: Font.DemiBold
            color: root.textTone

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width - Config.padding * 4
            text: root.label
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
