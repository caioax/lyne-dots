pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.config
import qs.services

Rectangle {
    id: root

    property bool dismissed: false
    readonly property bool hasProgress: MprisService.positionSupported && MprisService.length > 0

    function formatTime(seconds: real): string {
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

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
    color: Config.surface0Color

    // --- BLURRED BACKGROUND ---
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: Config.radiusLarge
            }
        }

        Image {
            id: bgSource
            anchors.fill: parent
            source: MprisService.artUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
        }

        FastBlur {
            anchors.fill: parent
            source: bgSource
            radius: 48
            opacity: 0.35
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.3
        }
    }

    // --- DISMISS BUTTON ---
    Rectangle {
        visible: !MprisService.isPlaying
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

                // Controls
                RowLayout {
                    spacing: 8
                    Layout.topMargin: 2

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
                        width: 36
                        height: 36
                        radius: 18
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
                            font.pixelSize: Config.fontSizeLarge
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
                }
            }
        }

        // --- BOTTOM: Progress section ---
        RowLayout {
            visible: root.hasProgress
            Layout.fillWidth: true
            spacing: 8

            // Current time
            Text {
                text: root.formatTime(progressMouse.pressed ? progressBar.dragRatio * MprisService.length : MprisService.position)
                font.family: Config.font
                font.pixelSize: 10
                color: Config.subtextColor
                opacity: 0.7
                Layout.preferredWidth: 30
            }

            // Progress bar
            Item {
                id: progressBar
                Layout.fillWidth: true
                Layout.preferredHeight: progressMouse.containsMouse || progressMouse.pressed ? 6 : 4

                property bool wasPlaying: false
                property real dragRatio: 0

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Config.animDurationShort
                        easing.type: Easing.OutQuad
                    }
                }

                // Track background
                Rectangle {
                    anchors.fill: parent
                    radius: parent.height / 2
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

                // Handle dot
                Rectangle {
                    width: progressMouse.containsMouse || progressMouse.pressed ? 10 : 6
                    height: width
                    radius: width / 2
                    color: Config.accentColor
                    y: (parent.height - height) / 2
                    x: Math.max(0, progressFill.width - (width / 2))
                    opacity: progressMouse.containsMouse || progressMouse.pressed ? 1.0 : 0.0

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
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
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
                font.pixelSize: 10
                color: Config.subtextColor
                opacity: 0.7
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
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

    // --- CONTROL BUTTON COMPONENT ---
    component ControlButton: Item {
        id: btn
        property string icon: ""
        property bool active: false
        signal clicked

        width: 28
        height: 28
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
            width: 4
            height: 4
            radius: 2
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
