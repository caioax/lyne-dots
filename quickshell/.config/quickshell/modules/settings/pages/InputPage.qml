pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../rows/"

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

        SliderRow {
            label: "Repeat delay"
            description: "How long a key is held before it repeats"
            path: "hyprland.input.repeat_delay"
            from: 150
            to: 800
            stepSize: 25
            format: v => v + " ms"
        }

        SliderRow {
            label: "Repeat rate"
            description: "Repeats per second while a key is held"
            path: "hyprland.input.repeat_rate"
            from: 10
            to: 80
            format: v => v + "/s"
        }

        InfoRow {
            label: "Layouts"
            description: "Set per keyboard in hypr/local/extra_input.lua"
            value: "Per device"
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
