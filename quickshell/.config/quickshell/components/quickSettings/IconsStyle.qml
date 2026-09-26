pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A glyph per shown indicator; the unread count sits on the bell
RowLayout {
    id: root

    required property QsIndicatorsModel model
    // Tone "normal" (the button tints it while Quick Settings is open)
    property color iconColor: Config.textColor

    function toneColor(tone: string): color {
        switch (tone) {
        case "success":
            return Config.successColor;
        case "warning":
            return Config.warningColor;
        case "error":
            return Config.errorColor;
        default:
            return iconColor;
        }
    }

    spacing: Config.spacing

    Repeater {
        model: root.model.order

        Text {
            id: glyph

            required property string modelData
            readonly property var indicator: root.model.indicators[modelData]

            visible: indicator.shown
            text: indicator.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: root.toneColor(indicator.tone)
            Layout.alignment: Qt.AlignVCenter

            // Sits on the bell's top-right corner without taking layout space
            Rectangle {
                readonly property int textSize: Math.round(Config.fontSizeSmall * 0.7)

                visible: glyph.modelData === "notifications" && !glyph.indicator.dnd
                anchors.horizontalCenter: parent.right
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: Math.round(Config.padding / 2)
                height: textSize + Math.round(Config.padding * 2 / 3)
                width: Math.max(height, badgeText.implicitWidth + Config.padding)
                radius: height / 2
                color: Config.errorColor

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: (glyph.indicator.count ?? 0) > 99 ? "99+" : (glyph.indicator.count ?? 0)
                    font.family: Config.font
                    font.pixelSize: parent.textSize
                    font.bold: true
                    color: Config.textColor
                }
            }
        }
    }
}
