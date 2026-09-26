pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.services

// Miniature lock screen over the wallpaper: blurred with the clock and the
// password in the middle (center), three cards (cards), or the sharp
// wallpaper with the clock in the corner (wallpaper)
ClippingRectangle {
    id: root

    // Lock template: "center", "cards" or "wallpaper"
    property string value

    readonly property real unit: height / 12

    radius: Config.radius
    color: Config.surface2Color

    Image {
        id: wallpaper

        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
        visible: root.value === "wallpaper"
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: root.value !== "wallpaper"
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 32
        blur: 1
    }

    Rectangle {
        anchors.fill: parent
        color: Config.backgroundColor
        opacity: root.value === "wallpaper" ? 0.15 : 0.45
    }

    // Center: clock bar, avatar, password pill
    Column {
        visible: root.value === "center"
        anchors.centerIn: parent
        spacing: root.unit * 0.5

        Bar {
            width: root.unit * 5
            height: root.unit * 1.4
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.unit * 1.4
            height: width
            radius: width / 2
            color: Config.accentColor
        }

        Pill {}
    }

    // Cards: three glass cards
    Row {
        visible: root.value === "cards"
        anchors.centerIn: parent
        spacing: root.unit * 0.4

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: index === 1 ? root.unit * 5.5 : root.unit * 3.2
                height: root.unit * 6
                radius: root.unit * 0.5
                color: Config.cardColor

                Column {
                    visible: parent.index === 1
                    anchors.centerIn: parent
                    spacing: root.unit * 0.5

                    Bar {
                        width: root.unit * 4
                        height: root.unit * 1.2
                    }

                    Pill {
                        width: root.unit * 4
                    }
                }
            }
        }
    }

    // Wallpaper: clock in the corner, a hint at the bottom
    Bar {
        visible: root.value === "wallpaper"
        x: root.unit
        y: root.unit
        width: root.unit * 5
        height: root.unit * 1.6
        anchors.horizontalCenter: undefined
    }

    Pill {
        visible: root.value === "wallpaper"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.unit
        width: root.unit * 5
        height: root.unit * 0.8
    }

    component Bar: Rectangle {
        anchors.horizontalCenter: parent?.horizontalCenter
        radius: height / 4
        color: Config.textColor
        opacity: 0.85
    }

    component Pill: Rectangle {
        anchors.horizontalCenter: parent?.horizontalCenter
        width: root.unit * 4.5
        height: root.unit * 1
        radius: height / 2
        color: Config.cardColor
        border.width: 1
        border.color: Config.accentColor
    }
}
