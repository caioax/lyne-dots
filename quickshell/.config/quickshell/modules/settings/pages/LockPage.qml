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
        title: I18n.tr("Style")

        TemplatePicker {
            label: I18n.tr("Template")
            description: I18n.tr("Other monitors show only the clock over the blurred wallpaper")
            path: "lock.style"
            options: [
                {
                    label: I18n.tr("Center"),
                    value: "center"
                },
                {
                    label: I18n.tr("Cards"),
                    value: "cards"
                },
                {
                    label: I18n.tr("Wallpaper"),
                    value: "wallpaper"
                }
            ]
            preview: Component {
                LockStylePreview {}
            }
        }

        ToggleRow {
            label: I18n.tr("Status")
            description: I18n.tr("Battery, weather and the number of new notifications (never their content)")
            path: "lock.showStatus"
        }

        ToggleRow {
            label: I18n.tr("Media player")
            description: I18n.tr("Cover with the cava ring, track and controls once something plays")
            path: "lock.showMedia"
        }

        ToggleRow {
            label: I18n.tr("Power buttons")
            description: I18n.tr("Suspend, reboot and shut down, with the power menu's countdown")
            path: "lock.showPower"
        }
    }

    SettingsGroup {
        title: I18n.tr("Behavior")

        ToggleRow {
            label: I18n.tr("Lock before sleep")
            description: I18n.tr("Lock when the computer suspends or hibernates, lid close included")
            path: "lock.beforeSleep"
        }

        SettingRow {
            label: I18n.tr("Lock now")
            description: I18n.tr("Also Super + Escape, or qs ipc call lock lock")

            ActionButton {
                icon: "\u{f033e}"
                text: I18n.tr("Lock")
                onClicked: {
                    SettingsService.close();
                    LockService.lock();
                }
            }
        }
    }
}
