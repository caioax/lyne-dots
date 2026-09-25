pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// One result: an app (icon), an action / calculator result (glyph) or a
// clipboard entry (glyph, or a thumbnail for images), with name and
// description. The selected row gets the accent outline and the ⏎ hint.
// Clicks go out as `activated`; for apps and clipboard entries, the ⋮
// button (on hover) and right click ask for the item's menu
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    property bool showDescription: true
    // A HoverHandler keeps reporting hover while over the ⋮ button
    readonly property bool hovered: rowHover.hovered
    readonly property bool isApp: LauncherService.isApp(modelData)
    // ClipboardService entry, for clipboard items
    readonly property var clipEntry: modelData?.clip ?? null
    readonly property string thumbnail: clipEntry?.kind === "image" ? ClipboardService.thumbnails[clipEntry.id] ?? "" : ""
    readonly property bool hasMenu: isApp || clipEntry !== null
    // Waiting for a second Enter (power actions)
    readonly property bool confirming: !isApp && LauncherService.pendingConfirm === modelData.id
    readonly property string description: confirming ? "Press Enter again to confirm" : modelData?.comment || modelData?.genericName || ""

    signal activated
    signal menuRequested(Item anchor)

    readonly property int iconBoxSize: Config.fontSizeIconLarge + Config.padding * 2

    implicitHeight: iconBoxSize + Config.padding * 2

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
        id: rowHover
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button !== Qt.RightButton)
                root.activated();
            else if (root.hasMenu)
                root.menuRequested(menuButton);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding
        anchors.rightMargin: Config.padding * 2
        spacing: Config.spacing + Config.padding

        ClippingRectangle {
            // Images get a wider box, closer to a screenshot's shape
            Layout.preferredWidth: root.clipEntry?.kind === "image" ? Math.round(root.iconBoxSize * 1.6) : root.iconBoxSize
            Layout.preferredHeight: root.iconBoxSize
            radius: Config.radiusLarge
            color: root.selected ? Config.surface2Color : Config.surface1Color

            Image {
                anchors.fill: parent
                visible: root.thumbnail !== ""
                source: root.thumbnail
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                anchors.centerIn: parent
                visible: !root.isApp && root.thumbnail === ""
                text: root.modelData?.glyph ?? ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: root.confirming ? Config.warningColor : Config.accentColor
            }

            Image {
                anchors.centerIn: parent
                visible: root.isApp
                width: Config.fontSizeIconLarge
                height: width
                source: root.isApp ? "image://icon/" + (root.modelData?.icon || "application-x-executable") : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: Math.round(Config.padding / 3)

            Text {
                width: parent.width
                // Chars matched by the search in accent
                text: LauncherService.highlightedName(root.modelData, Config.accentColor)
                textFormat: Text.StyledText
                elide: Text.ElideRight
                // Copied text without a description line gets two lines
                wrapMode: root.clipEntry && !descriptionText.visible ? Text.Wrap : Text.NoWrap
                maximumLineCount: root.clipEntry && !descriptionText.visible ? 2 : 1
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: root.selected
                color: Config.textColor
            }

            Text {
                id: descriptionText
                width: parent.width
                visible: root.showDescription && root.description !== ""
                text: root.description
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: root.confirming
                color: root.confirming ? Config.warningColor : Config.subtextColor
            }
        }

        MenuButton {
            id: menuButton
            visible: root.hasMenu && root.hovered
            onClicked: root.menuRequested(menuButton)
        }

        // md-keyboard-return
        Text {
            visible: root.selected && !menuButton.visible
            text: "\u{f0311}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: Config.accentColor
        }
    }

}
