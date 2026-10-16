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
        title: I18n.tr("Style")

        TemplatePicker {
            label: I18n.tr("Template")
            description: ({
                    pill: I18n.tr("Icon, level bar and percentage in a capsule"),
                    vertical: I18n.tr("A slim capsule on a screen side, filling upwards"),
                    card: I18n.tr("A square card with a ring around the icon"),
                    attached: I18n.tr("Slides out of the bar like the attached panels (from the screen edge with islands or a floating bar)")
                })[OsdService.style]
            path: "osd.style"
            thumbHeight: Config.fontSizeIconLarge * 5
            options: [
                {
                    label: I18n.tr("Pill"),
                    value: "pill"
                },
                {
                    label: I18n.tr("Vertical"),
                    value: "vertical"
                },
                {
                    label: I18n.tr("Card"),
                    value: "card"
                },
                {
                    label: I18n.tr("Attached"),
                    value: "attached"
                }
            ]
            preview: Component {
                OsdStylePreview {}
            }
        }

        // Options depend on the style (OsdService.positions)
        SelectRow {
            readonly property string barIcon: Config.barOnBottom ? "\u{f10a9}" : "\u{f1513}"
            readonly property string oppositeIcon: Config.barOnBottom ? "\u{f1513}" : "\u{f10a9}"
            readonly property var choices: ({
                    top: {
                        label: I18n.tr("Top"),
                        icon: "\u{f1513}"
                    },
                    bottom: {
                        label: I18n.tr("Bottom"),
                        icon: "\u{f10a9}"
                    },
                    left: {
                        label: I18n.tr("Left"),
                        icon: "\u{f10aa}"
                    },
                    right: {
                        label: I18n.tr("Right"),
                        icon: "\u{f10ab}"
                    },
                    center: {
                        label: I18n.tr("Center"),
                        icon: "\u{f11c6}"
                    },
                    bar: {
                        label: I18n.tr("Bar"),
                        icon: barIcon
                    },
                    opposite: {
                        label: I18n.tr("Opposite"),
                        icon: oppositeIcon
                    }
                })

            label: I18n.tr("Position")
            description: OsdService.style === "attached" ? I18n.tr("Under the bar, or on the other screen edge") : I18n.tr("Where it sits, clear of the bar")
            path: "osd.position"
            value: OsdService.position
            segmentWidth: Config.fontSizeNormal * 7
            options: OsdService.positions[OsdService.style].map(p => Object.assign({
                        value: p
                    }, choices[p]))
        }

        SettingRow {
            label: I18n.tr("Preview")
            description: I18n.tr("Shows the OSD with the current volume")

            ActionButton {
                icon: "\u{f0f1b}"
                text: I18n.tr("Show")
                onClicked: OsdService.show("volume")
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Behavior")

        SelectRow {
            label: I18n.tr("Show on")
            description: Config.osdTrigger === "any" ? I18n.tr("Every volume or brightness change, from apps and headset buttons too (not while Quick Settings or the dashboard is open)") : I18n.tr("Only the volume and brightness keys")
            path: "osd.trigger"
            segmentWidth: Config.fontSizeNormal * 7
            options: [
                {
                    label: I18n.tr("Shortcuts"),
                    icon: "\u{f097b}",
                    value: "shortcuts"
                },
                {
                    label: I18n.tr("Any change"),
                    icon: "\u{f0241}",
                    value: "any"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Microphone")
            description: I18n.tr("The mic mute key (XF86AudioMicMute) shows the mic level and state")
            path: "osd.mic"
        }

        ToggleRow {
            label: I18n.tr("Output device")
            description: I18n.tr("Switching the default output shows its name and volume, whatever \"Show on\" says")
            path: "osd.device"
        }

        ToggleRow {
            label: I18n.tr("Keyboard layout")
            description: I18n.tr("Switching layouts shows the new one, whatever \"Show on\" says")
            path: "osd.layout"
        }

        ToggleRow {
            label: I18n.tr("Window layout")
            description: I18n.tr("Cycling the tiling layout (Super + Ctrl + Tab) shows the new one")
            path: "osd.tiling"
        }

        SelectRow {
            label: I18n.tr("Monitor")
            description: I18n.tr("Where the OSD shows up")
            path: "osd.monitor"
            options: [
                {
                    label: I18n.tr("Focused"),
                    icon: "\u{f0379}",
                    value: "focused"
                },
                {
                    label: I18n.tr("All"),
                    icon: "\u{f037a}",
                    value: "all"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Interactive")
            description: I18n.tr("Hovering keeps it open, scrolling changes the level and a click mutes")
            path: "osd.interactive"
        }

        StepperRow {
            label: I18n.tr("Duration")
            description: I18n.tr("How long the OSD stays after the last change")
            path: "osd.timeout"
            from: 500
            to: 5000
            stepSize: 250
            format: v => v / 1000 + "s"
        }
    }

    SettingsGroup {
        title: I18n.tr("Volume")

        SliderRow {
            label: I18n.tr("Maximum volume")
            description: I18n.tr("Above 100% the shell amplifies in software, which can distort; the OSD shows the boost in the warning color")
            path: "audio.maxVolume"
            from: 100
            to: 150
            stepSize: 5
            format: v => v + "%"
        }
    }
}
