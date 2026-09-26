pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// One indicator as a glyph; the unread count sits on the bell. Put it in an
// IndicatorSlot, which shows and hides it
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

    // Sits on the bell's top-right corner without taking layout space
    Rectangle {
        readonly property int textSize: Math.round(Config.fontSizeSmall * 0.7)

        visible: root.indicatorId === "notifications" && !root.indicator.dnd
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
            text: (root.indicator.count ?? 0) > 99 ? "99+" : (root.indicator.count ?? 0)
            font.family: Config.font
            font.pixelSize: parent.textSize
            font.bold: true
            color: Config.textColor
        }
    }
}
