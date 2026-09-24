pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

ColumnLayout {
    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Behaviour"

        // Owned by NotificationService, which keeps its own copy
        ToggleRow {
            label: "Do not disturb"
            description: "Silence popups; notifications still go to the history"
            checked: NotificationService.dndEnabled
            onToggled: value => NotificationService.setDnd(value)
        }

        StepperRow {
            label: "Timeout"
            description: "How long a popup stays on screen when the app doesn't set one"
            path: "notifications.timeout"
            from: 1000
            to: 30000
            stepSize: 1000
            format: v => v / 1000 + "s"
        }

        StepperRow {
            label: "Popups on screen"
            description: "Older popups are hidden when there are more than this"
            path: "notifications.maxPopups"
            from: 1
            to: 8
        }
    }

    SettingsGroup {
        title: "Appearance"

        SliderRow {
            label: "Popup width"
            path: "notifications.width"
            from: 280
            to: 520
            stepSize: 10
            format: v => v + "px"
        }

        SliderRow {
            label: "Icon size"
            description: "App icon and image in popups and in the history"
            path: "notifications.imageSize"
            from: 24
            to: 64
            stepSize: 4
            format: v => v + "px"
        }

        SliderRow {
            label: "Spacing"
            description: "Gap between stacked popups"
            path: "notifications.spacing"
            from: 0
            to: 24
            format: v => v + "px"
        }
    }
}
