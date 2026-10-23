pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    spacing: Config.spacing * 3

    HyprlandErrorGroup {}

    SettingsGroup {
        title: I18n.tr("Mouse")

        SliderRow {
            label: I18n.tr("Sensitivity")
            description: I18n.tr("0 leaves the device speed unchanged")
            path: "hyprland.input.sensitivity"
            from: -1
            to: 1
            stepSize: 0.05
            format: v => (v > 0 ? "+" : "") + v.toFixed(2)
        }

        ToggleRow {
            label: I18n.tr("Mouse acceleration")
            description: I18n.tr("Pointer speed grows with how fast the mouse moves")
            path: "hyprland.input.force_no_accel"
            inverted: true
        }
    }

    SettingsGroup {
        title: I18n.tr("Keyboard")

        SettingRow {
            resettable: false
            label: I18n.tr("Layouts, keys and repeat")
            description: I18n.tr("In their own page now")

            // md-chevron_right
            ActionButton {
                icon: "\u{f0142}"
                text: I18n.tr("Keyboard")
                onClicked: SettingsService.currentPage = "keyboard"
            }
        }
    }

    // Only on machines with a touchpad
    SettingsGroup {
        title: I18n.tr("Touchpad")
        visible: TouchpadService.available

        ToggleRow {
            label: I18n.tr("Touchpad")
            description: I18n.tr("Turn it off to use only a mouse")
            resettable: false
            checked: TouchpadService.enabled
            onToggled: value => TouchpadService.setEnabled(value)
        }

        ToggleRow {
            label: I18n.tr("Natural scrolling")
            description: I18n.tr("Content follows your fingers")
            path: "hyprland.input.touchpad.natural_scroll"
            enabled: TouchpadService.enabled
        }

        ToggleRow {
            label: I18n.tr("Tap to click")
            path: "hyprland.input.touchpad.tap_to_click"
            enabled: TouchpadService.enabled
        }

        ToggleRow {
            label: I18n.tr("Disable while typing")
            path: "hyprland.input.touchpad.disable_while_typing"
            enabled: TouchpadService.enabled
        }
    }
}
