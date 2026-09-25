pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/"

// Miniature desktop showing one power menu template over the dimmed
// wallpaper: the card with a row of tiles, the strip on its side, or the
// farewell screen with an avatar and round buttons
ClippingRectangle {
    id: root

    // Power menu template: "card", "strip" or "farewell"
    property string value

    readonly property real unit: height / 12
    readonly property int count: 5

    radius: Config.radius
    color: Config.surface2Color

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: Config.backgroundColor
        opacity: root.value === "strip" ? 0.25 : root.value === "farewell" ? 0.7 : 0.45
    }

    // Card: header line + tiles
    Rectangle {
        visible: root.value === "card"
        anchors.centerIn: parent
        width: root.unit * 11.5
        height: root.unit * 5.2
        radius: root.unit * 0.8
        color: Config.backgroundColor
        border.width: 1
        border.color: Config.surface2Color

        Row {
            x: root.unit * 0.6
            y: root.unit * 0.6
            spacing: root.unit * 0.4

            Rectangle {
                width: root.unit * 1.1
                height: width
                radius: width / 2
                color: Config.accentColor
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.unit * 3
                height: root.unit * 0.4
                radius: height / 2
                color: Config.surface2Color
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.unit * 2.2
            spacing: root.unit * 0.3

            Repeater {
                model: root.count

                Rectangle {
                    required property int index

                    width: root.unit * 1.9
                    height: root.unit * 2.4
                    radius: root.unit * 0.4
                    color: index === 0 ? Qt.alpha(Config.accentColor, 0.3) : Config.surface0Color
                    border.width: index === 0 ? 1 : 0
                    border.color: Config.accentColor
                }
            }
        }
    }

    // Strip: a column of squares out of the side edge
    AttachedPanel {
        visible: root.value === "strip"
        shown: true
        edges: [PowerService.side === "left" ? "left" : "right"]
        x: PowerService.side === "left" ? 0 : parent.width - width
        anchors.verticalCenter: parent.verticalCenter
        width: root.unit * 2
        height: root.unit * 9.5
        radius: root.unit * 0.6
        filletSize: root.unit * 0.6
        color: Config.backgroundColor

        Column {
            anchors.centerIn: parent
            spacing: root.unit * 0.3

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.unit
                height: width
                radius: width / 2
                color: Config.surface2Color
            }

            Repeater {
                model: root.count

                Rectangle {
                    required property int index

                    width: root.unit * 1.2
                    height: width
                    radius: root.unit * 0.3
                    color: index === 0 ? Config.accentColor : Config.surface0Color
                }
            }
        }
    }

    // Farewell: avatar, greeting and round buttons, no panel
    Column {
        visible: root.value === "farewell"
        anchors.centerIn: parent
        spacing: root.unit * 0.5

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.unit * 2.4
            height: width
            radius: width / 2
            color: Config.accentColor
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.unit * 5
            height: root.unit * 0.6
            radius: height / 2
            color: Config.textColor
            opacity: 0.8
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.unit * 0.5

            Repeater {
                model: root.count

                Rectangle {
                    required property int index

                    width: root.unit * 1.4
                    height: width
                    radius: width / 2
                    color: index === 0 ? Config.accentColor : Config.surface1Color
                }
            }
        }
    }
}
