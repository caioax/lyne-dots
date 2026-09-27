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
        title: "Capture"

        SelectRow {
            label: "Opens in"
            description: {
                switch (Config.screenshotMode) {
                case "window":
                    return "Picks the window under the cursor; R, W and S switch modes";
                case "screen":
                    return "Takes the whole monitor under the cursor; R, W and S switch modes";
                default:
                    return "Drag to draw a region; R, W and S switch modes";
                }
            }
            path: "screenshot.mode"
            options: [
                {
                    label: "Region",
                    value: "region",
                    icon: "\u{f0a6d}"
                },
                {
                    label: "Window",
                    value: "window",
                    icon: "\u{f05af}"
                },
                {
                    label: "Screen",
                    value: "screen",
                    icon: "\u{f0379}"
                }
            ]
        }

        SettingRow {
            id: tryRow

            label: "Take a screenshot"
            description: "Closes Settings and opens the capture overlay · Print"

            ActionButton {
                icon: "\u{f0e51}"
                text: "Capture"
                size: root.buttonSize
                baseColor: tryRow.controlColor
                onClicked: {
                    SettingsService.close();
                    // Wait for the window to close so it isn't captured
                    ShortcutService.requestScreenshotAfter(Config.animDurationLong);
                }
            }
        }
    }

    SettingsGroup {
        title: "Overlay"

        SliderRow {
            label: "Dimming"
            description: "How dark the screen gets outside the selection"
            path: "screenshot.dim"
            from: 0
            to: 90
            stepSize: 5
            format: v => v + "%"
        }

        ToggleRow {
            label: "Guides"
            description: "Dashed lines from the cursor, and then from the region, to the screen edges"
            path: "screenshot.guides"
        }

        ToggleRow {
            label: "Animations"
            description: "Animate the window and screen selections (a region follows the mouse as it is drawn)"
            path: "screenshot.animations"
        }
    }
}
