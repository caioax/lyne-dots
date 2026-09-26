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

    spacing: Config.spacing

    Repeater {
        model: root.model.order

        RowLayout {
            id: slot

            required property string modelData
            readonly property var indicator: root.model.indicators[modelData]
            readonly property bool withPercent: modelData === "battery" && root.model.batteryPercent

            visible: indicator.shown
            spacing: Math.round(Config.spacing / 3)

            IndicatorGlyph {
                model: root.model
                indicatorId: slot.modelData
                iconColor: root.iconColor
            }

            Text {
                visible: slot.withPercent
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
