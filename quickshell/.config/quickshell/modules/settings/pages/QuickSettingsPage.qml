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
        title: "Sliders"

        SelectRow {
            label: "Brightness"
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
        title: "Opening"

        SettingRow {
            resettable: false
            label: "Bar button"
            description: "Its style and indicators are in the Bar page. Right click toggles do not disturb"

            // md-chevron_right
            ActionButton {
                icon: "\u{f0142}"
                text: "Bar"
                onClicked: SettingsService.reveal({
                    kind: "group",
                    page: "bar",
                    group: "",
                    label: "Quick Settings"
                })
            }
        }

        InfoRow {
            label: "Command"
            description: "Opens or closes it on the focused monitor, optionally on a page: wifi, bluetooth, nightLight, sound or notifications"
            value: "qs ipc call quicksettings toggle"
        }
    }
}
