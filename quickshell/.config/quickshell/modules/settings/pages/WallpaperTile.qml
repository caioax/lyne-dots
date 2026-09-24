pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Wallpaper thumbnail with its name. Click applies it (the page decides what
// that means), Ctrl+click selects; the ⋮ button shows up on hover
Item {
    id: root

    required property string path

    property bool current: false
    property bool selected: false
    // Page is in multi-select mode: clicks toggle the selection
    property bool selecting: false
    // Small label in the corner (e.g. "Active" for a theme's wallpaper)
    property string badge: ""

    readonly property bool favorite: WallpaperService.isFavorite(path)
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

    implicitHeight: thumb.height + nameText.implicitHeight + Config.padding

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
            source: "file://" + root.path
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
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
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (root.selecting || (mouse.modifiers & Qt.ControlModifier))
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

        // Details (md-dots_vertical), on hover
        Rectangle {
            visible: (root.hovered || menuMouse.containsMouse) && !root.selecting
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

    // Current wallpaper: outline + check, above the clipped content
    Rectangle {
        anchors.fill: thumb
        radius: Config.radiusLarge
        color: "transparent"
        border.width: root.current ? 2 : 0
        border.color: Config.accentColor
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
}
