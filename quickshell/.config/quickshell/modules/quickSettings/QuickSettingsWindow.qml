pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"
import "./pages/"

QsPopupWindow {
    id: root

    popupWidth: 420
    popupMaxHeight: 820
    anchorSide: "right"
    moduleName: "QuickSettings"
    contentImplicitHeight: pageStack.children[pageStack.currentIndex]?.implicitHeight ?? popupMaxHeight - 32

    onClosing: pageStack.currentIndex = 0

    StackLayout {
        id: pageStack
        anchors.fill: parent
        currentIndex: 0

        // ==========================
        // PAGE 0: DASHBOARD
        // ==========================
        DashboardPage {
            availableHeight: root.popupMaxHeight - 32
            onCloseWindow: root.closeWindow()
        }

        // ==========================
        // PAGE 1: WI-FI
        // ==========================
        WifiPage {
            availableHeight: root.popupMaxHeight - 32
            onBackRequested: pageStack.currentIndex = 0
            onPasswordRequested: ssid => {
                wifiPasswordPage.targetSsid = ssid;
                pageStack.currentIndex = 2;
            }
        }

        // ==========================
        // PAGE 2: WI-FI PASSWORD
        // ==========================
        WifiPasswordPage {
            id: wifiPasswordPage
            onCancelled: pageStack.currentIndex = 1
            onConnectClicked: password => {
                NetworkService.connect(targetSsid, password);
                pageStack.currentIndex = 1;
            }
        }

        // ==========================
        // PAGE 3: BLUETOOTH
        // ==========================
        BluetoothPage {
            availableHeight: root.popupMaxHeight - 32
            onBackRequested: pageStack.currentIndex = 0
        }

        // ==========================
        // PAGE 4: NIGHT LIGHT
        // ==========================
        NightLightPage {
            onBackRequested: pageStack.currentIndex = 0
        }

        // ==========================
        // PAGE 5: THEME
        // ==========================
        ThemePage {
            availableHeight: root.popupMaxHeight - 32
            onBackRequested: pageStack.currentIndex = 0
            onCloseWindow: root.closeWindow()
        }

        // ==========================
        // PAGE 6: SOUND
        // ==========================
        SoundPage {
            onBackRequested: pageStack.currentIndex = 0
        }
    }
}
