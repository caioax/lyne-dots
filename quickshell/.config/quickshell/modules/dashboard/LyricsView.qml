pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "../../components/"

// Lyrics of the active track. Synced ones follow the song: the current line
// is highlighted and kept in the middle, the others fade with distance, and
// clicking a line seeks there. Scrolling by hand pauses the follow for a bit
Item {
    id: root

    // Shown to the user: LyricsService only looks lyrics up while true
    property bool active: false

    onActiveChanged: active ? LyricsService.acquire() : LyricsService.release()
    Component.onDestruction: {
        if (active)
            LyricsService.release();
    }

    readonly property bool hasLines: LyricsService.status === "synced" || LyricsService.status === "plain"
    // Follows the current line unless the user scrolled recently
    property bool following: true

    function recenter() {
        const item = repeater.itemAt(LyricsService.currentIndex);
        const target = item ? item.y + item.height / 2 - flick.height / 2 : 0;
        flick.contentY = Math.max(0, Math.min(target, flick.contentHeight - flick.height));
    }

    Connections {
        target: LyricsService

        function onCurrentIndexChanged() {
            if (root.following)
                root.recenter();
        }

        function onLinesChanged() {
            root.following = true;
        }
    }

    Timer {
        id: resumeFollow
        interval: 3000
        onTriggered: {
            root.following = true;
            root.recenter();
        }
    }

    // ==================== STATES ====================
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: !root.hasLines
        spacing: Config.padding

        Spinner {
            Layout.alignment: Qt.AlignHCenter
            visible: LyricsService.status === "loading"
            running: visible
            color: Config.subtextColor
        }

        Text {
            Layout.fillWidth: true
            visible: LyricsService.status !== "loading"
            text: {
                switch (LyricsService.status) {
                case "instrumental":
                    return "\u{f075a}  Instrumental";
                case "none":
                    return "No lyrics found";
                case "error":
                    return "Couldn't reach LRCLIB or NetEase";
                default:
                    return "";
                }
            }
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    // ==================== LINES ====================
    Flickable {
        id: flick

        // Share of the height that fades out at the top and the bottom, so
        // the lines cut by the edges melt away
        readonly property real fade: 0.3

        anchors.fill: parent
        visible: root.hasLines
        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: flick.width
                height: flick.height
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha("black", 0)
                    }
                    GradientStop {
                        position: flick.fade
                        color: "black"
                    }
                    GradientStop {
                        position: 1 - flick.fade
                        color: "black"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha("black", 0)
                    }
                }
            }
        }
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: root.following

            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Easing.OutCubic
            }
        }

        onMovementStarted: {
            root.following = false;
            resumeFollow.stop();
        }
        onMovementEnded: resumeFollow.restart()

        // Column, not ListView: wrapped lines change height after creation
        Column {
            id: column

            // The lines only get their place after a layout pass
            onPositioningComplete: {
                if (root.following)
                    root.recenter();
            }

            width: flick.width
            spacing: Config.padding
            // Room so the first and last lines can reach the middle
            topPadding: LyricsService.synced ? flick.height / 2 : 0
            bottomPadding: LyricsService.synced ? flick.height / 2 : 0

            Repeater {
                id: repeater
                model: LyricsService.lines

                Text {
                    id: line

                    required property var modelData
                    required property int index
                    readonly property bool current: index === LyricsService.currentIndex
                    readonly property int distance: Math.abs(index - LyricsService.currentIndex)

                    width: column.width
                    text: modelData.text !== "" ? modelData.text : "\u{f075a}"
                    font.family: Config.font
                    font.pixelSize: current ? Config.fontSizeNormal : Config.fontSizeSmall
                    font.bold: current
                    color: current ? Config.accentColor : lineMouse.containsMouse && LyricsService.synced ? Config.textColor : Config.subtextColor
                    opacity: !LyricsService.synced || current ? 1 : Math.max(0.35, 1 - distance * 0.18)
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }

                    MouseArea {
                        id: lineMouse
                        anchors.fill: parent
                        enabled: LyricsService.synced
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.following = true;
                            LyricsService.seekTo(line.index);
                        }
                    }
                }
            }
        }
    }
}
