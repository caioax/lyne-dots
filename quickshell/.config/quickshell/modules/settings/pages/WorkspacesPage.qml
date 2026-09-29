pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Workspaces per monitor (hypr/conf/workspaces.lua): every monitor Hyprland
// has seen keeps its own block of workspaces, also while disconnected. The
// order of the blocks, how next/previous move and what the laptop lid does
// are set here.
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    HyprlandErrorGroup {}

    SettingsGroup {
        title: "Monitors"

        SettingRow {
            visible: WorkspacesService.monitors.length === 0
            label: "No monitors yet"
            description: "Hyprland lists them here once conf/workspaces.lua has loaded"
        }

        // In block order: the first one holds 1–99, the next 101–199...
        Repeater {
            model: WorkspacesService.monitors

            SettingRow {
                id: monitorRow

                required property var modelData
                required property int index

                readonly property bool connected: modelData.connected !== ""
                readonly property string range: (modelData.base + 1) + "–" + (modelData.base + WorkspacesService.max)
                readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

                label: WorkspacesService.labelOf(modelData)
                description: connected ? modelData.connected + " · workspaces " + range : "Disconnected (last on " + modelData.name + ") · workspaces " + range

                // md-laptop / md-monitor / md-monitor_off
                leading: Text {
                    text: !monitorRow.connected ? "\u{f0d90}" : WorkspacesService.isInternal(monitorRow.modelData) ? "\u{f0322}" : "\u{f0379}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: monitorRow.connected ? Config.textColor : Config.subtextColor
                }

                // md-arrow_up / md-arrow_down: swap blocks with the neighbour,
                // renumbering the open workspaces
                ActionButton {
                    icon: "\u{f005d}"
                    size: monitorRow.buttonSize
                    baseColor: monitorRow.controlColor
                    opacity: monitorRow.index > 0 ? 1 : 0.3
                    onClicked: WorkspacesService.move(monitorRow.index, -1)
                }

                ActionButton {
                    icon: "\u{f0045}"
                    size: monitorRow.buttonSize
                    baseColor: monitorRow.controlColor
                    opacity: monitorRow.index < WorkspacesService.monitors.length - 1 ? 1 : 0.3
                    onClicked: WorkspacesService.move(monitorRow.index, 1)
                }

                // md-close
                ActionButton {
                    visible: !monitorRow.connected
                    icon: "\u{f0156}"
                    text: "Forget"
                    size: monitorRow.buttonSize
                    baseColor: monitorRow.controlColor
                    onClicked: WorkspacesService.forget(monitorRow.modelData.slot)
                }
            }
        }

        SettingRow {
            visible: WorkspacesService.error !== ""
            label: "Hyprland rejected the change"
            description: WorkspacesService.error

            // md-alert
            leading: Text {
                text: "\u{f0026}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.errorColor
            }
        }
    }

    SettingsGroup {
        title: "Next & previous"

        ToggleRow {
            label: "Skip empty workspaces"
            description: "Only stop at workspaces with windows, with the keys and the mouse wheel over the bar"
            path: "workspaces.skipEmpty"
        }

        ToggleRow {
            label: "Go around"
            description: StateService.get("workspaces.skipEmpty", false) ? "From the last busy workspace back to the first, and the other way" : "After the last busy workspace and one empty one, back to the first, and the other way"
            path: "workspaces.wrap"
        }
    }

    // Only with a laptop screen among the known monitors
    SettingsGroup {
        title: "Laptop lid"
        visible: WorkspacesService.monitors.some(m => WorkspacesService.isInternal(m))

        ToggleRow {
            label: "Turn the screen off when closed"
            description: "While another monitor is connected: the laptop's workspaces move there and come back when you open the lid"
            path: "workspaces.lidOff"
        }
    }
}
