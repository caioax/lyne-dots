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
            label: "Fast",
            value: "fast",
            durations: [60, 120, 250]
        },
        {
            label: "Normal",
            value: "normal",
            durations: [100, 200, 400]
        },
        {
            label: "Relaxed",
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
        title: "Corners"

        SliderRow {
            label: "Small radius"
            description: "Chips, handles and other small elements"
            path: "geometry.radiusSmall"
            from: 0
            to: 12
            format: v => v + "px"
        }

        SliderRow {
            label: "Radius"
            description: "Buttons, list items and inputs"
            path: "geometry.radius"
            from: 0
            to: 20
            format: v => v + "px"
        }

        SliderRow {
            label: "Large radius"
            description: "Cards, popups and icon boxes"
            path: "geometry.radiusLarge"
            from: 0
            to: 28
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: "Spacing"

        SliderRow {
            label: "Spacing"
            description: "Gap between elements"
            path: "geometry.spacing"
            from: 2
            to: 16
            format: v => v + "px"
        }

        SliderRow {
            label: "Padding"
            description: "Space inside cards, buttons and the bar islands"
            path: "geometry.padding"
            from: 2
            to: 12
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: "Motion"

        SelectRow {
            label: "Animation speed"
            description: "Duration of popups, page switches and other transitions"
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
            label: "Screenshot animations"
            description: "Animate the screenshot tool (region selection is never animated)"
            path: "animations.screenshot"
        }
    }
}
