pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Appearance"

        SelectRow {
            label: "Style"
            description: "Icon, level bar and percentage in a capsule"
            path: "osd.style"
            options: [
                {
                    label: "Pill",
                    icon: "\u{f0402}",
                    value: "pill"
                }
            ]
        }

        SelectRow {
            label: "Position"
            description: "Screen edge the OSD sits on, clear of the bar"
            path: "osd.position"
            options: [
                {
                    label: "Top",
                    icon: "\u{f1513}",
                    value: "top"
                },
                {
                    label: "Bottom",
                    icon: "\u{f10a9}",
                    value: "bottom"
                }
            ]
        }

        SettingRow {
            label: "Preview"
            description: "Shows the OSD with the current volume"

            ActionButton {
                icon: "\u{f0f1b}"
                text: "Show"
                onClicked: OsdService.show("volume")
            }
        }
    }

    SettingsGroup {
        title: "Behaviour"

        SelectRow {
            label: "Show on"
            description: Config.osdTrigger === "any" ? "Every volume or brightness change, from apps and headset buttons too (not while Quick Settings or the dashboard is open)" : "Only the volume and brightness keys"
            path: "osd.trigger"
            segmentWidth: Config.fontSizeNormal * 7
            options: [
                {
                    label: "Shortcuts",
                    icon: "\u{f097b}",
                    value: "shortcuts"
                },
                {
                    label: "Any change",
                    icon: "\u{f0241}",
                    value: "any"
                }
            ]
        }

        SelectRow {
            label: "Monitor"
            description: "Where the OSD shows up"
            path: "osd.monitor"
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
            label: "Duration"
            description: "How long the OSD stays after the last change"
            path: "osd.timeout"
            from: 500
            to: 5000
            stepSize: 250
            format: v => v / 1000 + "s"
        }
    }
}
