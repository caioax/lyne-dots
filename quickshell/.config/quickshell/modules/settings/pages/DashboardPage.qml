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
        title: "Tabs"

        SelectRow {
            label: "Opens on"
            description: "Tab shown when the clock opens the dashboard"
            path: "dashboard.defaultTab"
            segmentWidth: Config.fontSizeNormal * 5.5
            options: [
                {
                    label: "Last used",
                    value: "last"
                },
                {
                    label: "Overview",
                    value: "overview"
                },
                {
                    label: "Media",
                    value: "media"
                },
                {
                    label: "System",
                    value: "system"
                },
                {
                    label: "Weather",
                    value: "weather"
                }
            ]
        }

        TabRow {
            tabId: "overview"
        }

        TabRow {
            tabId: "media"
        }

        TabRow {
            tabId: "system"
        }

        TabRow {
            tabId: "weather"
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
            label: "Cover background"
            description: "Blurred album cover behind the Media tab instead of a plain card"
            path: "dashboard.coverBackdrop"
        }

        ToggleRow {
            label: "GIF"
            description: "In the Media tab and under the Overview player; moves while something plays"
            path: "dashboard.showGif"
        }

        SettingRow {
            id: gifRow

            label: "GIF file"
            description: DashboardService.gifPath !== "" ? "Custom GIF" : "Capoo (default)"
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

    // Shows or hides one tab; the last one shown can't be hidden
    component TabRow: ToggleRow {
        id: tabRow

        required property string tabId
        readonly property var tab: DashboardService.allTabs.find(t => t.id === tabId)
        readonly property bool shown: !DashboardService.hiddenTabs.includes(tabId)

        label: tab.label + " tab"
        description: tab.description
        checked: shown
        enabled: !shown || DashboardService.tabs.length > 1
        onToggled: value => DashboardService.setTabShown(tabId, value)
    }
}
