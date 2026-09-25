import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// Profile picture from ProfileService, or the distro logo
ClippingRectangle {
    id: root

    property real size: Config.fontSizeLarge * 3

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: Config.surface1Color

    Image {
        id: image

        anchors.fill: parent
        visible: status === Image.Ready
        source: ProfileService.avatar !== "" ? "file://" + ProfileService.avatar : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        visible: !image.visible
        text: "\u{f08c7}"
        font.family: Config.font
        font.pixelSize: root.size / 2
        color: Config.accentColor
    }
}
