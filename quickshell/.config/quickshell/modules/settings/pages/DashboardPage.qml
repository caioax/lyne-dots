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
        title: "Overview"

        TemplatePicker {
            label: "Layout"
            description: "Stacked keeps the Quick Settings player; grid is wider, with a tall player"
            path: "dashboard.overviewLayout"
            options: [
                {
                    label: "Stacked",
                    value: "stacked"
                },
                {
                    label: "Grid",
                    value: "grid"
                }
            ]
            preview: Component {
                DashboardLayoutPreview {}
            }
        }
    }
}
