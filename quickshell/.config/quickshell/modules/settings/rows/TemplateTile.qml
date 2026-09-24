pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// One option of a TemplatePicker: a drawn thumbnail (`preview`, which gets
// the option's `value`) with the label below. Click selects it
Item {
    id: tile

    property string label
    property var value
    property bool current: false
    property Component preview
    property real thumbHeight

    signal clicked

    Layout.fillWidth: true
    implicitHeight: tile.thumbHeight + labelText.implicitHeight + Config.padding * 3
    scale: tileMouse.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: tileMouse.containsMouse ? Config.surface2Color : Config.surface1Color

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    Loader {
        x: Config.padding
        y: Config.padding
        width: parent.width - Config.padding * 2
        height: tile.thumbHeight
        sourceComponent: tile.preview
        onLoaded: item.value = Qt.binding(() => tile.value)
    }

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Config.padding
        horizontalAlignment: Text.AlignHCenter
        text: tile.label
        elide: Text.ElideRight
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: tile.current
        color: tile.current ? Config.accentColor : Config.textColor
    }

    // Selection outline and check, like the theme tiles
    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: "transparent"
        border.width: tile.current ? 2 : 0
        border.color: Config.accentColor
    }

    Rectangle {
        visible: tile.current
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Config.padding * 2
        width: Config.fontSizeLarge + Config.padding
        height: width
        radius: width / 2
        color: Config.accentColor

        Text {
            anchors.centerIn: parent
            text: "\u{f012c}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textReverseColor
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.current ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!tile.current)
                tile.clicked();
        }
    }
}
