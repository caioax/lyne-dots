pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Elapsed time, seekable progress bar and length of the active track.
// Hidden when the player doesn't report a position. `wavy` draws the played
// part as a wave that flows while playing and flattens when paused
RowLayout {
    id: root

    property bool wavy: false
    property int timeFontSize: Config.fontSizeSmall - 2

    readonly property real lineWidth: Config.padding - 2

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
        font.pixelSize: root.timeFontSize
        color: Config.subtextColor
        opacity: 0.7
        Layout.preferredWidth: root.timeFontSize * 3
    }

    // Progress bar
    Item {
        id: progressBar
        Layout.fillWidth: true
        Layout.preferredHeight: {
            if (root.wavy)
                return Config.padding * 3;
            return progressMouse.containsMouse || progressMouse.pressed ? Config.padding : Config.padding - 2;
        }

        property bool wasPlaying: false
        property real dragRatio: 0

        Behavior on Layout.preferredHeight {
            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: Easing.OutQuad
            }
        }

        // Track background (wavy: a thin line after the played part)
        Rectangle {
            x: root.wavy ? progressFill.width + Config.padding : 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            height: root.wavy ? root.lineWidth : parent.height
            radius: height / 2
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
            visible: !root.wavy

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

        // Wavy fill: a sine up to the fill's width
        Canvas {
            id: wave

            property real phase: 0
            // Flattens while paused
            property real amplitude: MprisService.isPlaying ? (height - root.lineWidth) / 2 : 0
            readonly property real wavelength: Config.fontSizeIcon * 1.5

            visible: root.wavy
            anchors.fill: parent

            Behavior on amplitude {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutCubic
                }
            }

            NumberAnimation on phase {
                running: root.wavy && MprisService.isPlaying && wave.visible
                from: 0
                to: Math.PI * 2
                duration: 2000
                loops: Animation.Infinite
            }

            onPhaseChanged: requestPaint()
            onAmplitudeChanged: requestPaint()
            onWidthChanged: requestPaint()

            Connections {
                target: progressFill
                function onWidthChanged() {
                    wave.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const end = progressFill.width;
                if (end <= 0)
                    return;
                const mid = height / 2;
                ctx.strokeStyle = Config.accentColor;
                ctx.lineWidth = root.lineWidth;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                const start = root.lineWidth / 2;
                for (let x = start; x <= end; x += 2)
                    ctx[x === start ? "moveTo" : "lineTo"](x, mid + Math.sin(x / wavelength * Math.PI * 2 - phase) * amplitude);
                ctx.stroke();
            }
        }

        // Handle: a dot, or a vertical pill for the wave
        Rectangle {
            width: {
                if (root.wavy)
                    return progressMouse.containsMouse || progressMouse.pressed ? root.lineWidth * 1.5 : root.lineWidth;
                return progressMouse.containsMouse || progressMouse.pressed ? Config.padding + 4 : Config.padding;
            }
            height: root.wavy ? parent.height + Config.padding : width
            radius: width / 2
            color: Config.accentColor
            y: (parent.height - height) / 2
            x: Math.max(0, progressFill.width - (width / 2))
            opacity: root.wavy || progressMouse.containsMouse || progressMouse.pressed ? 1.0 : 0.0

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
        font.pixelSize: root.timeFontSize
        color: Config.subtextColor
        opacity: 0.7
        Layout.preferredWidth: root.timeFontSize * 3
        horizontalAlignment: Text.AlignRight
    }
}
