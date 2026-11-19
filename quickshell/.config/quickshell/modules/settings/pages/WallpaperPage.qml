pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"
import "../../../services/listSync.js" as ListSync

// Wallpaper library: apply, favorite, add, delete. The wallpaper each theme
// brings is picked in the theme's detail view (Theme page); picking one here
// while themes bring their wallpaper offers to save it to the current theme
ColumnLayout {
    id: root

    readonly property int columns: 3
    readonly property int thumbHeight: Config.fontSizeIconLarge * 2

    property string category: "all" // "all" | "favorites"
    property string query: ""
    property var selection: []
    // The library tile whose name is a field now (Rename in its menu)
    property string renamingPath: ""

    // A renamed file stays selected (and new) under its new name
    Connections {
        target: WallpaperService

        function onWallpaperRenamed(from: string, to: string) {
            root.selection = root.selection.map(p => p === from ? to : p);
            root.newPaths = root.newPaths.map(p => p === from ? to : p);
        }
    }
    property bool confirmingDelete: false
    // Wallpaper just picked that may become the current theme's (inline prompt)
    property string offerPath: ""
    // The picker's shortcut is being recorded
    property bool recording: false
    // Added while the page is open: marked "New" until it closes
    property var newPaths: []
    // First of the last ones added, scrolled to once the grid shows it
    property string _scrollTarget: ""

    readonly property bool selecting: selection.length > 0
    // What Delete removes: the selection without the wallpaper in use
    readonly property var deletable: selection.filter(p => p !== WallpaperService.currentWallpaper)
    readonly property string themeName: ThemeService.currentThemeName
    readonly property string themeLabel: ThemeService.themePreviews[themeName]?.name ?? themeName
    readonly property bool themeLinked: WallpaperService.dynamicWallpaper && !ThemeService.isAutoMode
    readonly property bool onThemeWallpaper: WallpaperService.currentWallpaper !== "" && WallpaperService.fileName(WallpaperService.currentWallpaper) === WallpaperService.fileName(WallpaperService.themeWallpaperPath(themeName))

    readonly property var shown: {
        let list = WallpaperService.wallpapers;
        if (category === "favorites")
            list = list.filter(w => WallpaperService.isFavorite(w));
        if (query !== "") {
            const q = query.toLowerCase();
            list = list.filter(w => WallpaperService.fileName(w).toLowerCase().includes(q));
        }
        return list;
    }

    // Videos Add is scaling down, shown above the library until they're
    // listed: then they take their place in it like any new wallpaper
    readonly property var fittingShown: Object.keys(WallpaperService.fitting).filter(p => !WallpaperService.wallpapers.includes(p))

    function displayName(path: string): string {
        const name = WallpaperService.fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function clearSelection() {
        selection = [];
        confirmingDelete = false;
    }

    function toggleSelected(path: string) {
        selection = selection.includes(path) ? selection.filter(p => p !== path) : [...selection, path];
        confirmingDelete = false;
    }

    // Sets it as the wallpaper; while themes bring their wallpaper, asks
    // whether it should become the current theme's too
    function activate(path: string) {
        WallpaperService.setWallpaper(path);
        const themePath = WallpaperService.themeWallpaperPath(themeName);
        offerPath = themeLinked && WallpaperService.fileName(path) !== WallpaperService.fileName(themePath) ? path : "";
    }

    function saveOfferToTheme() {
        WallpaperService.setThemeWallpaper(offerPath, themeName);
        offerPath = "";
    }

    function startRecording() {
        recording = true;
        KeybindsService.startCapture();
    }

    function stopRecording() {
        if (!recording)
            return;
        recording = false;
        KeybindsService.stopCapture();
    }

    function deleteSelection() {
        if (deletable.length === 0)
            return;
        if (deletable.length > 1 && !confirmingDelete) {
            confirmingDelete = true;
            return;
        }
        WallpaperService.deleteWallpapers(deletable);
        clearSelection();
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (recording) {
            stopRecording();
            return true;
        }
        if (menu.opened) {
            menu.close();
            return true;
        }
        if (offerPath !== "") {
            offerPath = "";
            return true;
        }
        if (selecting) {
            clearSelection();
            return true;
        }
        if (search.text !== "") {
            search.text = "";
            return true;
        }
        return false;
    }

    // The grid's rows follow `shown` change by change, so deleting or
    // filtering keeps the other tiles (and the page height, and so the
    // scroll) instead of building them all again
    onShownChanged: ListSync.apply(tilesModel, "path", shown)

    onCategoryChanged: clearSelection()
    // Switching theme (or unlinking) makes the question moot
    onThemeNameChanged: offerPath = ""
    onThemeLinkedChanged: offerPath = ""

    Component.onCompleted: {
        ListSync.apply(tilesModel, "path", shown);
        WallpaperService.refreshWallpapers();
    }
    // Never leave Hyprland in the capture submap
    Component.onDestruction: stopRecording()

    ListModel {
        id: tilesModel
    }

    // New ones show even when the tab or the search would hide them
    Connections {
        target: WallpaperService

        function onWallpapersAdded(paths) {
            root.newPaths = [...root.newPaths, ...paths];
            root.category = "all";
            if (!paths.some(p => root.shown.includes(p)))
                search.text = "";
            root._scrollTarget = paths[0];
            scrollTimer.restart();
        }

        // A video Add starts scaling down: the area above the library comes
        // into view
        function onFittingChanged() {
            const started = Object.keys(WallpaperService.fitting).filter(p => !root._fitSeen.includes(p));
            root._fitSeen = Object.keys(WallpaperService.fitting);
            if (started.length > 0)
                fitScrollTimer.restart();
        }
    }

    // Progress tiles already announced
    property var _fitSeen: []

    Timer {
        id: fitScrollTimer

        // Lets the area lay out before measuring
        interval: Config.animDuration
        onTriggered: {
            if (fittingArea.visible)
                SettingsService.scrollToItem(fittingArea);
        }
    }

    Timer {
        id: scrollTimer

        // Lets the grid lay the new tiles out before measuring
        interval: Config.animDuration
        onTriggered: {
            for (let i = 0; i < tilesModel.count; i++) {
                if (tilesModel.get(i).path === root._scrollTarget) {
                    SettingsService.scrollToItem(tiles.itemAt(i));
                    break;
                }
            }
            root._scrollTarget = "";
        }
    }

    Connections {
        target: KeybindsService

        // The service's safety timeout ended the capture
        function onCapturingChanged() {
            if (!KeybindsService.capturing)
                root.recording = false;
        }
    }

    spacing: Config.spacing * 3

    // Not while a name is typed: Ctrl+A and Delete belong to the field then
    Shortcut {
        sequence: "Ctrl+A"
        enabled: root.renamingPath === ""
        onActivated: root.selection = [...root.shown]
    }

    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: root.selecting && root.renamingPath === ""
        onActivated: root.deleteSelection()
    }

    ContextMenu {
        id: menu

        readonly property bool isFavorite: typeof target === "string" && WallpaperService.isFavorite(target)

        items: [
            {
                label: isFavorite ? I18n.tr("Remove from favorites") : I18n.tr("Add to favorites"),
                icon: isFavorite ? "\u{f02d5}" : "\u{f02d1}",
                action: "favorite"
            },
            {
                label: I18n.tr("Use for %1", root.themeLabel),
                icon: "\u{f012c}",
                action: "useForTheme",
                hidden: ThemeService.isAutoMode
            },
            {
                label: I18n.tr("Add to theme"),
                icon: "\u{f03d8}",
                children: ThemeService.availableThemes.map(t => ({
                            label: ThemeService.themePreviews[t]?.name ?? t,
                            icon: "\u{f03d8}",
                            action: "theme:" + t
                        }))
            },
            {
                label: I18n.tr("Rename"),
                icon: "\u{f03eb}",
                action: "rename"
            },
            {
                label: I18n.tr("Select"),
                icon: "\u{f0485}",
                action: "select"
            },
            {
                label: I18n.tr("Delete"),
                icon: "\u{f09e7}",
                action: "delete",
                danger: true,
                // The one in use can't go: apply another first
                disabled: target === WallpaperService.currentWallpaper,
                detail: target === WallpaperService.currentWallpaper ? I18n.tr("In use") : ""
            }
        ].filter(item => !item.hidden)

        onTriggered: (action, path) => {
            if (action.startsWith("theme:")) {
                WallpaperService.addToTheme(path, action.slice(6));
                return;
            }
            switch (action) {
            case "useForTheme":
                WallpaperService.setThemeWallpaper(path, root.themeName);
                break;
            case "favorite":
                WallpaperService.toggleFavorite(path);
                break;
            case "rename":
                root.renamingPath = path;
                break;
            case "select":
                root.toggleSelected(path);
                break;
            case "delete":
                WallpaperService.deleteWallpapers([path]);
                break;
            }
        }
    }

    // ================= CURRENT =================
    SettingsGroup {
        title: I18n.tr("Current")

        SettingRow {
            label: WallpaperService.currentWallpaper !== "" ? root.displayName(WallpaperService.currentWallpaper) : I18n.tr("No wallpaper")
            description: {
                if (ThemeService.isAutoMode)
                    return I18n.tr("Material You: the colors follow this wallpaper");
                if (!WallpaperService.dynamicWallpaper)
                    return I18n.tr("Stays when switching theme");
                if (root.onThemeWallpaper)
                    return I18n.tr("Wallpaper of %1 · switching theme brings the new theme's", root.themeLabel);
                return I18n.tr("Switching theme replaces it with the theme's wallpaper");
            }

            leading: ClippingRectangle {
                implicitWidth: Math.round(root.thumbHeight * 16 / 9)
                implicitHeight: root.thumbHeight
                radius: Config.radius
                color: Config.surface1Color

                Image {
                    anchors.fill: parent
                    source: WallpaperService.stillSource(WallpaperService.currentWallpaper)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Config.wallpaperThumbSize
                    asynchronous: true
                }
            }
        }

        // Asked after picking a wallpaper while themes bring their own
        SettingRow {
            id: offerRow

            visible: root.offerPath !== ""
            label: I18n.tr("Also make it the wallpaper of %1?", root.themeLabel)
            description: I18n.tr("Otherwise it stays until you switch theme, and %1 keeps its own", root.themeLabel)

            leading: Text {
                text: "\u{f03d8}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
            }

            ActionButton {
                text: I18n.tr("Only now")
                baseColor: offerRow.controlColor
                onClicked: root.offerPath = ""
            }

            ActionButton {
                icon: "\u{f012c}"
                text: I18n.tr("Save to theme")
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: root.saveOfferToTheme()
            }
        }

        // Where the link between themes and wallpapers is set
        SettingRow {
            id: linkRow

            visible: !ThemeService.isAutoMode
            label: WallpaperService.dynamicWallpaper ? I18n.tr("Themes bring their wallpaper") : I18n.tr("Themes keep your wallpaper")
            description: I18n.tr("Change it, or pick each theme's wallpaper, in Theme")

            leading: Text {
                text: WallpaperService.dynamicWallpaper ? "\u{f0339}" : "\u{f033a}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.subtextColor
            }

            ActionButton {
                icon: "\u{f03d8}"
                text: I18n.tr("Wallpapers of %1", root.themeLabel)
                baseColor: linkRow.controlColor
                onClicked: SettingsService.openThemeDetail(root.themeName)
            }
        }
    }

    // ================= TRANSITION =================
    SettingsGroup {
        title: I18n.tr("Transition")

        SelectRow {
            label: I18n.tr("Effect")
            description: I18n.tr("How a new wallpaper replaces the one on screen, also when switching theme and at login")
            path: "wallpaper.transition"
            segmentWidth: Config.fontSizeNormal * 4.5
            value: WallpaperService.transition
            options: [
                {
                    label: I18n.tr("None"),
                    value: "none"
                },
                {
                    label: I18n.tr("Fade"),
                    value: "fade"
                },
                {
                    label: I18n.tr("Grow"),
                    value: "grow"
                },
                {
                    label: I18n.tr("Wipe"),
                    value: "wipe"
                },
                {
                    label: I18n.tr("Wave"),
                    value: "wave"
                },
                {
                    label: I18n.tr("Random"),
                    value: "random"
                }
            ]
            onSelected: value => WallpaperService.transition = value
            onResetRequested: WallpaperService.transition = StateService.get(path, "fade")
        }

        SelectRow {
            visible: WallpaperService.transition !== "none"
            label: I18n.tr("Speed")
            description: I18n.tr("How long the transition takes")
            path: "wallpaper.transitionSpeed"
            value: WallpaperService.transitionSpeed
            options: [
                {
                    label: I18n.tr("Fast"),
                    value: "fast"
                },
                {
                    label: I18n.tr("Normal"),
                    value: "normal"
                },
                {
                    label: I18n.tr("Slow"),
                    value: "slow"
                }
            ]
            onSelected: value => WallpaperService.transitionSpeed = value
            onResetRequested: WallpaperService.transitionSpeed = StateService.get(path, "normal")
        }
    }

    // ================= ANIMATED WALLPAPERS =================
    SettingsGroup {
        title: I18n.tr("Animated wallpapers")

        ToggleRow {
            label: I18n.tr("Pause under fullscreen windows")
            description: I18n.tr("Once every screen is covered; a free screen keeps it moving")
            path: "wallpaper.pauseCovered"
            onToggled: value => WallpaperService.pauseCovered = value
            onResetRequested: WallpaperService.pauseCovered = StateService.get(path, true)
        }

        ToggleRow {
            label: I18n.tr("Pause while locked")
            description: I18n.tr("The lock screen shows a still frame of it instead")
            path: "wallpaper.pauseLocked"
            onToggled: value => WallpaperService.pauseLocked = value
            onResetRequested: WallpaperService.pauseLocked = StateService.get(path, true)
        }

        // Unset until chosen: on where there is a battery (the service decides)
        ToggleRow {
            label: I18n.tr("Pause on battery")
            description: I18n.tr("Saves power while the charger is unplugged")
            path: "wallpaper.pauseOnBattery"
            checked: WallpaperService.pauseOnBattery
            onToggled: value => WallpaperService.pauseOnBatteryStored = value
            onResetRequested: WallpaperService.pauseOnBatteryStored = StateService.get(path, null)
        }

        SelectRow {
            label: I18n.tr("Frame rate")
            description: I18n.tr("Fewer frames take less work to draw; slower videos keep their own")
            path: "wallpaper.videoFps"
            value: WallpaperService.videoFps
            options: [
                {
                    label: I18n.tr("Original"),
                    value: 0
                },
                {
                    label: I18n.tr("30 fps"),
                    value: 30
                },
                {
                    label: I18n.tr("15 fps"),
                    value: 15
                }
            ]
            onSelected: value => WallpaperService.videoFps = value
            onResetRequested: WallpaperService.videoFps = StateService.get(path, 30)
        }
    }

    // ================= PICKER =================
    SettingsGroup {
        title: I18n.tr("Picker")

        SettingRow {
            id: pickerRow

            readonly property var bind: KeybindsService.binds.find(b => b.id === "wallpapers") ?? null
            readonly property var conflicts: KeybindsService.conflicts(bind?.keys ?? "", "wallpapers", -1)

            resettable: false
            label: I18n.tr("Wallpaper picker")
            descriptionColor: conflicts.length > 0 ? Config.warningColor : Config.subtextColor
            description: conflicts.length > 0 ? I18n.tr("Also used by %1", conflicts.join(", ")) : I18n.tr("A carousel of the library: type to filter, Enter applies, Escape closes")

            KeyCombo {
                visible: pickerRow.bind !== null
                keys: pickerRow.bind?.keys ?? ""
                baseColor: pickerRow.controlColor
                recording: root.recording
                onRecordRequested: root.startRecording()
                onRecorded: combo => {
                    KeybindsService.setKeys("wallpapers", combo);
                    root.stopRecording();
                }
            }

            // md-play
            ActionButton {
                icon: "\u{f040a}"
                text: I18n.tr("Open")
                baseColor: pickerRow.controlColor
                onClicked: WallpaperPickerService.show()
            }
        }

        SelectRow {
            label: I18n.tr("Position")
            description: I18n.tr("Screen edge the picker opens against (past the bar, when it's there)")
            path: "wallpaper.pickerPosition"
            options: [
                {
                    label: I18n.tr("Bottom"),
                    icon: "\u{f10a9}",
                    value: "bottom"
                },
                {
                    label: I18n.tr("Top"),
                    icon: "\u{f1513}",
                    value: "top"
                }
            ]
        }
    }

    // ================= LIBRARY =================
    SettingsGroup {
        title: I18n.tr("Library")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: library.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.cardColor

            ColumnLayout {
                id: library

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Config.padding * 2
                spacing: Config.spacing + Config.padding

                // Tabs + what changes the library, then the search
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing

                    SegmentedControl {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Config.fontSizeNormal * 15
                        options: [
                            {
                                label: I18n.tr("All"),
                                icon: "\u{f02f9}"
                            },
                            {
                                label: I18n.tr("Favorites"),
                                icon: "\u{f02d1}"
                            }
                        ]
                        currentIndex: ["all", "favorites"].indexOf(root.category)
                        onSelected: index => root.category = ["all", "favorites"][index]
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // md-shuffle_variant
                    ActionButton {
                        icon: "\u{f049f}"
                        text: I18n.tr("Random")
                        onClicked: WallpaperService.setRandomWallpaper()
                    }

                    // md-image_plus
                    ActionButton {
                        icon: "\u{f087c}"
                        text: I18n.tr("Add")
                        onClicked: WallpaperService.addWallpapers(false)
                    }

                    // md-folder_plus
                    ActionButton {
                        icon: "\u{f0257}"
                        text: I18n.tr("Add folder")
                        onClicked: WallpaperService.addWallpapers(true)
                    }
                }

                QsSearchField {
                    id: search

                    Layout.fillWidth: true
                    placeholder: I18n.tr("Search")
                    onTextChanged: root.query = text
                }


                // Selection bar
                Rectangle {
                    visible: root.selecting
                    Layout.fillWidth: true
                    implicitHeight: selectionRow.implicitHeight + Config.padding * 2
                    radius: Config.radius
                    color: Qt.alpha(Config.accentColor, 0.15)

                    RowLayout {
                        id: selectionRow

                        anchors.fill: parent
                        anchors.margins: Config.padding
                        anchors.leftMargin: Config.padding * 2
                        spacing: Config.spacing

                        Text {
                            Layout.fillWidth: true
                            text: root.deletable.length < root.selection.length ? I18n.trn("%n selected · the one in use is kept", "%n selected · the one in use is kept", root.selection.length) : I18n.trn("%n selected · Ctrl+A selects all", "%n selected · Ctrl+A selects all", root.selection.length)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.accentColor
                        }

                        ActionButton {
                            icon: "\u{f09e7}"
                            enabled: root.deletable.length > 0
                            opacity: enabled ? 1 : 0.4
                            text: root.confirmingDelete ? I18n.tr("Delete %1?", root.deletable.length) : I18n.tr("Delete")
                            baseColor: root.confirmingDelete ? Config.errorColor : Config.surface1Color
                            hoverColor: root.confirmingDelete ? Qt.lighter(Config.errorColor, 1.1) : Config.surface2Color
                            textColor: root.confirmingDelete ? Config.textReverseColor : Config.errorColor
                            onClicked: root.deleteSelection()
                        }

                        // md-close
                        ActionButton {
                            icon: "\u{f0156}"
                            onClicked: root.clearSelection()
                        }
                    }
                }

                // Videos being scaled down (Add), apart until they're done
                ColumnLayout {
                    id: fittingArea

                    visible: root.fittingShown.length > 0
                    Layout.fillWidth: true
                    Layout.bottomMargin: Config.padding
                    spacing: Config.padding

                    Text {
                        Layout.fillWidth: true
                        text: I18n.trn("Fitting %n video to your screen", "Fitting %n videos to your screen", root.fittingShown.length)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.columns
                        columnSpacing: Config.spacing
                        rowSpacing: Config.spacing

                        Repeater {
                            model: root.fittingShown

                            WallpaperTile {
                                id: fitTile

                                required property string modelData
                                readonly property var fit: WallpaperService.fitting[modelData] ?? null

                                Layout.fillWidth: true
                                Layout.preferredWidth: grid.cellWidth
                                path: modelData
                                progress: fit ? fit.progress : 0
                                progressPoster: fit?.poster ?? ""
                                showMenu: false
                                onCancelRequested: WallpaperService.cancelFit(fitTile.path)
                            }
                        }

                        // Keeps a lone tile at the library's size
                        Repeater {
                            model: Math.max(0, root.columns - root.fittingShown.length)

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: grid.cellWidth
                            }
                        }
                    }
                }

                GridLayout {
                    id: grid

                    readonly property real cellWidth: (width - columnSpacing * (root.columns - 1)) / root.columns

                    visible: root.shown.length > 0
                    Layout.fillWidth: true
                    columns: root.columns
                    columnSpacing: Config.spacing
                    rowSpacing: Config.spacing

                    Repeater {
                        id: tiles

                        model: tilesModel

                        // `path` comes from the model's role
                        WallpaperTile {
                            id: tile

                            Layout.fillWidth: true
                            Layout.preferredWidth: grid.cellWidth
                            current: path === WallpaperService.currentWallpaper
                            selected: root.selection.includes(path)
                            selecting: root.selecting
                            isNew: root.newPaths.includes(path)
                            badge: isNew ? I18n.tr("New") : ""
                            onActivated: root.activate(tile.path)
                            onSelectToggled: root.toggleSelected(tile.path)
                            onMenuRequested: anchor => menu.openAt(anchor, tile.path)
                            renaming: root.renamingPath === path
                            onRenamingChanged: renameError = ""
                            onRenameAccepted: name => {
                                const error = WallpaperService.renameWallpaper(tile.path, name);
                                if (error !== "")
                                    tile.renameError = error;
                                else
                                    root.renamingPath = "";
                            }
                            onRenameCancelled: root.renamingPath = ""
                        }
                    }

                    // Fills the first row when there are fewer tiles than
                    // columns, so a lone tile keeps its size
                    Repeater {
                        model: Math.max(0, root.columns - root.shown.length)

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: grid.cellWidth
                        }
                    }
                }

                // Empty state
                ColumnLayout {
                    visible: root.shown.length === 0 && root.fittingShown.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: Config.spacing * 2
                    Layout.bottomMargin: Config.spacing * 2
                    spacing: Config.padding

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.category === "favorites" ? "\u{f02d5}" : "\u{f11d1}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        color: Config.subtextColor
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: {
                            if (root.query !== "")
                                return I18n.tr("No wallpapers match “%1”", root.query);
                            if (root.category === "favorites")
                                return I18n.tr("No favorites yet: use ⋮ › Add to favorites");
                            return I18n.tr("No wallpapers in ~/.local/wallpapers: use Add");
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                    }
                }
            }
        }
    }
}
