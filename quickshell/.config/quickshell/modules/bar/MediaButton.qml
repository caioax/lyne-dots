pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Now playing, compact: round cover and a mirrored spectrum (cava while the
// dashboard visualizer is on, a looping equalizer otherwise); the title
// slides out on hover. Click opens the dashboard's Media tab, middle click
// plays/pauses, right click skips and the wheel changes the volume
BarButton {
    id: root

    readonly property int maxTitleWidth: Config.fontSizeNormal * 14
    readonly property int artSize: Config.barButtonHeight - Config.padding
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    // Spectrum: `half` bars each side of the tallest center one (bass in the
    // middle, higher bands outwards)
    readonly property int half: 3
    readonly property real barMaxHeight: artSize
    readonly property bool cava: CavaService.enabled && CavaService.available
    // Cava band range folded into each level, center first
    readonly property var bandRanges: [[0, 3], [3, 8], [8, 16], [16, 30]]

    readonly property bool visualizing: visible && cava && MprisService.isPlaying
    // acquire/release only on real changes (a handler doesn't run for the
    // initial value)
    property bool held: false
    function sync(): void {
        if (visualizing === held)
            return;
        held = visualizing;
        visualizing ? CavaService.acquire() : CavaService.release();
    }
    onVisualizingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held)
            CavaService.release();
    }

    // Levels 0-1, center first: the peak of each range (an average flattens
    // the few bars into the same calm height), same curve as the Media tab
    readonly property var levels: {
        const values = CavaService.values;
        return bandRanges.map(r => Math.pow(Math.max(...values.slice(r[0], r[1])), 0.6));
    }

    visible: Config.barShowMedia && DashboardService.hasTab("media") && MprisService.hasPlayer
    active: DashboardService.screen === screenName && DashboardService.tab === "media"
    contentItem: content
    onClicked: DashboardService.toggle("media", screenName)
    onMiddleClicked: MprisService.playPause()
    onRightClicked: MprisService.next()

    // A handler, not a MouseArea: one on top of the button's own resets the
    // pointing hand cursor
    WheelHandler {
        onWheel: event => {
            const step = 0.05;
            MprisService.setVolume(MprisService.volume + (event.angleDelta.y > 0 ? step : -step));
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
            radius: width / 2
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

        // Mirrored spectrum, centered vertically
        Row {
            Layout.alignment: Qt.AlignVCenter
            height: root.barMaxHeight
            spacing: Math.round(Config.padding / 3)

            Repeater {
                model: root.half * 2 + 1

                Rectangle {
                    id: spectrumBar

                    required property int index
                    // Distance from the center bar: 0 = bass
                    readonly property int band: Math.abs(index - root.half)
                    // Looping stand-in while cava is off
                    property real fake: 0.3
                    readonly property real level: root.cava ? (root.levels[band] ?? 0) : fake

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Config.padding / 2)
                    height: Math.max(width, root.barMaxHeight * (0.1 + 0.9 * (MprisService.isPlaying ? level : 0)))
                    radius: width / 2
                    color: MprisService.isPlaying ? Config.accentColor : Config.subtextColor

                    Behavior on height {
                        NumberAnimation {
                            duration: Config.animDurationShort
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }

                    SequentialAnimation on fake {
                        running: !root.cava && MprisService.isPlaying && root.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1 - spectrumBar.band * 0.2
                            duration: Config.animDurationLong - spectrumBar.band * Config.animDurationShort / 2
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0.3
                            duration: Config.animDurationLong + spectrumBar.band * Config.animDurationShort / 2
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }

        // Title · artist, slides out on hover
        Item {
            Layout.preferredWidth: root.hovered || root.active ? Math.min(title.implicitWidth, root.maxTitleWidth) : 0
            Layout.preferredHeight: title.implicitHeight
            // Drops out of the layout (and its spacing) once collapsed
            visible: Layout.preferredWidth > 0
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.maxTitleWidth)
                text: MprisService.title + (MprisService.artist && MprisService.artist !== "Unknown" ? "  ·  " + MprisService.artist : "")
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: MprisService.isPlaying ? Config.textColor : Config.subtextColor
                elide: Text.ElideRight
            }
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
