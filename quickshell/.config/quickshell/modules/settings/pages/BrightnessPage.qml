pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    spacing: Config.spacing * 3

    // Every screen, with how its brightness is controlled (or why it isn't)
    SettingsGroup {
        title: "Monitors"

        Repeater {
            model: BrightnessService.monitors

            SettingRow {
                id: monitorRow

                required property var modelData

                label: modelData.label
                description: modelData.name + " · " + modelData.status
                belowVisible: modelData.available

                // md-laptop / md-monitor / md-monitor_off
                leading: Text {
                    text: !monitorRow.modelData.available ? "\u{f0d90}" : monitorRow.modelData.internal ? "\u{f0322}" : "\u{f0379}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: monitorRow.modelData.available ? Config.textColor : Config.subtextColor
                }

                Text {
                    visible: monitorRow.modelData.available
                    text: Math.round(monitorRow.modelData.brightness * 100) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.subtextColor
                }

                below: QsSlider {
                    width: parent.width
                    icon: ""
                    showPercentage: false
                    value: monitorRow.modelData.brightness
                    stepSize: Config.brightnessStep
                    onMoved: v => monitorRow.modelData.set(v)
                }
            }
        }
    }

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
        title: "Quick Settings"

        SelectRow {
            label: "Sliders"
            description: Config.brightnessQuickSettings === "all" ? "One slider per monitor, each with its name" : "One slider for the focused monitor, with a button that switches to the others"
            path: "brightness.quickSettings"
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

        SettingRow {
            label: "Detect monitors"
            description: "Looks for DDC/CI monitors again, e.g. after turning on DDC/CI in the monitor's menu. Plugging one in does this by itself"
            enabled: Config.brightnessDdc

            // md-refresh
            ActionButton {
                icon: "\u{f0450}"
                text: BrightnessService.detecting ? "Detecting…" : "Detect"
                opacity: BrightnessService.detecting ? 0.6 : 1
                onClicked: BrightnessService.detect()
            }
        }
    }
}
