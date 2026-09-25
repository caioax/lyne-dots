pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// App (or clipboard entry) as a tile: icon over the name. Copied images show
// their thumbnail over their size, copied text fills the tile. Same signals
// as AppRow (clicks go out as `activated`, ⋮ on hover or right click ask for
// the menu)
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    readonly property bool hovered: tileHover.hovered
    readonly property int iconSize: Config.fontSizeIconLarge + Config.padding * 2
    readonly property var clipEntry: modelData?.clip ?? null
    readonly property string thumbnail: clipEntry?.kind === "image" ? ClipboardService.thumbnails[clipEntry.id] ?? "" : ""
    readonly property bool textClip: clipEntry !== null && clipEntry.kind !== "image" && clipEntry.kind !== "color"

    signal activated
    signal menuRequested(Item anchor)

    implicitHeight: iconSize + nameText.implicitHeight + Config.padding * 5

    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        // Rest is a see-through surface0, not "transparent" (black at alpha
        // 0), so the hover fade doesn't pass through a dark tint
        color: root.selected ? Config.surface1Color : root.hovered ? Config.surface0Color : Qt.alpha(Config.surface0Color, 0)
        border.width: root.selected ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    HoverHandler {
        id: tileHover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.menuRequested(menuButton);
            else
                root.activated();
        }
    }

    Column {
        anchors.centerIn: parent
        visible: !root.textClip
        width: parent.width - Config.padding * 2
        spacing: Config.padding

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.clipEntry
            width: root.iconSize
            height: width
            source: root.clipEntry ? "" : "image://icon/" + (root.modelData?.icon || "application-x-executable")
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
        }

        // Copied image: its thumbnail (the glyph until it's decoded);
        // copied color: a swatch
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.clipEntry !== null
            width: parent.width
            height: root.iconSize
            radius: Config.radiusLarge
            color: root.clipEntry?.kind === "color" ? root.clipEntry.color : root.selected ? Config.surface2Color : Config.surface1Color
            border.width: root.clipEntry?.kind === "color" ? 1 : 0
            border.color: Config.surface2Color

            Image {
                anchors.fill: parent
                visible: root.thumbnail !== ""
                source: root.thumbnail
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                anchors.centerIn: parent
                visible: root.thumbnail === "" && root.clipEntry?.kind !== "color"
                text: root.modelData?.glyph ?? ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
            }
        }

        Text {
            id: nameText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            // Images are named by their size
            text: root.clipEntry?.kind === "image" && root.clipEntry.width > 0 ? root.clipEntry.width + "×" + root.clipEntry.height : root.modelData?.name ?? ""
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: root.selected
            color: Config.textColor
        }
    }

    // Copied text: the text itself, as many lines as fit
    Text {
        visible: root.textClip
        anchors.fill: parent
        anchors.margins: Math.round(Config.padding * 1.5)
        text: root.modelData?.name ?? ""
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        elide: Text.ElideRight
        maximumLineCount: Math.max(1, Math.floor(height / metrics.lineSpacing))
        verticalAlignment: Text.AlignVCenter
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: root.selected
        color: root.clipEntry?.kind === "link" ? Config.accentColor : Config.textColor

        FontMetrics {
            id: metrics
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
        }
    }

    MenuButton {
        id: menuButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Math.round(Config.padding / 2)
        visible: root.hovered
        onClicked: root.menuRequested(menuButton)
    }
}
