pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Wallpaper library: apply, favorite, add, delete, and pick the wallpaper of
// each preset theme (Themes tab)
ColumnLayout {
    id: root

    readonly property int columns: 3
    readonly property int thumbHeight: Config.fontSizeIconLarge * 2

    property string category: "all" // "all" | "favorites" | "themes"
    property string query: ""
    // Theme whose folder the Themes tab shows
    property string theme: ThemeService.currentThemeName
    property var selection: []
    property bool confirmingDelete: false

    readonly property bool selecting: selection.length > 0
    readonly property bool themesTab: category === "themes"
    readonly property string themeActive: WallpaperService.themeWallpaperPath(theme)

    readonly property var shown: {
        let list = themesTab ? WallpaperService.themeWallpapers : WallpaperService.wallpapers;
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

    // Library: set as wallpaper. Themes tab: make it the theme's wallpaper,
    // and show it right away when that theme is the one in use
    function activate(path: string) {
        if (!themesTab) {
            WallpaperService.setWallpaper(path);
            return;
        }
        WallpaperService.setActiveThemeWallpaper(path, theme);
        if (theme === ThemeService.currentThemeName && !ThemeService.isAutoMode)
            WallpaperService.setWallpaper(path);
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
    onThemeChanged: {
        clearSelection();
        if (themesTab)
            WallpaperService.refreshThemeWallpapers(theme);
    }
    onThemesTabChanged: {
        if (themesTab)
            WallpaperService.refreshThemeWallpapers(theme);
    }

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

    WallpaperMenu {
        id: menu

        items: root.themesTab ? [
            {
                label: "Apply now",
                icon: "\u{f012c}",
                action: "apply"
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
        ] : [
            {
                label: WallpaperService.isFavorite(menu.path) ? "Remove from favorites" : "Add to favorites",
                icon: WallpaperService.isFavorite(menu.path) ? "\u{f02d5}" : "\u{f02d1}",
                action: "favorite"
            },
            {
                label: "Add to theme",
                icon: "\u{f03d8}",
                action: "add-to-theme"
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
        ]

        onTriggered: (action, path) => {
            switch (action) {
            case "apply":
                WallpaperService.setWallpaper(path);
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
        onThemePicked: (theme, path) => WallpaperService.addToTheme(path, theme)
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
                if (WallpaperService.dynamicWallpaper)
                    return "Switching preset also switches to its wallpaper";
                return "Stays when switching preset";
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
    }

    // ================= LIBRARY =================
    SettingsGroup {
        title: "Library"

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: library.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.surface0Color

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
                        Layout.preferredWidth: Config.fontSizeNormal * 22
                        options: [
                            {
                                label: "All",
                                icon: "\u{f02f9}"
                            },
                            {
                                label: "Favorites",
                                icon: "\u{f02d1}"
                            },
                            {
                                label: "Themes",
                                icon: "\u{f03d8}"
                            }
                        ]
                        currentIndex: ["all", "favorites", "themes"].indexOf(root.category)
                        onSelected: index => root.category = ["all", "favorites", "themes"][index]
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

                // Themes tab: which preset's folder is shown
                Flow {
                    visible: root.themesTab
                    Layout.fillWidth: true
                    spacing: Config.padding

                    Repeater {
                        model: ThemeService.availableThemes

                        Rectangle {
                            id: chip

                            required property string modelData
                            readonly property bool active: modelData === root.theme

                            width: chipText.implicitWidth + Config.padding * 4
                            height: chipText.implicitHeight + Config.padding * 2
                            radius: height / 2
                            color: active ? Config.accentColor : chipMouse.containsMouse ? Config.surface2Color : Config.surface1Color

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: ThemeService.themePreviews[chip.modelData]?.name ?? chip.modelData
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: chip.active
                                color: chip.active ? Config.textReverseColor : Config.textColor
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.theme = chip.modelData
                            }
                        }
                    }
                }

                Text {
                    visible: root.themesTab
                    Layout.fillWidth: true
                    text: "Click a wallpaper to use it for this theme. Add more from the All tab (⋮ › Add to theme)"
                    wrapMode: Text.WordWrap
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
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
                            Layout.preferredWidth: (grid.width - grid.columnSpacing * (root.columns - 1)) / root.columns
                            path: modelData
                            current: root.themesTab ? false : modelData === WallpaperService.currentWallpaper
                            badge: root.themesTab && modelData === root.themeActive ? "\u{f012c} Active" : ""
                            selected: root.selection.includes(modelData)
                            selecting: root.selecting
                            onActivated: root.activate(modelData)
                            onSelectToggled: root.toggleSelected(modelData)
                            onMenuRequested: anchor => menu.openAt(anchor, modelData)
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
                            if (root.themesTab)
                                return "This theme has no wallpapers yet";
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
