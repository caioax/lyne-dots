pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Layout"

        TemplatePicker {
            label: "Template"
            description: "Card in the middle, a strip on a screen edge, or a full-screen goodbye"
            path: "power.style"
            options: [
                {
                    label: "Card",
                    value: "card"
                },
                {
                    label: "Side strip",
                    value: "strip"
                },
                {
                    label: "Farewell",
                    value: "farewell"
                }
            ]
            preview: Component {
                PowerStylePreview {}
            }
        }

        SelectRow {
            label: "Side"
            description: "Screen edge the strip grows out of"
            path: "power.side"
            enabled: PowerService.style === "strip"
            options: [
                {
                    label: "Left",
                    value: "left"
                },
                {
                    label: "Right",
                    value: "right"
                }
            ]
        }
    }

    SettingsGroup {
        title: "Confirmation"

        SelectRow {
            label: "Countdown"
            description: "Log out, reboot and shut down wait this long in the menu; Enter runs them at once, Esc cancels"
            path: "power.countdown"
            segmentWidth: Config.fontSizeNormal * 4
            options: [
                {
                    label: "Off",
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
        title: "Actions"

        Repeater {
            model: PowerService.allActions

            ToggleRow {
                id: actionRow

                required property var modelData
                readonly property bool available: PowerService.isAvailable(modelData.id)
                readonly property bool shown: available && !PowerService.hiddenActions.includes(modelData.id)

                label: modelData.name
                description: available ? modelData.comment : "Not supported on this system"
                checked: shown
                // The last shown action can't be hidden
                enabled: available && (!shown || PowerService.actions.length > 1)
                onToggled: value => PowerService.setShown(modelData.id, value)
            }
        }
    }
}
