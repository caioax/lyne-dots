pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"
import "../../components/"

// Appearance step: dark or light, and a theme (with its wallpaper, when
// themes bring theirs). Material You and making a theme stay in Settings ›
// Theme
ColumnLayout {
    id: root

    readonly property int columns: width > Config.fontSizeNormal * 44 ? 3 : 2

    spacing: Config.spacing * 3

    // md-palette
    WelcomeHeader {
        icon: "\u{f03d8}"
        title: "Look"
        description: "Colors for the shell, GTK and Qt apps, Kitty and Neovim. Settings › Theme also takes colors from your wallpaper and makes new themes."
    }

    SettingsGroup {
        title: "Colors"

        SelectRow {
            label: "Mode"
            description: ThemeService.schemeHint || "The themes below follow it"
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
    }

    SettingsGroup {
        title: "Theme"

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
                    }
                }
            }
        }
    }
}
