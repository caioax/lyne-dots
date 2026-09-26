pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import ".."

// Tray style "overflow": one button in the bar; the icons live in a grid
// popup under it
BarButton {
    id: root

    required property var model

    // Tiles per row in the popup
    property int columns: 4
    readonly property var items: model.items
    readonly property int tileSize: Config.fontSizeIcon + Config.padding * 2
    readonly property int tileGap: Math.round(Config.padding / 2)

    signal itemActivated

    visible: model.hasItems
    implicitWidth: Config.barButtonHeight
    active: popup.visible
    onClicked: popup.visible ? popup.closeWindow() : popup.reopen()

    // md-chevron_down / md-chevron_up: points where the popup opens, flips
    // while it is open
    Text {
        anchors.centerIn: parent
        text: Config.barOnBottom ? "\u{f0143}" : "\u{f0140}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: root.active ? Config.accentColor : Config.subtextColor
        rotation: root.active ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    QsPopupWindow {
        id: popup

        readonly property int shownColumns: Math.max(1, Math.min(root.columns, root.items.length))

        visible: false
        anchorItem: root
        moduleName: "Tray"
        // QsPopupWindow insets its content by 16 on every side
        popupWidth: shownColumns * root.tileSize + (shownColumns - 1) * root.tileGap + 32
        contentImplicitHeight: grid.implicitHeight

        Connections {
            target: root.model

            // Nothing left to show
            function onHasItemsChanged() {
                if (!root.model.hasItems)
                    popup.closeWindow();
            }

            // A menu opened from the grid took the focus grab: stay open
            // for Esc (back to the grid), close with it otherwise
            function onMenuClosed(reason) {
                if (!popup.holdOpen)
                    return;
                popup.holdOpen = false;
                if (reason === "escape")
                    popup.regrab();
                else
                    popup.closeWindow();
            }
        }

        Grid {
            id: grid

            anchors.horizontalCenter: parent.horizontalCenter
            columns: popup.shownColumns
            spacing: root.tileGap

            Repeater {
                model: root.items

                delegate: TrayItem {
                    required property var modelData
                    model: root.model
                    item: modelData
                    size: root.tileSize
                    iconSize: Config.fontSizeIcon
                    round: false
                    onMenuRequested: popup.holdOpen = true
                    onActivated: {
                        popup.closeWindow();
                        root.itemActivated();
                    }
                }
            }
        }
    }
}
