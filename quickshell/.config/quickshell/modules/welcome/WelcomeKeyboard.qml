pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"
import "../settings/pages/"
import "../../components/"

// Keyboard step: the layout (the system's, when lyne-dots still has its
// default) with a field to try it, and the navigation keys preset
ColumnLayout {
    id: root

    readonly property var layouts: KeyboardService.layouts
    readonly property var first: layouts[0] ?? null

    // Called by WelcomeWindow before Escape closes the window
    function handleEscape(): bool {
        if (picker.opened) {
            picker.close();
            return true;
        }
        return false;
    }

    Component.onCompleted: WelcomeService.suggestKeyboard()

    spacing: Config.spacing * 3

    XkbPicker {
        id: picker

        title: I18n.tr("Keyboard layout")
        placeholder: I18n.tr("Search layouts, languages and variants")
        items: KeyboardService.allEntries.map(e => ({
                    key: e.layout + "(" + e.variant + ")",
                    label: e.description,
                    detail: e.variant ? e.layout + " · " + e.variant : e.layout,
                    entry: e
                }))
        selected: root.first ? [root.first.layout + "(" + root.first.variant + ")"] : []
        onPicked: item => KeyboardService.replaceLayout(0, item.entry)
    }

    // md-keyboard
    WelcomeHeader {
        icon: "\u{f030c}"
        title: I18n.tr("Keyboard")
        description: I18n.tr("Your layout, and the keys that move you between windows and workspaces.")
    }

    SettingsGroup {
        title: I18n.tr("Layout")

        SettingRow {
            id: layoutRow

            label: root.first ? KeyboardService.describe(root.first) : I18n.tr("Loading layouts…")
            description: {
                const others = root.layouts.slice(1).map(l => KeyboardService.describe(l));
                if (others.length > 0)
                    return I18n.tr("Also %1. More layouts and key options in Settings › %2", others.join(", "), I18n.translate("Keyboard"));
                if (WelcomeService.keyboardFromSystem)
                    return I18n.tr("Taken from your system settings. More layouts and key options in Settings › %1", I18n.translate("Keyboard"));
                return I18n.tr("More layouts and key options in Settings › %1", I18n.translate("Keyboard"));
            }

            ActionButton {
                enabled: KeyboardService.ready
                text: I18n.tr("Change")
                baseColor: layoutRow.controlColor
                onClicked: picker.openWith("")
            }
        }

        SettingRow {
            id: tryRow

            label: I18n.tr("Try it")
            description: I18n.tr("Type a few keys to check the layout")

            QsTextField {
                color: tryRow.controlColor
                placeholder: "ç ã é ñ ß ; / ?"
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Navigation")

        NavKeysPicker {}
    }
}
