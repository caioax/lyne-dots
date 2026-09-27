pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../"

// OSD that slides out of the bar (or a screen edge) like the attached
// panels: flush with `edge`, fillets flowing into it. Animates itself
Item {
    id: root

    property real value: 0
    property bool muted: false
    property string icon: ""
    // "top" | "bottom"
    property string edge: "top"
    property bool shown: false

    readonly property color tone: muted ? Config.mutedColor : Config.accentColor

    // Room on both sides for the fillets
    implicitWidth: Config.fontSizeNormal * 18 + Config.radiusLarge * 2
    implicitHeight: Config.fontSizeIcon + Config.padding * 3

    TextMetrics {
        id: percentMetrics
        font: percent.font
        text: "100%"
    }

    AttachedPanel {
        x: Config.radiusLarge
        width: parent.width - Config.radiusLarge * 2
        height: parent.height
        edges: [root.edge]
        shown: root.shown

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Config.padding * 3
            anchors.rightMargin: Config.padding * 3
            spacing: Config.spacing * 1.5

            Text {
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

            LevelBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.padding
                value: root.value
                tone: root.tone
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
}
