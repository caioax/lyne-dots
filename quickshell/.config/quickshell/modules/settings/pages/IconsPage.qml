pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The icon theme (IconService; also `lyne icons`)
ColumnLayout {
    spacing: Config.spacing * 3

    // Themes may have been installed or removed since
    Component.onCompleted: IconService.refresh()

    SettingsGroup {
        title: I18n.tr("Icons")

        SettingRow {
            id: themeRow

            label: I18n.tr("Theme")
            description: IconService.missing ? I18n.tr("%1 isn't installed: apps fall back to another icon theme", IconService.theme) : I18n.tr("Themes with dark and light versions follow the shell's theme. Apps change at once; X11 apps when you reopen them")
            descriptionColor: IconService.missing ? Config.warningColor : Config.subtextColor
            path: "icons.theme"

            // md-shape_outline
            ActionButton {
                id: themeButton

                icon: "\u{f0832}"
                text: IconService.nameOf(IconService.theme)
                baseColor: themeRow.controlColor
                onClicked: themeMenu.openAt(themeButton, null)
            }

            ContextMenu {
                id: themeMenu

                width: Config.fontSizeNormal * 22

                items: IconService.themes.map(t => ({
                            label: t.name,
                            detail: t.dark !== "" || t.light !== "" ? I18n.tr("dark and light") : "",
                            action: t.id,
                            checked: t.id === IconService.theme
                        }))
                onTriggered: action => IconService.setTheme(action)
            }
        }
    }
}
