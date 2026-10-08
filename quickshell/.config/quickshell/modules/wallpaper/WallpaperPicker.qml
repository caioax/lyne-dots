pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.config
import "../../components/"
// SearchField
import "../launcher/"

// Wallpaper picker (SUPER+B): a carousel of the library against the bottom
// (or top) edge, the selected wallpaper in the middle and bigger. Typing
// filters, Enter applies (it stays open to try others), Escape closes.
// Created on open and destroyed after the exit animation by the keepAlive
// Loader in shell.qml
PanelWindow {
    id: root

    readonly property string edge: WallpaperPickerService.position
    readonly property bool onBottom: edge === "bottom"
    readonly property string barEdge: Config.barOnBottom ? "bottom" : "top"
    // Against the bar's edge: past the bar, and it keeps an auto-hiding bar shown
    readonly property bool atBar: edge === barEdge
    // Same switch as the bar popups (Settings › Bar › Attach to the bar)
    readonly property bool attached: StateService.get("bar.attachPopups", true)
    // A docked bar has a continuous edge to attach below; islands and
    // floating bars don't, so the panel attaches to the screen edge
    readonly property real attachLine: atBar && !Config.barIslands && !Config.barFloating ? Config.barHeight : 0
    // Distance from the screen edge to the panel
    readonly property real edgeOffset: attached ? attachLine : atBar ? Config.barReservedHeight + Config.spacing : Config.spacing

    readonly property int tileWidth: Config.fontSizeNormal * 18
    readonly property int tileHeight: Math.round(tileWidth * 9 / 16)
    // Tiles beside the selected one are drawn smaller
    readonly property real sideScale: 0.8

    // Filters on offer: Theme only when the theme has a folder
    readonly property var filters: WallpaperPickerService.filters.filter(f => f.id !== "theme" || WallpaperPickerService.themeName !== "")

    readonly property bool holdsBar: WallpaperPickerService.visible && atBar
    onHoldsBarChanged: {
        if (holdsBar)
            WindowManagerService.registerOpen("WallpaperPicker");
        else
            WindowManagerService.registerClose("WallpaperPicker");
    }
    // Created already open, so the change handler doesn't run for it
    Component.onCompleted: {
        if (holdsBar)
            WindowManagerService.registerOpen("WallpaperPicker");
    }
    Component.onDestruction: WindowManagerService.registerClose("WallpaperPicker")

    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    // Attached: blur like the bar (wallpaper only) so both share one tint
    WlrLayershell.namespace: attached ? "qs_attached" : "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    // Released as soon as the service hides, so the exit animation doesn't
    // keep the keyboard from other windows
    WlrLayershell.keyboardFocus: WallpaperPickerService.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    color: "transparent"

    function hide() {
        // Focus off the TextField first (Wayland text-input warning)
        panel.forceActiveFocus();
        WallpaperPickerService.hide();
    }

    function applySelected() {
        WallpaperPickerService.applySelected();
    }

    // Keys the search field passes on: navigation, apply and close
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;

        switch (event.key) {
        case Qt.Key_Escape:
            // Closes the menu, then clears what was typed, then the picker
            if (menu.opened)
                menu.close();
            else if (search.text !== "")
                search.text = "";
            else
                hide();
            break;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
            // Alt+1…3 picks the filter
            if (!(event.modifiers & Qt.AltModifier) || event.key - Qt.Key_1 >= filters.length)
                return;
            WallpaperPickerService.setFilter(filters[event.key - Qt.Key_1].id);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            applySelected();
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            WallpaperPickerService.move(1);
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            WallpaperPickerService.move(-1);
            break;
        case Qt.Key_PageDown:
            WallpaperPickerService.move(carousel.visibleCount);
            break;
        case Qt.Key_PageUp:
            WallpaperPickerService.move(-carousel.visibleCount);
            break;
        case Qt.Key_Home:
            WallpaperPickerService.selectFirst();
            break;
        case Qt.Key_End:
            WallpaperPickerService.selectLast();
            break;
        case Qt.Key_L:
        case Qt.Key_N:
            if (!ctrl)
                return;
            WallpaperPickerService.move(1);
            break;
        case Qt.Key_H:
        case Qt.Key_P:
            if (!ctrl)
                return;
            WallpaperPickerService.move(-1);
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

    // Where the panel goes: centered, against its edge (or past the bar)
    Item {
        id: frame

        readonly property int margin: Config.padding * 2

        width: Math.min(root.width - Config.spacing * 2, Config.fontSizeNormal * 96)
        height: column.implicitHeight + margin * 2
        x: Math.round((root.width - width) / 2)
        y: root.onBottom ? root.height - root.edgeOffset - height : root.edgeOffset
    }

    AnimatedPopup {
        id: popup

        visible: !root.attached
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        transformOrigin: root.onBottom ? Item.Bottom : Item.Top
        shown: WallpaperPickerService.visible && !root.attached

        Rectangle {
            id: floatingPanel

            anchors.fill: parent
            radius: Config.radiusLarge
            color: Config.backgroundTransparentColor
            border.width: 1
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
        edges: [root.edge]
        radius: Config.radiusLarge + frame.margin
        shown: WallpaperPickerService.visible && root.attached
    }

    // The content, inside whichever panel is in use
    Item {
        id: panel

        parent: root.attached ? attachedPanel.body : floatingPanel
        anchors.fill: parent

        // Swallow clicks so they don't reach the closing MouseArea
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: frame.margin
            y: frame.margin
            width: parent.width - frame.margin * 2
            spacing: Config.spacing

            // Search and filters
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                SearchField {
                    id: search

                    Layout.fillWidth: false
                    Layout.preferredWidth: Config.fontSizeNormal * 24
                    icon: "\u{f0e09}"
                    placeholder: "Search wallpapers…"
                    count: WallpaperPickerService.items.length
                    onTextChanged: WallpaperPickerService.query = text
                    onKeyPressed: event => root.handleKey(event)
                    Component.onCompleted: Qt.callLater(() => {
                        if (WallpaperPickerService.visible)
                            focusInput();
                    })
                }

                Item {
                    Layout.fillWidth: true
                }

                // Alt+1…3
                SegmentedControl {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Config.fontSizeNormal * 7 * root.filters.length
                    options: root.filters
                    currentIndex: Math.max(0, root.filters.findIndex(f => f.id === WallpaperPickerService.filter))
                    onSelected: index => WallpaperPickerService.setFilter(root.filters[index].id)
                }
            }

            ListView {
                id: carousel

                // Cells the width can show, for PageUp/PageDown
                readonly property int visibleCount: Math.max(1, Math.floor(width / cellWidth))
                readonly property real cellWidth: Math.round(root.tileWidth * (1 + root.sideScale) / 2 + Config.spacing)

                Layout.fillWidth: true
                Layout.preferredHeight: root.tileHeight
                visible: count > 0
                orientation: ListView.Horizontal
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: WallpaperPickerService.items
                cacheBuffer: cellWidth * 4

                // The selected tile stays in the middle
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.round((width - cellWidth) / 2)
                preferredHighlightEnd: preferredHighlightBegin + cellWidth
                highlightMoveDuration: Config.animDuration
                highlightFollowsCurrentItem: true

                currentIndex: WallpaperPickerService.selectedIndex
                // A drag or flick moves the current item: tell the service.
                // Other changes (a new model resets it, the highlight sliding
                // past items) follow the service
                onCurrentIndexChanged: {
                    if (currentIndex === WallpaperPickerService.selectedIndex)
                        return;
                    if ((dragging || flicking) && currentIndex >= 0)
                        WallpaperPickerService.select(currentIndex);
                    else
                        currentIndex = WallpaperPickerService.selectedIndex;
                }
                onCountChanged: currentIndex = WallpaperPickerService.selectedIndex

                Connections {
                    target: WallpaperPickerService

                    function onSelectedIndexChanged() {
                        carousel.currentIndex = WallpaperPickerService.selectedIndex;
                    }
                }

                delegate: Item {
                    id: cell

                    required property string modelData
                    required property int index
                    readonly property bool selected: index === carousel.currentIndex

                    width: carousel.cellWidth
                    height: root.tileHeight

                    WallpaperTile {
                        anchors.centerIn: parent
                        width: root.tileWidth
                        path: cell.modelData
                        current: cell.modelData === WallpaperService.currentWallpaper
                        highlighted: cell.selected
                        showName: false
                        scale: cell.selected ? 1 : root.sideScale
                        opacity: cell.selected ? 1 : 0.6

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDuration
                            }
                        }

                        // First click selects, a click on the selected one applies it
                        onActivated: {
                            if (cell.selected)
                                root.applySelected();
                            else
                                WallpaperPickerService.select(cell.index);
                        }
                        onMenuRequested: anchor => menu.openAt(anchor, cell.modelData)
                    }
                }
            }

            // Nothing to show, with a way out when there's one
            ColumnLayout {
                id: empty

                readonly property bool searching: WallpaperPickerService.query.trim() !== ""
                readonly property string filter: WallpaperPickerService.filter
                readonly property bool generating: WallpaperService.generatingFor === WallpaperPickerService.themeName

                Layout.fillWidth: true
                Layout.preferredHeight: root.tileHeight
                visible: carousel.count === 0
                spacing: Config.spacing

                Item {
                    Layout.fillHeight: true
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: {
                        if (empty.searching)
                            return "No wallpaper matches “" + WallpaperPickerService.query.trim() + "”";
                        if (empty.filter === "favorites")
                            return "No favorites yet: right click a wallpaper to add it";
                        if (empty.filter === "theme")
                            return WallpaperService.generateErrors[WallpaperPickerService.themeName] ?? "This theme has no wallpapers yet";
                        return "No wallpapers in ~/.local/wallpapers";
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                // md-image_plus
                ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !empty.searching && empty.filter === "all"
                    icon: "\u{f087c}"
                    text: "Add wallpapers"
                    onClicked: WallpaperPickerService.addWallpapers()
                }

                // md-creation
                ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !empty.searching && empty.filter === "theme"
                    enabled: WallpaperService.generatingFor === ""
                    icon: "\u{f0674}"
                    text: empty.generating ? "Generating… " + WallpaperService.generatedCount + " / " + WallpaperService.generatorScenes.length : "Generate lyne-dots wallpapers"
                    onClicked: WallpaperService.generateThemeWallpapers(WallpaperPickerService.themeName)
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // The selected wallpaper's name, then the keys
            RowLayout {
                id: footer

                Layout.fillWidth: true
                Layout.leftMargin: Config.padding
                Layout.rightMargin: Config.padding
                spacing: Config.spacing * 2

                readonly property string path: WallpaperPickerService.selectedPath

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing
                    visible: footer.path !== ""

                    Text {
                        Layout.maximumWidth: Config.fontSizeNormal * 24
                        text: WallpaperPickerService.highlightedName(footer.path, Config.accentColor)
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textColor
                    }

                    // md-heart
                    Text {
                        visible: WallpaperService.isFavorite(footer.path)
                        text: "\u{f02d1}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.errorColor
                    }

                    Text {
                        text: (WallpaperPickerService.selectedIndex + 1) + " / " + WallpaperPickerService.items.length + (footer.path === WallpaperService.currentWallpaper ? "  ·  in use" : "")
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.mutedColor
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                    visible: footer.path === ""
                }

                KeyHint {
                    keys: "←→"
                    label: "navigate"
                }

                KeyHint {
                    keys: "⏎"
                    label: "apply"
                }

                KeyHint {
                    keys: "alt 1-" + root.filters.length
                    label: "filter"
                }

                KeyHint {
                    keys: "esc"
                    label: WallpaperPickerService.query !== "" ? "clear" : "close"
                }
            }
        }

        // The wheel moves through the wallpapers anywhere on the panel. On
        // top of the content (it only takes the wheel, clicks go through),
        // so the carousel's own flicking never gets it
        Item {
            id: wheelArea

            anchors.fill: parent

            // Steps add up to a notch per move (touchpads send small ones)
            property real rest: 0

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    wheelArea.rest += delta;
                    const steps = Math.trunc(wheelArea.rest / 120);
                    if (steps !== 0) {
                        wheelArea.rest -= steps * 120;
                        WallpaperPickerService.move(-steps);
                    }
                }
            }
        }
    }

    // Wallpaper menu: favorite, make it the current theme's, open Settings
    ContextMenu {
        id: menu

        readonly property bool isFavorite: typeof target === "string" && WallpaperService.isFavorite(target)
        readonly property string themeLabel: ThemeService.themePreviews[WallpaperPickerService.themeName]?.name ?? WallpaperPickerService.themeName

        items: [
            {
                label: isFavorite ? "Remove from favorites" : "Add to favorites",
                icon: isFavorite ? "\u{f02d5}" : "\u{f02d1}",
                action: "favorite"
            },
            {
                label: "Use for " + themeLabel,
                icon: "\u{f03d8}",
                action: "useForTheme",
                hidden: WallpaperPickerService.themeName === ""
            },
            {
                label: "Open in Settings",
                icon: "\u{f0493}",
                action: "settings"
            }
        ].filter(item => !item.hidden)

        onTriggered: (action, path) => {
            switch (action) {
            case "favorite":
                WallpaperService.toggleFavorite(path);
                break;
            case "useForTheme":
                WallpaperPickerService.useForTheme(path);
                break;
            case "settings":
                panel.forceActiveFocus();
                WallpaperPickerService.openSettings();
                break;
            }
        }
    }

    Connections {
        target: WallpaperPickerService

        // Reopened before the exit animation ended: same window, so delay
        // the grab again and give the search its focus back
        function onVisibleChanged() {
            if (!WallpaperPickerService.visible)
                return;
            search.text = "";
            search.focusInput();
        }
    }

    DelayedFocusGrab {
        windows: [root]
        wanted: WallpaperPickerService.visible
        onCleared: {
            if (WallpaperPickerService.visible)
                root.hide();
        }
    }
}
