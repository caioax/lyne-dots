pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// OSD capsule: icon badge, level bar and percentage
Rectangle {
    id: root

    property real value: 0
    property bool muted: false
    property string icon: ""

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor

    implicitWidth: Config.fontSizeNormal * 20
    implicitHeight: Config.fontSizeIcon + Config.padding * 4
    radius: height / 2
    color: Config.backgroundTransparentColor
    border.width: 1
    border.color: Config.surface2Color

    TextMetrics {
        id: percentMetrics
        font: percent.font
        text: "100%"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding
        anchors.rightMargin: Config.padding * 3
        spacing: Config.spacing * 1.5

        // Icon badge, concentric with the capsule
        Rectangle {
            Layout.preferredWidth: root.height - Config.padding * 2
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

        // Level bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Config.padding
            radius: height / 2
            color: Config.surface1Color

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, root.value))
                radius: parent.radius
                color: root.tone

                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDurationShort
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }
        }

        Text {
            id: percent

            Layout.preferredWidth: percentMetrics.advanceWidth
            text: Math.round(root.value * 100) + "%"
            horizontalAlignment: Text.AlignRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.weight: Font.DemiBold
            color: root.muted ? Config.mutedColor : Config.textColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }
    }
}
