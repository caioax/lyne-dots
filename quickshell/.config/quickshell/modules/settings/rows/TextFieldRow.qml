pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

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
        const value = input.text.trim();
        if (value === root.text)
            return;
        if (root.path !== "")
            StateService.set(root.path, value);
        root.submitted(value);
    }

    // Follow external changes while not editing
    onTextChanged: {
        if (!input.activeFocus)
            input.text = text;
    }

    Rectangle {
        Layout.preferredWidth: root.fieldWidth
        implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
        radius: Config.radius
        color: root.controlColor
        border.width: input.activeFocus ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Config.padding * 2
            anchors.rightMargin: Config.padding * 2
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: root.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.textColor
            selectionColor: Qt.alpha(Config.accentColor, 0.4)
            selectByMouse: true

            onEditingFinished: root._submit()
            // Escape cancels the edit instead of closing the window
            Keys.onShortcutOverride: event => event.accepted = event.key === Qt.Key_Escape
            Keys.onEscapePressed: event => {
                text = root.text;
                focus = false;
                event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: root.placeholder
                font: input.font
                color: Config.subtextColor
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            // Only focuses; the TextInput handles the clicks after that
            enabled: !input.activeFocus
            onClicked: input.forceActiveFocus()
        }
    }
}
