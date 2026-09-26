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
            description: "Other monitors show only the clock over the blurred wallpaper"
            path: "lock.style"
            options: [
                {
                    label: "Center",
                    value: "center"
                },
                {
                    label: "Cards",
                    value: "cards"
                },
                {
                    label: "Wallpaper",
                    value: "wallpaper"
                }
            ]
            preview: Component {
                LockStylePreview {}
            }
        }

        ToggleRow {
            label: "Status"
            description: "Battery, weather and the number of new notifications (never their content)"
            path: "lock.showStatus"
        }

        ToggleRow {
            label: "Media player"
            description: "Cover with the cava ring, track and controls once something plays"
            path: "lock.showMedia"
        }

        ToggleRow {
            label: "Power buttons"
            description: "Suspend, reboot and shut down, with the power menu's countdown"
            path: "lock.showPower"
        }
    }

    SettingsGroup {
        title: "Behavior"

        ToggleRow {
            label: "Lock before sleep"
            description: "Lock when the computer suspends or hibernates, lid close included"
            path: "lock.beforeSleep"
        }

        SettingRow {
            label: "Lock now"
            description: "Also Super + Escape, or qs ipc call lock lock"

            ActionButton {
                icon: "\u{f033e}"
                text: "Lock"
                onClicked: {
                    SettingsService.close();
                    LockService.lock();
                }
            }
        }
    }
}
