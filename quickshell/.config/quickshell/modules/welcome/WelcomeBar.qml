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
        title: I18n.tr("Bar")
        description: I18n.tr("How the bar sits on the screen. Settings › %1 has its height, the launcher button and the widgets.", I18n.translate("Bar"))
    }

    SettingsGroup {
        title: I18n.tr("Style")

        BarTemplatePicker {}

        SelectRow {
            label: I18n.tr("Position")
            description: I18n.tr("Screen edge the bar sits on")
            path: "bar.position"
            options: [
                {
                    label: I18n.tr("Top"),
                    icon: "\u{f1513}",
                    value: "top"
                },
                {
                    label: I18n.tr("Bottom"),
                    icon: "\u{f10a9}",
                    value: "bottom"
                }
            ]
        }
    }
}
