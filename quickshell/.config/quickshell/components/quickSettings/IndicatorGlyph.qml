pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// One indicator as a glyph. Put it in an IndicatorSlot, which shows and
// hides it
Text {
    id: root

    required property QsIndicatorsModel model
    required property string indicatorId
    // Tone "normal"
    property color iconColor: Config.textColor

    readonly property var indicator: model.indicators[indicatorId]

    text: indicator.icon
    font.family: Config.font
    font.pixelSize: Config.fontSizeNormal
    font.bold: true
    color: model.toneColor(indicator.tone, iconColor)
    Layout.alignment: Qt.AlignVCenter

}
