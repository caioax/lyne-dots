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
        title: I18n.tr("Tabs")

        SelectRow {
            label: I18n.tr("Opens on")
            description: I18n.tr("Tab shown when the clock opens the dashboard")
            path: "dashboard.defaultTab"
            segmentWidth: Config.fontSizeNormal * 5.5
            options: [
                {
                    label: I18n.tr("Last used"),
                    value: "last"
                },
                {
                    label: I18n.tr("Overview"),
                    value: "overview"
                },
                {
                    label: I18n.tr("Media"),
                    value: "media"
                },
                {
                    label: I18n.tr("System"),
                    value: "system"
                },
                {
                    label: I18n.tr("Weather"),
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
        title: I18n.tr("Calendar")

        SelectRow {
            label: I18n.tr("Holidays")
            description: {
                const shown = HolidayService.enabled ? I18n.tr("Brazil's national holidays") : I18n.tr("no holidays");
                return HolidayService.setting === "auto" ? I18n.tr("Marked on the Overview calendar; Automatic follows your time zone and language (now: %1)", shown) : I18n.tr("Marked on the Overview calendar");
            }
            path: "dashboard.holidays"
            options: [
                {
                    label: I18n.tr("Automatic"),
                    value: "auto"
                },
                {
                    label: I18n.tr("None"),
                    value: "none"
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.tr("Media")

        ToggleRow {
            label: I18n.tr("Visualizer")
            description: CavaService.available ? I18n.tr("Audio spectrum around the cover while something plays (cava)") : I18n.tr("cava isn't installed")
            path: "dashboard.visualizer"
            enabled: CavaService.available
        }

        ToggleRow {
            label: I18n.tr("Cover background")
            description: I18n.tr("Blurred album cover behind the Media tab instead of a plain card")
            path: "dashboard.coverBackdrop"
        }

        ToggleRow {
            label: I18n.tr("Lyrics")
            description: I18n.tr("Synced lyrics (LRCLIB, NetEase) in place of the album in the Media tab")
            path: "dashboard.lyrics"
        }

        ToggleRow {
            label: "GIF"
            description: I18n.tr("In the Media tab and under the Overview player; moves while something plays")
            path: "dashboard.showGif"
        }

        SettingRow {
            id: gifRow

            label: I18n.tr("GIF file")
            description: DashboardService.gifPath !== "" ? I18n.tr("Custom GIF") : I18n.tr("Duck (default)")
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
                text: I18n.tr("Choose GIF")
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

        label: I18n.tr("%1 tab", tab.label)
        description: tab.description
        checked: shown
        enabled: !shown || DashboardService.tabs.length > 1
        onToggled: value => DashboardService.setTabShown(tabId, value)
    }
}
