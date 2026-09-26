pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/workspaces/"

// A slice of the bar over the current wallpaper with the real workspace
// style, drawn from a fixed sample: five workspaces, the third active, 1-3
// and 5 with windows
ClippingRectangle {
    id: root

    // Workspace style: "pills", "numbers", "dots", "groups" or "icons"
    property string value

    readonly property var styles: ({
            "pills": pillsStyle,
            "numbers": numbersStyle,
            "dots": dotsStyle,
            "groups": groupsStyle,
            "icons": iconsStyle
        })

    radius: Config.radius
    color: Config.surface2Color

    WorkspacesModel {
        id: sample
        live: false
        activeId: 3
        workspaces: ({
                "1": {
                    windows: ["kitty"],
                    urgent: false
                },
                "2": {
                    windows: ["zen", "kitty"],
                    urgent: false
                },
                "3": {
                    windows: ["kitty"],
                    urgent: false
                },
                "5": {
                    windows: ["spotify"],
                    urgent: false
                }
            })
    }

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // The bar, with the strip scaled down to fit the tile
    Rectangle {
        id: bar
        anchors.centerIn: parent
        width: parent.width - Config.spacing * 2
        height: strip.implicitHeight * strip.scale + Config.spacing
        radius: height / 2
        color: Config.backgroundColor

        Loader {
            id: strip
            anchors.centerIn: parent
            sourceComponent: root.styles[root.value] ?? pillsStyle
            scale: implicitWidth > 0 ? Math.min(1, (bar.width - Config.spacing * 2) / implicitWidth) : 1
        }
    }

    Component {
        id: pillsStyle
        PillsStyle {
            model: sample
            count: 5
        }
    }

    Component {
        id: numbersStyle
        NumbersStyle {
            model: sample
            count: 5
        }
    }

    Component {
        id: dotsStyle
        DotsStyle {
            model: sample
            count: 5
        }
    }

    Component {
        id: groupsStyle
        GroupsStyle {
            model: sample
            count: 5
        }
    }

    Component {
        id: iconsStyle
        IconsStyle {
            model: sample
            count: 5
        }
    }
}
