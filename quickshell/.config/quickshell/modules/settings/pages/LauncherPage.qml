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
        title: "Layout"

        TemplatePicker {
            label: "Template"
            description: "How the launcher opens"
            path: "launcher.style"
            options: [
                {
                    label: "Spotlight",
                    value: "spotlight"
                },
                {
                    label: "Dropdown",
                    value: "dropdown"
                },
                {
                    label: "Sidebar",
                    value: "sidebar"
                },
                {
                    label: "Grid",
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
            label: "Position"
            description: "In the upper third of the screen, or right next to the bar"
            path: "launcher.position"
            value: LauncherService.position
            segmentWidth: Config.fontSizeNormal * 8
            options: [
                {
                    label: "Center",
                    value: "center"
                },
                {
                    label: "Near the bar",
                    value: "bar"
                }
            ]
        }

        SelectRow {
            visible: LauncherService.style === "sidebar"
            label: "Side"
            description: "Screen edge the sidebar opens on"
            path: "launcher.position"
            value: LauncherService.position
            options: [
                {
                    label: "Left",
                    value: "left"
                },
                {
                    label: "Right",
                    value: "right"
                }
            ]
        }

        // Only the templates that sit against the bar or a screen edge. The
        // switch is shared with the bar popups, so it lives in the Bar page
        SettingRow {
            id: attachRow

            readonly property bool on: StateService.get("bar.attachPopups", true)

            visible: LauncherService.style === "dropdown" || LauncherService.style === "sidebar" || (LauncherService.style === "spotlight" && LauncherService.position === "bar")
            label: on ? "Attached to the bar" : "Floating"
            description: "Follows Attach to the bar in the Bar settings, like the bar popups"

            ActionButton {
                icon: "\u{f1513}"
                text: "Bar settings"
                size: root.buttonSize
                baseColor: attachRow.controlColor
                onClicked: SettingsService.open("bar")
            }
        }
    }

    SettingsGroup {
        title: "Search"

        ToggleRow {
            label: "Show descriptions"
            description: "A line under each app name with what it does"
            path: "launcher.showDescriptions"
        }

        ToggleRow {
            label: "Rank by usage"
            description: "Apps you open often come first; off keeps the list alphabetical"
            path: "launcher.rankByUsage"
        }

        StepperRow {
            label: "Visible rows"
            description: "How many results show before the list scrolls"
            path: "launcher.rows"
            from: 4
            to: 12
        }
    }

    SettingsGroup {
        title: "Apps"

        TextFieldRow {
            label: "Terminal"
            description: "Runs apps that need a terminal (Terminal=true in their .desktop file)"
            path: "launcher.terminal"
            placeholder: "kitty"
        }
    }

    SettingsGroup {
        title: "Favorites"

        SettingRow {
            visible: LauncherService.favorites.length === 0
            label: "No favorites yet"
            description: "Pin apps from the ⋮ menu in the launcher; they show up as tiles above the list"
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
                    text: "Unpin"
                    size: root.buttonSize
                    baseColor: favoriteRow.controlColor
                    onClicked: LauncherService.unpin(favoriteRow.modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: "Hidden apps"

        SettingRow {
            visible: LauncherService.hidden.length === 0
            label: "No hidden apps"
            description: "Hide apps you never open from the ⋮ menu in the launcher"
        }

        Repeater {
            model: LauncherService.hidden

            AppSettingRow {
                id: hiddenRow

                required property string modelData

                appId: modelData

                ActionButton {
                    icon: "\u{f0208}"
                    text: "Restore"
                    size: root.buttonSize
                    baseColor: hiddenRow.controlColor
                    onClicked: LauncherService.unhideApp(hiddenRow.modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: "Usage"

        SettingRow {
            id: usageRow

            label: "Usage history"
            description: LauncherService.usage.length === 0 ? "Nothing yet: apps are counted as you open them" : LauncherService.usage.length + (LauncherService.usage.length === 1 ? " app" : " apps") + " counted, used to rank the list"

            ActionButton {
                enabled: LauncherService.usage.length > 0
                opacity: enabled ? 1 : 0.4
                icon: "\u{f00e2}"
                text: "Clear"
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
        description: entry ? (entry.comment || entry.genericName || "") : "Not installed anymore"

        leading: Rectangle {
            implicitWidth: Config.fontSizeIconLarge + Config.padding * 2
            implicitHeight: implicitWidth
            radius: Config.radiusLarge
            color: appRow.controlColor

            Image {
                anchors.centerIn: parent
                width: Config.fontSizeIconLarge
                height: width
                source: "image://icon/" + (appRow.entry?.icon || "application-x-executable")
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
