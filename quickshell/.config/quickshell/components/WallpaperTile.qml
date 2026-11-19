pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// Wallpaper thumbnail with its name. Click applies it (the page decides what
// that means), Ctrl+click selects; the ⋮ button shows up on hover, and a
// right click asks for the same menu. A video shows its poster, with a play
// mark in the corner. With a progress (a video Add is scaling down), the
// source's poster shows dimmed under a ring with the percentage and a ✕
// that cancels; nothing else reacts. While `renaming`, the name is a field:
// Enter asks for the new name (renameAccepted), Escape or a click elsewhere
// gives up (renameCancelled); `renameError` says why a name was refused
Item {
    id: root

    required property string path

    property bool current: false
    // Outlined in a surface color when not the current one (the wallpaper
    // picker's keyboard focus)
    property bool highlighted: false
    property bool selected: false
    // Page is in multi-select mode: clicks toggle the selection
    property bool selecting: false
    // Small label in the corner (e.g. "Active" for a theme's wallpaper)
    property string badge: ""
    // The ⋮ button on hover
    property bool showMenu: true
    // The name under the thumbnail (the picker shows it once, below)
    property bool showName: true
    // Just added: an accent outline pulses a few times when it turns on
    property bool isNew: false
    // 0-100 while it's being made (-1: a wallpaper in the library), over
    // progressPoster
    property real progress: -1
    property string progressPoster: ""
    readonly property bool making: progress >= 0
    property bool renaming: false
    property string renameError: ""

    readonly property bool favorite: WallpaperService.isFavorite(path)
    readonly property bool animated: WallpaperService.isVideo(path)
    readonly property bool hovered: tileHover.hovered
    readonly property string displayName: {
        const name = WallpaperService.fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }
    readonly property int badgeSize: Config.fontSizeLarge + Config.padding

    signal activated
    signal selectToggled
    signal menuRequested(Item anchor)
    signal cancelRequested
    signal renameAccepted(string name)
    signal renameCancelled

    implicitHeight: thumb.height + (showName ? nameText.implicitHeight + Config.padding : 0)

    HoverHandler {
        id: tileHover
    }

    ClippingRectangle {
        id: thumb

        width: parent.width
        height: Math.round(width * 9 / 16)
        radius: Config.radiusLarge
        color: Config.surface1Color
        scale: tileMouse.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Image {
            id: image
            anchors.fill: parent
            source: root.making ? (root.progressPoster ? "file://" + root.progressPoster : "") : WallpaperService.thumbSource(root.path)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Config.wallpaperThumbSize
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDuration
                }
            }
        }

        // Selection tint
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Config.accentColor, 0.3)
            visible: root.selected
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            enabled: !root.making
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (root.showMenu && !root.selecting)
                        root.menuRequested(menuButton);
                } else if (root.selecting || (mouse.modifiers & Qt.ControlModifier))
                    root.selectToggled();
                else
                    root.activated();
            }
        }

        // Favorite (md-heart), always shown when set
        Rectangle {
            visible: root.favorite && !root.selecting
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Config.padding
            width: root.badgeSize
            height: width
            radius: width / 2
            color: Qt.alpha(Config.backgroundColor, 0.7)

            Text {
                anchors.centerIn: parent
                text: "\u{f02d1}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.errorColor
            }
        }

        // Being made: dimmed, a ring with the percentage, ✕ to cancel
        Rectangle {
            visible: root.making
            anchors.fill: parent
            color: Qt.alpha(Config.backgroundColor, 0.6)

            ProgressRing {
                id: ring

                anchors.centerIn: parent
                width: Math.round(parent.height * 0.5)
                height: width
                strokeWidth: Math.max(3, Math.round(width / 12))
                value: root.progress
                trackColor: Qt.alpha(Config.textColor, 0.2)
            }

            Text {
                anchors.centerIn: ring
                text: Math.round(root.progress) + "%"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
            }

            // md-close
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Config.padding
                width: root.badgeSize + Config.padding
                height: width
                radius: Config.radius
                color: cancelMouse.containsMouse ? Config.surface2Color : Qt.alpha(Config.backgroundColor, 0.7)

                Text {
                    anchors.centerIn: parent
                    text: "\u{f0156}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: cancelMouse.containsMouse ? Config.errorColor : Config.textColor
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRequested()
                }
            }
        }

        // Animated wallpaper (md-play), always shown; as large as the ⋮ button
        Rectangle {
            visible: root.animated && !root.selecting && !root.making
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Config.padding
            width: root.badgeSize + Config.padding
            height: width
            radius: width / 2
            color: Qt.alpha(Config.backgroundColor, 0.85)

            Text {
                anchors.centerIn: parent
                // The triangle's weight sits left: nudged to look centered
                anchors.horizontalCenterOffset: Math.round(Config.fontSizeLarge / 12)
                text: "\u{f040a}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                color: Config.textColor
            }
        }

        // Text badge (top-left)
        Rectangle {
            visible: root.badge !== ""
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Config.padding
            width: badgeText.implicitWidth + Config.padding * 2
            height: root.badgeSize
            radius: height / 2
            color: Config.accentColor

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textReverseColor
            }
        }

        // Details (md-dots_vertical), on hover; a right click opens it too
        Rectangle {
            id: menuButton

            visible: root.showMenu && (root.hovered || menuMouse.containsMouse) && !root.selecting && !root.making
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Config.padding
            width: root.badgeSize + Config.padding
            height: width
            radius: Config.radius
            color: menuMouse.containsMouse ? Config.surface2Color : Qt.alpha(Config.backgroundColor, 0.7)

            Text {
                anchors.centerIn: parent
                text: "\u{f01d9}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                color: Config.textColor
            }

            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuRequested(parent)
            }
        }

        // Selection check (md-checkbox_marked_circle)
        Text {
            visible: root.selecting
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Config.padding
            text: root.selected ? "\u{f0133}" : "\u{f0130}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIcon
            color: root.selected ? Config.accentColor : Config.textColor
            style: Text.Outline
            styleColor: Qt.alpha(Config.backgroundColor, 0.5)
        }
    }

    // Current wallpaper: accent outline + check, above the clipped content;
    // a highlighted one gets a surface outline
    Rectangle {
        anchors.fill: thumb
        radius: Config.radiusLarge
        color: "transparent"
        border.width: root.current || root.highlighted ? 2 : 0
        border.color: root.current ? Config.accentColor : Config.surface3Color
    }

    // Pulse of a new wallpaper
    Rectangle {
        id: pulse

        anchors.fill: thumb
        radius: Config.radiusLarge
        color: Qt.alpha(Config.accentColor, 0)
        border.width: 2
        border.color: Config.accentColor
        opacity: 0

        SequentialAnimation {
            id: pulseAnim

            loops: 3

            NumberAnimation {
                target: pulse
                property: "opacity"
                to: 1
                duration: Config.animDurationLong
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: pulse
                property: "opacity"
                to: 0
                duration: Config.animDurationLong
                easing.type: Easing.InCubic
            }
        }
    }

    onIsNewChanged: {
        if (isNew)
            pulseAnim.restart();
    }
    Component.onCompleted: {
        if (isNew)
            pulseAnim.restart();
    }

    Rectangle {
        visible: root.current && root.badge === ""
        x: Config.padding
        y: Config.padding
        width: root.badgeSize
        height: width
        radius: width / 2
        color: Config.accentColor

        Text {
            anchors.centerIn: parent
            text: "\u{f012c}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textReverseColor
        }
    }

    Text {
        id: nameText

        visible: root.showName && !root.renaming
        anchors.top: thumb.bottom
        anchors.topMargin: Config.padding
        width: parent.width
        text: root.displayName
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: root.current
        color: root.current ? Config.accentColor : root.hovered ? Config.textColor : Config.subtextColor
    }

    Loader {
        active: root.renaming
        anchors.top: thumb.bottom
        anchors.topMargin: Math.round(Config.padding / 2)
        width: parent.width

        sourceComponent: QsTextField {
            id: nameField

            compact: true
            catchEscape: true
            text: root.displayName
            textColor: root.renameError !== "" ? Config.errorColor : Config.textColor
            border.width: 1
            border.color: root.renameError !== "" ? Config.errorColor : Qt.alpha(Config.accentColor, 0.6)
            // Opens with the whole name selected, ready to type over
            Component.onCompleted: {
                focusInput();
                selectAll();
            }
            onAccepted: root.renameAccepted(text)
            onEscapePressed: root.renameCancelled()
            onTextEdited: root.renameError = ""
            // A click elsewhere: given up
            Connections {
                target: nameField.input

                function onActiveFocusChanged() {
                    if (!nameField.input.activeFocus && root.renaming)
                        root.renameCancelled();
                }
            }

            QsToolTip {
                text: root.renameError
                shown: root.renameError !== ""
                delay: 0
            }
        }
    }
}
