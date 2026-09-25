pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Full player: big cover, track details, progress, controls and volume over
// the blurred cover, and a chip per player to switch between them
ColumnLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    signal closeRequested

    readonly property int coverSize: Config.fontSizeIconLarge * 8

    spacing: Config.spacing

    // ==================== NOTHING PLAYING ====================
    Card {
        visible: !MprisService.hasPlayer
        Layout.fillWidth: true
        Layout.preferredHeight: root.coverSize

        Item {
            Layout.fillHeight: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{f075b}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge * 2
            color: Config.subtextColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing playing"
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Play something in Spotify, a browser, mpv or any MPRIS player"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // ==================== PLAYER ====================
    Rectangle {
        visible: MprisService.hasPlayer
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + Config.padding * 6
        radius: Config.radiusLarge
        color: Config.cardColor

        CoverBackdrop {
            anchors.fill: parent
            radius: Config.radiusLarge
        }

        // The wheel changes the player's volume
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const step = 0.05;
                MprisService.setVolume(MprisService.volume + (wheel.angleDelta.y > 0 ? step : -step));
            }
        }

        RowLayout {
            id: hero
            anchors.fill: parent
            anchors.margins: Config.padding * 3
            spacing: Config.spacing * 3

            // Cover (room for the visualizer around it later)
            ClippingRectangle {
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                Layout.alignment: Qt.AlignTop
                radius: Config.radiusLarge
                color: Config.surface1Color

                Image {
                    id: cover
                    anchors.fill: parent
                    source: MprisService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "\u{f075a}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge * 3
                    color: Config.subtextColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.padding

                // App + Open
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.padding

                    PlayerIcon {
                        player: MprisService.activePlayer
                        size: Config.fontSizeNormal
                    }

                    Text {
                        Layout.fillWidth: true
                        text: MprisService.identity
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.subtextColor
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        visible: MprisService.canRaise
                        icon: "\u{f03cc}"
                        text: "Open"
                        size: Config.fontSizeSmall * 2 + Config.padding
                        iconSize: Config.fontSizeNormal
                        baseColor: Qt.alpha(Config.surface1Color, 0.6)
                        textColor: Config.subtextColor
                        hoverTextColor: Config.accentColor
                        onClicked: {
                            MprisService.raise();
                            root.closeRequested();
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Text {
                    Layout.fillWidth: true
                    text: MprisService.title
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    font.bold: true
                    color: Config.textColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: MprisService.artist
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.textColor
                    opacity: 0.85
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    // Singles repeat the title as the album
                    visible: text !== "" && text !== MprisService.title
                    text: MprisService.album
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                MediaProgress {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing * 2

                    MediaControls {
                        playSize: Config.fontSizeIconLarge * 1.6
                    }

                    QsSlider {
                        visible: MprisService.volumeSupported
                        icon: "\u{f057e}"
                        value: MprisService.volume
                        onMoved: value => MprisService.setVolume(value)
                    }
                }
            }
        }
    }

    // ==================== PLAYERS ====================
    Flow {
        visible: MprisService.players.length > 1
        Layout.fillWidth: true
        spacing: Config.padding

        Repeater {
            model: MprisService.players

            Rectangle {
                id: chip

                required property MprisPlayer modelData
                readonly property bool current: modelData === MprisService.activePlayer

                implicitWidth: chipRow.implicitWidth + Config.padding * 4
                implicitHeight: Config.fontSizeSmall * 2 + Config.padding
                radius: height / 2
                color: chipMouse.containsMouse && !current ? Config.cardHoverColor : Config.cardColor
                border.width: current ? 1 : 0
                border.color: Qt.alpha(Config.accentColor, 0.6)

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Config.padding

                    PlayerIcon {
                        player: chip.modelData
                        size: Config.fontSizeNormal
                    }

                    Text {
                        text: chip.modelData.identity
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: chip.current
                        color: chip.current ? Config.textColor : Config.subtextColor
                    }

                    Text {
                        visible: chip.modelData.isPlaying
                        text: "\u{f040a}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.accentColor
                    }
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MprisService.selectPlayer(chip.modelData)
                }
            }
        }
    }

    // App icon of a player, or a note when it has none
    component PlayerIcon: Item {
        id: playerIcon

        property MprisPlayer player
        property real size: Config.fontSizeNormal
        readonly property string source: MprisService.playerIcon(player)

        implicitWidth: size
        implicitHeight: size

        IconImage {
            anchors.fill: parent
            visible: playerIcon.source !== ""
            source: playerIcon.source
        }

        Text {
            anchors.centerIn: parent
            visible: playerIcon.source === ""
            text: "\u{f075a}"
            font.family: Config.font
            font.pixelSize: playerIcon.size
            color: Config.subtextColor
        }
    }
}
