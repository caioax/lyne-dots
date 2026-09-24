pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../rows/"

// Shown on the Hyprland pages when `hyprctl eval` rejected the settings
SettingsGroup {
    visible: HyprlandSettingsService.error !== ""

    SettingRow {
        label: "Hyprland rejected a setting"
        description: HyprlandSettingsService.error

        // md-alert
        leading: Text {
            text: "\u{f0026}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIcon
            color: Config.errorColor
        }
    }
}
