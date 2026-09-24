pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Preset theme card: wallpaper thumbnail, name and palette. Click applies it
Item {
    id: tile

    required property string modelData
    // Height of the wallpaper thumbnail
    property real thumbHeight: Config.fontSizeIconLarge * 2 + Config.spacing * 2
    // Only load the thumbnail while it can be seen
    property bool loadImage: true

    readonly property bool auto: ThemeService.isAutoMode
    readonly property var preview: ThemeService.themePreviews[modelData] ?? {}
    readonly property var palette: preview.palette ?? {}
    readonly property bool isCurrent: !auto && modelData === ThemeService.currentThemeName

    Layout.fillWidth: true
    implicitHeight: tile.thumbHeight + footer.implicitHeight + Config.padding * 2
    opacity: tile.auto && !tileMouse.containsMouse ? 0.55 : 1
    scale: tileMouse.pressed ? 0.97 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: tileMouse.containsMouse ? Config.surface2Color : Config.surface1Color

        Image {
            width: parent.width
            height: tile.thumbHeight
            // Only loaded while the page is open
            source: tile.loadImage && tile.preview.wallpaper ? "file://" + ThemeService.wallpaperDir + "/" + tile.preview.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
        }

        RowLayout {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Config.padding + Config.padding / 2
            spacing: Config.padding

            Text {
                Layout.fillWidth: true
                text: tile.preview.name ?? tile.modelData
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: tile.isCurrent
                color: tile.isCurrent ? Config.accentColor : Config.textColor
                elide: Text.ElideRight
            }

            PaletteDots {
                colors: [tile.palette.accent, tile.palette.success, tile.palette.warning, tile.palette.error]
            }
        }
    }

    // Selection outline and check, above the clipped content
    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: "transparent"
        border.width: tile.isCurrent ? 2 : 0
        border.color: Config.accentColor
    }

    Rectangle {
        visible: tile.isCurrent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Config.padding
        width: Config.fontSizeLarge + Config.padding
        height: width
        radius: width / 2
        color: Config.accentColor

        Text {
            anchors.centerIn: parent
            text: "󰄬"
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
        cursorShape: tile.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!tile.isCurrent)
                ThemeService.setPresetMode(tile.modelData);
        }
    }
}
