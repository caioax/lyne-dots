pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Keys"

        SelectRow {
            label: "Adjust"
            description: Config.brightnessTarget === "all" ? "Every monitor with brightness control, each keeping its own level" : "The focused monitor, or the laptop screen when the focused one has no control"
            path: "brightness.target"
            segmentWidth: Config.fontSizeNormal * 7
            options: [
                {
                    label: "Focused",
                    icon: "\u{f0379}",
                    value: "focused"
                },
                {
                    label: "All",
                    icon: "\u{f037a}",
                    value: "all"
                }
            ]
        }

        StepperRow {
            label: "Step"
            description: "How much each key press or scroll on the OSD changes"
            path: "brightness.step"
            values: [1, 2, 5, 10, 20]
            format: v => v + "%"
        }
    }

    SettingsGroup {
        title: "External monitors"

        ToggleRow {
            label: "DDC/CI"
            description: BrightnessService.ddcMissing ? "ddcutil isn't installed: run lyne update, or install it and load the i2c-dev module" : "Controls the brightness of external monitors through their cable (needs ddcutil and the i2c-dev module)"
            descriptionColor: BrightnessService.ddcMissing && Config.brightnessDdc ? Config.warningColor : Config.subtextColor
            path: "brightness.ddc"
        }

        StepperRow {
            label: "Refresh"
            description: "Re-reads their brightness to catch changes made on the monitor's own buttons. It's also read when Quick Settings opens"
            enabled: Config.brightnessDdc
            path: "brightness.pollInterval"
            values: [0, 30, 60, 120, 300]
            format: v => v === 0 ? "Never" : v < 60 ? v + "s" : v / 60 + " min"
        }
    }
}
