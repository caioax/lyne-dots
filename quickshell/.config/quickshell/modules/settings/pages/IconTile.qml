pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Icon theme card: a few of its icons, in the version for the shell's
// mode (dark or light), and its name. A click uses it (IconService); themes
// you installed get a ⋮ menu to remove them (not the one in use)
Rectangle {
    id: tile

    // { id, name, path, dark, light, removable }
    required property var modelData
    readonly property bool isCurrent: modelData.id === IconService.theme
    readonly property bool hasVariants: modelData.dark !== "" || modelData.light !== ""
    // The theme the previews come from
    readonly property string shown: IconService.variantOf(modelData, ThemeService.isDarkMode)
    readonly property int iconSize: Config.fontSizeIconLarge
    // As many icons as fit with room between them
    readonly property int iconCount: Math.max(3, Math.min(IconService.slots.length, Math.floor((content.width + Config.spacing) / (iconSize + Config.spacing))))

    implicitHeight: content.implicitHeight + Config.padding * 3
    radius: Config.radiusLarge
    color: tileMouse.containsMouse ? Config.surface2Color : Config.surface1Color
    border.width: tile.isCurrent ? 2 : 0
    border.color: Config.accentColor
    scale: tileMouse.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Config.padding * 1.5
        spacing: Config.padding

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing / 2

            Repeater {
                model: IconService.slots.slice(0, tile.iconCount)

                Item {
                    id: slot

                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: tile.iconSize

                    Image {
                        anchors.centerIn: parent
                        width: tile.iconSize
                        height: tile.iconSize
                        sourceSize.width: tile.iconSize * 2
                        sourceSize.height: tile.iconSize * 2
                        source: IconService.previewUrl(tile.shown, slot.modelData)
                        fillMode: Image.PreserveAspectFit
                        // A theme updated on disk keeps its file names
                        cache: false
                        smooth: true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.padding

            Text {
                Layout.fillWidth: true
                // Names with dashes may break after them
                text: tile.modelData.name.replace(/-/g, "-​")
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: tile.isCurrent
                color: tile.isCurrent ? Config.accentColor : Config.textColor
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // Keeps the name clear of the ⋮ button
            Item {
                visible: tile.modelData.removable && !tile.isCurrent
                implicitWidth: menuButton.width
            }

            // md-check_circle
            Text {
                visible: tile.isCurrent
                text: "\u{f05e0}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: Config.accentColor
            }
        }

        Text {
            visible: tile.hasVariants
            text: I18n.tr("Dark and light versions")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }

    MouseArea {
        id: tileMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!tile.isCurrent)
                IconService.setTheme(tile.modelData.id);
        }
    }

    MenuButton {
        id: menuButton

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Config.padding
        visible: tile.modelData.removable && !tile.isCurrent && (tileMouse.containsMouse || hovered || menu.visible)
        onClicked: menu.openAt(menuButton, null)
    }

    ContextMenu {
        id: menu

        items: [
            {
                label: I18n.tr("Remove"),
                icon: "\u{f01b4}", // md-delete
                action: "remove",
                danger: true
            }
        ]
        onTriggered: IconService.remove(tile.modelData.id)
    }
}
