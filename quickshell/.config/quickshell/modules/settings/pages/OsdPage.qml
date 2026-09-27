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
            description: ({
                    pill: "Icon, level bar and percentage in a capsule",
                    vertical: "A slim capsule on a screen side, filling upwards",
                    card: "A square card with a ring around the icon",
                    attached: "Slides out of the bar like the attached panels (from the screen edge with islands or a floating bar)"
                })[OsdService.style]
            path: "osd.style"
            segmentWidth: Config.fontSizeNormal * 7
            options: [
                {
                    label: "Pill",
                    icon: "\u{f0402}",
                    value: "pill"
                },
                {
                    label: "Vertical",
                    icon: "\u{f084f}",
                    value: "vertical"
                },
                {
                    label: "Card",
                    icon: "\u{f07af}",
                    value: "card"
                },
                {
                    label: "Attached",
                    icon: "\u{f10ac}",
                    value: "attached"
                }
            ]
        }

        // Options depend on the style (OsdService.positions)
        SelectRow {
            readonly property string barIcon: Config.barOnBottom ? "\u{f10a9}" : "\u{f1513}"
            readonly property string oppositeIcon: Config.barOnBottom ? "\u{f1513}" : "\u{f10a9}"
            readonly property var choices: ({
                    top: {
                        label: "Top",
                        icon: "\u{f1513}"
                    },
                    bottom: {
                        label: "Bottom",
                        icon: "\u{f10a9}"
                    },
                    left: {
                        label: "Left",
                        icon: "\u{f10aa}"
                    },
                    right: {
                        label: "Right",
                        icon: "\u{f10ab}"
                    },
                    center: {
                        label: "Center",
                        icon: "\u{f11c6}"
                    },
                    bar: {
                        label: "Bar",
                        icon: barIcon
                    },
                    opposite: {
                        label: "Opposite",
                        icon: oppositeIcon
                    }
                })

            label: "Position"
            description: OsdService.style === "attached" ? "Under the bar, or on the other screen edge" : "Where it sits, clear of the bar"
            path: "osd.position"
            value: OsdService.position
            segmentWidth: Config.fontSizeNormal * 7
            options: OsdService.positions[OsdService.style].map(p => Object.assign({
                        value: p
                    }, choices[p]))
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
