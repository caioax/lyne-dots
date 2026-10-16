pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Style")

        TemplatePicker {
            label: I18n.tr("Template")
            description: I18n.tr("Card in the middle, a strip on a screen edge, or a full-screen goodbye")
            path: "power.style"
            options: [
                {
                    label: I18n.tr("Card"),
                    value: "card"
                },
                {
                    label: I18n.tr("Side strip"),
                    value: "strip"
                },
                {
                    label: I18n.tr("Farewell"),
                    value: "farewell"
                }
            ]
            preview: Component {
                PowerStylePreview {}
            }
        }

        SelectRow {
            label: I18n.tr("Side")
            description: I18n.tr("Screen edge the strip grows out of")
            path: "power.side"
            enabled: PowerService.style === "strip"
            options: [
                {
                    label: I18n.tr("Left"),
                    value: "left"
                },
                {
                    label: I18n.tr("Right"),
                    value: "right"
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.tr("Confirmation")

        SelectRow {
            label: I18n.tr("Countdown")
            description: I18n.tr("Log out, reboot and shut down wait this long in the menu; Enter runs them at once, Esc cancels")
            path: "power.countdown"
            segmentWidth: Config.fontSizeNormal * 4
            options: [
                {
                    label: I18n.tr("Off"),
                    value: 0
                },
                {
                    label: "3s",
                    value: 3
                },
                {
                    label: "5s",
                    value: 5
                },
                {
                    label: "10s",
                    value: 10
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.tr("Actions")

        ToggleRow {
            label: I18n.tr("Reversed order")
            description: I18n.tr("Shut down comes first and is selected when the menu opens, instead of lock")
            path: "power.reversed"
        }

        Repeater {
            model: PowerService.allActions

            ToggleRow {
                id: actionRow

                required property var modelData
                readonly property bool available: PowerService.isAvailable(modelData.id)
                readonly property bool shown: available && !PowerService.hiddenActions.includes(modelData.id)

                label: modelData.name
                description: available ? modelData.comment : I18n.tr("Not supported on this system")
                checked: shown
                // The last shown action can't be hidden
                enabled: available && (!shown || PowerService.actions.length > 1)
                onToggled: value => PowerService.setShown(modelData.id, value)
            }
        }
    }
}
