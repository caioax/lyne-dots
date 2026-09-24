pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Popup stack at the top right of the focused monitor
PanelWindow {
    id: root

    readonly property bool hasPopups: NotificationService.activePopupCount > 0
    // Popup whose inline reply field was clicked (null when destroyed)
    property Item keyboardOwner: null
    // Exclusive takes the keyboard right away (OnDemand would only get it on
    // a second click); then OnDemand, so clicking another window takes it back
    property bool keyboardGrabbed: false
    onKeyboardOwnerChanged: keyboardGrabbed = false

    Timer {
        running: root.keyboardOwner !== null && !root.keyboardGrabbed
        interval: Config.animDurationShort
        onTriggered: root.keyboardGrabbed = true
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // Stays mapped a bit after the last popup so its exit animation can play
    visible: hasPopups || lingerTimer.running
    onHasPopupsChanged: {
        if (!hasPopups)
            lingerTimer.restart();
    }

    Timer {
        id: lingerTimer
        interval: Config.animDurationLong
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs_notifications"
    WlrLayershell.exclusiveZone: -1
    // No keyboard by default so new popups never steal focus (that closed
    // bar menus and unfocused windows); only while a reply field is in use
    WlrLayershell.keyboardFocus: !keyboardOwner ? WlrKeyboardFocus.None : keyboardGrabbed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        right: true
    }

    margins {
        top: Config.barOnBottom ? Config.spacing : Config.barReservedHeight + Config.spacing
        right: Config.spacing
    }

    implicitWidth: Config.notifWidth
    implicitHeight: screen ? screen.height - Config.barReservedHeight - Config.spacing * 2 : 0
    color: "transparent"

    // Only the cards take input; the rest of the column clicks through
    mask: Region {
        item: list.contentItem
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.min(contentHeight, parent.height)
        interactive: false

        model: ScriptModel {
            values: [...NotificationService.popups]
        }

        delegate: NotificationPopup {
            id: popup

            width: list.width
            onWantsKeyboardChanged: {
                if (wantsKeyboard)
                    root.keyboardOwner = popup;
                else if (root.keyboardOwner === popup)
                    root.keyboardOwner = null;
            }
        }

        add: Transition {
            NumberAnimation {
                property: "x"
                from: Config.notifWidth
                to: 0
                duration: Config.animDurationLong
                easing.type: Easing.OutExpo
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "x"
                    to: Config.notifWidth
                    duration: Config.animDuration
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Config.animDuration
                }
            }
        }
    }
}
