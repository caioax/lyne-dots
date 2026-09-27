pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    readonly property bool auto: ThemeService.isAutoMode
    readonly property int columns: 3

    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Colors"

        SelectRow {
            label: "Source"
            description: "A preset palette, or colors picked from your wallpaper"
            segmentWidth: Config.fontSizeNormal * 9
            options: [
                {
                    label: "Preset",
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

        // Owned by WallpaperService, which keeps its own copy
        ToggleRow {
            visible: !root.auto
            label: "Theme wallpaper"
            description: "Switching preset also switches to its wallpaper"
            checked: WallpaperService.dynamicWallpaper
            onToggled: WallpaperService.toggleDynamicWallpaper()
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
        title: "Transparency"

        SliderRow {
            label: "Background opacity"
            description: "Bar, panels, launcher, notifications, Settings and their cards. Presets may set their own when applied"
            path: "opacity.background"
            from: 0.5
            to: 1
            stepSize: 0.01
            format: v => Math.round(v * 100) + "%"
        }
    }

    SettingsGroup {
        title: "Presets"

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
                        Layout.preferredWidth: (grid.width - grid.columnSpacing * (root.columns - 1)) / root.columns
                        thumbHeight: Config.fontSizeIconLarge * 3
                    }
                }
            }
        }
    }
}
