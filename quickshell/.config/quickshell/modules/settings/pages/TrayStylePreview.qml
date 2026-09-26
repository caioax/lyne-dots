pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/tray/"

// The bar's tray over the current wallpaper with the real tray
// style, drawn from a fixed sample of five items (Spotify and the network
// pinned, mail asking for attention). The drawer is shown open, and the
// overflow and pinned styles with their grid open under the button.
ClippingRectangle {
    id: root

    // Tray style: "row", "drawer", "overflow" or "pinned"
    property string value

    readonly property var styles: ({
            "row": rowStyle,
            "drawer": drawerStyle,
            "overflow": overflowStyle,
            "pinned": pinnedStyle
        })
    // Icons shown in the open grid, if the style has one
    readonly property var gridItems: value === "overflow" ? sample.items : value === "pinned" ? sample.restItems : []

    radius: Config.radius
    color: Config.surface2Color

    TrayModel {
        id: sample
        live: false
        sampleItems: [
            {
                id: "spotify",
                icon: "spotify",
                title: "Spotify",
                status: Status.Active,
                pinned: true
            },
            {
                id: "network",
                icon: "network-wireless",
                title: "Network",
                status: Status.Active,
                pinned: true
            },
            {
                id: "steam",
                icon: "steam",
                title: "Steam",
                status: Status.Active
            },
            {
                id: "volume",
                icon: "audio-volume-high",
                title: "Volume",
                status: Status.Active
            },
            {
                id: "mail",
                icon: "mail-unread",
                title: "Mail",
                status: Status.NeedsAttention
            }
        ]
    }

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // Bar piece and grid at their real size, scaled down to fit the tile and
    // centered in it (clear of the selected tile's check in the corner)
    Item {
        id: scene

        readonly property real fit: Math.min(1, (root.width - Config.spacing * 2) / width, (root.height - Config.spacing * 2) / height)
        // The grid centers under the tray's button (its last item), like the
        // popup; the scene spans both
        readonly property real buttonCenter: barRow.x + tray.x + tray.width - Config.barButtonHeight / 2
        readonly property real gridLeft: grid.visible ? buttonCenter - grid.width / 2 : 0
        readonly property real shift: -Math.min(0, gridLeft)

        anchors.centerIn: parent
        width: Math.max(shift + bar.width, grid.visible ? shift + gridLeft + grid.width : 0)
        height: bar.height + (grid.visible ? Config.spacing + grid.height : 0)
        scale: fit

        Rectangle {
            id: bar

            x: scene.shift
            width: barRow.implicitWidth + Config.padding * 2
            height: Config.barIslandHeight
            radius: height / 2
            color: Config.backgroundColor

            Row {
                id: barRow

                anchors.centerIn: parent
                spacing: Config.padding

                Loader {
                    id: tray
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.styles[root.value] ?? drawerStyle
                }

            }
        }

        // The open popup
        Rectangle {
            id: grid

            readonly property int columns: Math.max(1, Math.min(4, root.gridItems.length))
            readonly property int tileSize: Config.fontSizeIcon + Config.padding * 2
            readonly property int gap: Math.round(Config.padding / 2)
            visible: root.gridItems.length > 0
            x: scene.shift + scene.gridLeft
            y: bar.height + Config.spacing
            width: tiles.width + Config.padding * 2
            height: tiles.height + Config.padding * 2
            radius: Config.radiusLarge
            color: Config.backgroundTransparentColor
            border.width: 1
            border.color: Config.surface2Color

            Grid {
                id: tiles

                anchors.centerIn: parent
                columns: grid.columns
                spacing: grid.gap

                Repeater {
                    model: root.gridItems

                    TrayItem {
                        required property var modelData
                        model: sample
                        item: modelData
                        size: grid.tileSize
                        iconSize: Config.fontSizeIcon
                        round: false
                    }
                }
            }
        }
    }

    Component {
        id: rowStyle
        RowStyle {
            model: sample
        }
    }

    Component {
        id: drawerStyle
        DrawerStyle {
            model: sample
            isOpen: true
        }
    }

    Component {
        id: overflowStyle
        OverflowStyle {
            model: sample
            showOpen: true
        }
    }

    Component {
        id: pinnedStyle
        PinnedStyle {
            model: sample
            showOpen: true
        }
    }
}
