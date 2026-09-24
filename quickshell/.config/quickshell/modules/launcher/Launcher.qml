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

    function activateSelected() {
        // Only the Enter that really closes the launcher moves the focus
        // (a power action may just ask for confirmation)
        const item = LauncherService.entries[LauncherService.selectedIndex];
        if (!item?.confirm || LauncherService.pendingConfirm === item.id)
            panel.forceActiveFocus();
        LauncherService.activateSelected();
    }

    // Keys the search field passes on: navigation, launch and close. The
    // selection runs through the favorite tiles (a grid: arrows move in 2D)
    // and then the list
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const favorites = LauncherService.favoriteCount;
        const selected = LauncherService.selectedIndex;
        const inTiles = selected < favorites;
        const columns = favoritesGrid.columns;

        switch (event.key) {
        case Qt.Key_Escape:
            // Closes the menu, then clears the search, then the launcher
            if (menu.opened)
                menu.close();
            else if (search.text !== "")
                search.text = "";
            else
                hide();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activateSelected();
            break;
        case Qt.Key_Down:
            // From the tiles: the row below, or the first app of the list
            if (inTiles)
                LauncherService.select(Math.min(selected + columns, favorites));
            else
                LauncherService.move(1);
            break;
        case Qt.Key_Up:
            if (inTiles) {
                if (selected >= columns)
                    LauncherService.move(-columns);
            } else if (selected === favorites && favorites > 0) {
                // Back up to the first tile of the last row
                LauncherService.select(Math.floor((favorites - 1) / columns) * columns);
            } else {
                LauncherService.move(-1);
            }
            break;
        case Qt.Key_Left:
            if (!inTiles)
                return;
            LauncherService.move(-1);
            break;
        case Qt.Key_Right:
            if (!inTiles)
                return;
            if (selected + 1 < favorites)
                LauncherService.move(1);
            break;
        // Tab navigates like the arrows; with Ctrl it switches modes
        case Qt.Key_Tab:
            if (ctrl)
                LauncherService.cycleMode(1);
            else
                LauncherService.move(1);
            break;
        case Qt.Key_Backtab:
            if (ctrl)
                LauncherService.cycleMode(-1);
            else
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

                    count: LauncherService.mode.id === "calc" ? 0 : LauncherService.entries.length
                    icon: LauncherService.mode.icon
                    chip: LauncherService.mode.id === "apps" ? "" : LauncherService.mode.label
                    placeholder: LauncherService.mode.placeholder
                    onTextChanged: LauncherService.query = text
                    onKeyPressed: event => root.handleKey(event)
                    Component.onCompleted: Qt.callLater(() => {
                        if (LauncherService.visible)
                            focusInput();
                    })
                }

                SectionLabel {
                    visible: favoritesGrid.count > 0
                    text: "Favorites"
                }

                FavoritesGrid {
                    id: favoritesGrid

                    Layout.fillWidth: true
                    visible: count > 0
                    onLaunched: panel.forceActiveFocus()
                    onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
                }

                SectionLabel {
                    visible: favoritesGrid.count > 0 && results.count > 0
                    text: "Apps"
                }

                ResultsList {
                    id: results

                    // Leaves room for the favorites above
                    maxRows: favoritesGrid.count > 0 ? 5 : 7

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
                    onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
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
                        keys: "ctrl ⇥"
                        label: "mode"
                    }

                    KeyHint {
                        keys: "esc"
                        label: search.text !== "" ? "clear" : "close"
                    }
                }
            }
        }
    }

    // Tab switches modes by rewriting the query's prefix: mirror it back
    Connections {
        target: LauncherService

        function onQueryChanged() {
            if (search.text !== LauncherService.query)
                search.text = LauncherService.query;
        }
    }

    // App menu: pin to the favorites or hide from the launcher
    ContextMenu {
        id: menu

        readonly property bool isFavorite: target ? LauncherService.isFavorite(target) : false

        items: [
            {
                label: menu.isFavorite ? "Unpin from favorites" : "Pin to favorites",
                icon: menu.isFavorite ? "\u{f0404}" : "\u{f0403}",
                action: "pin"
            },
            {
                label: "Hide from launcher",
                icon: "\u{f0209}",
                action: "hide"
            }
        ]

        onTriggered: (action, app) => {
            if (action === "pin")
                LauncherService.toggleFavorite(app);
            else if (action === "hide")
                LauncherService.hideApp(app);
        }
    }

    component SectionLabel: Text {
        Layout.leftMargin: Config.padding
        Layout.topMargin: Config.padding
        text: ""
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: Config.accentColor
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
