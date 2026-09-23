pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Now playing: play/pause and the track title; the title opens Quick Settings
// (which has the full media card)
BarIsland {
    id: root

    readonly property int maxTitleWidth: Config.fontSizeNormal * 14

    signal openRequested

    visible: MprisService.hasPlayer
    spacing: Math.round(Config.padding / 2)

    BarButton {
        id: playButton
        contentItem: playIcon
        implicitWidth: implicitHeight
        onClicked: MprisService.playPause()
        onRightClicked: MprisService.next()

        Text {
            id: playIcon
            anchors.centerIn: parent
            text: MprisService.isPlaying ? "󰏤" : "󰐊"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.accentColor
        }
    }

    BarButton {
        id: titleButton
        contentItem: titleText
        implicitWidth: Math.min(titleText.implicitWidth, root.maxTitleWidth) + Config.padding * 2
        onClicked: root.openRequested()

        Text {
            id: titleText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.maxTitleWidth)
            text: MprisService.title + (MprisService.artist && MprisService.artist !== "Unknown" ? "  ·  " + MprisService.artist : "")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: MprisService.isPlaying ? Config.textColor : Config.subtextColor
            elide: Text.ElideRight
        }
    }
}
