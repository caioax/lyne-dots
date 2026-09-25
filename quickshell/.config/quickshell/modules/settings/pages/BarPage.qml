pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
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

        ToggleRow {
            label: "Attach to the bar"
            description: (Config.barIslands || Config.barFloating ? "Popups grow out of the screen edge with rounded joins (the bar has no continuous edge in its current style)" : "Popups grow out of the bar with rounded joins") + ": Quick Settings, the dashboard and the launcher (dropdown, sidebar and spotlight next to the bar)"
            path: "bar.attachPopups"
        }
    }

    SettingsGroup {
        title: "Layout"

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
        title: "Center"

        ToggleRow {
            label: "Media"
            description: "Cover and spectrum of what's playing, title on hover; opens the dashboard's Media tab"
            path: "bar.showMedia"
            enabled: DashboardService.hasTab("media")
        }

        ToggleRow {
            label: "System"
            description: "CPU usage graph; opens the dashboard's System tab"
            path: "bar.showSystem"
            enabled: DashboardService.hasTab("system")
        }

        ToggleRow {
            label: "Weather"
            description: "Its own button for the Weather tab; off, the clock shows the weather"
            path: "bar.showWeather"
            enabled: DashboardService.hasTab("weather")
        }
    }

    SettingsGroup {
        title: "Behaviour"

        ToggleRow {
            label: "Auto hide"
            description: "Hide the bar until the pointer reaches its edge of the screen"
            path: "bar.autoHide"
        }
    }
}
