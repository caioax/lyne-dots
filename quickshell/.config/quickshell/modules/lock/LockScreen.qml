pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Session lock. Every monitor gets the blurred wallpaper; the one focused
// when locking shows the lock.style template with the password, the others
// only the clock. Each surface has a hidden input that edits the shared
// LockService.buffer, so typing works whichever monitor has the keyboard
WlSessionLock {
    id: root

    // Set locked on creation — NOT bound to LockService.locked
    // This avoids the race condition where Loader destruction and protocol
    // unlock happen simultaneously
    locked: true

    // Fading out after a successful password
    property bool unlocking: false

    onLockStateChanged: {
        // Protocol unlock complete → defer LockService.unlock() to the next
        // event loop so surface destruction finishes cleanly before the Loader
        // tries to destroy this component (avoids "invalid context" warning)
        if (!locked)
            Qt.callLater(LockService.unlock);
    }

    onSecureChanged: LockService.secure = secure

    Component.onCompleted: {
        PowerService.refresh();
        WeatherService.refresh(false);
    }

    Connections {
        id: lockServiceConn

        target: LockService

        function onAuthSucceeded() {
            PowerService.cancel();
            root.unlocking = true;
            unlockDelay.start();
        }
    }

    // Lets the content fade and the blur clear before the surfaces go
    Timer {
        id: unlockDelay

        interval: Config.animDurationLong
        onTriggered: {
            // Disconnect before unlocking to prevent signal handlers
            // from firing during surface destruction
            lockServiceConn.enabled = false;
            root.locked = false;
        }
    }

    WlSessionLockSurface {
        id: surface

        // The monitor focused when locking, or the first one
        readonly property bool main: {
            const name = LockService.screen;
            const known = Quickshell.screens.some(s => s.name === name);
            return known ? screen?.name === name : screen === Quickshell.screens[0];
        }
        property bool ready: false
        readonly property bool shown: ready && !root.unlocking

        Component.onCompleted: Qt.callLater(() => ready = true)

        color: Config.backgroundColor

        LockBackground {
            anchors.fill: parent
            revealed: surface.shown
            blurred: !surface.main || LockService.style !== "wallpaper" || (template.item?.typing ?? false)
        }

        // Clicks bring the keyboard back to the hidden input
        MouseArea {
            anchors.fill: parent
            onClicked: input.forceActiveFocus()
        }

        Loader {
            id: template

            anchors.fill: parent
            active: surface.main
            sourceComponent: LockService.style === "cards" ? cards : LockService.style === "wallpaper" ? wallpaper : center
        }

        Component {
            id: center

            LockCenter {
                shown: surface.shown
            }
        }

        Component {
            id: cards

            LockCards {
                shown: surface.shown
            }
        }

        Component {
            id: wallpaper

            LockWallpaper {
                shown: surface.shown
            }
        }

        // Other monitors: just the time
        LockClock {
            visible: !surface.main
            anchors.centerIn: parent
            opacity: surface.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutCubic
                }
            }
        }

        TextInput {
            id: input

            width: 1
            height: 1
            opacity: 0
            echoMode: TextInput.Password
            focus: true
            text: LockService.buffer

            onTextEdited: LockService.buffer = text

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    LockService.tryUnlock();
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    // Cancels a power countdown first, then clears the password
                    if (PowerService.pendingId !== "")
                        PowerService.cancel();
                    else
                        LockService.buffer = "";
                    event.accepted = true;
                    break;
                }
            }
            Keys.onReleased: LockService.checkCapsLock()

            // Typed on another monitor (or cleared after a try)
            Connections {
                target: LockService

                function onBufferChanged() {
                    if (input.text !== LockService.buffer)
                        input.text = LockService.buffer;
                }
            }
        }
    }
}
