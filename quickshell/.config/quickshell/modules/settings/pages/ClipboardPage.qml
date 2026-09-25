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
    // Clear asks for a second click
    property bool confirmingClear: false

    spacing: Config.spacing * 3

    // For the entry count
    Component.onCompleted: ClipboardService.refresh()

    SettingsGroup {
        title: "History"

        ToggleRow {
            label: "Save images"
            description: "Keep copied images and screenshots too; off stores text only"
            path: "clipboard.storeImages"
        }

        StepperRow {
            label: "Entries kept"
            description: "The oldest are dropped as new ones come in"
            path: "clipboard.maxItems"
            values: [100, 250, 500, 750, 1000, 2000]
        }
    }

    SettingsGroup {
        title: "Data"

        SettingRow {
            id: openRow

            label: "Clipboard history"
            description: {
                if (ClipboardService.missing)
                    return "cliphist isn't installed";
                if (!ClipboardService.loaded)
                    return "Reading…";
                const count = ClipboardService.entries.length;
                return (count === 1 ? "1 entry" : count + " entries") + " · opens with Super + V";
            }

            ActionButton {
                icon: "\u{f014d}"
                text: "Open"
                size: root.buttonSize
                baseColor: openRow.controlColor
                onClicked: {
                    SettingsService.close();
                    LauncherService.showMode("clipboard");
                }
            }
        }

        SettingRow {
            id: clearRow

            label: "Clear history"
            description: root.confirmingClear ? "Click again to delete every entry" : "Deletes everything saved, text and images"
            enabled: ClipboardService.entries.length > 0

            ActionButton {
                icon: "\u{f01b4}"
                text: root.confirmingClear ? "Delete all" : "Clear"
                size: root.buttonSize
                baseColor: root.confirmingClear ? Config.errorColor : clearRow.controlColor
                hoverColor: root.confirmingClear ? Qt.lighter(Config.errorColor, 1.1) : Config.surface3Color
                textColor: root.confirmingClear ? Config.textReverseColor : Config.textColor
                onClicked: {
                    if (!root.confirmingClear) {
                        root.confirmingClear = true;
                        confirmTimer.restart();
                        return;
                    }
                    root.confirmingClear = false;
                    ClipboardService.wipe();
                }
            }
        }
    }

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: root.confirmingClear = false
    }
}
