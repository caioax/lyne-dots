pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    id: root

    readonly property bool blurEnabled: StateService.get("hyprland.decoration.blur.enabled", true)
    readonly property bool scrolling: StateService.get("hyprland.general.layout", "dwindle") === "scrolling"

    spacing: Config.spacing * 3

    HyprlandErrorGroup {}

    SettingsGroup {
        title: "Gaps & borders"

        SliderRow {
            label: "Inner gaps"
            description: "Space between windows"
            path: "hyprland.general.gaps_in"
            from: 0
            to: 20
            format: v => v + "px"
        }

        SliderRow {
            label: "Outer gaps"
            description: "Space between windows and the screen edges"
            path: "hyprland.general.gaps_out"
            from: 0
            to: 40
            format: v => v + "px"
        }

        SliderRow {
            label: "Border size"
            description: "Colors come from the current theme"
            path: "hyprland.general.border_size"
            from: 0
            to: 6
            format: v => v + "px"
        }

        SliderRow {
            label: "Corner radius"
            description: "Window corners; the shell has its own in Appearance › Layout"
            path: "hyprland.decoration.rounding"
            from: 0
            to: 20
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: "Tiling"

        SelectRow {
            label: "Layout"
            description: "Dwindle splits the focused window; Master keeps one main window and stacks the rest; Scrolling lays windows out in columns on a strip you scroll through"
            path: "hyprland.general.layout"
            options: [
                {
                    label: "Dwindle",
                    value: "dwindle"
                },
                {
                    label: "Master",
                    value: "master"
                },
                {
                    label: "Scrolling",
                    value: "scrolling"
                }
            ]
        }

        SliderRow {
            enabled: root.scrolling
            label: "Column width"
            description: "Width of new columns in the Scrolling layout; Super + Tab cycles the focused one"
            path: "hyprland.scrolling.column_width"
            from: 0.3
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
        }

        SelectRow {
            enabled: root.scrolling
            label: "Focused column"
            description: "Fit just scrolls it into view; Center puts it in the middle of the screen"
            path: "hyprland.scrolling.focus_fit_method"
            options: [
                {
                    label: "Fit",
                    value: 1
                },
                {
                    label: "Center",
                    value: 0
                }
            ]
        }

        ToggleRow {
            enabled: root.scrolling
            label: "Lone column fills the screen"
            description: "A single column takes the whole width of the workspace"
            path: "hyprland.scrolling.fullscreen_on_one_column"
        }

        SelectRow {
            enabled: root.scrolling
            label: "Direction"
            description: "Where new columns appear and the strip scrolls"
            path: "hyprland.scrolling.direction"
            options: [
                {
                    label: "Right",
                    value: "right"
                },
                {
                    label: "Left",
                    value: "left"
                },
                {
                    label: "Down",
                    value: "down"
                },
                {
                    label: "Up",
                    value: "up"
                }
            ]
        }
    }

    SettingsGroup {
        title: "Effects"

        ToggleRow {
            label: "Blur"
            description: "Blur what's behind transparent windows and the shell"
            path: "hyprland.decoration.blur.enabled"
        }

        SliderRow {
            enabled: root.blurEnabled
            label: "Blur size"
            path: "hyprland.decoration.blur.size"
            from: 1
            to: 16
        }

        StepperRow {
            enabled: root.blurEnabled
            label: "Blur passes"
            description: "More passes look smoother but cost more GPU"
            path: "hyprland.decoration.blur.passes"
            from: 1
            to: 4
        }

        ToggleRow {
            label: "Shadows"
            path: "hyprland.decoration.shadow.enabled"
        }

        SliderRow {
            label: "Inactive window opacity"
            description: "Fade windows that don't have focus"
            path: "hyprland.decoration.inactive_opacity"
            from: 0.5
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
        }

        ToggleRow {
            label: "Animations"
            description: "Window, workspace and layer animations"
            path: "hyprland.animations.enabled"
        }
    }
}
