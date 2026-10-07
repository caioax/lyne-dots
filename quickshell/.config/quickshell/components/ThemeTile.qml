pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Preset theme card: wallpaper thumbnail, name and palette. Click applies it;
// with showDetails, a ⋯ button on hover asks for the theme's detail view
Item {
    id: tile

    required property string modelData
    // Height of the wallpaper thumbnail
    property real thumbHeight: Config.fontSizeIconLarge * 2 + Config.spacing * 2
    // Only load the thumbnail while it can be seen
    property bool loadImage: true
    property bool showDetails: false

    signal detailsRequested

    readonly property bool auto: ThemeService.isAutoMode
    readonly property var preview: ThemeService.themePreviews[modelData] ?? {}
    readonly property var themePalette: preview.palette ?? {}
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
                colors: [tile.themePalette.accent, tile.themePalette.success, tile.themePalette.warning, tile.themePalette.error]
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

    // md-dots_horizontal: theme details (wallpapers, colors)
    Rectangle {
        visible: tile.showDetails
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Config.padding
        width: Config.fontSizeLarge + Config.padding * 2
        height: Config.fontSizeLarge + Config.padding
        radius: height / 2
        color: detailsMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.backgroundColor, 0.8)
        opacity: tileMouse.containsMouse || detailsMouse.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: "\u{f01d8}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: detailsMouse.containsMouse ? Config.textReverseColor : Config.textColor
        }

        MouseArea {
            id: detailsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.detailsRequested()
        }
    }
}
