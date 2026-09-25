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

    SettingsGroup {
        title: "Media"

        ToggleRow {
            label: "Visualizer"
            description: CavaService.available ? "Audio spectrum around the cover while something plays (cava)" : "cava isn't installed"
            path: "dashboard.visualizer"
            enabled: CavaService.available
        }

        ToggleRow {
            label: "GIF"
            description: "Beside the players in the Overview and the Media tab; moves while something plays"
            path: "dashboard.showGif"
        }

        SettingRow {
            id: gifRow

            label: "GIF file"
            description: DashboardService.gifPath !== "" ? "Custom GIF" : "Bongocat (default)"
            path: "dashboard.gif"
            enabled: DashboardService.showGif

            leading: AnimatedImage {
                Layout.preferredWidth: Config.fontSizeLarge * 4
                Layout.preferredHeight: Config.fontSizeLarge * 2.5
                source: DashboardService.gifSource
                fillMode: AnimatedImage.PreserveAspectFit
                playing: gifRow.hovered
            }

            ActionButton {
                icon: "\u{f0d78}"
                text: "Choose GIF"
                baseColor: gifRow.controlColor
                onClicked: DashboardService.pickGif()
            }
        }
    }
}
