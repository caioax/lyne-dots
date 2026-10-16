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
        title: I18n.tr("Gaps & borders")

        SliderRow {
            label: I18n.tr("Inner gaps")
            description: I18n.tr("Space between windows")
            path: "hyprland.general.gaps_in"
            from: 0
            to: 20
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Outer gaps")
            description: I18n.tr("Space between windows and the screen edges")
            path: "hyprland.general.gaps_out"
            from: 0
            to: 40
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Border size")
            description: I18n.tr("Colors come from the current theme")
            path: "hyprland.general.border_size"
            from: 0
            to: 6
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Corner radius")
            description: I18n.tr("Window corners; the shell has its own in Appearance › Layout")
            path: "hyprland.decoration.rounding"
            from: 0
            to: 20
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: I18n.tr("Tiling")

        // Label repeated here for the Settings search (it reads the page source)
        TilingPicker {
            label: I18n.tr("Layout")
            showCycleKeys: true
        }

        SliderRow {
            enabled: root.scrolling
            label: I18n.tr("Column width")
            description: I18n.tr("Width of new columns in the Scrolling layout; Super + Tab cycles the focused one")
            path: "hyprland.scrolling.column_width"
            from: 0.3
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
        }

        SelectRow {
            enabled: root.scrolling
            label: I18n.tr("Focused column")
            description: I18n.tr("Fit just scrolls it into view; Center puts it in the middle of the screen")
            path: "hyprland.scrolling.focus_fit_method"
            options: [
                {
                    label: I18n.tr("Fit"),
                    value: 1
                },
                {
                    label: I18n.tr("Center"),
                    value: 0
                }
            ]
        }

        ToggleRow {
            enabled: root.scrolling
            label: I18n.tr("Lone column fills the screen")
            description: I18n.tr("A single column takes the whole width of the workspace")
            path: "hyprland.scrolling.fullscreen_on_one_column"
        }

        SelectRow {
            enabled: root.scrolling
            label: I18n.tr("Direction")
            description: I18n.tr("Where new columns appear and the strip scrolls")
            path: "hyprland.scrolling.direction"
            options: [
                {
                    label: I18n.tr("Right"),
                    value: "right"
                },
                {
                    label: I18n.tr("Left"),
                    value: "left"
                },
                {
                    label: I18n.tr("Down"),
                    value: "down"
                },
                {
                    label: I18n.tr("Up"),
                    value: "up"
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.tr("Effects")

        ToggleRow {
            label: I18n.tr("Blur")
            description: I18n.tr("Blur what's behind transparent windows and the shell")
            path: "hyprland.decoration.blur.enabled"
        }

        SliderRow {
            enabled: root.blurEnabled
            label: I18n.tr("Blur size")
            path: "hyprland.decoration.blur.size"
            from: 1
            to: 16
        }

        StepperRow {
            enabled: root.blurEnabled
            label: I18n.tr("Blur passes")
            description: I18n.tr("More passes look smoother but cost more GPU")
            path: "hyprland.decoration.blur.passes"
            from: 1
            to: 4
        }

        ToggleRow {
            label: I18n.tr("Shadows")
            path: "hyprland.decoration.shadow.enabled"
        }

        SliderRow {
            label: I18n.tr("Inactive window opacity")
            description: I18n.tr("Fade windows that don't have focus")
            path: "hyprland.decoration.inactive_opacity"
            from: 0.5
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
        }

        ToggleRow {
            label: I18n.tr("Animations")
            description: I18n.tr("Window, workspace and layer animations")
            path: "hyprland.animations.enabled"
        }
    }
}
