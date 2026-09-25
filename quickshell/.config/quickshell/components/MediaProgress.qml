pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Elapsed time, seekable progress bar and length of the active track.
// Hidden when the player doesn't report a position
RowLayout {
    id: root

    function formatTime(seconds: real): string {
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    visible: MprisService.positionSupported && MprisService.length > 0
    spacing: Config.spacing

    // Current time
    Text {
        text: root.formatTime(progressMouse.pressed ? progressBar.dragRatio * MprisService.length : MprisService.position)
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall - 2
        color: Config.subtextColor
        opacity: 0.7
        Layout.preferredWidth: Config.fontSizeSmall * 2.5
    }

    // Progress bar
    Item {
        id: progressBar
        Layout.fillWidth: true
        Layout.preferredHeight: progressMouse.containsMouse || progressMouse.pressed ? Config.padding : Config.padding - 2

        property bool wasPlaying: false
        property real dragRatio: 0

        Behavior on Layout.preferredHeight {
            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: Easing.OutQuad
            }
        }

        // Track background
        Rectangle {
            anchors.fill: parent
            radius: parent.height / 2
            color: Config.surface3Color
            opacity: 0.5
        }

        // Fill
        Rectangle {
            id: progressFill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: parent.height / 2
            color: Config.accentColor

            property real liveRatio: MprisService.length > 0 ? MprisService.position / MprisService.length : 0
            property real currentRatio: progressMouse.pressed ? progressBar.dragRatio : liveRatio

            width: currentRatio * parent.width

            Behavior on width {
                enabled: !progressMouse.pressed
                NumberAnimation {
                    duration: 80
                    easing.type: Easing.OutQuad
                }
            }
        }

        // Handle dot
        Rectangle {
            width: progressMouse.containsMouse || progressMouse.pressed ? Config.padding + 4 : Config.padding
            height: width
            radius: width / 2
            color: Config.accentColor
            y: (parent.height - height) / 2
            x: Math.max(0, progressFill.width - (width / 2))
            opacity: progressMouse.containsMouse || progressMouse.pressed ? 1.0 : 0.0

            Behavior on width {
                NumberAnimation {
                    duration: Config.animDurationShort
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        MouseArea {
            id: progressMouse
            anchors.fill: parent
            anchors.topMargin: -Config.padding
            anchors.bottomMargin: -Config.padding
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => {
                progressBar.dragRatio = Math.max(0, Math.min(1, mouse.x / width));
                progressBar.wasPlaying = MprisService.isPlaying;
                if (progressBar.wasPlaying)
                    MprisService.activePlayer.pause();
            }

            onPositionChanged: mouse => {
                if (pressed)
                    progressBar.dragRatio = Math.max(0, Math.min(1, mouse.x / width));
            }

            onReleased: mouse => {
                const ratio = Math.max(0, Math.min(1, mouse.x / width));
                MprisService.setPosition(ratio * MprisService.length);
                if (progressBar.wasPlaying)
                    MprisService.activePlayer.play();
                progressBar.wasPlaying = false;
            }
        }
    }

    // Total time
    Text {
        text: root.formatTime(MprisService.length)
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall - 2
        color: Config.subtextColor
        opacity: 0.7
        Layout.preferredWidth: Config.fontSizeSmall * 2.5
        horizontalAlignment: Text.AlignRight
    }
}
