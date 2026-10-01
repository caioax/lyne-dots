pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Colors, transparency and the theme grid. A theme's ⋯ opens its detail view
// (ThemeDetail) in place of the grid
ColumnLayout {
    id: root

    readonly property bool auto: ThemeService.isAutoMode
    readonly property int columns: 3
    // Theme shown in the detail view, "" for the grid
    property string detail: ""
    // New theme view; createEdit / createFrom open it on a custom theme to
    // edit, or on a theme to duplicate
    property bool creating: false
    property string createEdit: ""
    property string createFrom: ""
    readonly property bool onGrid: detail === "" && !creating

    function openDetail(themeName: string) {
        detail = themeName;
        scrollToTop();
    }

    function openCreator(editSlug: string, fromSlug: string) {
        createEdit = editSlug;
        createFrom = fromSlug;
        detail = "";
        creating = true;
        scrollToTop();
    }

    // The page lives in SettingsWindow's Flickable: back to its top when
    // switching between the grid and a detail view
    function scrollToTop() {
        let item = root.parent;
        while (item && item.contentY === undefined)
            item = item.parent;
        if (item)
            item.contentY = 0;
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (onGrid)
            return false;
        if (creating && creatorLoader.item?.confirmLeave())
            return true;
        detail = "";
        creating = false;
        scrollToTop();
        return true;
    }

    Component.onCompleted: {
        if (SettingsService.pendingThemeDetail !== "") {
            detail = SettingsService.pendingThemeDetail;
            SettingsService.pendingThemeDetail = "";
        }
    }

    Connections {
        target: SettingsService

        function onThemeDetailRequested(themeName) {
            SettingsService.pendingThemeDetail = "";
            root.openDetail(themeName);
        }
    }

    spacing: Config.spacing * 3

    ThemeDetail {
        visible: root.detail !== ""
        Layout.fillWidth: true
        theme: root.detail
        onBack: root.handleEscape()
        onEditRequested: root.openCreator(root.detail, "")
        onDuplicateRequested: root.openCreator("", root.detail)
    }

    // Created on demand, so each visit starts from fresh picks
    Loader {
        id: creatorLoader

        active: root.creating
        visible: active
        Layout.fillWidth: true

        sourceComponent: ThemeCreator {
            editSlug: root.createEdit
            duplicateFrom: root.createFrom
            onBack: root.handleEscape()
            onSaved: slug => {
                root.creating = false;
                root.openDetail(slug);
            }
        }
    }

    SettingsGroup {
        visible: root.onGrid
        title: "Colors"

        SelectRow {
            label: "Source"
            description: "A theme's palette, or colors picked from your wallpaper"
            segmentWidth: Config.fontSizeNormal * 9
            options: [
                {
                    label: "Theme",
                    icon: "\u{f03d8}",
                    value: "preset"
                },
                {
                    label: "Material You",
                    icon: "\u{f0e09}",
                    value: "auto"
                }
            ]
            value: ThemeService.themeMode
            onSelected: value => {
                if (value === "auto")
                    ThemeService.setAutoMode();
                else
                    ThemeService.setPresetMode(ThemeService.currentThemeName);
            }
        }

        SelectRow {
            label: "Mode"
            description: "Also applied to GTK and Qt apps, Kitty and Neovim"
            options: [
                {
                    label: "Dark",
                    icon: "\u{f0594}",
                    value: "dark"
                },
                {
                    label: "Light",
                    icon: "\u{f05a8}",
                    value: "light"
                }
            ]
            value: ThemeService.colorScheme
            onSelected: value => ThemeService.setColorScheme(value)
        }

        SettingRow {
            id: wallpaperRow

            visible: root.auto
            label: "Colors follow your wallpaper"
            description: "Pick another wallpaper to get a new palette"

            PaletteDots {
                colors: [Config.accentColor, Config.successColor, Config.warningColor, Config.errorColor]
            }

            ActionButton {
                icon: "\u{f0e09}"
                text: "Change wallpaper"
                baseColor: wallpaperRow.controlColor
                onClicked: SettingsService.currentPage = "wallpaper"
            }
        }
    }

    SettingsGroup {
        visible: root.onGrid
        title: "Themes"

        SettingRow {
            id: createRow

            label: "Make your own"
            description: "Start from an accent color; the rest of the theme follows"

            ActionButton {
                icon: "\u{f0415}"
                text: "New theme"
                baseColor: createRow.controlColor
                onClicked: root.openCreator("", "")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.cardColor

            GridLayout {
                id: grid

                anchors.fill: parent
                anchors.margins: Config.padding * 2
                columns: root.columns
                columnSpacing: Config.spacing
                rowSpacing: Config.spacing

                Repeater {
                    model: ThemeService.displayThemes

                    ThemeTile {
                        id: tile

                        Layout.preferredWidth: (grid.width - grid.columnSpacing * (root.columns - 1)) / root.columns
                        thumbHeight: Config.fontSizeIconLarge * 3
                        loadImage: root.onGrid
                        showDetails: true
                        onDetailsRequested: root.openDetail(tile.modelData)
                    }
                }
            }
        }
    }

    SettingsGroup {
        visible: root.onGrid && !root.auto
        title: "Wallpaper"

        SelectRow {
            label: "When switching theme"
            description: WallpaperService.dynamicWallpaper ? "Each theme brings its own wallpaper: pick it in the theme's ⋯ page" : "Your wallpaper stays; themes only change the colors"
            path: "wallpaper.dynamic"
            segmentWidth: Config.fontSizeNormal * 8
            options: [
                {
                    label: "Use theme's",
                    icon: "\u{f0339}",
                    value: true
                },
                {
                    label: "Keep mine",
                    icon: "\u{f033a}",
                    value: false
                }
            ]
        }
    }

    // Profiles found in ~/.zen (none until Zen has run once)
    SettingsGroup {
        visible: root.onGrid && ZenService.installed
        title: "Zen Browser"

        Component.onCompleted: ZenService.refresh()

        Repeater {
            model: ZenService.profiles

            ToggleRow {
                required property var modelData

                label: modelData.name
                description: [modelData.enabled ? "Follows the theme" : "Zen's own colors", modelData.default ? "default profile" : "", modelData.running ? "open" : ""].filter(s => s !== "").join(" · ")
                checked: modelData.enabled
                resettable: false
                onToggled: value => ZenService.setEnabled(modelData.dir, value)
            }
        }

        ToggleRow {
            label: "Theme background"
            description: checked ? "Every workspace uses the theme's background" : "Workspaces with their own gradient keep it"
            path: "zen.themeBackground"
            enabled: ZenService.enabledProfiles.length > 0
        }

        ToggleRow {
            label: "Transparency"
            description: "The window follows Background opacity (Layout), blurred like the shell"
            path: "zen.transparent"
            enabled: ZenService.enabledProfiles.length > 0
        }

        SettingRow {
            visible: ZenService.restartNeeded
            label: "Zen is open"
            description: "Restart it to see the new colors (Zen reads its theme at startup)"
            descriptionColor: Config.warningColor
        }
    }
}
