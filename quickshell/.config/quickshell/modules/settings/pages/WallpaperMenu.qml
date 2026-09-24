pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services

// ⋮ menu of a wallpaper tile. `items` is a list of { label, icon, action,
// danger? }; "add-to-theme" swaps the list for the theme names
Popup {
    id: root

    property string path
    property var items: []
    property bool pickingTheme: false

    signal triggered(string action, string path)
    signal themePicked(string theme, string path)

    // Opens next to `anchor` (the ⋮ button), kept inside the window
    function openAt(anchor: Item, wallpaperPath: string) {
        path = wallpaperPath;
        pickingTheme = false;
        const pos = anchor.mapToItem(parent, anchor.width, 0);
        x = Math.min(pos.x - width, parent.width - width - Config.spacing);
        y = Math.min(pos.y + anchor.height + Config.padding, parent.height - implicitHeight - Config.spacing);
        open();
    }

    parent: Overlay.overlay
    width: Config.fontSizeNormal * 15
    padding: Math.round(Config.padding / 2)

    background: Rectangle {
        radius: Config.radiusLarge
        color: Config.surface0Color
        border.width: 1
        border.color: Config.surface2Color
    }

    contentItem: Column {
        spacing: Math.round(Config.padding / 3)

        // Back from the theme list (md-chevron_left)
        MenuItem {
            visible: root.pickingTheme
            label: "Add to theme"
            icon: "\u{f0141}"
            muted: true
            onClicked: root.pickingTheme = false
        }

        Repeater {
            model: root.pickingTheme ? ThemeService.availableThemes.map(t => ({
                        label: ThemeService.themePreviews[t]?.name ?? t,
                        icon: "\u{f03d8}",
                        action: t
                    })) : root.items

            MenuItem {
                required property var modelData

                label: modelData.label
                icon: modelData.icon
                danger: modelData.danger ?? false
                // md-chevron_right
                trailingIcon: modelData.action === "add-to-theme" ? "\u{f0142}" : ""
                onClicked: {
                    if (root.pickingTheme) {
                        root.themePicked(modelData.action, root.path);
                        root.close();
                    } else if (modelData.action === "add-to-theme") {
                        root.pickingTheme = true;
                    } else {
                        root.triggered(modelData.action, root.path);
                        root.close();
                    }
                }
            }
        }
    }

    component MenuItem: Rectangle {
        id: item

        property string label
        property string icon
        property string trailingIcon
        property bool danger: false
        property bool muted: false

        signal clicked

        width: parent?.width ?? 0
        implicitHeight: row.implicitHeight + Config.padding * 2
        radius: Config.radius
        color: itemMouse.containsMouse ? (danger ? Qt.alpha(Config.errorColor, 0.15) : Config.surface1Color) : "transparent"

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: Config.padding * 2
            anchors.rightMargin: Config.padding * 2
            spacing: Config.spacing

            Text {
                text: item.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                color: item.danger ? Config.errorColor : item.muted ? Config.subtextColor : Config.textColor
            }

            Text {
                Layout.fillWidth: true
                text: item.label
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: item.muted
                color: item.danger ? Config.errorColor : item.muted ? Config.subtextColor : Config.textColor
            }

            Text {
                visible: item.trailingIcon !== ""
                text: item.trailingIcon
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.subtextColor
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }
    }
}
