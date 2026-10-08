pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Detail view of one theme inside the Theme page: its colors and the
// wallpapers in its folder (~/.local/wallpapers/themes/<theme>/), one of them
// being the wallpaper the theme brings when switched to
ColumnLayout {
    id: root

    required property string theme

    readonly property int columns: 3
    readonly property int thumbHeight: Config.fontSizeIconLarge * 2
    readonly property var preview: ThemeService.themePreviews[theme] ?? {}
    readonly property var themePalette: preview.palette ?? {}
    readonly property var terminal: preview.terminal ?? {}
    readonly property string displayName: preview.name ?? theme
    readonly property bool inUse: !ThemeService.isAutoMode && theme === ThemeService.currentThemeName
    readonly property string activePath: WallpaperService.themeWallpaperPath(theme)
    readonly property bool linked: WallpaperService.dynamicWallpaper && !ThemeService.isAutoMode
    property bool pickingFromLibrary: false
    property bool confirmingDelete: false
    readonly property bool generating: WallpaperService.generatingFor === theme
    readonly property bool hasLyneWallpapers: WallpaperService.themeWallpapers.some(p => WallpaperService.fileName(p).startsWith("lyne-" + theme + "-"))
    readonly property string generateError: WallpaperService.generateErrors[theme] ?? ""
    readonly property bool custom: preview.custom === true

    // Library wallpapers that aren't in the theme's folder yet
    readonly property var libraryChoices: {
        const names = WallpaperService.themeWallpapers.map(p => WallpaperService.fileName(p));
        return WallpaperService.wallpapers.filter(p => !names.includes(WallpaperService.fileName(p)));
    }

    signal back
    signal editRequested
    signal duplicateRequested

    function displayFileName(path: string): string {
        const name = WallpaperService.fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function pick(path: string) {
        WallpaperService.setThemeWallpaper(path, theme);
        pickingFromLibrary = false;
    }

    onThemeChanged: {
        pickingFromLibrary = false;
        confirmingDelete = false;
        WallpaperService.refreshThemeWallpapers(theme);
    }
    Component.onCompleted: {
        WallpaperService.refreshThemeWallpapers(theme);
        WallpaperService.refreshWallpapers();
    }

    spacing: Config.spacing * 3

    ContextMenu {
        id: menu

        items: [
            {
                label: "Use for " + root.displayName,
                icon: "\u{f012c}",
                action: "use"
            },
            {
                label: "Show now",
                icon: "\u{f02e9}",
                action: "apply"
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
            case "use":
                root.pick(path);
                break;
            case "apply":
                WallpaperService.setWallpaper(path);
                break;
            case "delete":
                WallpaperService.deleteWallpapers([path]);
                break;
            }
        }
    }

    ContextMenu {
        id: themeMenu

        items: [
            {
                label: "Edit colors",
                icon: "\u{f03eb}",
                action: "edit",
                hidden: !root.custom
            },
            {
                label: "Duplicate",
                icon: "\u{f0191}",
                action: "duplicate"
            },
            {
                label: "Delete",
                icon: "\u{f09e7}",
                action: "delete",
                danger: true,
                hidden: !root.custom
            }
        ].filter(item => !item.hidden)

        onTriggered: action => {
            if (action === "edit")
                root.editRequested();
            else if (action === "duplicate")
                root.duplicateRequested();
            else if (action === "delete")
                root.confirmingDelete = true;
        }
    }

    PageHeader {
        title: root.displayName
        subtitle: {
            const kind = (root.preview.variant === "light" ? "Light" : "Dark") + (root.custom ? " · made by you" : " theme");
            return root.inUse ? kind + " · in use" : kind;
        }
        icon: "\u{f03d8}"
        onBackClicked: root.back()

        ActionButton {
            visible: !root.inUse
            icon: "\u{f012c}"
            text: "Apply"
            baseColor: Config.accentColor
            hoverColor: Qt.lighter(Config.accentColor, 1.1)
            textColor: Config.textReverseColor
            onClicked: ThemeService.setPresetMode(root.theme)
        }

        // md-pencil: custom themes open straight in the editor
        ActionButton {
            visible: root.custom
            icon: "\u{f03eb}"
            text: "Edit"
            onClicked: root.editRequested()
        }

        ActionButton {
            id: themeMenuButton
            icon: "\u{f01d9}"
            onClicked: themeMenu.openAt(themeMenuButton, root.theme)
        }
    }

    // Delete confirmation (custom themes)
    SettingsGroup {
        visible: root.confirmingDelete

        SettingRow {
            id: deleteRow

            label: "Delete " + root.displayName + "?"
            description: root.inUse ? "It's the theme in use: switch to another one first" : "Its file and its wallpaper folder are removed"
            descriptionColor: root.inUse ? Config.warningColor : Config.subtextColor

            ActionButton {
                text: "Cancel"
                baseColor: deleteRow.controlColor
                onClicked: root.confirmingDelete = false
            }

            ActionButton {
                visible: !root.inUse
                icon: "\u{f09e7}"
                text: "Delete"
                baseColor: Config.errorColor
                hoverColor: Qt.lighter(Config.errorColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: {
                    ThemeService.deleteTheme(root.theme);
                    root.confirmingDelete = false;
                    root.back();
                }
            }
        }
    }

    // ================= COLORS =================
    SettingsGroup {
        title: "Colors"

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: colors.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.cardColor

            ColumnLayout {
                id: colors

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Config.padding * 2
                spacing: Config.spacing

                ThemeMock {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(width * 9 / 16, Config.fontSizeNormal * 22)
                    theme: root.preview
                    wallpaper: root.activePath
                }

                // Interface palette
                Flow {
                    Layout.fillWidth: true
                    spacing: Config.padding

                    Repeater {
                        model: [
                            {
                                key: "background",
                                label: "Background"
                            },
                            {
                                key: "surface1",
                                label: "Surface"
                            },
                            {
                                key: "text",
                                label: "Text"
                            },
                            {
                                key: "subtext",
                                label: "Subtext"
                            },
                            {
                                key: "accent",
                                label: "Accent"
                            },
                            {
                                key: "success",
                                label: "Success"
                            },
                            {
                                key: "warning",
                                label: "Warning"
                            },
                            {
                                key: "error",
                                label: "Error"
                            }
                        ]

                        Rectangle {
                            id: chip

                            required property var modelData
                            readonly property color swatch: root.themePalette[modelData.key] ?? "transparent"

                            width: chipRow.implicitWidth + Config.padding * 2
                            height: chipRow.implicitHeight + Config.padding
                            radius: height / 2
                            color: Config.surface1Color

                            RowLayout {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: Config.padding

                                Rectangle {
                                    implicitWidth: Config.fontSizeNormal
                                    implicitHeight: implicitWidth
                                    radius: width / 2
                                    color: chip.swatch
                                    border.width: 1
                                    border.color: Qt.alpha(Config.textColor, 0.2)
                                }

                                Text {
                                    text: chip.modelData.label
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.textColor
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= WALLPAPER =================
    SettingsGroup {
        title: "Wallpaper"

        SettingRow {
            id: activeRow

            label: root.activePath !== "" ? root.displayFileName(root.activePath) : "No wallpaper"
            description: {
                if (ThemeService.isAutoMode)
                    return "Not used while the colors follow your wallpaper (Material You)";
                if (!WallpaperService.dynamicWallpaper)
                    return "Not used: switching theme keeps your wallpaper (Theme › When switching theme)";
                return "Shown when you switch to " + root.displayName;
            }

            leading: ClippingRectangle {
                implicitWidth: Math.round(root.thumbHeight * 16 / 9)
                implicitHeight: root.thumbHeight
                radius: Config.radius
                color: Config.surface1Color

                Image {
                    anchors.fill: parent
                    source: root.activePath !== "" ? "file://" + root.activePath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Config.wallpaperThumbSize
                    asynchronous: true
                }
            }

            // md-image_plus
            ActionButton {
                icon: root.pickingFromLibrary ? "\u{f0156}" : "\u{f087c}"
                text: root.pickingFromLibrary ? "Cancel" : "From library"
                baseColor: activeRow.controlColor
                onClicked: root.pickingFromLibrary = !root.pickingFromLibrary
            }
        }

        // lyne-dots scenes rendered in the theme's colors
        SettingRow {
            id: generateRow

            label: "lyne-dots wallpapers"
            description: {
                if (root.generating)
                    return "Rendering the scenes… " + WallpaperService.generatedCount + " of 3 ready";
                if (root.generateError !== "")
                    return root.generateError;
                if (WallpaperService.generatingFor !== "")
                    return "Another theme's wallpapers are rendering";
                if (root.hasLyneWallpapers)
                    return "Lake, waves and contour in " + root.displayName + "'s colors. Render them again after changing its colors";
                return "Render lake, waves and contour scenes in " + root.displayName + "'s colors";
            }
            descriptionColor: root.generateError !== "" && !root.generating ? Config.errorColor : Config.subtextColor

            leading: LyneLogo {
                height: Config.fontSizeIconSmall
                dotColor: root.themePalette.accent ?? Config.accentColor
            }

            Spinner {
                visible: root.generating
                running: visible
                size: Config.fontSizeIconSmall
            }

            ActionButton {
                visible: !root.generating
                opacity: WallpaperService.generatingFor === "" ? 1 : 0.4
                icon: "\u{f1a00}"
                text: root.hasLyneWallpapers ? "Render again" : "Generate"
                baseColor: generateRow.controlColor
                onClicked: {
                    if (WallpaperService.generatingFor === "")
                        WallpaperService.generateThemeWallpapers(root.theme);
                }
            }
        }

        // Theme folder, or the library while picking from it
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: wallpapers.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.cardColor

            ColumnLayout {
                id: wallpapers

                readonly property var shown: root.pickingFromLibrary ? root.libraryChoices : WallpaperService.themeWallpapers

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Config.padding * 2
                spacing: Config.spacing + Config.padding

                Text {
                    Layout.fillWidth: true
                    text: root.pickingFromLibrary ? "Pick a wallpaper from your library: it's copied to " + root.displayName + "'s wallpapers and used for it" : "Click one to use it for " + root.displayName
                    wrapMode: Text.WordWrap
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                GridLayout {
                    id: grid

                    readonly property real cellWidth: (width - columnSpacing * (root.columns - 1)) / root.columns

                    visible: wallpapers.shown.length > 0
                    Layout.fillWidth: true
                    columns: root.columns
                    columnSpacing: Config.spacing
                    rowSpacing: Config.spacing

                    Repeater {
                        model: wallpapers.shown

                        WallpaperTile {
                            required property string modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: grid.cellWidth
                            path: modelData
                            badge: !root.pickingFromLibrary && modelData === root.activePath ? "\u{f012c} Active" : ""
                            current: !root.pickingFromLibrary && modelData === WallpaperService.currentWallpaper
                            onActivated: root.pick(modelData)
                            onSelectToggled: root.pick(modelData)
                            showMenu: !root.pickingFromLibrary
                            onMenuRequested: anchor => menu.openAt(anchor, modelData)
                        }
                    }

                    // Keeps a lone tile at column size
                    Repeater {
                        model: Math.max(0, root.columns - wallpapers.shown.length)

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: grid.cellWidth
                        }
                    }
                }

                Text {
                    visible: wallpapers.shown.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: Config.spacing
                    Layout.bottomMargin: Config.spacing
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pickingFromLibrary ? "Every library wallpaper is already in this theme" : "No wallpapers yet: add one with From library"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }
            }
        }
    }
}
