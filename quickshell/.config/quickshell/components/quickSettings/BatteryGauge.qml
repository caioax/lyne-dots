pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Battery drawn as an outline with a level bar and a terminal nub; a bolt
// over it while charging
Item {
    id: root

    property int percentage: 100
    property bool charging: false
    // Outline and nub
    property color frameColor: Config.textColor
    // Level bar
    property color fillColor: Config.textColor

    readonly property int bodyHeight: Math.round(Config.fontSizeNormal * 0.75)
    readonly property int bodyWidth: Math.round(bodyHeight * 1.9)
    readonly property int nubWidth: Math.max(2, Math.round(bodyHeight / 6))
    readonly property int stroke: Math.max(1, Math.round(bodyHeight / 8))

    implicitWidth: bodyWidth + nubWidth
    implicitHeight: bodyHeight

    Rectangle {
        id: body
        width: root.bodyWidth
        height: root.bodyHeight
        radius: Math.round(root.bodyHeight / 4)
        color: Qt.alpha(root.frameColor, 0)
        border.width: root.stroke
        border.color: root.frameColor

        Rectangle {
            readonly property int inset: root.stroke * 2
            readonly property real level: Math.max(0, Math.min(100, root.percentage)) / 100

            x: inset
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - inset * 2
            // Never fully empty, so a dying battery still shows a sliver
            width: Math.max(root.stroke, Math.round((parent.width - inset * 2) * level))
            radius: Math.max(0, body.radius - inset)
            color: root.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: Config.animDuration
                }
            }
        }

        Text {
            visible: root.charging
            anchors.centerIn: parent
            text: "󱐋"
            font.family: Config.font
            font.pixelSize: Math.round(root.bodyHeight * 1.1)
            color: root.frameColor
            style: Text.Outline
            styleColor: Config.backgroundColor
        }
    }

    Rectangle {
        anchors.left: body.right
        anchors.verticalCenter: body.verticalCenter
        width: root.nubWidth
        height: Math.round(root.bodyHeight / 2)
        radius: width / 2
        color: root.frameColor
    }
}
