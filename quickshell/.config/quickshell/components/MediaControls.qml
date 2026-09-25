pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.services

// Shuffle, previous, play/pause, next and loop for the active player.
// `round` puts every button in a tonal circle (active ones tinted) instead
// of bare icons with a dot under the active ones
RowLayout {
    id: root

    // Diameter of the play button; the others scale with it
    property real playSize: Config.fontSizeIconSmall * 2
    property bool round: false

    readonly property real buttonSize: round ? Math.round(playSize * 0.75) : Config.fontSizeIcon + Config.padding

    spacing: Config.spacing

    ControlButton {
        icon: "\u{f049f}"
        visible: MprisService.shuffleSupported
        active: MprisService.shuffle
        onClicked: MprisService.toggleShuffle()
    }

    ControlButton {
        icon: "\u{f04ae}"
        enabled: MprisService.canPrevious
        onClicked: MprisService.previous()
    }

    Rectangle {
        implicitWidth: root.playSize
        implicitHeight: root.playSize
        radius: root.playSize / 2
        color: playBtnMouse.containsMouse ? Qt.lighter(Config.accentColor, 1.1) : Config.accentColor
        opacity: MprisService.canToggle ? 1.0 : 0.4
        scale: playBtnMouse.pressed ? 0.9 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: MprisService.isPlaying ? "\u{f03e4}" : "\u{f040a}"
            font.family: Config.font
            font.pixelSize: Math.round(root.playSize * 0.45)
            color: Config.textReverseColor
        }

        MouseArea {
            id: playBtnMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: MprisService.canToggle
            onClicked: MprisService.playPause()
        }
    }

    ControlButton {
        icon: "\u{f04ad}"
        enabled: MprisService.canNext
        onClicked: MprisService.next()
    }

    ControlButton {
        visible: MprisService.loopSupported
        active: MprisService.loopState !== MprisLoopState.None
        icon: MprisService.loopState === MprisLoopState.Track ? "\u{f0458}" : MprisService.loopState === MprisLoopState.Playlist ? "\u{f0456}" : "\u{f0457}"
        onClicked: MprisService.cycleLoop()
    }

    component ControlButton: Item {
        id: btn

        property string icon: ""
        property bool active: false
        signal clicked

        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        opacity: enabled ? 1.0 : 0.3
        scale: mouseArea.pressed ? 0.9 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        // Tonal circle (round)
        Rectangle {
            anchors.fill: parent
            visible: root.round
            radius: width / 2
            color: {
                if (btn.active)
                    return Qt.alpha(Config.accentColor, mouseArea.containsMouse ? 0.35 : 0.25);
                return mouseArea.containsMouse ? Config.cardHoverColor : Config.cardColor;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        Text {
            id: btnIcon
            anchors.centerIn: parent
            text: btn.icon
            font.family: Config.font
            font.pixelSize: root.round ? Math.round(root.buttonSize * 0.45) : Config.fontSizeIconSmall
            color: btn.active || mouseArea.containsMouse ? Config.accentColor : Config.textColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        // Active dot (bare icons)
        Rectangle {
            visible: !root.round
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: btnIcon.bottom
            anchors.topMargin: -2
            width: Config.padding - 2
            height: width
            radius: width / 2
            color: Config.accentColor
            opacity: btn.active ? 1.0 : 0.0
            scale: btn.active ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutBack
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: btn.enabled
            onClicked: btn.clicked()
        }
    }
}
