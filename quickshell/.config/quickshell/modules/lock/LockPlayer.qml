pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"
import "../dashboard/"

// Now playing on the lock screen: the round cover inside the cava ring,
// the track, the wavy progress and the controls, over the blurred cover.
// Shows up once something plays and stays after a pause (to resume it);
// cava runs only while playing (and the dashboard visualizer is on)
Rectangle {
    id: root

    readonly property int coverSize: Config.fontSizeIconLarge * 3
    // Something played during this lock (stays true after a pause)
    property bool seen: false
    readonly property bool wanted: LockService.showMedia && MprisService.hasPlayer && seen
    readonly property bool visualizing: wanted && MprisService.isPlaying

    Connections {
        target: MprisService

        function onIsPlayingChanged() {
            if (MprisService.isPlaying)
                root.seen = true;
        }
    }

    visible: opacity > 0
    opacity: wanted ? 1 : 0
    implicitWidth: Config.fontSizeNormal * 28
    implicitHeight: row.implicitHeight + Config.padding * 4
    radius: Config.radiusLarge * 1.5
    color: Config.cardColor
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    // acquire/release pair through a guard: change handlers don't run for
    // the initial value
    property bool held: false
    function syncCava() {
        if (visualizing && !held) {
            held = true;
            CavaService.acquire();
        } else if (!visualizing && held) {
            held = false;
            CavaService.release();
        }
    }
    onVisualizingChanged: syncCava()
    Component.onCompleted: {
        seen = MprisService.isPlaying;
        syncCava();
    }
    Component.onDestruction: {
        if (held)
            CavaService.release();
    }

    CoverBackdrop {
        anchors.fill: parent
        radius: root.radius
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Config.padding * 2
        spacing: Config.spacing * 2

        CoverVisualizer {
            Layout.alignment: Qt.AlignVCenter
            coverSize: root.coverSize
            coverRadius: root.coverSize / 2
            ring: CavaService.enabled && CavaService.available ? Config.spacing * 4 : Config.padding
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
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.subtextColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Config.padding

            Text {
                Layout.fillWidth: true
                text: MprisService.title
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                font.bold: true
                color: Config.textColor
            }

            Text {
                Layout.fillWidth: true
                text: MprisService.artist
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
            }

            MediaProgress {
                Layout.fillWidth: true
                wavy: true
            }

            MediaControls {
                Layout.alignment: Qt.AlignHCenter
                round: true
            }
        }
    }
}
