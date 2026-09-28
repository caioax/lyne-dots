pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

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
    property bool confirmingDelete: false
    // Wallpaper just picked that may become the current theme's (inline prompt)
    property string offerPath: ""

    readonly property bool selecting: selection.length > 0
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

    function deleteSelection() {
        if (selection.length > 1 && !confirmingDelete) {
            confirmingDelete = true;
            return;
        }
        WallpaperService.deleteWallpapers(selection);
        clearSelection();
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
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

    onCategoryChanged: clearSelection()
    // Switching theme (or unlinking) makes the question moot
    onThemeNameChanged: offerPath = ""
    onThemeLinkedChanged: offerPath = ""

    Component.onCompleted: WallpaperService.refreshWallpapers()

    spacing: Config.spacing * 3

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: search.forceActiveFocus()
    }

    Shortcut {
        sequence: "Ctrl+A"
        onActivated: root.selection = [...root.shown]
    }

    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: root.selecting
        onActivated: root.deleteSelection()
    }

    ContextMenu {
        id: menu

        readonly property bool isFavorite: typeof target === "string" && WallpaperService.isFavorite(target)

        items: [
            {
                label: isFavorite ? "Remove from favorites" : "Add to favorites",
                icon: isFavorite ? "\u{f02d5}" : "\u{f02d1}",
                action: "favorite"
            },
            {
                label: "Use for " + root.themeLabel,
                icon: "\u{f012c}",
                action: "useForTheme",
                hidden: ThemeService.isAutoMode
            },
            {
                label: "Add to theme",
                icon: "\u{f03d8}",
                children: ThemeService.availableThemes.map(t => ({
                            label: ThemeService.themePreviews[t]?.name ?? t,
                            icon: "\u{f03d8}",
                            action: "theme:" + t
                        }))
            },
            {
                label: "Select",
                icon: "\u{f0485}",
                action: "select"
            },
            {
                label: "Delete",
                icon: "\u{f09e7}",
                action: "delete",
                danger: true
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
        title: "Current"

        SettingRow {
            id: currentRow

            label: WallpaperService.currentWallpaper !== "" ? root.displayName(WallpaperService.currentWallpaper) : "No wallpaper"
            description: {
                if (ThemeService.isAutoMode)
                    return "Material You: the colors follow this wallpaper";
                if (!WallpaperService.dynamicWallpaper)
                    return "Stays when switching theme";
                if (root.onThemeWallpaper)
                    return root.themeLabel + "'s wallpaper · switching theme brings the new theme's";
                return "Switching theme replaces it with the theme's wallpaper";
            }

            leading: ClippingRectangle {
                implicitWidth: Math.round(root.thumbHeight * 16 / 9)
                implicitHeight: root.thumbHeight
                radius: Config.radius
                color: Config.surface1Color

                Image {
                    anchors.fill: parent
                    source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                    asynchronous: true
                }
            }

            // md-shuffle_variant
            ActionButton {
                icon: "\u{f049f}"
                text: "Random"
                baseColor: currentRow.controlColor
                onClicked: WallpaperService.setRandomWallpaper()
            }

            // md-image_plus
            ActionButton {
                icon: "\u{f087c}"
                text: "Add"
                baseColor: currentRow.controlColor
                onClicked: WallpaperService.addWallpapers()
            }
        }

        // Asked after picking a wallpaper while themes bring their own
        SettingRow {
            id: offerRow

            visible: root.offerPath !== ""
            label: "Also make it " + root.themeLabel + "'s wallpaper?"
            description: "Otherwise it stays until you switch theme, and " + root.themeLabel + " keeps its own"

            leading: Text {
                text: "\u{f03d8}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
            }

            ActionButton {
                text: "Only now"
                baseColor: offerRow.controlColor
                onClicked: root.offerPath = ""
            }

            ActionButton {
                icon: "\u{f012c}"
                text: "Save to theme"
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
            label: WallpaperService.dynamicWallpaper ? "Themes bring their wallpaper" : "Themes keep your wallpaper"
            description: "Change it, or pick each theme's wallpaper, in Theme"

            leading: Text {
                text: WallpaperService.dynamicWallpaper ? "\u{f0339}" : "\u{f033a}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.subtextColor
            }

            ActionButton {
                icon: "\u{f03d8}"
                text: root.themeLabel + "'s wallpapers"
                baseColor: linkRow.controlColor
                onClicked: SettingsService.openThemeDetail(root.themeName)
            }
        }
    }

    // ================= LIBRARY =================
    SettingsGroup {
        title: "Library"

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

                // Tabs + search
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing

                    SegmentedControl {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Config.fontSizeNormal * 15
                        options: [
                            {
                                label: "All",
                                icon: "\u{f02f9}"
                            },
                            {
                                label: "Favorites",
                                icon: "\u{f02d1}"
                            }
                        ]
                        currentIndex: ["all", "favorites"].indexOf(root.category)
                        onSelected: index => root.category = ["all", "favorites"][index]
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Config.fontSizeIconSmall * 2
                        radius: Config.radiusLarge
                        color: Config.surface1Color
                        border.width: search.activeFocus ? 1 : 0
                        border.color: Qt.alpha(Config.accentColor, 0.6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Config.padding * 2
                            anchors.rightMargin: Config.padding * 2
                            spacing: Config.spacing

                            // md-magnify
                            Text {
                                text: "\u{f0349}"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeLarge
                                color: Config.subtextColor
                            }

                            TextInput {
                                id: search

                                Layout.fillWidth: true
                                clip: true
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                color: Config.textColor
                                selectionColor: Qt.alpha(Config.accentColor, 0.4)
                                onTextChanged: root.query = text

                                Text {
                                    visible: search.text === ""
                                    text: "Search"
                                    font: search.font
                                    color: Config.subtextColor
                                }
                            }
                        }
                    }
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
                            text: root.selection.length + " selected · Ctrl+A selects all"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.accentColor
                        }

                        ActionButton {
                            icon: "\u{f09e7}"
                            text: root.confirmingDelete ? "Delete " + root.selection.length + "?" : "Delete"
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

                GridLayout {
                    id: grid

                    readonly property real cellWidth: (width - columnSpacing * (root.columns - 1)) / root.columns

                    visible: root.shown.length > 0
                    Layout.fillWidth: true
                    columns: root.columns
                    columnSpacing: Config.spacing
                    rowSpacing: Config.spacing

                    Repeater {
                        model: root.shown

                        WallpaperTile {
                            required property string modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: grid.cellWidth
                            path: modelData
                            current: modelData === WallpaperService.currentWallpaper
                            selected: root.selection.includes(modelData)
                            selecting: root.selecting
                            onActivated: root.activate(modelData)
                            onSelectToggled: root.toggleSelected(modelData)
                            onMenuRequested: anchor => menu.openAt(anchor, modelData)
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
                    visible: root.shown.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: Config.spacing * 2
                    Layout.bottomMargin: Config.spacing * 2
                    spacing: Config.padding

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.category === "favorites" ? "\u{f02d5}" : "\u{f11d1}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        color: Config.subtextColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (root.query !== "")
                                return "No wallpapers match \"" + root.query + "\"";
                            if (root.category === "favorites")
                                return "No favorites yet: use ⋮ › Add to favorites";
                            return "No wallpapers in ~/.local/wallpapers: use Add";
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
