pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Full player over the blurred cover: the round cover with the cava spectrum
// around it, then the track (or its synced lyrics), wavy progress, and the
// round controls with the volume on their right, with the GIF floating in
// the top-right corner beside the track
Item {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    readonly property int coverSize: Config.fontSizeIconLarge * 6
    readonly property int gifSize: Config.fontSizeIconLarge * 5
    // Space between the GIF and the right edge
    readonly property real gifMargin: Config.spacing * 2
    // Kept free on the right of the track text for the GIF
    readonly property real gifRoom: gif.visible ? gif.paintedWidth + root.gifMargin + Config.spacing : 0
    // cava only runs while the tab is shown and something plays
    readonly property bool visualizing: active && MprisService.isPlaying
    // Lyrics in place of the title, artist and album
    readonly property bool showLyrics: DashboardService.lyrics

    onVisualizingChanged: visualizing ? CavaService.acquire() : CavaService.release()
    Component.onDestruction: {
        if (visualizing)
            CavaService.release();
    }

    implicitHeight: MprisService.hasPlayer ? columns.implicitHeight + Config.padding * 4 : empty.implicitHeight + Config.padding * 12

    // Blurred cover, or a plain card (Settings › Dashboard › Media)
    CoverBackdrop {
        anchors.fill: parent
        visible: MprisService.hasPlayer && DashboardService.coverBackdrop
        radius: Config.radiusLarge
    }

    Rectangle {
        anchors.fill: parent
        visible: MprisService.hasPlayer && !DashboardService.coverBackdrop
        radius: Config.radiusLarge
        color: Config.cardColor
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

        // ==================== COVER ====================
        CoverVisualizer {
            id: visualizer
            Layout.alignment: Qt.AlignVCenter
            coverSize: root.coverSize
            coverRadius: root.coverSize / 2
            ring: CavaService.enabled && CavaService.available ? Config.spacing * 5 : Config.spacing
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

        // ==================== TRACK + CONTROLS ====================
        ColumnLayout {
            id: info
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.padding

            // App, and a switch between players when there are several
            RowLayout {
                id: header
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

                LyricsButton {}

                Repeater {
                    model: MprisService.players.length > 1 ? MprisService.players : []

                    PlayerButton {}
                }
            }

            Item {
                visible: !root.showLyrics
                Layout.fillHeight: true
            }

            Text {
                visible: !root.showLyrics
                Layout.fillWidth: true
                Layout.rightMargin: root.gifRoom
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
                visible: !root.showLyrics
                Layout.fillWidth: true
                Layout.rightMargin: root.gifRoom
                text: MprisService.artist
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                color: Config.subtextColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.rightMargin: root.gifRoom
                // Singles repeat the title as the album
                visible: !root.showLyrics && text !== "" && text !== MprisService.title
                text: MprisService.album
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
                elide: Text.ElideRight
            }

            Item {
                visible: !root.showLyrics
                Layout.fillHeight: true
            }

            // ==================== LYRICS ====================
            LyricsView {
                visible: root.showLyrics
                active: root.active && root.showLyrics
                Layout.fillWidth: true
                Layout.fillHeight: true
                // About 3 lines: takes the room of the title, artist and album
                // without making the tab taller
                Layout.minimumHeight: Config.fontSizeNormal * 5
                Layout.rightMargin: root.gifRoom
            }

            // Title · artist, in one line under the lyrics
            RowLayout {
                visible: root.showLyrics
                Layout.fillWidth: true
                Layout.rightMargin: root.gifRoom
                spacing: Config.spacing

                // The title takes what it needs, the artist keeps some room
                Text {
                    Layout.minimumWidth: 0
                    text: MprisService.title
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Config.fontSizeNormal * 6
                    text: "\u00b7  " + MprisService.artist
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                    elide: Text.ElideRight
                }
            }

            MediaProgress {
                id: progress
                Layout.fillWidth: true
                wavy: true
                timeFontSize: Config.fontSizeSmall
            }

            // Controls in the middle, the volume in the room on their right
            Item {
                Layout.fillWidth: true
                Layout.topMargin: Config.padding
                implicitHeight: controls.implicitHeight

                MediaControls {
                    id: controls
                    anchors.centerIn: parent
                    round: true
                    playSize: Config.fontSizeIconLarge * 1.6
                    spacing: Config.padding
                }

                RowLayout {
                    visible: MprisService.volumeSupported
                    anchors.left: controls.right
                    anchors.leftMargin: Config.spacing * 2
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
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
        }
    }

    // ==================== GIF ====================
    // Floats in the top-right corner, beside the track text and clear of the
    // progress line. Placed by hand (not in the layout) so its size never
    // grows the tab
    MediaGif {
        id: gif

        readonly property real lineY: columns.y + info.y + progress.y + progress.height / 2
        // Below the header when it holds the player switches on the right
        readonly property real topY: columns.y + info.y + (MprisService.players.length > 1 ? header.height + Config.spacing : 0)

        x: columns.x + info.x + info.width - width - root.gifMargin
        y: topY
        width: root.gifSize
        height: Math.max(0, Math.min(root.gifSize, lineY - Config.spacing * 2 - topY))
        horizontalAlignment: Image.AlignRight
        verticalAlignment: Image.AlignVCenter
    }

    // Round switch to one of the players (outlined when it's the current one)
    component PlayerButton: Rectangle {
        id: playerButton

        required property MprisPlayer modelData
        readonly property bool current: modelData === MprisService.activePlayer

        implicitWidth: Config.fontSizeNormal + Config.padding * 2
        implicitHeight: implicitWidth
        radius: width / 2
        color: current ? Qt.alpha(Config.accentColor, 0.15) : buttonMouse.containsMouse ? Config.cardHoverColor : Qt.alpha(Config.cardHoverColor, 0)
        border.width: current ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        PlayerIcon {
            anchors.centerIn: parent
            player: playerButton.modelData
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MprisService.selectPlayer(playerButton.modelData)
        }
    }

    // Switches between the track info and its lyrics (outlined while on)
    component LyricsButton: Rectangle {
        implicitWidth: Config.fontSizeNormal + Config.padding * 2
        implicitHeight: implicitWidth
        radius: width / 2
        color: root.showLyrics ? Qt.alpha(Config.accentColor, 0.15) : lyricsMouse.containsMouse ? Config.cardHoverColor : Qt.alpha(Config.cardHoverColor, 0)
        border.width: root.showLyrics ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: "\u{f0370}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: root.showLyrics ? Config.accentColor : Config.subtextColor
        }

        MouseArea {
            id: lyricsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: StateService.set("dashboard.lyrics", !root.showLyrics)
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
