pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import "tray"

// Bar tray: the status notifier items (TrayModel) drawn by the tray style,
// plus the context menu shared by the style's icons
Item {
    id: root

    TrayModel {
        id: trayModel
        onMenuRequested: (item, anchor) => {
            // Under the icon. Positions inside a layer are relative to it,
            // so add the layer's own offset (the overflow popup has one;
            // the bar spans the screen edge)
            const win = anchor.QsWindow.window;
            const pos = anchor.mapToItem(null, 0, 0);
            sharedMenu.companion = win !== root.QsWindow.window ? win : null;
            sharedMenu.rootMenuHandle = item.menu;
            sharedMenu.anchorX = pos.x + (win?.margins?.left ?? 0);
            sharedMenu.anchorY = (win?.margins?.top ?? 0) + pos.y + anchor.height + Config.padding;
            sharedMenu.anchorBottom = (win?.margins?.bottom ?? 0) + (win?.height ?? 0) - pos.y + Config.padding;
            sharedMenu.open();
        }
    }

    TrayMenu {
        id: sharedMenu
        visible: false

        onDismissed: reason => trayModel.menuClosed(reason)
        onVisibleChanged: {
            if (visible)
                TrayService.registerActiveMenu(sharedMenu);
        }
    }

    readonly property var styles: ({
            "row": rowStyle,
            "drawer": drawerStyle,
            "overflow": overflowStyle
        })

    implicitWidth: style.implicitWidth
    implicitHeight: style.implicitHeight

    Loader {
        id: style
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.styles[Config.barTrayStyle] ?? drawerStyle
    }

    Component {
        id: rowStyle
        RowStyle {
            model: trayModel
            onItemActivated: sharedMenu.close()
        }
    }

    Component {
        id: overflowStyle
        OverflowStyle {
            model: trayModel
            onItemActivated: sharedMenu.close()
        }
    }

    Component {
        id: drawerStyle
        DrawerStyle {
            model: trayModel
            onItemActivated: sharedMenu.close()
        }
    }
}
