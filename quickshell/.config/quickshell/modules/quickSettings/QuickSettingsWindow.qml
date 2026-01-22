pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services
import "./pages/"

PopupWindow {
    id: root

    // Configurações de tamanho
    readonly property int contentWidth: 400
    readonly property int defaultHeight: 300
    readonly property int internalMargin: 32
    readonly property int screenMargin: 15

    implicitWidth: contentWidth + screenMargin
    implicitHeight: (pageStack.children[pageStack.currentIndex]?.implicitHeight ?? defaultHeight) + internalMargin

    // Animação suave quando a altura muda (troca de página)
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    color: "transparent"

    property bool isClosing: false
    property bool isOpening: false

    function closeWindow() {
        if (!visible)
            return;
        isClosing = true;
        closeTimer.restart();
    }

    // Timer de saída
    Timer {
        id: closeTimer
        interval: Config.animDuration
        onTriggered: {
            root.visible = false;
            isClosing = false;
            pageStack.currentIndex = 0;
        }
    }

    // --- Foco ---
    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: root.closeWindow()
    }

    Timer {
        id: grapTimer
        interval: 10
        onTriggered: {
            focusGrab.active = true;
            background.forceActiveFocus();
        }
    }

    // Gestão de estado ao abrir/fechar
    onVisibleChanged: {
        if (visible) {
            isClosing = false;
            isOpening = true;
            WindowManagerService.registerOpen("QuickSettings");
            grapTimer.restart();
        } else {
            WindowManagerService.registerClose("QuickSettings");
            pageStack.currentIndex = 0;
            focusGrab.active = false;
            isOpening = false;
        }
    }

    // Layout
    Item {
        anchors.fill: parent

        Rectangle {
            id: background
            width: root.contentWidth
            height: root.implicitHeight
            anchors.centerIn: parent
            color: Config.backgroundColor
            radius: Config.radiusLarge
            clip: true

            transformOrigin: Item.TopRight
            property bool showState: visible && !isClosing && isOpening
            scale: showState ? 1.0 : 0.9
            opacity: showState ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }

            Keys.onEscapePressed: {
                root.closeWindow();
            }

            StackLayout {
                id: pageStack
                anchors.fill: parent
                anchors.margins: 16
                currentIndex: 0

                // ==========================
                // PÁGINA 0: DASHBOARD
                // ==========================
                DashboardPage {
                    onCloseWindow: root.closeWindow()
                }

                // ==========================
                // PÁGINA 1: WI-FI
                // ==========================
                WifiPage {
                    onBackRequested: pageStack.currentIndex = 0
                    onPasswordRequested: ssid => {
                        wifiPasswordPage.targetSsid = ssid;
                        pageStack.currentIndex = 2;
                    }
                }

                // ==========================
                // PÁGINA 2: SENHA WI-FI
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
                // PÁGINA 3: BLUETOOTH
                // ==========================
                BluetoothPage {
                    onBackRequested: pageStack.currentIndex = 0
                }

                // ==========================
                // PÁGINA 4: LUZ NOTURNA
                // ==========================
                NightLightPage {
                    onBackRequested: pageStack.currentIndex = 0
                }
            }
        }
    }
}
