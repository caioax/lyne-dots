import QtQuick
import qs.config

// Round ⋮ button that opens an item's menu
Rectangle {
    id: root

    readonly property bool hovered: mouse.containsMouse

    signal clicked

    implicitWidth: Config.fontSizeIconSmall + Config.padding * 2
    implicitHeight: implicitWidth
    radius: width / 2
    color: hovered ? Config.surface2Color : "transparent"

    Text {
        anchors.centerIn: parent
        text: "\u{f142}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: root.hovered ? Config.textColor : Config.subtextColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
