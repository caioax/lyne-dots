pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../rows/"

ColumnLayout {
    spacing: Config.spacing * 3

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
