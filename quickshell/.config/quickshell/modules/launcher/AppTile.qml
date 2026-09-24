pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// App as a tile: icon over the name. Same signals as AppRow (clicks go out
// as `activated`, ⋮ on hover or right click ask for the menu)
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    readonly property bool hovered: tileHover.hovered
    readonly property int iconSize: Config.fontSizeIconLarge + Config.padding * 2

    signal activated
    signal menuRequested(Item anchor)

    implicitHeight: iconSize + nameText.implicitHeight + Config.padding * 5

    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: root.selected ? Config.surface1Color : root.hovered ? Config.surface0Color : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    HoverHandler {
        id: tileHover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.menuRequested(menuButton);
            else
                root.activated();
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Config.padding * 2
        spacing: Config.padding

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.iconSize
            height: width
            source: "image://icon/" + (root.modelData?.icon || "application-x-executable")
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
        }

        Text {
            id: nameText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.modelData?.name ?? ""
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: root.selected
            color: Config.textColor
        }
    }

    MenuButton {
        id: menuButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Math.round(Config.padding / 2)
        visible: root.hovered
        onClicked: root.menuRequested(menuButton)
    }
}
