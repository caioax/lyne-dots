pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Each shown indicator in a small round chip tinted with its tone
RowLayout {
    id: root

    required property QsIndicatorsModel model
    // Tone "normal" (the button tints it while Quick Settings is open)
    property color iconColor: Config.textColor

    spacing: Math.round(Config.spacing / 2)

    Repeater {
        model: root.model.order

        Rectangle {
            id: chip

            required property string modelData
            readonly property var indicator: root.model.indicators[modelData]
            readonly property color toneColor: root.model.toneColor(indicator.tone, root.iconColor)
            readonly property bool withPercent: modelData === "battery" && root.model.batteryPercent

            visible: indicator.shown
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: Config.barButtonHeight - Config.padding
            implicitWidth: Math.max(implicitHeight, content.implicitWidth + Config.padding * 2)
            radius: height / 2
            color: Qt.alpha(toneColor, indicator.tone === "normal" ? 0.1 : 0.16)

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: Math.round(Config.spacing / 3)

                IndicatorGlyph {
                    model: root.model
                    indicatorId: chip.modelData
                    iconColor: root.iconColor
                    font.pixelSize: Config.fontSizeSmall
                }

                Text {
                    visible: chip.withPercent
                    text: (chip.indicator.percentage ?? 0) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: chip.toneColor
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
