pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/"

// Miniature desktop showing one bar style over the current wallpaper
ClippingRectangle {
    id: root

    // Bar style: "islands", "docked", "floating" or "docked-corners"
    property string value
    readonly property bool islands: value === "islands"
    readonly property bool floating: value === "floating"
    readonly property bool corners: value === "docked-corners"

    // Everything is sized from the thumbnail height
    readonly property real unit: height / 12
    readonly property real barHeight: unit * 2
    readonly property real margin: floating ? unit * 0.6 : 0
    readonly property real groupHeight: islands ? barHeight * 0.8 : barHeight
    readonly property real groupY: margin + (barHeight - groupHeight) / 2

    radius: Config.radius
    color: Config.surface2Color

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // A window below the bar
    Rectangle {
        x: root.unit
        y: root.margin + root.barHeight + root.unit * 0.8
        width: parent.width - root.unit * 2
        height: parent.height - y - root.unit
        radius: Config.radiusSmall
        color: Qt.alpha(Config.surface0Color, 0.9)
        border.width: 1
        border.color: Config.accentColor
    }

    Rectangle {
        visible: !root.islands
        x: root.margin
        y: root.margin
        width: parent.width - root.margin * 2
        height: root.barHeight
        radius: root.floating ? height / 2 : 0
        color: Config.backgroundColor
    }

    ConcaveCorner {
        y: root.barHeight
        size: root.corners ? root.unit * 3 : 0
        color: Config.backgroundColor
    }

    ConcaveCorner {
        x: parent.width - width
        y: root.barHeight
        size: root.corners ? root.unit * 3 : 0
        color: Config.backgroundColor
        mirrored: true
    }

    // Left, center and right groups of items; islands in that style
    component Group: Rectangle {
        id: group

        property bool launcher: false

        y: root.groupY
        height: root.groupHeight
        radius: height / 2
        color: root.islands ? Config.backgroundColor : "transparent"

        Row {
            anchors.centerIn: parent
            spacing: root.unit * 0.4

            Rectangle {
                visible: group.launcher
                width: root.unit * 0.7
                height: width
                radius: width / 2
                color: Config.accentColor
            }

            Rectangle {
                width: group.width - (group.launcher ? root.unit * 2.1 : root.unit)
                height: root.unit * 0.45
                radius: height / 2
                color: Config.surface3Color
            }
        }
    }

    Group {
        x: root.margin + root.unit * 0.5
        width: root.unit * 5
        launcher: true
    }

    Group {
        x: (parent.width - width) / 2
        width: root.unit * 3.5
    }

    Group {
        x: parent.width - root.margin - root.unit * 0.5 - width
        width: root.unit * 3.5
    }
}
