pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    id: root

    // Animation speed presets: durations of animations.short/normal/long
    readonly property var speeds: [
        {
            label: I18n.tr("Fast"),
            value: "fast",
            durations: [60, 120, 250]
        },
        {
            label: I18n.tr("Normal"),
            value: "normal",
            durations: [100, 200, 400]
        },
        {
            label: I18n.tr("Relaxed"),
            value: "relaxed",
            durations: [150, 300, 600]
        }
    ]
    // Preset whose normal duration is closest to the current one
    readonly property string currentSpeed: {
        let best = speeds[0];
        for (const s of speeds) {
            if (Math.abs(s.durations[1] - Config.animDuration) < Math.abs(best.durations[1] - Config.animDuration))
                best = s;
        }
        return best.value;
    }

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Corners")

        SliderRow {
            label: I18n.tr("Small radius")
            description: I18n.tr("Chips, handles and other small elements")
            path: "geometry.radiusSmall"
            from: 0
            to: 12
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Radius")
            description: I18n.tr("Buttons, list items and inputs")
            path: "geometry.radius"
            from: 0
            to: 20
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Large radius")
            description: I18n.tr("Cards, popups and icon boxes")
            path: "geometry.radiusLarge"
            from: 0
            to: 28
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: I18n.tr("Spacing")

        SliderRow {
            label: I18n.tr("Spacing")
            description: I18n.tr("Gap between elements")
            path: "geometry.spacing"
            from: 2
            to: 16
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Padding")
            description: I18n.tr("Space inside cards, buttons and the bar islands")
            path: "geometry.padding"
            from: 2
            to: 12
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: I18n.tr("Transparency")

        SliderRow {
            label: I18n.tr("Background opacity")
            description: I18n.tr("Bar, panels, launcher, notifications, Settings and their cards. Themes may set their own when applied")
            path: "opacity.background"
            from: 0.5
            to: 1
            stepSize: 0.01
            format: v => Math.round(v * 100) + "%"
        }
    }

    SettingsGroup {
        title: I18n.tr("Shadows")

        ToggleRow {
            label: I18n.tr("Panel shadows")
            description: I18n.tr("A soft shadow under popups, menus, the launcher and notifications. Wider on light themes, where it shows the most")
            path: "shadow.enabled"
        }

        SliderRow {
            visible: Config.shadowEnabled
            label: I18n.tr("Shadow strength")
            description: I18n.tr("How dark the shadow is, on top of what the theme sets")
            path: "shadow.strength"
            from: 0.5
            to: 2
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
        }
    }

    SettingsGroup {
        title: I18n.tr("Motion")

        SelectRow {
            label: I18n.tr("Animation speed")
            description: I18n.tr("Duration of popups, page switches and other transitions")
            options: root.speeds
            value: root.currentSpeed
            onSelected: value => {
                const speed = root.speeds.find(s => s.value === value);
                StateService.set("animations.short", speed.durations[0]);
                StateService.set("animations.normal", speed.durations[1]);
                StateService.set("animations.long", speed.durations[2]);
            }
        }

        ToggleRow {
            label: I18n.tr("Theme color transition")
            description: I18n.tr("Fade the shell's colors and the window borders when switching theme or mode. Kitty, GTK/Qt apps and Neovim switch at once")
            path: "animations.themeTransition"
        }

        SelectRow {
            visible: Config.themeTransition
            label: I18n.tr("Transition length")
            description: I18n.tr("%1 ms now; follows the animation speed", Config.themeTransitionDuration)
            path: "animations.themeTransitionLength"
            options: [
                {
                    label: I18n.tr("Short"),
                    value: "short"
                },
                {
                    label: I18n.tr("Medium"),
                    value: "medium"
                },
                {
                    label: I18n.tr("Long"),
                    value: "long"
                }
            ]
        }
    }
}
