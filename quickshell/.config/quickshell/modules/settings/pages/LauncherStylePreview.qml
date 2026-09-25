pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/"

// Miniature desktop showing one launcher template over the current
// wallpaper, with the bar on its configured edge and the launcher in the
// position saved for that template (attached to the bar when that's on)
ClippingRectangle {
    id: root

    // Launcher template: "spotlight", "dropdown", "sidebar" or "grid"
    property string value
    readonly property string position: LauncherService.positionFor(value)

    // Everything is sized from the thumbnail height
    readonly property real unit: height / 12
    readonly property real barHeight: unit * 1.4
    readonly property bool barOnBottom: Config.barOnBottom
    // Room between the bar's edge and a launcher next to it
    readonly property real barGap: barHeight + unit * 0.6

    readonly property bool grid: value === "grid"
    readonly property bool sidebar: value === "sidebar"
    readonly property string barEdge: barOnBottom ? "bottom" : "top"
    // Screen edge a spotlight hangs from, "" in the center
    readonly property string spotlightEdge: value === "spotlight" && position !== "center" ? position : ""
    readonly property bool atBar: value === "dropdown" || spotlightEdge === barEdge
    // Same rules as the launcher: attached panels touch the bar, or the
    // screen edge when the bar has no continuous edge
    readonly property bool attached: StateService.get("bar.attachPopups", true) && (value === "dropdown" || sidebar || spotlightEdge !== "")
    readonly property real edgeOffset: attached ? (Config.barIslands || Config.barFloating ? 0 : barHeight) : barGap
    readonly property real inset: attached ? 0 : unit * 0.4
    // Search at the bottom, the rows growing upward
    readonly property bool reversed: LauncherService.isReversed(value, position)

    radius: Config.radius
    color: Config.surface2Color

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // The bar, as a docked strip
    Rectangle {
        width: parent.width
        height: root.barHeight
        y: root.barOnBottom ? parent.height - height : 0
        color: Config.backgroundColor

        Rectangle {
            x: root.unit * 0.6
            anchors.verticalCenter: parent.verticalCenter
            width: root.unit * 0.6
            height: width
            radius: width / 2
            color: Config.accentColor
        }
    }

    AttachedPanel {
        visible: root.attached
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height
        edges: {
            if (root.sidebar)
                return [root.position, "top", "bottom"];
            if (root.value === "dropdown")
                return [root.barEdge, "left"];
            return [root.spotlightEdge];
        }
        color: Config.backgroundColor
        radius: root.unit * 0.6
        filletSize: root.unit * 0.6
        shown: true
    }

    // The launcher panel (only its content when attached)
    Rectangle {
        id: panel

        readonly property real rowHeight: root.unit * 0.9

        width: {
            if (root.grid)
                return parent.width;
            if (root.sidebar)
                return parent.width * 0.3;
            return parent.width * (root.value === "spotlight" ? 0.45 : 0.36);
        }
        height: {
            if (root.grid)
                return parent.height;
            if (root.sidebar)
                return parent.height - root.edgeOffset - root.inset;
            return root.unit * 6;
        }
        x: {
            if (root.grid)
                return 0;
            if (root.sidebar)
                return root.position === "right" ? parent.width - width - root.inset : root.inset;
            if (root.value === "dropdown")
                return root.inset;
            return (parent.width - width) / 2;
        }
        y: {
            if (root.grid)
                return 0;
            if (root.sidebar)
                return root.barOnBottom ? root.inset : root.edgeOffset;
            if (root.value === "dropdown")
                return root.barOnBottom ? parent.height - root.edgeOffset - height : root.edgeOffset;
            if (root.spotlightEdge !== "") {
                const offset = root.atBar ? root.edgeOffset : root.inset;
                return root.spotlightEdge === "bottom" ? parent.height - offset - height : offset;
            }
            return parent.height / 5;
        }
        radius: root.grid ? 0 : root.unit * 0.6
        color: root.attached ? "transparent" : root.grid ? Qt.alpha(Config.backgroundColor, 0.9) : Config.backgroundColor
        border.width: root.grid || root.attached ? 0 : 1
        border.color: Config.surface2Color

        // Search field
        Rectangle {
            id: searchPill
            x: root.grid ? (parent.width - width) / 2 : root.unit * 0.4
            y: {
                if (root.reversed)
                    return parent.height - height - (root.grid ? root.unit * 1.2 : root.unit * 0.4);
                return root.grid ? root.unit * 1.2 : root.unit * 0.4;
            }
            width: root.grid ? parent.width * 0.4 : parent.width - root.unit * 0.8
            height: root.unit * 0.9
            radius: height / 2
            color: Config.surface1Color
        }

        // Grid: apps as tiles
        Grid {
            visible: root.grid
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.reversed ? searchPill.y - height - root.unit * 0.8 : searchPill.y + searchPill.height + root.unit * 0.8
            columns: 7
            spacing: root.unit * 0.55

            Repeater {
                model: 21

                Rectangle {
                    required property int index
                    width: root.unit * 0.9
                    height: width
                    radius: width / 3
                    color: index === 0 ? Config.accentColor : Config.surface3Color
                }
            }
        }

        // Others: a list of rows, the first one selected (right above the
        // search when upside down)
        Item {
            visible: !root.grid
            x: root.unit * 0.4
            y: root.reversed ? root.unit * 0.3 : searchPill.y + searchPill.height + root.unit * 0.3
            width: parent.width - root.unit * 0.8
            height: root.reversed ? searchPill.y - y - root.unit * 0.3 : parent.height - y - root.unit * 0.3
            clip: true

            Column {
                // Upside down, pinned to the bottom with the last row selected
                id: rows

                readonly property int selected: root.reversed ? 11 : 0

                width: parent.width
                y: root.reversed ? parent.height - height : 0
                spacing: root.unit * 0.2

                Repeater {
                    model: 12

                    Rectangle {
                        id: row
                        required property int index
                        readonly property bool selected: index === rows.selected
                        width: parent.width
                        height: panel.rowHeight
                        radius: height / 3
                        color: selected ? Config.surface1Color : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: Qt.alpha(Config.accentColor, 0.6)

                        Rectangle {
                            x: root.unit * 0.2
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.height * 0.6
                            height: width
                            radius: width / 3
                            color: row.selected ? Config.accentColor : Config.surface3Color
                        }

                        Rectangle {
                            x: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * (row.index % 2 ? 0.45 : 0.6)
                            height: root.unit * 0.3
                            radius: height / 2
                            color: Config.surface3Color
                        }
                    }
                }
            }
        }
    }
}
