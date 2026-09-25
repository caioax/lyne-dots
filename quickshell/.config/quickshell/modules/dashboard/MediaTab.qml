pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Full player in three columns over the blurred cover:
//   round cover with the cava spectrum around it, and the GIF below
//   track, wavy progress, round controls and volume
//   lyrics and the players
Item {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    signal closeRequested

    readonly property int coverSize: Config.fontSizeIconLarge * 6
    readonly property int sideWidth: DashboardService.panelWidth >= 840 ? 240 : 180
    // cava only runs while the tab is shown and something plays
    readonly property bool visualizing: active && MprisService.isPlaying

    onVisualizingChanged: visualizing ? CavaService.acquire() : CavaService.release()
    Component.onDestruction: {
        if (visualizing)
            CavaService.release();
    }

    implicitHeight: MprisService.hasPlayer ? columns.implicitHeight + Config.padding * 4 : empty.implicitHeight + Config.padding * 12

    CoverBackdrop {
        anchors.fill: parent
        visible: MprisService.hasPlayer
        radius: Config.radiusLarge
    }

    // ==================== NOTHING PLAYING ====================
    ColumnLayout {
        id: empty
        anchors.centerIn: parent
        visible: !MprisService.hasPlayer
        spacing: Config.padding

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Config.padding
            implicitWidth: Config.fontSizeIconLarge * 2.5
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.alpha(Config.accentColor, 0.15)

            Text {
                anchors.centerIn: parent
                text: "\u{f075b}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconLarge
                color: Config.accentColor
            }
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
    }

    // The wheel changes the player's volume
    MouseArea {
        anchors.fill: parent
        enabled: MprisService.hasPlayer
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const step = 0.05;
            MprisService.setVolume(MprisService.volume + (wheel.angleDelta.y > 0 ? step : -step));
        }
    }

    RowLayout {
        id: columns
        visible: MprisService.hasPlayer
        anchors.fill: parent
        anchors.margins: Config.padding * 2
        spacing: Config.spacing * 2

        // ==================== COVER + GIF ====================
        ColumnLayout {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            CoverVisualizer {
                id: visualizer
                coverSize: root.coverSize
                coverRadius: root.coverSize / 2
                ring: CavaService.enabled && CavaService.available ? Config.spacing * 3 : Config.spacing
                running: root.visualizing

                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
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
                        font.pixelSize: Config.fontSizeIconLarge * 2
                        color: Config.subtextColor
                    }
                }
            }

            MediaGif {
                Layout.preferredWidth: visualizer.implicitWidth
                Layout.preferredHeight: Config.fontSizeIconLarge * 3
                Layout.fillHeight: true
            }
        }

        // ==================== TRACK + CONTROLS ====================
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
                    baseColor: Config.cardColor
                    hoverColor: Config.cardHoverColor
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
                color: Config.subtextColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                // Singles repeat the title as the album
                visible: text !== "" && text !== MprisService.title
                text: MprisService.album
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            MediaProgress {
                Layout.fillWidth: true
                wavy: true
                timeFontSize: Config.fontSizeSmall
            }

            MediaControls {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Config.padding
                round: true
                playSize: Config.fontSizeIconLarge * 1.6
                spacing: Config.padding
            }

            // Volume
            RowLayout {
                visible: MprisService.volumeSupported
                Layout.fillWidth: true
                Layout.topMargin: Config.padding
                spacing: Config.spacing

                Text {
                    text: MprisService.volume <= 0 ? "\u{f0581}" : MprisService.volume < 0.5 ? "\u{f0580}" : "\u{f057e}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    color: Config.subtextColor
                }

                SlimSlider {
                    Layout.fillWidth: true
                    value: MprisService.volume
                    onMoved: value => MprisService.setVolume(value)
                }

                Text {
                    Layout.preferredWidth: Config.fontSizeSmall * 3
                    text: Math.round(MprisService.volume * 100) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // ==================== LYRICS + PLAYERS ====================
        ColumnLayout {
            Layout.preferredWidth: root.sideWidth
            Layout.fillHeight: true
            spacing: Config.spacing

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Config.radiusLarge
                color: Config.cardColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Config.padding * 2
                    spacing: Config.padding

                    SectionTitle {
                        icon: "\u{f0370}"
                        text: "Lyrics"
                    }

                    LyricsView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.active
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: players.implicitHeight + Config.padding * 4
                radius: Config.radiusLarge
                color: Config.cardColor

                ColumnLayout {
                    id: players
                    anchors.fill: parent
                    anchors.margins: Config.padding * 2
                    spacing: Config.padding / 2

                    SectionTitle {
                        icon: "\u{f04c3}"
                        text: "Players"
                    }

                    Repeater {
                        model: MprisService.players

                        Rectangle {
                            id: playerRow

                            required property MprisPlayer modelData
                            readonly property bool current: modelData === MprisService.activePlayer

                            Layout.fillWidth: true
                            implicitHeight: Config.fontSizeSmall * 2 + Config.padding
                            radius: Config.radius
                            color: current ? Qt.alpha(Config.accentColor, 0.15) : rowMouse.containsMouse ? Config.cardHoverColor : "transparent"
                            border.width: current ? 1 : 0
                            border.color: Qt.alpha(Config.accentColor, 0.6)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Config.padding
                                anchors.rightMargin: Config.padding
                                spacing: Config.padding

                                PlayerIcon {
                                    player: playerRow.modelData
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: playerRow.modelData.identity
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    font.bold: playerRow.current
                                    color: playerRow.current ? Config.textColor : Config.subtextColor
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: playerRow.modelData.isPlaying
                                    text: "\u{f040a}"
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.accentColor
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MprisService.selectPlayer(playerRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    component SectionTitle: RowLayout {
        id: section

        property string icon
        property string text

        spacing: Config.padding

        Text {
            text: section.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.accentColor
        }

        Text {
            text: section.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
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

    // Thin draggable line with a round handle (0-1)
    component SlimSlider: Item {
        id: slider

        property real value: 0
        signal moved(real value)

        property real dragValue: 0
        readonly property real shown: Math.max(0, Math.min(1, sliderMouse.pressed ? dragValue : value))

        implicitHeight: Config.padding * 3

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Config.padding - 2
            radius: height / 2
            color: Qt.alpha(Config.surface3Color, 0.5)

            Rectangle {
                width: parent.width * slider.shown
                height: parent.height
                radius: height / 2
                color: Config.accentColor
            }
        }

        Rectangle {
            id: handle

            readonly property real size: sliderMouse.containsMouse || sliderMouse.pressed ? Config.padding * 2.5 : Config.padding * 2

            x: slider.width * slider.shown - size / 2
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size
            radius: size / 2
            color: Config.accentColor
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function update(x: real) {
                slider.dragValue = Math.max(0, Math.min(1, x / width));
                slider.moved(slider.dragValue);
            }

            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    update(mouse.x);
            }
        }
    }
}
