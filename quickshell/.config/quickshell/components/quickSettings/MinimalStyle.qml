pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// One icon for all of Quick Settings; a dot on its corner when something
// needs a glance (unread notifications, low battery, no network, a
// microphone in use...), colored by the worst of them
Item {
    id: root

    required property QsIndicatorsModel model
    // Icon color (the button tints it while Quick Settings is open)
    property color iconColor: Config.textColor

    readonly property string tone: model.summaryTone

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.centerIn: parent
        text: "󱕃"
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true
        color: root.iconColor
    }

    Rectangle {
        readonly property int size: Math.round(Config.fontSizeSmall * 0.75)

        anchors.horizontalCenter: icon.right
        anchors.verticalCenter: icon.top
        anchors.verticalCenterOffset: Math.round(Config.padding / 3)
        width: size
        height: size
        radius: size / 2
        // Ring in the bar color keeps it apart from the icon
        border.width: Math.max(1, Math.round(size / 5))
        border.color: Config.backgroundColor
        color: root.model.toneColor(root.tone || "error", root.iconColor)
        scale: root.tone ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
            }
        }
    }
}
