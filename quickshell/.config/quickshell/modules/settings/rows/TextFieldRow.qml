pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Text setting. Saved on Enter or when the field loses focus (not on every
// keystroke, so services reacting to it don't run for partial input); Escape
// restores the saved value
SettingRow {
    id: root

    property string text: path !== "" ? StateService.get(path, StateService.getDefault(path, "")) : ""
    property string placeholder
    property real fieldWidth: Config.fontSizeNormal * 16

    signal submitted(string value)

    function _submit() {
        const value = field.text.trim();
        if (value === root.text)
            return;
        if (root.path !== "")
            StateService.set(root.path, value);
        root.submitted(value);
    }

    // Follow external changes while not editing
    onTextChanged: {
        if (!field.focused)
            field.text = text;
    }

    QsTextField {
        id: field

        Layout.preferredWidth: root.fieldWidth
        color: root.controlColor
        text: root.text
        placeholder: root.placeholder
        // Escape cancels the edit instead of closing the window
        catchEscape: true
        onEditingFinished: root._submit()
        onEscapePressed: {
            text = root.text;
            field.input.focus = false;
        }
    }
}
