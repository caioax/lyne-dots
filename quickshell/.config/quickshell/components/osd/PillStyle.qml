pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// OSD capsule: icon badge, level bar and percentage
Rectangle {
    id: root

    property real value: 0
    // Level at the end of the scale (above 1: volume boost)
    property real max: 1
    property bool muted: false
    property string icon: ""
    // Line above the level bar (device name), "" for none
    property string caption: ""

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor
    readonly property bool boosted: value > 1.005
    readonly property color textTone: muted ? Config.mutedColor : boosted ? Config.warningColor : Config.textColor

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
                enabled: !Config.themeTransitioning
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
                    enabled: !Config.themeTransitioning
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.padding / 2

            Text {
                Layout.fillWidth: true
                visible: root.caption !== ""
                text: root.caption
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }

            LevelBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.padding
                value: root.value
                max: root.max
                tone: root.tone
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
            color: root.textTone

            Behavior on color {
                enabled: !Config.themeTransitioning
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }
    }
}
