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
        title: I18n.tr("History")

        ToggleRow {
            label: I18n.tr("Save images")
            description: I18n.tr("Keep copied images and screenshots too; off stores text only")
            path: "clipboard.storeImages"
        }

        StepperRow {
            label: I18n.tr("Entries kept")
            description: I18n.tr("The oldest are dropped as new ones come in")
            path: "clipboard.maxItems"
            values: [100, 250, 500, 750, 1000, 2000]
        }
    }

    SettingsGroup {
        title: I18n.tr("Data")

        SettingRow {
            id: openRow

            label: I18n.tr("Clipboard history")
            description: {
                if (ClipboardService.missing)
                    return I18n.tr("cliphist isn't installed");
                if (!ClipboardService.loaded)
                    return I18n.tr("Reading…");
                const count = ClipboardService.entries.length;
                return I18n.trn("%n entry · opens with Super + V", "%n entries · opens with Super + V", count);
            }

            ActionButton {
                icon: "\u{f014d}"
                text: I18n.tr("Open")
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

            label: I18n.tr("Clear history")
            description: root.confirmingClear ? I18n.tr("Click again to delete every entry") : I18n.tr("Deletes everything saved, text and images")
            enabled: ClipboardService.entries.length > 0

            ActionButton {
                icon: "\u{f01b4}"
                text: root.confirmingClear ? I18n.tr("Delete all") : I18n.tr("Clear")
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
