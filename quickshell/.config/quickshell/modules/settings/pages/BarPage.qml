pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    // What a right or middle click on the launcher button can do
    readonly property var launcherClickOptions: [
        {
            label: I18n.tr("Nothing"),
            value: "none"
        },
        {
            label: I18n.tr("Actions"),
            value: "actions"
        },
        {
            label: I18n.tr("Clipboard"),
            value: "clipboard"
        },
        {
            label: I18n.tr("Settings"),
            value: "settings"
        },
        {
            label: I18n.tr("Power"),
            value: "power"
        }
    ]

    SettingsGroup {
        title: I18n.tr("Style")

        // Label repeated here for the Settings search (it reads the page source)
        BarTemplatePicker {
            label: I18n.tr("Template")
        }

        ToggleRow {
            label: I18n.tr("Attach to the bar")
            description: Config.barIslands || Config.barFloating ? I18n.tr("Popups grow out of the screen edge with rounded joins (the bar has no continuous edge in its current style): Quick Settings, the dashboard and the launcher (dropdown, sidebar and spotlight next to the bar)") : I18n.tr("Popups grow out of the bar with rounded joins: Quick Settings, the dashboard and the launcher (dropdown, sidebar and spotlight next to the bar)")
            path: "bar.attachPopups"
        }
    }

    SettingsGroup {
        title: I18n.tr("Layout")

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

        SliderRow {
            label: I18n.tr("Height")
            description: I18n.tr("Height of the bar; the islands and buttons follow it")
            path: "bar.height"
            from: 24
            to: 48
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Margin")
            description: I18n.tr("Gap between the floating bar and the screen edges")
            path: "bar.margin"
            enabled: Config.barFloating
            from: 0
            to: 24
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: I18n.tr("Launcher button")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "pill": I18n.tr("The logo on a soft accent pill that is always there"),
                    "compact": I18n.tr("A round button, the same size as the bar's other icons")
                })[Config.barLauncherStyle] ?? I18n.tr("Just the logo; a pill the size of the logo shows on hover")
            path: "bar.launcher.style"
            options: [
                {
                    label: I18n.tr("Logo"),
                    value: "logo"
                },
                {
                    label: I18n.tr("Pill"),
                    value: "pill"
                },
                {
                    label: I18n.tr("Compact"),
                    value: "compact"
                }
            ]
            preview: Component {
                LauncherButtonPreview {}
            }
        }

        SelectRow {
            label: I18n.tr("Icon")
            description: I18n.tr("The lyne-dots logo, or your distro's logo from the Nerd Font")
            path: "bar.launcher.icon"
            options: [
                {
                    label: "lyne-dots",
                    value: "lyne"
                },
                {
                    label: I18n.tr("Distro"),
                    icon: "\u{f31a}",
                    value: "distro"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Animate")
            description: I18n.tr("The dot bounces on hover and rides the line when the launcher opens; the logo draws itself when the shell starts")
            path: "bar.launcher.animate"
        }

        SelectRow {
            label: I18n.tr("Right click")
            description: I18n.tr("Actions and Clipboard open that launcher mode")
            path: "bar.launcher.rightClick"
            options: page.launcherClickOptions
        }

        SelectRow {
            label: I18n.tr("Middle click")
            description: I18n.tr("Same choices as the right click")
            path: "bar.launcher.middleClick"
            options: page.launcherClickOptions
        }
    }

    SettingsGroup {
        title: I18n.tr("Workspaces")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "numbers": I18n.tr("Numbers of the workspaces in use, dots for the empty ones"),
                    "dots": I18n.tr("Filled dots for workspaces in use, rings for empty ones; the active one is a bar"),
                    "groups": I18n.tr("Numbers where neighbouring workspaces in use share one background"),
                    "icons": I18n.tr("Icons of the apps open on each workspace, numbers for the empty ones")
                })[Config.barWorkspaceStyle] ?? I18n.tr("A pill per workspace, solid when it has windows")
            path: "bar.workspaces.style"
            options: [
                {
                    label: I18n.tr("Pills"),
                    value: "pills"
                },
                {
                    label: I18n.tr("Numbers"),
                    value: "numbers"
                },
                {
                    label: I18n.tr("Dots"),
                    value: "dots"
                },
                {
                    label: I18n.tr("Groups"),
                    value: "groups"
                },
                {
                    label: I18n.tr("Icons"),
                    value: "icons"
                }
            ]
            preview: Component {
                WorkspaceStylePreview {}
            }
        }

        StepperRow {
            label: I18n.tr("Shown")
            description: I18n.tr("Workspaces in view at once; the strip scrolls to reach the others")
            path: "bar.workspaces.count"
            from: 3
            to: 15
            enabled: !Config.barWorkspaceHideEmpty
        }

        ToggleRow {
            label: I18n.tr("Hide empty")
            description: I18n.tr("Only workspaces with windows, plus the active one")
            path: "bar.workspaces.hideEmpty"
        }

        ToggleRow {
            label: I18n.tr("Scroll to switch")
            description: I18n.tr("The mouse wheel over the workspaces moves to the next or previous one, like the keys (Hyprland › Workspaces)")
            path: "bar.workspaces.scroll"
        }
    }

    SettingsGroup {
        title: I18n.tr("Center")

        SelectRow {
            label: I18n.tr("Style")
            description: Config.barCenterClock ? I18n.tr("The clock alone, with cava faintly behind it while something plays; hover shows the track") : I18n.tr("The clock plus the buttons below, each opening its dashboard tab")
            path: "bar.centerStyle"
            options: [
                {
                    label: I18n.tr("Buttons"),
                    icon: "\u{f056e}",
                    value: "buttons"
                },
                {
                    label: I18n.tr("Clock"),
                    icon: "\u{f0954}",
                    value: "clock"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Media")
            description: I18n.tr("Cover and spectrum of what's playing, title on hover; opens the dashboard's Media tab")
            path: "bar.showMedia"
            enabled: !Config.barCenterClock && DashboardService.hasTab("media")
        }

        ToggleRow {
            label: I18n.tr("System")
            description: I18n.tr("CPU usage graph; opens the dashboard's System tab")
            path: "bar.showSystem"
            enabled: !Config.barCenterClock && DashboardService.hasTab("system")
        }

        ToggleRow {
            label: I18n.tr("Weather")
            description: I18n.tr("Its own button for the Weather tab; off, the clock shows the weather")
            path: "bar.showWeather"
            enabled: !Config.barCenterClock && DashboardService.hasTab("weather")
        }

        SelectRow {
            label: I18n.tr("Keyboard layout")
            description: I18n.tr("The layout in use: click to pick one, scroll to switch. Auto shows it with two or more layouts")
            path: "bar.keyboardLayout"
            options: [
                {
                    label: I18n.tr("Auto"),
                    value: "auto"
                },
                {
                    label: I18n.tr("Always"),
                    value: "always"
                },
                {
                    label: I18n.tr("Never"),
                    value: "never"
                }
            ]
        }
    }

    SettingsGroup {
        title: I18n.tr("Tray")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "row": I18n.tr("Every icon always in the bar"),
                    "overflow": I18n.tr("One button in the bar; the icons open in a grid under it"),
                    "pinned": I18n.tr("The items switched on below stay in the bar; the rest wait behind a button")
                })[Config.barTrayStyle] ?? I18n.tr("The icons slide out of a button in the bar")
            path: "bar.tray.style"
            options: [
                {
                    label: I18n.tr("Row"),
                    value: "row"
                },
                {
                    label: I18n.tr("Drawer"),
                    value: "drawer"
                },
                {
                    label: I18n.tr("Overflow"),
                    value: "overflow"
                },
                {
                    label: I18n.tr("Pinned"),
                    value: "pinned"
                }
            ]
            thumbHeight: Config.fontSizeIconLarge * 4
            preview: Component {
                TrayStylePreview {}
            }
        }

        ToggleRow {
            label: I18n.tr("Tooltips")
            description: I18n.tr("The item's name on hover. Middle click and the mouse wheel go to the app")
            path: "bar.tray.tooltips"
        }

        ToggleRow {
            label: I18n.tr("Monochrome icons")
            description: I18n.tr("Tint the icons with the text color, like the rest of the bar")
            path: "bar.tray.monochrome"
        }

        ToggleRow {
            label: I18n.tr("Attention badge")
            description: I18n.tr("A pulsing dot on items asking for attention, and on the button hiding them")
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
                description: hidden ? I18n.tr("Hidden from the bar") : !pinnedStyle ? "" : pinned ? I18n.tr("Pinned to the bar") : I18n.tr("Behind the button")

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
                    text: trayRow.hidden ? I18n.tr("Show") : I18n.tr("Hide")
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
                description: TrayService.isHidden(modelData) ? I18n.tr("Hidden, not running") : I18n.tr("Pinned, not running")

                leading: TrayIconBox {
                    source: ""
                    color: missingRow.controlColor
                }

                // md-close
                ActionButton {
                    icon: "\u{f0156}"
                    text: I18n.tr("Forget")
                    size: Config.fontSizeIconSmall + Config.padding * 2
                    baseColor: missingRow.controlColor
                    onClicked: TrayService.forget(missingRow.modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Quick Settings")

        TemplatePicker {
            label: I18n.tr("Style")
            description: Config.barQsStyle === "minimal" ? I18n.tr("One icon; a dot on it when something needs a glance: unread notifications, low battery, no network, a microphone in use") : I18n.tr("Network, Bluetooth, battery and notifications; muted audio and a microphone in use show up only then")
            path: "bar.quickSettings.style"
            options: [
                {
                    label: I18n.tr("Icons"),
                    value: "icons"
                },
                {
                    label: I18n.tr("Pill"),
                    value: "pill"
                },
                {
                    label: I18n.tr("Chips"),
                    value: "chips"
                },
                {
                    label: I18n.tr("Minimal"),
                    value: "minimal"
                }
            ]
            preview: Component {
                QsStylePreview {}
            }
        }

        ToggleRow {
            label: I18n.tr("Battery percentage")
            description: I18n.tr("Next to the battery icon, or inside the pill style's battery capsule (not in the minimal style)")
            path: "bar.quickSettings.batteryPercent"
            enabled: BatteryService.hasBattery && Config.barQsStyle !== "minimal"
        }
    }

    SettingsGroup {
        title: I18n.tr("Quick Settings indicators")

        ToggleRow {
            label: I18n.tr("Network")
            description: I18n.tr("Wi-Fi signal, or ethernet while a cable is connected")
            path: "bar.quickSettings.indicators.network"
        }

        ToggleRow {
            label: I18n.tr("Bluetooth")
            description: I18n.tr("While a device is connected")
            path: "bar.quickSettings.indicators.bluetooth"
        }

        ToggleRow {
            label: I18n.tr("Muted sound")
            description: I18n.tr("While the output is muted")
            path: "bar.quickSettings.indicators.volume"
        }

        ToggleRow {
            label: I18n.tr("Microphone")
            description: I18n.tr("While it's muted or an app is recording")
            path: "bar.quickSettings.indicators.mic"
        }

        ToggleRow {
            label: I18n.tr("Battery")
            description: I18n.tr("Level and charging, on laptops")
            path: "bar.quickSettings.indicators.battery"
        }

        ToggleRow {
            label: I18n.tr("Notifications")
            description: I18n.tr("Unread count, or the do not disturb bell")
            path: "bar.quickSettings.indicators.notifications"
        }
    }

    SettingsGroup {
        title: I18n.tr("Behavior")

        ToggleRow {
            label: I18n.tr("Auto hide")
            description: I18n.tr("Hide the bar until the pointer reaches its edge of the screen")
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
            source: IconService.url("application-x-executable", "")
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            visible: icon.status !== Image.Ready
        }
    }
}
