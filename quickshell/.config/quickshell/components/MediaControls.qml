pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.services

// Shuffle, previous, play/pause, next and loop for the active player
RowLayout {
    id: root

    // Diameter of the play button; the others scale with it
    property real playSize: Config.fontSizeIconSmall * 2

    spacing: Config.spacing

    ControlButton {
        icon: "󰒟"
        visible: MprisService.shuffleSupported
        active: MprisService.shuffle
        onClicked: MprisService.toggleShuffle()
    }

    ControlButton {
        icon: "󰒮"
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
            text: MprisService.isPlaying ? "󰏤" : "󰐊"
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
        icon: "󰒭"
        enabled: MprisService.canNext
        onClicked: MprisService.next()
    }

    ControlButton {
        visible: MprisService.loopSupported
        active: MprisService.loopState !== MprisLoopState.None
        icon: MprisService.loopState === MprisLoopState.Track ? "󰑘" : MprisService.loopState === MprisLoopState.Playlist ? "󰑖" : "󰑗"
        onClicked: MprisService.cycleLoop()
    }

    component ControlButton: Item {
            id: btn
            property string icon: ""
            property bool active: false
            signal clicked
    
            implicitWidth: Config.fontSizeIcon + Config.padding
            implicitHeight: Config.fontSizeIcon + Config.padding
            opacity: enabled ? 1.0 : 0.3
    
            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }
    
            Text {
                id: btnIcon
                anchors.centerIn: parent
                text: btn.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: btn.active ? Config.accentColor : mouseArea.containsMouse ? Config.accentColor : Config.textColor
                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }
    
            Rectangle {
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
                onPressedChanged: btn.scale = pressed ? 0.9 : 1.0
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }
        }
}
