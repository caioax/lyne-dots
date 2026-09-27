pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../"

// Square OSD card: a ring around the icon, the percentage and what it is
Rectangle {
    id: root

    property real value: 0
    property bool muted: false
    property string icon: ""
    property string label: ""

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor

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
            value: root.value * 100
            strokeWidth: Config.padding
            color: root.tone
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
            color: root.muted ? Config.mutedColor : Config.textColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
