import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// The current wallpaper behind the lock. It starts sharp and blurs and
// darkens in when `revealed`, and clears again on the way out; `blurred`
// false keeps it sharp (only darkened a little) for the wallpaper template
Item {
    id: root

    property bool revealed: false
    property bool blurred: true

    readonly property real amount: revealed ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Config.backgroundColor
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.blurred ? root.amount : 0

        Behavior on blur {
            NumberAnimation {
                duration: Config.animDurationLong * 2
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.backgroundColor
        opacity: root.amount * (root.blurred ? 0.45 : 0.2)

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationLong * 2
                easing.type: Easing.OutCubic
            }
        }
    }
}
