pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import "../../../components/"

// The shell language (general.language): a button with the current choice
// that opens the list of languages, Automatic first (with the one the
// system gives) and each translation by its own name, partial ones with
// their translated share
SettingRow {
    id: root

    path: "general.language"

    // md-translate
    ActionButton {
        id: button

        icon: "\u{f05ca}"
        text: I18n.setting === "auto" ? I18n.tr("Automatic (%1)", I18n.systemLanguageName) : I18n.languageName
        baseColor: root.controlColor
        onClicked: menu.openAt(button, null)
    }

    ContextMenu {
        id: menu

        items: I18n.languageOptions.map(o => ({
                    label: o.label,
                    detail: o.detail,
                    action: o.value,
                    checked: o.value === I18n.setting
                }))
        onTriggered: action => StateService.set("general.language", action)
    }
}
