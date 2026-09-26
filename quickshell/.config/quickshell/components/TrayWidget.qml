pragma ComponentBehavior: Bound
import QtQuick
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
            // Opens under the icon, at its absolute position on screen
            const globalPos = anchor.mapToGlobal(0, anchor.height);
            sharedMenu.rootMenuHandle = item.menu;
            sharedMenu.anchorX = globalPos.x;
            sharedMenu.anchorY = globalPos.y + Config.padding;
            sharedMenu.open();
        }
    }

    TrayMenu {
        id: sharedMenu
        visible: false

        onVisibleChanged: {
            if (visible)
                TrayService.registerActiveMenu(sharedMenu);
        }
    }

    readonly property var styles: ({
            "row": rowStyle,
            "drawer": drawerStyle
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
        id: drawerStyle
        DrawerStyle {
            model: trayModel
            onItemActivated: sharedMenu.close()
        }
    }
}
