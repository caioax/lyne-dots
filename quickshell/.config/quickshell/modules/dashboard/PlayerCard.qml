pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Tall player for the grid Overview: cover on top, then the track, progress
// and controls. The wheel changes the player's volume; the cover opens the
// Media tab
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

    Item {
        Layout.fillHeight: true
    }

    MediaProgress {
        Layout.fillWidth: true
        wavy: true
    }

    MediaControls {
        Layout.alignment: Qt.AlignHCenter
        round: true
        spacing: Config.padding / 2
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
