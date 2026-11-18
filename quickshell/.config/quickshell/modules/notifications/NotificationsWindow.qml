pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../../components/"

// One per bar; shows itself while NotificationService.historyScreen names
// its screen. Opens under the bell, or at the right of the screen when the
// bell is off (bar.showNotifications) and the IPC opened it
QsPopupWindow {
    id: root

    readonly property bool wanted: NotificationService.historyScreen !== "" && NotificationService.historyScreen === (screen?.name ?? "")

    popupWidth: Config.fontSizeNormal * 30
    popupMaxHeight: screen ? screen.height - Config.barReservedHeight - Config.spacing * 2 : 820
    anchorSide: "right"
    moduleName: "Notifications"
    contentImplicitHeight: loader.implicitHeight
    visible: false

    onWantedChanged: {
        // Next tick: showing it in this handler re-reads `screen`, which
        // `wanted` depends on (binding loop)
        if (wanted)
            Qt.callLater(reopen);
        else
            closeWindow();
    }

    // Closed from the popup itself (Escape, a click outside)
    onClosing: {
        if (wanted)
            NotificationService.closeHistory();
    }

    Loader {
        id: loader
        width: parent.width
        active: root.visible
        sourceComponent: Component {
            NotificationHistory {
                availableHeight: root.contentMaxHeight
                onCloseWindow: root.closeWindow()
            }
        }
    }
}
