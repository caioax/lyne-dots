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
        title: "Mouse"

        SliderRow {
            label: "Sensitivity"
            description: "0 leaves the device speed unchanged"
            path: "hyprland.input.sensitivity"
            from: -1
            to: 1
            stepSize: 0.05
            format: v => (v > 0 ? "+" : "") + v.toFixed(2)
        }

        ToggleRow {
            label: "Mouse acceleration"
            description: "Pointer speed grows with how fast the mouse moves"
            path: "hyprland.input.force_no_accel"
            inverted: true
        }
    }

    SettingsGroup {
        title: "Keyboard"

        SettingRow {
            resettable: false
            label: "Layouts, keys and repeat"
            description: "In their own page now"

            // md-chevron_right
            ActionButton {
                icon: "\u{f0142}"
                text: "Keyboard"
                onClicked: SettingsService.currentPage = "keyboard"
            }
        }
    }

    SettingsGroup {
        title: "Touchpad"

        ToggleRow {
            label: "Natural scrolling"
            description: "Content follows your fingers"
            path: "hyprland.input.touchpad.natural_scroll"
        }

        ToggleRow {
            label: "Tap to click"
            path: "hyprland.input.touchpad.tap_to_click"
        }

        ToggleRow {
            label: "Disable while typing"
            path: "hyprland.input.touchpad.disable_while_typing"
        }
    }
}
