pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"
import "../settings/pages/"

// Bar step: its template and screen edge (Settings › Bar has the rest:
// height, launcher button, widgets)
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // md-dock_top
    WelcomeHeader {
        icon: "\u{f1513}"
        title: "Bar"
        description: "How the bar sits on the screen. Settings › Bar has its height, the launcher button and the widgets."
    }

    SettingsGroup {
        title: "Style"

        BarTemplatePicker {}

        SelectRow {
            label: "Position"
            description: "Screen edge the bar sits on"
            path: "bar.position"
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
    }
}
