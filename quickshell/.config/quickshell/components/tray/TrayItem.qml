pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// One tray icon: left click activates the item, right click asks the model
// for its context menu
Rectangle {
    id: root

    required property var model
    required property var item

    // Emitted after a left click, so the owner can close an open menu
    signal activated

    implicitWidth: Config.barButtonHeight
    implicitHeight: Config.barButtonHeight
    radius: width / 2
    color: mouseArea.containsMouse ? Config.surface1Color : "transparent"

    // Primary icon (theme name, file path, or pixmap URL)
    Image {
        id: icon
        anchors.centerIn: parent
        width: Config.fontSizeIconSmall
        height: Config.fontSizeIconSmall
        source: root.model.iconSource(root.item)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize: Qt.size(Config.fontSizeIconSmall * 2, Config.fontSizeIconSmall * 2)
        smooth: true
        visible: status === Image.Ready
    }

    // Fallback when the primary icon fails (e.g. pixmap-based icons from nm-applet)
    Image {
        anchors.centerIn: parent
        width: Config.fontSizeIconSmall
        height: Config.fontSizeIconSmall
        source: "image://icon/application-default-icon"
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Config.fontSizeIconSmall * 2, Config.fontSizeIconSmall * 2)
        smooth: true
        visible: icon.status === Image.Error
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
            } else {
                root.model.openMenu(root.item, root);
            }
        }
    }
}
