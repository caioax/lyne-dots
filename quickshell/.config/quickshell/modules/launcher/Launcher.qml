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
//   spotlight  centered panel, in the upper third or against the top or
//              bottom edge (the bar, when it's there)
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
    readonly property bool barOnBottom: Config.barOnBottom
    readonly property string barEdge: barOnBottom ? "bottom" : "top"
    // Screen edge a spotlight hangs from, "" in the center
    readonly property string spotlightEdge: style === "spotlight" && position !== "center" ? position : ""
    // Opens from the bar's edge (dropdown, spotlight on the bar's side)
    readonly property bool atBar: dropdown || spotlightEdge === barEdge
    // Distance from the bar's screen edge to just past the bar
    readonly property int barGap: Config.barReservedHeight + Config.spacing
    // Grow out of the bar (or the screen edge) instead of floating near it
    readonly property bool attachable: dropdown || sidebar || spotlightEdge !== ""
    // Same switch as the bar popups (Settings › Bar › Attach to the bar)
    readonly property bool attached: attachable && StateService.get("bar.attachPopups", true)
    // With a docked bar the panel attaches below it; islands and floating
    // bars have no continuous edge, so it attaches to the screen edge
    readonly property real attachLine: Config.barIslands || Config.barFloating ? 0 : Config.barHeight
    // Flush sides of the attached panel, the one it slides out of first
    readonly property var attachedEdges: {
        if (sidebar)
            return [position, "top", "bottom"];
        if (dropdown)
            return [barEdge, "left"];
        return [spotlightEdge];
    }

    // Templates next to the bar keep an auto-hiding bar shown while open,
    // like the bar popups do
    readonly property bool holdsBar: LauncherService.visible && (atBar || sidebar)
    onHoldsBarChanged: {
        if (holdsBar)
            WindowManagerService.registerOpen("Launcher");
        else
            WindowManagerService.registerClose("Launcher");
    }
    // Created already open, so the change handler doesn't run for it
    Component.onCompleted: {
        if (holdsBar)
            WindowManagerService.registerOpen("Launcher");
    }
    Component.onDestruction: WindowManagerService.registerClose("Launcher")

    // Upside down (Settings › Launcher › Search bar, or hanging from the
    // bottom edge in auto): search at the bottom, the list growing upward
    // with the best match right above it
    readonly property bool reversed: LauncherService.isReversed(style, position)

    // Apps and clipboard entries as tiles in the grid template (actions and
    // calculator results stay a list)
    readonly property bool clipboard: LauncherService.modeId === "clipboard"
    readonly property bool tileResults: grid && (LauncherService.modeId === "apps" || clipboard) && LauncherService.results.length > 0
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
    // Attached: blur like the bar (wallpaper only) so both share one tint
    WlrLayershell.namespace: attached ? "qs_attached" : "qs_modules"
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

    // The selection runs through two sections: the favorite tiles and the
    // results (a list, or tiles in the grid template), listed as drawn, top
    // to bottom. Arrows move in 2D inside a section and cross into the other
    // one at its edge
    function sections(): var {
        const favorites = LauncherService.favoriteCount;
        const list = [
            {
                start: 0,
                count: favorites,
                columns: favoritesGrid.columns,
                flipped: false
            },
            {
                start: favorites,
                count: LauncherService.results.length,
                columns: tileResults ? resultsGrid.columns : 1,
                // Upside down, the list draws its first item at the bottom
                flipped: reversed && !tileResults
            }
        ].filter(s => s.count > 0);
        // Upside down, the results sit above the favorites
        return reversed ? list.reverse() : list;
    }

    // Item at a place of a section on screen (0 = top left), and back: the
    // same mapping both ways
    function itemAt(section, place: int): int {
        return section.start + (section.flipped ? section.count - 1 - place : place);
    }

    function placeOf(section, index: int): int {
        return itemAt(section, index - section.start) - section.start;
    }

    // `step` is the key's direction: 1 = Down, -1 = Up
    function moveVertical(step: int) {
        const list = sections();
        const selected = LauncherService.selectedIndex;
        const i = list.findIndex(s => selected >= s.start && selected < s.start + s.count);
        if (i === -1)
            return;
        const section = list[i];
        const place = placeOf(section, selected);
        const target = place + step * section.columns;
        if (target >= 0 && target < section.count) {
            LauncherService.select(itemAt(section, target));
            return;
        }
        // Past the last row: next section's first item, or this section's
        // last item when the last row is shorter than the one above
        if (step > 0) {
            if (i + 1 < list.length)
                LauncherService.select(itemAt(list[i + 1], 0));
            else if (Math.floor(place / section.columns) < Math.floor((section.count - 1) / section.columns))
                LauncherService.select(itemAt(section, section.count - 1));
        } else if (i > 0) {
            // Up into the previous section: first item of its last row
            const previous = list[i - 1];
            LauncherService.select(itemAt(previous, Math.floor((previous.count - 1) / previous.columns) * previous.columns));
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
            // Closes the menu, then clears what was typed (keeping the
            // mode), then the launcher
            if (menu.opened)
                menu.close();
            else if (LauncherService.term !== "")
                search.text = LauncherService.mode.prefix;
            else
                hide();
            break;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
        case Qt.Key_4:
            // Alt+1…4 picks the clipboard filter
            if (!clipboard || !(event.modifiers & Qt.AltModifier))
                return;
            LauncherService.setClipFilter(LauncherService.clipFilters[event.key - Qt.Key_1].id);
            break;
        case Qt.Key_Delete:
            // Deletes the selected clipboard entry
            if (!clipboard)
                return;
            LauncherService.removeClip(LauncherService.entries[LauncherService.selectedIndex]);
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

    // Where the panel goes and how big it is. The floating templates sit a
    // gap away from the bar; attached ones touch the bar (or the screen edge)
    // and grow out of it. Sidebar and grid have a fixed size; the others
    // follow their content and are anchored by the edge facing the bar, so
    // they only grow away from it while typing
    Item {
        id: frame

        readonly property int margin: root.grid ? Config.padding * 4 : Config.padding * 2
        readonly property real contentHeight: column.implicitHeight + margin * 2
        // Distance from the bar's screen edge to the panel
        readonly property real edgeOffset: root.attached ? root.attachLine : root.barGap
        // Space left at a screen edge without the bar when floating
        readonly property real inset: root.attached ? 0 : Config.spacing

        width: {
            if (root.grid)
                return root.width;
            return Config.fontSizeNormal * (root.style === "spotlight" ? 40 : 32);
        }
        height: {
            if (root.grid)
                return root.height;
            if (root.sidebar)
                return root.height - edgeOffset - inset;
            return contentHeight;
        }
        x: {
            if (root.grid)
                return 0;
            if (root.sidebar)
                return root.position === "right" ? root.width - width - inset : inset;
            // Under the bar's launcher button, the first item on its left
            if (root.dropdown)
                return root.attached ? 0 : Config.barMargin + Config.spacing;
            return Math.round((root.width - width) / 2);
        }
        y: {
            if (root.grid)
                return 0;
            if (root.sidebar)
                return root.barOnBottom ? inset : edgeOffset;
            if (root.dropdown)
                return root.barOnBottom ? root.height - edgeOffset - height : edgeOffset;
            if (root.spotlightEdge !== "") {
                const offset = root.atBar ? edgeOffset : inset;
                return root.spotlightEdge === "bottom" ? root.height - offset - height : offset;
            }
            return Math.round(root.height / 5);
        }
    }

    AnimatedPopup {
        id: popup

        visible: !root.attached
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        transformOrigin: {
            if (root.grid)
                return Item.Center;
            if (root.sidebar)
                return root.position === "right" ? Item.Right : Item.Left;
            if (root.dropdown)
                return root.barOnBottom ? Item.BottomLeft : Item.TopLeft;
            return root.spotlightEdge === "bottom" ? Item.Bottom : Item.Top;
        }
        fromScale: root.grid ? 1.03 : Config.animPopupFromScale
        shown: LauncherService.visible && !root.attached

        Rectangle {
            id: floatingPanel

            anchors.fill: parent
            // Concentric with the rows inside the margin
            radius: root.grid ? 0 : Config.radiusLarge
            color: root.grid ? Qt.alpha(Config.backgroundColor, Math.min(0.95, Config.backgroundOpacity + 0.05)) : Config.backgroundTransparentColor
            border.width: root.grid ? 0 : 1
            border.color: Config.surface2Color
        }
    }

    AttachedPanel {
        id: attachedPanel

        visible: root.attached
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        edges: root.attachedEdges
        radius: Config.radiusLarge + frame.margin
        shown: LauncherService.visible && root.attached
    }

    // The content, inside whichever panel is in use
    Item {
        id: panel

        parent: root.attached ? attachedPanel.body : floatingPanel
        anchors.fill: parent

        // Swallow clicks so they don't reach the closing MouseArea; in
        // the grid template, clicks on the empty backdrop close
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.grid)
                    root.hide();
            }
        }

        // A one-column grid so the rows can be reordered (`reversed`)
        GridLayout {
            id: column

            // Row of each part, top to bottom
            readonly property var rows: root.reversed ? ({
                    footer: 0,
                    separator: 1,
                    resultsLabel: 2,
                    results: 3,
                    favoritesLabel: 4,
                    favorites: 5,
                    filters: 6,
                    search: 7
                }) : ({
                    search: 0,
                    filters: 1,
                    favoritesLabel: 2,
                    favorites: 3,
                    resultsLabel: 4,
                    results: 5,
                    separator: 6,
                    footer: 7
                })

            columns: 1
            rowSpacing: Config.spacing

            // The grid template keeps its content to a readable column
            width: root.grid ? Math.min(parent.width - frame.margin * 2, Config.fontSizeNormal * 72) : parent.width - frame.margin * 2
            x: Math.round((parent.width - width) / 2)
            y: root.grid ? Math.round(parent.height / 10) : frame.margin
            height: root.grid ? parent.height - y - frame.margin : root.sidebar ? parent.height - frame.margin * 2 : implicitHeight

            SearchField {
                id: search

                Layout.row: column.rows.search
                Layout.maximumWidth: root.grid ? Config.fontSizeNormal * 40 : -1
                Layout.alignment: Qt.AlignHCenter
                count: LauncherService.mode.id === "calc" ? 0 : LauncherService.entries.length
                icon: LauncherService.mode.icon
                chip: LauncherService.mode.id === "apps" ? "" : LauncherService.mode.label
                placeholder: LauncherService.mode.placeholder
                onTextChanged: LauncherService.query = text
                onKeyPressed: event => root.handleKey(event)
                Component.onCompleted: {
                    // Opened in a mode (SUPER+V): its prefix is already set
                    text = LauncherService.query;
                    Qt.callLater(() => {
                        if (LauncherService.visible)
                            focusInput();
                    });
                }
            }

            // Clipboard: kind of entries shown (Alt+1…4)
            SegmentedControl {
                Layout.row: column.rows.filters
                Layout.maximumWidth: root.grid ? Config.fontSizeNormal * 40 : -1
                Layout.alignment: Qt.AlignHCenter
                visible: root.clipboard && ClipboardService.entries.length > 0
                options: LauncherService.clipFilters
                currentIndex: Math.max(0, LauncherService.clipFilters.findIndex(f => f.id === LauncherService.clipFilter))
                onSelected: index => LauncherService.setClipFilter(LauncherService.clipFilters[index].id)
            }

            SectionLabel {
                Layout.row: column.rows.favoritesLabel
                visible: favoritesGrid.count > 0
                text: "Favorites"
            }

            FavoritesGrid {
                id: favoritesGrid

                Layout.row: column.rows.favorites
                Layout.fillWidth: true
                visible: count > 0
                columns: root.grid ? root.gridColumns : root.style === "spotlight" ? 6 : 5
                onLaunched: panel.forceActiveFocus()
                onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
            }

            SectionLabel {
                Layout.row: column.rows.resultsLabel
                visible: favoritesGrid.count > 0 && LauncherService.results.length > 0
                text: LauncherService.mode.id === "apps" ? "Apps" : LauncherService.mode.label
            }

            ResultsGrid {
                id: resultsGrid

                Layout.row: column.rows.results
                visible: root.tileResults
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root.gridColumns
                onLaunched: panel.forceActiveFocus()
                onMenuRequested: (anchor, app) => menu.openAt(anchor, app)
            }

            ResultsList {
                id: results

                Layout.row: column.rows.results
                verticalLayoutDirection: root.reversed ? ListView.BottomToTop : ListView.TopToBottom
                // Sidebar and grid fill the height they have
                fills: root.sidebar || root.grid

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
                Layout.row: column.rows.separator
                Layout.fillWidth: true
                implicitHeight: 1
                color: Config.surface1Color
            }

            RowLayout {
                id: footer

                Layout.row: column.rows.footer
                Layout.leftMargin: Config.padding
                Layout.rightMargin: Config.padding
                Layout.alignment: root.grid ? Qt.AlignHCenter : Qt.AlignLeft
                spacing: Config.spacing * 2

                // Hints that don't fit hide, least important first, instead
                // of widening the whole panel (narrow templates)
                readonly property real room: column.width - Config.padding * 2
                readonly property var shown: {
                    const byImportance = [closeHint, openHint, deleteHint, navigateHint, modeHint, filterHint];
                    const list = [];
                    let used = 0;
                    for (const hint of byImportance) {
                        if (!hint.wanted)
                            continue;
                        const width = hint.implicitWidth + (list.length > 0 ? spacing : 0);
                        if (used + width > room)
                            break;
                        used += width;
                        list.push(hint);
                    }
                    return list;
                }

                KeyHint {
                    id: navigateHint
                    visible: footer.shown.includes(this)
                    keys: root.tileResults || favoritesGrid.count > 0 ? "↑↓←→" : "↑↓"
                    label: "navigate"
                }

                KeyHint {
                    id: openHint
                    visible: footer.shown.includes(this)
                    keys: "⏎"
                    label: root.clipboard ? "copy" : "open"
                }

                KeyHint {
                    id: deleteHint
                    visible: footer.shown.includes(this)
                    wanted: root.clipboard
                    keys: "del"
                    label: "delete"
                }

                KeyHint {
                    id: filterHint
                    visible: footer.shown.includes(this)
                    wanted: root.clipboard
                    keys: "alt 1-4"
                    label: "filter"
                }

                KeyHint {
                    id: modeHint
                    visible: footer.shown.includes(this)
                    keys: "ctrl ⇥"
                    label: "mode"
                }

                KeyHint {
                    id: closeHint
                    visible: footer.shown.includes(this)
                    keys: "esc"
                    label: LauncherService.term !== "" ? "clear" : "close"
                }
            }
        }
    }

    Connections {
        target: LauncherService

        // Reopened before the exit animation ended: same window, so delay
        // the grab again and give the search its focus back
        function onVisibleChanged() {
            root.grabReady = false;
            if (!LauncherService.visible)
                return;
            grabTimer.restart();
            search.focusInput();
        }

        // Ctrl+Tab switches modes by rewriting the query's prefix: mirror it back
        function onQueryChanged() {
            if (search.text !== LauncherService.query)
                search.text = LauncherService.query;
        }
    }

    // Item menu. Apps: pin to the favorites or hide from the launcher;
    // clipboard entries: copy, open a link, delete
    ContextMenu {
        id: menu

        readonly property var clipEntry: target?.clip ?? null
        readonly property bool isFavorite: target && !clipEntry ? LauncherService.isFavorite(target) : false

        items: {
            if (clipEntry) {
                const list = [
                    {
                        label: "Copy",
                        icon: "\u{f018f}",
                        action: "copy"
                    }
                ];
                if (clipEntry.kind === "link")
                    list.push({
                        label: "Open link",
                        icon: "\u{f03cc}",
                        action: "open"
                    });
                list.push({
                    label: "Delete",
                    icon: "\u{f01b4}",
                    action: "delete",
                    danger: true
                });
                return list;
            }
            return [
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
            ];
        }

        onTriggered: (action, item) => {
            switch (action) {
            case "pin":
                LauncherService.toggleFavorite(item);
                break;
            case "hide":
                LauncherService.hideApp(item);
                break;
            case "copy":
                panel.forceActiveFocus();
                LauncherService.activate(item);
                break;
            case "open":
                panel.forceActiveFocus();
                LauncherService.openClipLink(item);
                break;
            case "delete":
                LauncherService.removeClip(item);
                break;
            }
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

    // Set a moment after each open, like the other popups: a grab taken in
    // the same tick the surface is mapped (or shown again while the exit
    // animation keeps this window alive) is cleared right away, which closed
    // the launcher as soon as it opened
    property bool grabReady: false

    Timer {
        id: grabTimer

        running: true
        interval: 50
        onTriggered: root.grabReady = true
    }

    // Deactivated as soon as the service hides (not tied to window
    // visibility) so the exit animation doesn't keep stealing focus
    HyprlandFocusGrab {
        windows: [root]
        active: LauncherService.visible && root.grabReady
        onCleared: {
            if (LauncherService.visible)
                root.hide();
        }
    }
}
