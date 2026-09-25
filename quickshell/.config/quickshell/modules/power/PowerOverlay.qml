pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Power menu: dims and blurs every monitor and shows the menu (in the
// power.style template) on the one that was focused. Clicking the backdrop
// closes it, or cancels a countdown
Scope {
    id: root

    // Set a tick after creation so the templates animate in
    property bool ready: false
    readonly property bool shown: ready && PowerService.open

    Component.onCompleted: Qt.callLater(() => ready = true)

    function handleKey(event: KeyEvent): void {
        const pending = PowerService.pendingId !== "";
        switch (event.key) {
        case Qt.Key_Escape:
            if (pending)
                PowerService.cancel();
            else
                PowerService.hide();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            PowerService.request(PowerService.selectedId);
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            PowerService.cancel();
            PowerService.move(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            PowerService.cancel();
            PowerService.move(1);
            break;
        default:
            {
                // Numbers select, letters run
                const actions = PowerService.actions;
                const number = event.key - Qt.Key_1;
                if (number >= 0 && number < Math.min(9, actions.length)) {
                    PowerService.cancel();
                    PowerService.selectedId = actions[number].id;
                    break;
                }
                const action = actions.find(a => a.key === event.text.toUpperCase());
                if (action) {
                    if (PowerService.pendingId !== action.id)
                        PowerService.cancel();
                    PowerService.selectedId = action.id;
                    PowerService.request(action.id);
                }
            }
        }
        event.accepted = true;
    }

    Variants {
        id: windows

        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            // The focused monitor, or the first one if it's unknown
            readonly property bool hasMenu: {
                const name = PowerService.screen;
                const known = Quickshell.screens.some(s => s.name === name);
                return known ? modelData.name === name : modelData === Quickshell.screens[0];
            }
            readonly property string style: PowerService.style

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            WlrLayershell.namespace: "qs_powerOverlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: hasMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Backdrop: lighter behind the strip, darkest for the farewell screen
            Rectangle {
                anchors.fill: parent
                color: Config.backgroundColor
                opacity: root.shown ? (window.style === "strip" ? 0.25 : window.style === "farewell" ? 0.7 : 0.45) : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.shown ? Config.animDurationLong : Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (PowerService.pendingId !== "")
                        PowerService.cancel();
                    else
                        PowerService.hide();
                }
            }

            Item {
                id: keys

                anchors.fill: parent
                focus: window.hasMenu
                Keys.onPressed: event => root.handleKey(event)
            }

            Loader {
                active: window.hasMenu && window.style === "card"
                anchors.centerIn: parent

                sourceComponent: PowerCard {
                    shown: root.shown
                }
            }

            Loader {
                active: window.hasMenu && window.style === "strip"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: PowerService.side === "left" ? parent.left : undefined
                anchors.right: PowerService.side === "left" ? undefined : parent.right

                sourceComponent: PowerStrip {
                    width: implicitWidth
                    height: implicitHeight
                    shown: root.shown
                }
            }

            Loader {
                active: window.hasMenu && window.style === "farewell"
                anchors.centerIn: parent

                sourceComponent: PowerFarewell {
                    shown: root.shown
                }
            }

            // Keyboard focus lands a moment after the layer maps
            Timer {
                running: window.hasMenu
                interval: 50
                onTriggered: keys.forceActiveFocus()
            }
        }
    }

    // Clicking another window (or the grab being lost) closes the menu. Set
    // a moment after opening: a grab activated in the same tick the windows
    // map can be cleared by the compositor right away
    HyprlandFocusGrab {
        id: grab

        windows: windows.instances
        onCleared: PowerService.hide()
    }

    Timer {
        id: grabDelay

        running: true
        interval: 50
        onTriggered: grab.active = true
    }

    // Reopened while closing: the grab may have been cleared
    Connections {
        target: PowerService

        function onOpenChanged() {
            if (PowerService.open)
                grabDelay.restart();
        }
    }
}
