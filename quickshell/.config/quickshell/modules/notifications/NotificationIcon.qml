pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// Notification image (avatar, album art...) with the app icon as a badge,
// or just the app icon when there is no image
Item {
    id: root

    required property var notif
    property int size: Config.notifImageSize

    readonly property string imageSource: NotificationService.iconSource(notif.image)
    readonly property string appIconSource: NotificationService.iconSource(notif.appIcon)
    readonly property bool hasImage: imageSource !== "" && image.status !== Image.Error
    readonly property color tint: notif.isCritical ? Config.errorColor : Config.accentColor

    implicitWidth: size
    implicitHeight: size

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(root.tint, 0.15)

        Image {
            id: image
            anchors.fill: parent
            visible: root.hasImage
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            asynchronous: true
            mipmap: true
        }

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            visible: !root.hasImage && root.appIconSource !== "" && status !== Image.Error
            implicitSize: Math.round(root.size * 0.6)
            source: root.hasImage ? "" : root.appIconSource
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasImage && !appIcon.visible
            text: root.notif.isCritical ? "󰀪" : "󰂚"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIcon
            color: root.tint
        }
    }

    // App badge over the image
    Rectangle {
        visible: root.hasImage && root.appIconSource !== "" && badgeIcon.status !== Image.Error
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: -Math.round(Config.padding / 3)
        width: Math.round(root.size * 0.45)
        height: width
        radius: width / 2
        color: Config.surface1Color

        IconImage {
            id: badgeIcon
            anchors.centerIn: parent
            implicitSize: Math.round(parent.width * 0.7)
            source: root.hasImage ? root.appIconSource : ""
        }
    }
}
