pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/"

// The launcher button over the current wallpaper with the real style, in its
// hover state (the only state where "logo" and "compact" differ), followed by
// a few workspace pills for scale. Follows the icon setting.
ClippingRectangle {
    id: root

    // Launcher button style: "logo", "pill" or "compact"
    property string value

    radius: Config.radius
    color: Config.surface2Color

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // Below the selected tile's check (TemplateTile: padding inside the tile,
    // fontSizeLarge + padding tall) plus a small gap
    readonly property int checkClearance: Config.padding * 2 + Config.fontSizeLarge + Math.round(Config.padding / 2)

    // Bar piece at its real size, scaled down to fit the tile if needed
    Rectangle {
        id: bar

        readonly property real fit: Math.min(1, (root.width - Config.spacing * 2) / width, (root.height - root.checkClearance - Config.spacing) / height)

        anchors.horizontalCenter: parent.horizontalCenter
        // Scaling keeps the center, so the drawn top sits lower than y
        y: Math.max((root.height - height) / 2, root.checkClearance - height * (1 - fit) / 2)
        width: row.implicitWidth + Config.padding * 2
        height: Config.barIslandHeight
        radius: height / 2
        color: Config.backgroundColor
        scale: fit

        Row {
            id: row

            anchors.left: parent.left
            anchors.leftMargin: Config.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Config.padding

            LauncherButton {
                live: false
                showLit: true
                style: root.value
            }

            // Workspace pills like the default style: the active one wide
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(Config.padding / 2)

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        readonly property int size: Config.barButtonHeight - Config.padding

                        width: index === 0 ? size * 2 : size
                        height: size
                        radius: size / 2
                        color: index === 0 ? Config.accentColor : Config.surface1Color
                    }
                }
            }
        }
    }
}
