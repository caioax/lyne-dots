pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Behavior")

        // Owned by NotificationService, which keeps its own copy
        ToggleRow {
            label: I18n.tr("Do not disturb")
            description: I18n.tr("Silence popups; notifications still go to the history")
            resettable: false
            checked: NotificationService.dndEnabled
            onToggled: value => NotificationService.setDnd(value)
        }

        StepperRow {
            label: I18n.tr("Timeout")
            description: I18n.tr("How long a popup stays on screen when the app doesn't set one")
            path: "notifications.timeout"
            from: 1000
            to: 30000
            stepSize: 1000
            format: v => v / 1000 + "s"
        }

        StepperRow {
            label: I18n.tr("Popups on screen")
            description: I18n.tr("Older popups are hidden when there are more than this")
            path: "notifications.maxPopups"
            from: 1
            to: 8
        }
    }

    SettingsGroup {
        title: I18n.tr("Appearance")

        SliderRow {
            label: I18n.tr("Popup width")
            path: "notifications.width"
            from: 280
            to: 520
            stepSize: 10
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Icon size")
            description: I18n.tr("App icon and image in popups and in the history")
            path: "notifications.imageSize"
            from: 24
            to: 64
            stepSize: 4
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Spacing")
            description: I18n.tr("Gap between stacked popups")
            path: "notifications.spacing"
            from: 0
            to: 24
            format: v => v + "px"
        }
    }
}
