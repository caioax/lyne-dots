pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

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
        title: "Workspaces"

        TemplatePicker {
            label: "Style"
            description: ({
                    "numbers": "Numbers of the workspaces in use, dots for the empty ones",
                    "dots": "Filled dots for workspaces in use, rings for empty ones; the active one is a bar",
                    "groups": "Numbers where neighbouring workspaces in use share one background",
                    "icons": "Icons of the apps open on each workspace, numbers for the empty ones"
                })[Config.barWorkspaceStyle] ?? "A pill per workspace, solid when it has windows"
            path: "bar.workspaces.style"
            options: [
                {
                    label: "Pills",
                    value: "pills"
                },
                {
                    label: "Numbers",
                    value: "numbers"
                },
                {
                    label: "Dots",
                    value: "dots"
                },
                {
                    label: "Groups",
                    value: "groups"
                },
                {
                    label: "Icons",
                    value: "icons"
                }
            ]
            preview: Component {
                WorkspaceStylePreview {}
            }
        }

        StepperRow {
            label: "Shown"
            description: "Workspaces in view at once; the strip scrolls to reach the others"
            path: "bar.workspaces.count"
            from: 3
            to: 15
            enabled: !Config.barWorkspaceHideEmpty
        }

        ToggleRow {
            label: "Hide empty"
            description: "Only workspaces with windows, plus the active one"
            path: "bar.workspaces.hideEmpty"
        }

        ToggleRow {
            label: "Scroll to switch"
            description: "The mouse wheel over the workspaces moves to the next or previous one"
            path: "bar.workspaces.scroll"
        }
    }

    SettingsGroup {
        title: "Center"

        SelectRow {
            label: "Style"
            description: Config.barCenterClock ? "The clock alone, with cava faintly behind it while something plays; hover shows the track" : "The clock plus the buttons below, each opening its dashboard tab"
            path: "bar.centerStyle"
            options: [
                {
                    label: "Buttons",
                    icon: "\u{f056e}",
                    value: "buttons"
                },
                {
                    label: "Clock",
                    icon: "\u{f0954}",
                    value: "clock"
                }
            ]
        }

        ToggleRow {
            label: "Media"
            description: "Cover and spectrum of what's playing, title on hover; opens the dashboard's Media tab"
            path: "bar.showMedia"
            enabled: !Config.barCenterClock && DashboardService.hasTab("media")
        }

        ToggleRow {
            label: "System"
            description: "CPU usage graph; opens the dashboard's System tab"
            path: "bar.showSystem"
            enabled: !Config.barCenterClock && DashboardService.hasTab("system")
        }

        ToggleRow {
            label: "Weather"
            description: "Its own button for the Weather tab; off, the clock shows the weather"
            path: "bar.showWeather"
            enabled: !Config.barCenterClock && DashboardService.hasTab("weather")
        }
    }

    SettingsGroup {
        title: "Tray"

        SelectRow {
            label: "Style"
            description: ({
                    "row": "Every icon always in the bar",
                    "overflow": "One button in the bar; the icons open in a grid under it",
                    "pinned": "The items switched on below stay in the bar; the rest wait behind a button"
                })[Config.barTrayStyle] ?? "The icons slide out of a button in the bar"
            path: "bar.tray.style"
            options: [
                {
                    label: "Row",
                    value: "row"
                },
                {
                    label: "Drawer",
                    value: "drawer"
                },
                {
                    label: "Overflow",
                    value: "overflow"
                },
                {
                    label: "Pinned",
                    value: "pinned"
                }
            ]
        }

        ToggleRow {
            label: "Attention badge"
            description: "A pulsing dot on items asking for attention, and on the button hiding them"
            path: "bar.tray.attention"
        }

        // Running items in bar order: move, hide, and pin (pinned style)
        Repeater {
            model: TrayService.items

            SettingRow {
                id: trayRow

                required property var modelData
                required property int index

                readonly property string itemId: modelData.id
                readonly property bool hidden: TrayService.isHidden(itemId)
                readonly property bool pinned: TrayService.isPinned(itemId)
                readonly property bool pinnedStyle: Config.barTrayStyle === "pinned"
                readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

                label: TrayService.itemName(modelData)
                description: hidden ? "Hidden from the bar" : !pinnedStyle ? "" : pinned ? "Pinned to the bar" : "Behind the button"

                leading: TrayIconBox {
                    source: TrayService.getIconSource(trayRow.modelData.icon)
                    color: trayRow.controlColor
                    opacity: trayRow.hidden ? 0.4 : 1
                }

                // md-arrow_up / md-arrow_down
                ActionButton {
                    icon: "\u{f005d}"
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    opacity: trayRow.index > 0 ? 1 : 0.3
                    onClicked: TrayService.move(trayRow.itemId, -1)
                }

                ActionButton {
                    icon: "\u{f0045}"
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    opacity: trayRow.index < TrayService.items.length - 1 ? 1 : 0.3
                    onClicked: TrayService.move(trayRow.itemId, 1)
                }

                // md-eye / md-eye_off
                ActionButton {
                    icon: trayRow.hidden ? "\u{f0208}" : "\u{f0209}"
                    text: trayRow.hidden ? "Show" : "Hide"
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    onClicked: TrayService.setHidden(trayRow.itemId, !trayRow.hidden)
                }

                QsSwitch {
                    visible: trayRow.pinnedStyle
                    enabled: !trayRow.hidden
                    opacity: enabled ? 1 : 0.4
                    checked: trayRow.pinned
                    onToggled: {
                        TrayService.setPinned(trayRow.itemId, checked);
                        checked = Qt.binding(() => trayRow.pinned);
                    }
                }
            }
        }

        // Pinned or hidden items that aren't running right now
        Repeater {
            model: TrayService.missingIds

            SettingRow {
                id: missingRow

                required property string modelData

                label: modelData
                description: (TrayService.isHidden(modelData) ? "Hidden" : "Pinned") + ", not running"

                leading: TrayIconBox {
                    source: ""
                    color: missingRow.controlColor
                }

                // md-close
                ActionButton {
                    icon: "\u{f0156}"
                    text: "Forget"
                    size: Config.fontSizeIconSmall + Config.padding * 2
                    baseColor: missingRow.controlColor
                    onClicked: TrayService.forget(missingRow.modelData)
                }
            }
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

    // Tray item icon in a rounded box, like the launcher's app rows
    component TrayIconBox: Rectangle {
        id: iconBox

        property string source

        implicitWidth: Config.fontSizeIconLarge + Config.padding * 2
        implicitHeight: implicitWidth
        radius: Config.radiusLarge

        Image {
            id: icon
            anchors.centerIn: parent
            width: Config.fontSizeIconLarge
            height: width
            source: iconBox.source
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }

        // Missing or broken icon
        Image {
            anchors.centerIn: parent
            width: Config.fontSizeIconLarge
            height: width
            source: "image://icon/application-x-executable"
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            visible: icon.status !== Image.Ready
        }
    }
}
