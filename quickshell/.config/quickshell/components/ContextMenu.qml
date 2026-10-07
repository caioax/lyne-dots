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

    // Opens next to `anchor` (the ⋮ button): below it, or above it when it
    // doesn't fit there, kept inside the window
    function openAt(anchor: Item, menuTarget) {
        target = menuTarget;
        _submenu = null;
        _anchor = anchor;
        // The height below must already be the root menu's, not a submenu's
        menuColumn.forceLayout();
        // Overlay.overlay stays null for a menu created outside a window (a
        // row built while its popup was closed): use the anchor's window root
        let rootItem = anchor;
        while (rootItem.parent)
            rootItem = rootItem.parent;
        parent = rootItem;
        const pos = anchor.mapToItem(parent, 0, 0);
        _above = pos.y + anchor.height + Config.padding + height > parent.height - Config.spacing && pos.y - Config.padding - height >= Config.spacing;
        _place();
        open();
    }

    // Also on resize, so an opened submenu grows away from the button and
    // stays inside the window
    function _place() {
        if (!_anchor || !parent)
            return;
        const pos = _anchor.mapToItem(parent, 0, 0);
        const wanted = _above ? pos.y - Config.padding - height : pos.y + _anchor.height + Config.padding;
        x = Math.max(Config.spacing, Math.min(pos.x + _anchor.width - width, parent.width - width - Config.spacing));
        y = Math.max(Config.spacing, Math.min(wanted, parent.height - height - Config.spacing));
    }

    property Item _anchor: null
    property bool _above: false

    onHeightChanged: _place()

    width: Config.fontSizeNormal * 16
    // Scrolls when taller than the window
    height: parent ? Math.min(implicitHeight, parent.height - Config.spacing * 2) : implicitHeight
    padding: Math.round(Config.padding / 2)

    background: Rectangle {
        radius: Config.radiusLarge
        color: Config.cardColor
        border.width: 1
        border.color: Config.surface2Color
    }

    contentItem: Flickable {
        implicitHeight: menuColumn.implicitHeight
        contentHeight: menuColumn.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: menuColumn

            width: parent.width
            spacing: Math.round(Config.padding / 3)

            // Back from a submenu (md-chevron_left)
            MenuRow {
                visible: root._submenu !== null
                label: root._submenu?.label ?? ""
                icon: "\u{f0141}"
                muted: true
                onClicked: root._submenu = null
            }

            Repeater {
                model: root._submenu ? root._submenu.children : root.items

                MenuRow {
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
    }

    component MenuRow: Rectangle {
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
