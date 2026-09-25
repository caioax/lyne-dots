pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Small round glyph button (expand, dismiss...)
Rectangle {
    id: root

    required property string icon
    property color iconColor: Config.subtextColor
    readonly property bool hovered: mouseArea.containsMouse
    signal clicked

    implicitWidth: Config.fontSizeNormal + Config.padding
    implicitHeight: implicitWidth
    radius: height / 2
    color: mouseArea.containsMouse ? Config.surface2Color : Qt.alpha(Config.surface2Color, 0)

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: root.iconColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
