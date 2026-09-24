pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// ⋮ menu. `items` is a list of { label, icon, action, danger?, children? };
// an item with `children` opens them in place, with a back row
Popup {
    id: root

    // Whatever the menu was opened for (a path, an id...), passed back
    property var target
    property var items: []
    property var _submenu: null

    signal triggered(string action, var target)

    // Opens next to `anchor` (the ⋮ button), kept inside the window
    function openAt(anchor: Item, menuTarget) {
        target = menuTarget;
        _submenu = null;
        const pos = anchor.mapToItem(parent, anchor.width, 0);
        x = Math.max(Config.spacing, Math.min(pos.x - width, parent.width - width - Config.spacing));
        y = Math.min(pos.y + anchor.height + Config.padding, parent.height - implicitHeight - Config.spacing);
        open();
    }

    parent: Overlay.overlay
    width: Config.fontSizeNormal * 16
    padding: Math.round(Config.padding / 2)

    background: Rectangle {
        radius: Config.radiusLarge
        color: Config.surface0Color
        border.width: 1
        border.color: Config.surface2Color
    }

    contentItem: Column {
        spacing: Math.round(Config.padding / 3)

        // Back from a submenu (md-chevron_left)
        MenuItem {
            visible: root._submenu !== null
            label: root._submenu?.label ?? ""
            icon: "\u{f0141}"
            muted: true
            onClicked: root._submenu = null
        }

        Repeater {
            model: root._submenu ? root._submenu.children : root.items

            MenuItem {
                required property var modelData

                label: modelData.label
                icon: modelData.icon ?? ""
                danger: modelData.danger ?? false
                // md-chevron_right
                trailingIcon: modelData.children ? "\u{f0142}" : ""
                onClicked: {
                    if (modelData.children) {
                        root._submenu = modelData;
                    } else {
                        root.triggered(modelData.action, root.target);
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
                visible: item.icon !== ""
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
