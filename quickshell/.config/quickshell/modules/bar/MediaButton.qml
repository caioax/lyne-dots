pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Now playing: cover, equalizer, title · artist and a progress line.
// Click opens the dashboard's Media tab, middle click plays/pauses, right
// click skips and the wheel changes the volume
BarButton {
    id: root

    readonly property int maxTitleWidth: Config.fontSizeNormal * 12
    readonly property int artSize: Config.barButtonHeight - Config.padding
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    visible: MprisService.hasPlayer
    active: DashboardService.screen === screenName && DashboardService.tab === "media"
    contentItem: content
    onClicked: DashboardService.toggle("media", screenName)
    onMiddleClicked: MprisService.playPause()
    onRightClicked: MprisService.next()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const step = 0.05;
            MprisService.setVolume(MprisService.volume + (wheel.angleDelta.y > 0 ? step : -step));
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Config.padding

        // Cover
        ClippingRectangle {
            implicitWidth: root.artSize
            implicitHeight: root.artSize
            radius: Config.radiusSmall
            color: Config.surface1Color

            Image {
                id: cover
                anchors.fill: parent
                source: MprisService.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "󰝚"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        // Equalizer bars: dance while playing, rest while paused
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(Config.padding / 3)

            Repeater {
                model: 3

                Rectangle {
                    id: bar

                    required property int index
                    readonly property real maxHeight: Config.fontSizeSmall

                    anchors.bottom: parent.bottom
                    width: Math.round(Config.padding / 2)
                    height: maxHeight * 0.3
                    radius: width / 2
                    color: Config.accentColor

                    SequentialAnimation on height {
                        running: MprisService.isPlaying
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation {
                            to: bar.maxHeight * (0.6 + bar.index * 0.2 % 0.4)
                            duration: Config.animDurationLong - bar.index * Config.animDurationShort / 2
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: bar.maxHeight * 0.3
                            duration: Config.animDurationLong + bar.index * Config.animDurationShort / 2
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // Row needs a height for the bottom-anchored bars
            height: Config.fontSizeSmall
        }

        Text {
            Layout.maximumWidth: root.maxTitleWidth
            text: MprisService.title + (MprisService.artist && MprisService.artist !== "Unknown" ? "  ·  " + MprisService.artist : "")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: MprisService.isPlaying ? Config.textColor : Config.subtextColor
            elide: Text.ElideRight
        }
    }

    // Progress along the bottom edge, on the straight part of the pill
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        anchors.bottomMargin: 1
        width: (root.width - root.radius * 2) * (MprisService.length > 0 ? Math.min(1, MprisService.position / MprisService.length) : 0)
        height: 2
        radius: 1
        color: Qt.alpha(Config.accentColor, 0.8)
        visible: MprisService.positionSupported && MprisService.length > 0

        Behavior on width {
            NumberAnimation {
                duration: MprisService.positionInterval
            }
        }
    }
}
