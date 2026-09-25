pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "../../components/"

Rectangle {
    id: root

    property bool dismissed: false
    // Shows the ✕ (while paused) that hides the card until something plays
    property bool dismissible: true
    // Clicking the cover emits openRequested (to show the full player)
    property bool openable: false

    // Shows the dashboard's GIF beside the controls
    property bool showGif: false

    signal openRequested

    visible: MprisService.hasPlayer && !dismissed

    Connections {
        target: MprisService
        function onIsPlayingChanged() {
            if (MprisService.isPlaying)
                root.dismissed = false;
        }
    }

    Layout.fillWidth: true
    implicitHeight: contentLayout.implicitHeight + contentLayout.anchors.topMargin + contentLayout.anchors.bottomMargin
    radius: Config.radiusLarge
    color: Config.cardColor

    // --- BLURRED BACKGROUND ---
    CoverBackdrop {
        anchors.fill: parent
        radius: Config.radiusLarge
    }

    // --- DISMISS BUTTON ---
    Rectangle {
        visible: root.dismissible && !MprisService.isPlaying
        z: 10
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        width: 22
        height: 22
        radius: 11
        color: dismissMouse.containsMouse ? Config.surface3Color : Config.surface2Color
        opacity: dismissMouse.containsMouse ? 1.0 : 0.7

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: Config.font
            font.pixelSize: 12
            color: Config.textColor
        }

        MouseArea {
            id: dismissMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.dismissed = true
        }
    }

    // --- MAIN LAYOUT ---
    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        spacing: 8

        // --- TOP: Cover + Info ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Album Cover
            Item {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80

                Rectangle {
                    anchors.fill: parent
                    radius: Config.radius
                    color: Config.surface2Color
                }

                Image {
                    id: coverSource
                    anchors.fill: parent
                    source: MprisService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: Config.radius
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: coverSource
                    maskSource: coverMask
                }

                Text {
                    visible: MprisService.artUrl === ""
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.subtextColor
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.openable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openRequested()
                }
            }

            // Info + Controls
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                // Title (marquee)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: titleText.implicitHeight
                    clip: true

                    Text {
                        id: titleText
                        text: MprisService.title
                        color: Config.textColor
                        font.bold: true
                        font.pixelSize: Config.fontSizeNormal
                        width: parent.width

                        property bool needsScroll: implicitWidth > parent.width
                        property real scrollOffset: 0
                        property real overflow: Math.max(0, implicitWidth - parent.width)

                        x: needsScroll ? -scrollOffset : 0

                        SequentialAnimation {
                            running: titleText.needsScroll
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: 2500
                            }
                            NumberAnimation {
                                target: titleText
                                property: "scrollOffset"
                                from: 0
                                to: titleText.overflow
                                duration: titleText.overflow * 40
                            }
                            PauseAnimation {
                                duration: 2500
                            }
                            NumberAnimation {
                                target: titleText
                                property: "scrollOffset"
                                to: 0
                                duration: titleText.overflow * 40
                            }
                        }
                    }
                }

                // Artist - Player
                Text {
                    text: MprisService.identity !== "" ? MprisService.artist + "  -  " + MprisService.identity : MprisService.artist
                    color: Config.subtextColor
                    font.pixelSize: Config.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    opacity: 0.8
                }

                MediaControls {
                    Layout.topMargin: 2
                }
            }

            // The dashboard's GIF, beside the controls
            MediaGif {
                visible: root.showGif && DashboardService.showGif
                Layout.preferredWidth: Config.fontSizeIconLarge * 4
                Layout.preferredHeight: Config.fontSizeIconLarge * 3
                Layout.alignment: Qt.AlignBottom
            }
        }

        // --- BOTTOM: Progress section ---
        MediaProgress {
            Layout.fillWidth: true
        }
    }

    // --- SCROLL WHEEL FOR VOLUME ---
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const step = 0.05;
            if (wheel.angleDelta.y > 0)
                MprisService.setVolume(MprisService.volume + step);
            else
                MprisService.setVolume(MprisService.volume - step);
        }
    }
}
