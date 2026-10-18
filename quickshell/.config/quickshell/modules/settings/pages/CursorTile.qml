pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Cursor theme card: its arrow, hand, text and wait cursors, and its name.
// A click uses it (CursorService); themes you installed get a ⋮ menu to
// remove them (not the one in use)
Rectangle {
    id: tile

    // { id, name, path, hyprcursor, removable }
    required property var modelData
    readonly property bool isCurrent: modelData.id === CursorService.theme
    // Shown at the size closest to the icons around them
    readonly property int shapeSize: Config.fontSizeIconLarge

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
            spacing: Config.spacing

            Repeater {
                model: CursorService.shapes

                Item {
                    id: shape

                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: tile.shapeSize

                    Image {
                        anchors.centerIn: parent
                        width: tile.shapeSize
                        height: tile.shapeSize
                        source: CursorService.previewUrl(tile.modelData.id, shape.modelData, 32)
                        fillMode: Image.PreserveAspectFit
                        // Made again when the theme changes on disk
                        cache: false
                        smooth: true
                        mipmap: true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.padding

            Text {
                Layout.fillWidth: true
                // Names like Bibata-Original-Classic-Right may break after
                // their dashes
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
            visible: tile.modelData.hyprcursor
            text: I18n.tr("hyprcursor too")
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
                CursorService.setTheme(tile.modelData.id);
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
        onTriggered: CursorService.remove(tile.modelData.id)
    }
}
