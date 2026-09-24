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
// animation by the keepAlive Loader in shell.qml, so every open starts fresh.
// The window covers the screen; the panel's place and shape come from the
// template (LauncherService.style / position):
//   spotlight  centered panel, in the upper third or next to the bar
//   dropdown   compact panel hanging from the bar's launcher button
//   sidebar    full-height panel on the left or right edge
//   grid       fullscreen, the apps as tiles
PanelWindow {
    id: root

    readonly property string style: LauncherService.style
    readonly property string position: LauncherService.position
    readonly property bool grid: style === "grid"
    readonly property bool sidebar: style === "sidebar"
    readonly property bool dropdown: style === "dropdown"
    // Opens from the bar's edge (dropdown, spotlight next to the bar)
    readonly property bool atBar: dropdown || (style === "spotlight" && position === "bar")
    readonly property bool barOnBottom: Config.barOnBottom
    // Distance from the bar's screen edge to just past the bar
    readonly property int barGap: Config.barReservedHeight + Config.spacing

    // Apps as tiles in the grid template (actions and results stay a list)
    readonly property bool tileResults: grid && LauncherService.mode.id === "apps" && LauncherService.results.length > 0
    readonly property int gridColumns: Math.max(4, Math.floor(column.width / (Config.fontSizeNormal * 9)))

    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Cover the bar too, so every template can place itself from the edges
    exclusionMode: ExclusionMode.Ignore
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

    // The selection runs through two sections: the favorite tiles, then the
    // results (a list, or tiles in the grid template). Arrows move in 2D
    // inside a section and cross into the other one at its edge
    function sections(): var {
        const favorites = LauncherService.favoriteCount;
        return [
            {
                start: 0,
                count: favorites,
                columns: favoritesGrid.columns
            },
            {
                start: favorites,
                count: LauncherService.results.length,
                columns: tileResults ? resultsGrid.columns : 1
            }
        ].filter(s => s.count > 0);
    }

    function moveVertical(step: int) {
        const list = sections();
        const selected = LauncherService.selectedIndex;
        const i = list.findIndex(s => selected >= s.start && selected < s.start + s.count);
        if (i === -1)
            return;
        const section = list[i];
        const target = selected + step * section.columns;
        if (target >= section.start && target < section.start + section.count) {
            LauncherService.select(target);
            return;
        }
        // Past the last row: next section's first item, or this section's
        // last item when the last row is shorter than the one above
        if (step > 0) {
            if (i + 1 < list.length)
                LauncherService.select(list[i + 1].start);
            else if (Math.floor((selected - section.start) / section.columns) < Math.floor((section.count - 1) / section.columns))
                LauncherService.select(section.start + section.count - 1);
        } else if (i > 0) {
            // Up into the previous section: first item of its last row
            const previous = list[i - 1];
            LauncherService.select(previous.start + Math.floor((previous.count - 1) / previous.columns) * previous.columns);
        }
    }

    function moveHorizontal(step: int): bool {
        const selected = LauncherService.selectedIndex;
        const section = sections().find(s => selected >= s.start && selected < s.start + s.count);
        if (!section || section.columns === 1)
            return false;
        const target = selected + step;
        if (target >= section.start && target < section.start + section.count)
            LauncherService.select(target);
        return true;
    }

    // Rows of results a PageUp/PageDown jumps
    function pageSize(): int {
        return tileResults ? resultsGrid.rowsVisible * resultsGrid.columns : results.maxRows;
    }

    // Keys the search field passes on: navigation, launch and close
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;

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
            moveVertical(1);
            break;
        case Qt.Key_Up:
            moveVertical(-1);
            break;
        case Qt.Key_Left:
            // Only in tiles; otherwise the text cursor moves
            if (!moveHorizontal(-1))
                return;
            break;
        case Qt.Key_Right:
            if (!moveHorizontal(1))
                return;
            break;
        // Tab walks every item in order; with Ctrl it switches modes
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
            LauncherService.move(pageSize());
            break;
        case Qt.Key_PageUp:
            LauncherService.move(-pageSize());
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
            moveVertical(1);
            break;
        case Qt.Key_K:
        case Qt.Key_P:
            if (!ctrl)
                return;
            moveVertical(-1);
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

    AnimatedPopup {
        id: popup

        // Width of the floating templates
        readonly property int panelWidth: Config.fontSizeNormal * (root.style === "spotlight" ? 40 : 32)

        // Sidebar and grid have a fixed size; the others follow their content
        // and are anchored by the edge facing the bar, so they only grow away
        // from it while typing
        width: {
            if (root.grid)
                return root.width;
            return panelWidth;
        }
        height: {
            if (root.grid)
                return root.height;
            if (root.sidebar)
                return root.height - root.barGap - Config.spacing;
            return panel.implicitHeight;
        }
        x: {
            if (root.grid)
                return 0;
            if (root.sidebar)
                return root.position === "right" ? root.width - width - Config.spacing : Config.spacing;
            // Under the bar's launcher button, the first item on its left
            if (root.dropdown)
                return Config.barMargin + Config.spacing;
            return Math.round((root.width - width) / 2);
        }
        y: {
            if (root.grid)
                return 0;
            if (root.sidebar || root.atBar)
                return root.barOnBottom ? root.height - root.barGap - (root.sidebar ? height : panel.implicitHeight) : root.barGap;
            return Math.round(root.height / 5);
        }
        transformOrigin: {
            if (root.grid)
                return Item.Center;
            if (root.sidebar)
                return root.position === "right" ? Item.Right : Item.Left;
            if (root.dropdown)
                return root.barOnBottom ? Item.BottomLeft : Item.TopLeft;
            return root.atBar && root.barOnBottom ? Item.Bottom : Item.Top;
        }
        fromScale: root.grid ? 1.03 : Config.animPopupFromScale
        shown: LauncherService.visible

        Rectangle {
            id: panel

            readonly property int margin: root.grid ? Config.padding * 4 : Config.padding * 2

            anchors.fill: parent
            implicitHeight: column.implicitHeight + margin * 2
            // Concentric with the rows inside the margin
            radius: root.grid ? 0 : Config.radiusLarge + margin
            color: root.grid ? Qt.alpha(Config.backgroundColor, Math.min(0.95, Config.backgroundOpacity + 0.05)) : Config.backgroundTransparentColor
            border.width: root.grid ? 0 : 1
            border.color: Config.surface2Color

            // Swallow clicks so they don't reach the closing MouseArea; in
            // the grid template, clicks on the empty backdrop close
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.grid)
                        root.hide();
                }
            }

            ColumnLayout {
                id: column

                // The grid template keeps its content to a readable column
                width: root.grid ? Math.min(parent.width - panel.margin * 2, Config.fontSizeNormal * 72) : parent.width - panel.margin * 2
                x: Math.round((parent.width - width) / 2)
                y: root.grid ? Math.round(parent.height / 10) : panel.margin
                height: root.grid ? parent.height - y - panel.margin : root.sidebar ? parent.height - panel.margin * 2 : implicitHeight
                spacing: Config.spacing

                SearchField {
                    id: search

                    Layout.maximumWidth: root.grid ? Config.fontSizeNormal * 40 : -1
                    Layout.alignment: Qt.AlignHCenter
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
                    columns: root.grid ? root.gridColumns : root.style === "spotlight" ? 6 : 5
                    onLaunched: panel.forceActiveFocus()
                    onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
                }

                SectionLabel {
                    visible: favoritesGrid.count > 0 && LauncherService.results.length > 0
                    text: LauncherService.mode.id === "apps" ? "Apps" : LauncherService.mode.label
                }

                ResultsGrid {
                    id: resultsGrid

                    visible: root.tileResults
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: root.gridColumns
                    onLaunched: panel.forceActiveFocus()
                    onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
                }

                ResultsList {
                    id: results

                    // Sidebar and grid fill the height they have
                    readonly property bool fills: root.sidebar || root.grid

                    visible: !root.tileResults
                    // Leaves room for the favorites above
                    maxRows: fills ? Math.max(1, Math.floor(height / (rowHeight + spacing))) : Math.max(3, StateService.get("launcher.rows", 7) - (favoritesGrid.count > 0 ? 2 : 0))
                    showDescription: StateService.get("launcher.showDescriptions", true)

                    // Animated copy of the height the list wants
                    property real shownHeight: implicitHeight

                    Behavior on shownHeight {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Layout.fillWidth: true
                    Layout.maximumWidth: root.grid ? Config.fontSizeNormal * 40 : -1
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                    Layout.fillHeight: fills
                    Layout.preferredHeight: fills ? -1 : shownHeight
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
                    Layout.alignment: root.grid ? Qt.AlignHCenter : Qt.AlignLeft
                    spacing: Config.spacing * 2

                    KeyHint {
                        keys: root.tileResults || favoritesGrid.count > 0 ? "↑↓←→" : "↑↓"
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

    // Ctrl+Tab switches modes by rewriting the query's prefix: mirror it back
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
