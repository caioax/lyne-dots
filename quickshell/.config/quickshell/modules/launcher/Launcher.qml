pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config
import "../../components/"

// App launcher window. Created on open and destroyed after the exit
// animation by the keepAlive Loader in shell.qml, so every open starts fresh
PanelWindow {
    id: root

    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    // Release the keyboard as soon as the service hides, so the exit
    // animation doesn't block other windows from receiving input
    WlrLayershell.keyboardFocus: LauncherService.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    color: "transparent"

    function hide() {
        // Move focus off the TextField first to avoid the Wayland text-input
        // warning "Try to disable surface X with focusing surface Y"
        panel.forceActiveFocus();
        LauncherService.hide();
    }

    function launchSelected() {
        panel.forceActiveFocus();
        LauncherService.launchSelected();
    }

    // Keys the search field passes on: list navigation, launch and close
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;

        switch (event.key) {
        case Qt.Key_Escape:
            // First Escape clears the search, the second one closes
            if (search.text !== "")
                search.text = "";
            else
                hide();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            launchSelected();
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            LauncherService.move(1);
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            LauncherService.move(-1);
            break;
        case Qt.Key_PageDown:
            LauncherService.move(results.maxRows);
            break;
        case Qt.Key_PageUp:
            LauncherService.move(-results.maxRows);
            break;
        case Qt.Key_Home:
            LauncherService.selectFirst();
            break;
        case Qt.Key_End:
            LauncherService.selectLast();
            break;
        case Qt.Key_J:
        case Qt.Key_N:
            if (!ctrl)
                return;
            LauncherService.move(1);
            break;
        case Qt.Key_K:
        case Qt.Key_P:
            if (!ctrl)
                return;
            LauncherService.move(-1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Click outside the panel closes
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    // Anchored by its top edge, so the panel only grows or shrinks downward
    // while typing
    AnimatedPopup {
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height / 5)
        width: panel.width
        height: panel.height
        transformOrigin: Item.Top
        shown: LauncherService.visible

        Rectangle {
            id: panel

            readonly property int margin: Config.padding * 2

            width: Config.fontSizeNormal * 40
            height: column.implicitHeight + margin * 2
            // Concentric with the rows inside the margin
            radius: Config.radiusLarge + margin
            color: Config.backgroundTransparentColor
            border.width: 1
            border.color: Config.surface2Color

            // Swallow clicks so they don't reach the closing MouseArea
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: column

                anchors.fill: parent
                anchors.margins: panel.margin
                spacing: Config.spacing

                SearchField {
                    id: search

                    count: LauncherService.filteredApps.length
                    onTextChanged: LauncherService.query = text
                    onKeyPressed: event => root.handleKey(event)
                    Component.onCompleted: Qt.callLater(() => {
                        if (LauncherService.visible)
                            focusInput();
                    })
                }

                ResultsList {
                    id: results

                    // Animated copy of the height the list wants
                    property real shownHeight: implicitHeight

                    Behavior on shownHeight {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: shownHeight
                    onLaunched: panel.forceActiveFocus()
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.surface1Color
                }

                RowLayout {
                    Layout.leftMargin: Config.padding
                    Layout.rightMargin: Config.padding
                    spacing: Config.spacing * 2

                    KeyHint {
                        keys: "↑↓"
                        label: "navigate"
                    }

                    KeyHint {
                        keys: "⏎"
                        label: "open"
                    }

                    KeyHint {
                        keys: "esc"
                        label: search.text !== "" ? "clear" : "close"
                    }
                }
            }
        }
    }

    // Deactivated as soon as the service hides (not tied to window
    // visibility) so the exit animation doesn't keep stealing focus
    HyprlandFocusGrab {
        windows: [root]
        active: LauncherService.visible
        onCleared: {
            if (LauncherService.visible)
                root.hide();
        }
    }
}
