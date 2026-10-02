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

        title: "Keyboard layout"
        placeholder: "Search layouts, languages and variants"
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
        title: "Keyboard"
        description: "Your layout, and the keys that move you between windows and workspaces."
    }

    SettingsGroup {
        title: "Layout"

        SettingRow {
            id: layoutRow

            label: root.first ? KeyboardService.describe(root.first) : "Loading layouts…"
            description: {
                const others = root.layouts.slice(1).map(l => KeyboardService.describe(l));
                if (others.length > 0)
                    return "Also " + others.join(", ") + ". More layouts and key options in Settings › Keyboard";
                if (WelcomeService.keyboardFromSystem)
                    return "Taken from your system settings. More layouts and key options in Settings › Keyboard";
                return "More layouts and key options in Settings › Keyboard";
            }

            ActionButton {
                enabled: KeyboardService.ready
                text: "Change"
                baseColor: layoutRow.controlColor
                onClicked: picker.openWith("")
            }
        }

        SettingRow {
            id: tryRow

            label: "Try it"
            description: "Type a few keys to check the layout"

            Rectangle {
                implicitWidth: Config.fontSizeNormal * 16
                implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                radius: Config.radius
                color: tryRow.controlColor
                border.width: tryField.activeFocus ? 1 : 0
                border.color: Qt.alpha(Config.accentColor, 0.6)

                TextInput {
                    id: tryField

                    anchors.fill: parent
                    anchors.leftMargin: Config.padding * 1.5
                    anchors.rightMargin: Config.padding * 1.5
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.textColor
                    selectionColor: Qt.alpha(Config.accentColor, 0.4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tryField.text === ""
                        text: "ç ã é ñ ß ; / ?"
                        font: tryField.font
                        color: Config.mutedColor
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Navigation"

        NavKeysPicker {}
    }
}
