pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Tall player for the Overview: cover on top, then the track, progress and
// controls, with the GIF dancing in the space left below while something
// plays. The wheel changes the player's volume; the cover opens the Media tab
Card {
    id: root

    visible: MprisService.hasPlayer

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: width
        radius: Config.radius
        color: Config.surface1Color

        Image {
            id: cover
            anchors.fill: parent
            source: MprisService.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "\u{f075a}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge * 2
            color: Config.subtextColor
        }

        // Opens the Media tab
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: DashboardService.tab = "media"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: MprisService.title
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: Config.textColor
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: MprisService.artist
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
            elide: Text.ElideRight
        }
    }

    MediaProgress {
        Layout.topMargin: Config.spacing
        Layout.fillWidth: true
        wavy: true
    }

    MediaControls {
        Layout.alignment: Qt.AlignHCenter
        round: true
        spacing: Config.padding / 2
    }

    // Whatever height is left, the GIF centered in it (kept free while paused
    // so the controls don't move)
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        MediaGif {
            anchors.centerIn: parent
            width: Math.min(parent.width, Config.fontSizeIconLarge * 5)
            height: Math.min(parent.height, Config.fontSizeIconLarge * 5)
            onlyWhilePlaying: true
        }
    }

    // The wheel changes the volume. A handler, not a MouseArea: one on top
    // resets the controls' pointing hand cursor
    WheelHandler {
        parent: root
        onWheel: event => {
            const step = 0.05;
            MprisService.setVolume(MprisService.volume + (event.angleDelta.y > 0 ? step : -step));
        }
    }
}
