pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Style")

        TemplatePicker {
            label: I18n.tr("Template")
            description: I18n.tr("How the launcher opens")
            path: "launcher.style"
            options: [
                {
                    label: I18n.tr("Spotlight"),
                    value: "spotlight"
                },
                {
                    label: I18n.tr("Dropdown"),
                    value: "dropdown"
                },
                {
                    label: I18n.tr("Sidebar"),
                    value: "sidebar"
                },
                {
                    label: I18n.tr("Grid"),
                    value: "grid"
                }
            ]
            preview: Component {
                LauncherStylePreview {}
            }
        }

        // Only the templates with a choice of place
        SelectRow {
            visible: LauncherService.style === "spotlight"
            label: I18n.tr("Position")
            description: I18n.tr("Against the top or bottom edge (the bar, when it's there), or in the upper third")
            path: "launcher.position"
            value: LauncherService.position
            options: [
                {
                    label: I18n.tr("Top"),
                    value: "top"
                },
                {
                    label: I18n.tr("Center"),
                    value: "center"
                },
                {
                    label: I18n.tr("Bottom"),
                    value: "bottom"
                }
            ]
        }

        SelectRow {
            visible: LauncherService.style === "sidebar"
            label: I18n.tr("Side")
            description: I18n.tr("Screen edge the sidebar opens on")
            path: "launcher.position"
            value: LauncherService.position
            options: [
                {
                    label: I18n.tr("Left"),
                    value: "left"
                },
                {
                    label: I18n.tr("Right"),
                    value: "right"
                }
            ]
        }

        // Only the templates that sit against the bar or a screen edge. The
        // switch is shared with the bar popups, so it lives in the Bar page
        SettingRow {
            id: attachRow

            readonly property bool on: StateService.get("bar.attachPopups", true)

            visible: LauncherService.style === "dropdown" || LauncherService.style === "sidebar" || (LauncherService.style === "spotlight" && LauncherService.position !== "center")
            label: on ? I18n.tr("Attached to the bar") : I18n.tr("Floating")
            description: I18n.tr("Follows Attach to the bar in the Bar settings, like the bar popups")

            ActionButton {
                icon: "\u{f1513}"
                text: I18n.tr("Bar settings")
                size: root.buttonSize
                baseColor: attachRow.controlColor
                onClicked: SettingsService.open("bar")
            }
        }

        SelectRow {
            label: I18n.tr("Search bar")
            description: I18n.tr("Auto puts it at the bottom when the launcher opens from the bottom edge")
            path: "launcher.order"
            options: [
                {
                    label: I18n.tr("Top"),
                    value: "top"
                },
                {
                    label: I18n.tr("Bottom"),
                    value: "bottom"
                },
                {
                    label: I18n.tr("Auto"),
                    value: "auto"
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.trc("section", "Search")

        ToggleRow {
            label: I18n.tr("Show descriptions")
            description: I18n.tr("A line under each app name with what it does")
            path: "launcher.showDescriptions"
        }

        ToggleRow {
            label: I18n.tr("Rank by usage")
            description: I18n.tr("Apps you open often come first; off keeps the list alphabetical")
            path: "launcher.rankByUsage"
        }

        StepperRow {
            label: I18n.tr("Visible rows")
            description: I18n.tr("How many results show before the list scrolls")
            path: "launcher.rows"
            from: 4
            to: 12
        }
    }

    SettingsGroup {
        title: I18n.tr("Apps")

        SettingRow {
            id: terminalRow

            label: I18n.tr("Terminal")
            description: I18n.tr("Apps that need a terminal (Terminal=true in their .desktop file) open in %1, the default terminal", AppsService.nameOf("terminal"))

            ActionButton {
                icon: "\u{f003b}"
                text: I18n.tr("Default apps")
                baseColor: terminalRow.controlColor
                onClicked: SettingsService.open("apps")
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Favorites")

        SettingRow {
            visible: LauncherService.favorites.length === 0
            label: I18n.tr("No favorites yet")
            description: I18n.tr("Pin apps from the ⋮ menu in the launcher; they show up as tiles above the list")
        }

        Repeater {
            model: LauncherService.favorites

            AppSettingRow {
                id: favoriteRow

                required property string modelData
                required property int index

                appId: modelData

                ActionButton {
                    icon: "\u{f005d}"
                    size: root.buttonSize
                    baseColor: favoriteRow.controlColor
                    opacity: favoriteRow.index > 0 ? 1 : 0.3
                    onClicked: LauncherService.moveFavorite(favoriteRow.modelData, -1)
                }

                ActionButton {
                    icon: "\u{f0045}"
                    size: root.buttonSize
                    baseColor: favoriteRow.controlColor
                    opacity: favoriteRow.index < LauncherService.favorites.length - 1 ? 1 : 0.3
                    onClicked: LauncherService.moveFavorite(favoriteRow.modelData, 1)
                }

                ActionButton {
                    icon: "\u{f0404}"
                    text: I18n.tr("Unpin")
                    size: root.buttonSize
                    baseColor: favoriteRow.controlColor
                    onClicked: LauncherService.unpin(favoriteRow.modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Hidden apps")

        SettingRow {
            visible: LauncherService.hidden.length === 0
            label: I18n.tr("No hidden apps")
            description: I18n.tr("Hide apps you never open from the ⋮ menu in the launcher")
        }

        Repeater {
            model: LauncherService.hidden

            AppSettingRow {
                id: hiddenRow

                required property string modelData

                appId: modelData

                ActionButton {
                    icon: "\u{f0208}"
                    text: I18n.tr("Restore")
                    size: root.buttonSize
                    baseColor: hiddenRow.controlColor
                    onClicked: LauncherService.unhideApp(hiddenRow.modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Usage")

        SettingRow {
            id: usageRow

            label: I18n.tr("Usage history")
            description: !LauncherService.rankByUsage ? I18n.tr("Paused while Rank by usage is off: nothing is counted") : LauncherService.usage.length === 0 ? I18n.tr("Nothing yet: apps are counted as you open them") : I18n.trn("%n app counted, used to rank the list", "%n apps counted, used to rank the list", LauncherService.usage.length)

            ActionButton {
                enabled: LauncherService.usage.length > 0
                opacity: enabled ? 1 : 0.4
                icon: "\u{f00e2}"
                text: I18n.tr("Clear")
                size: root.buttonSize
                baseColor: usageRow.controlColor
                onClicked: LauncherService.clearUsage()
            }
        }
    }

    // An app by desktop entry id: its icon, name and description, or the id
    // when the app was uninstalled
    component AppSettingRow: SettingRow {
        id: appRow

        property string appId
        readonly property var entry: LauncherService.entryById(appId)

        label: entry?.name ?? appId
        description: entry ? (entry.comment || entry.genericName || "") : I18n.tr("Not installed anymore")

        leading: Rectangle {
            implicitWidth: Config.fontSizeIconLarge + Config.padding * 2
            implicitHeight: implicitWidth
            radius: Config.radiusLarge
            color: appRow.controlColor

            Image {
                anchors.centerIn: parent
                width: Config.fontSizeIconLarge
                height: width
                source: IconService.url(appRow.entry?.icon || "application-x-executable", "")
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
