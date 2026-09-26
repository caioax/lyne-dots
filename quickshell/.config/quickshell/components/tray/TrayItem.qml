pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// One tray icon: left click activates the item, right click asks the model
// for its context menu
Rectangle {
    id: root

    required property var model
    required property var item

    // Bar size by default; the overflow grid uses bigger, squarer tiles
    property int size: Config.barButtonHeight
    property int iconSize: Config.fontSizeIconSmall
    property bool round: true

    // Emitted after a left click, so the owner can close an open menu
    signal activated
    // Emitted before asking the model for the context menu
    signal menuRequested

    implicitWidth: size
    implicitHeight: size
    radius: round ? width / 2 : Config.radius
    color: mouseArea.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

    Behavior on color {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    // Primary icon (theme name, file path, or pixmap URL)
    Image {
        id: icon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.model.iconSource(root.item)
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        smooth: true
        visible: status === Image.Ready
    }

    // Fallback when the primary icon fails (e.g. pixmap-based icons from nm-applet)
    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: "image://icon/application-default-icon"
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        smooth: true
        visible: icon.status === Image.Error
    }

    // On the icon's corner
    Item {
        anchors.centerIn: parent
        width: root.iconSize + Config.padding / 2
        height: width

        AttentionDot {
            active: root.model.needsAttention(root.item)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.model.activate(root.item);
                root.activated();
            } else if (root.model.hasMenu(root.item)) {
                root.menuRequested();
                root.model.openMenu(root.item, root);
            }
        }
    }
}
