pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A glyph per shown indicator, the battery percentage after its glyph
RowLayout {
    id: root

    required property QsIndicatorsModel model
    // Tone "normal" (the button tints it while Quick Settings is open)
    property color iconColor: Config.textColor

    // The slots carry the gaps
    spacing: 0

    Repeater {
        model: root.model.order

        IndicatorSlot {
            id: slot

            required property string modelData
            readonly property var indicator: root.model.indicators[modelData]

            model: root.model
            indicatorId: modelData

            RowLayout {
                spacing: Math.round(Config.spacing / 3)

                IndicatorGlyph {
                    model: root.model
                    indicatorId: slot.modelData
                    iconColor: root.iconColor
                }

                Text {
                    visible: slot.modelData === "battery" && root.model.batteryPercent
                    text: (slot.indicator.percentage ?? 0) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: root.model.toneColor(slot.indicator.tone, root.iconColor)
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
