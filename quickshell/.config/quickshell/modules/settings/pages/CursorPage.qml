pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The mouse cursor theme and size (CursorService; also `lyne cursor`)
ColumnLayout {
    spacing: Config.spacing * 3

    // Themes may have been installed or removed since
    Component.onCompleted: CursorService.refresh()

    SettingsGroup {
        title: I18n.tr("Cursor")

        SettingRow {
            id: themeRow

            label: I18n.tr("Theme")
            description: CursorService.missing ? I18n.tr("%1 isn't installed: apps fall back to another cursor", CursorService.theme) : I18n.tr("Hyprland and most apps change at once; X11 apps when you reopen them")
            descriptionColor: CursorService.missing ? Config.warningColor : Config.subtextColor
            path: "cursor.theme"

            // md-cursor_default_outline
            ActionButton {
                id: themeButton

                icon: "\u{f01bf}"
                text: CursorService.nameOf(CursorService.theme)
                baseColor: themeRow.controlColor
                onClicked: themeMenu.openAt(themeButton, null)
            }

            ContextMenu {
                id: themeMenu

                // Room for names like Bibata-Original-Classic-Right
                width: Config.fontSizeNormal * 22

                items: CursorService.themes.map(t => ({
                            label: t.name,
                            detail: t.hyprcursor ? I18n.tr("hyprcursor too") : "",
                            action: t.id,
                            checked: t.id === CursorService.theme
                        }))
                onTriggered: action => CursorService.setTheme(action)
            }
        }

        SelectRow {
            label: I18n.tr("Size")
            description: I18n.tr("Cursor themes are drawn at these sizes, so they stay sharp")
            path: "cursor.size"
            segmentWidth: Config.fontSizeNormal * 4
            options: CursorService.sizes.map(s => ({
                        label: String(s),
                        value: s
                    }))
        }
    }
}
