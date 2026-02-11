pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color baseColor: Config.surface1Color
    property color hoverColor: Config.surface2Color
    property color textColor: Config.textColor
    property color hoverTextColor: root.textColor
    property int size: 36
    property int iconSize: Config.fontSizeIconSmall

    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed

    signal clicked

    implicitHeight: size
    implicitWidth: root.text !== "" ? contentRow.implicitWidth + 16 : size
    Layout.preferredHeight: size
    Layout.preferredWidth: implicitWidth
    radius: Config.radius

    color: mouseArea.containsMouse ? root.hoverColor : root.baseColor

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Behavior on textColor {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Config.font
            font.pixelSize: root.iconSize
            color: mouseArea.containsMouse ? root.hoverTextColor : root.textColor
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: mouseArea.containsMouse ? root.hoverTextColor : root.textColor
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
