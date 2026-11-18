import QtQuick
import qs.config

// Round ⋮ button that opens an item's menu, or another glyph for a direct
// action (danger tints it red on hover, for a dismiss or delete)
Rectangle {
    id: root

    // ⋮
    property string icon: "\u{f142}"
    property bool danger: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked

    implicitWidth: Config.fontSizeIconSmall + Config.padding * 2
    implicitHeight: implicitWidth
    radius: width / 2
    color: hovered ? Config.surface2Color : Qt.alpha(Config.surface2Color, 0)

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: root.hovered ? (root.danger ? Config.errorColor : Config.textColor) : Config.subtextColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
