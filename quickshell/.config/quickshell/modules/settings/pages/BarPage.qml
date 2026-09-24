pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../rows/"

ColumnLayout {
    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Style"

        TemplatePicker {
            label: "Template"
            description: "How the bar sits on the screen"
            path: "bar.style"
            options: [
                {
                    label: "Docked",
                    value: "docked"
                },
                {
                    label: "Docked corners",
                    value: "docked-corners"
                },
                {
                    label: "Floating",
                    value: "floating"
                },
                {
                    label: "Islands",
                    value: "islands"
                }
            ]
            preview: Component {
                BarStylePreview {}
            }
        }
    }

    SettingsGroup {
        title: "Layout"

        SliderRow {
            label: "Height"
            description: "Height of the bar; the islands and buttons follow it"
            path: "bar.height"
            from: 24
            to: 48
            format: v => v + "px"
        }

        SliderRow {
            label: "Margin"
            description: "Gap between the floating bar and the screen edges"
            path: "bar.margin"
            enabled: Config.barFloating
            from: 0
            to: 24
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: "Behaviour"

        ToggleRow {
            label: "Auto hide"
            description: "Hide the bar until the pointer reaches the top edge of the screen"
            path: "bar.autoHide"
        }
    }
}
