pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Text field of the shell: a box that shows an accent border while focused,
// with a placeholder while empty. `input` is the TextInput, for key handlers;
// `compact` is the small one of inline editors (the hex of a color). The
// insets leave room for icons drawn over the box (QsSearchField). Escape
// goes on to the window (closing it or a dialog) unless `catchEscape`: then
// the field keeps it and emits escapePressed
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property alias maximumLength: input.maximumLength
    property alias input: input
    property bool compact: false
    property color textColor: Config.textColor
    property real leftInset: 0
    property real rightInset: 0
    property bool catchEscape: false
    readonly property bool focused: input.activeFocus

    signal accepted
    signal editingFinished
    signal textEdited
    signal escapePressed

    function focusInput(): void {
        input.forceActiveFocus();
    }

    implicitWidth: Config.fontSizeNormal * 16
    implicitHeight: Config.fontSizeIconSmall + Config.padding * (compact ? 2 : 3)
    radius: Config.radius
    color: Config.surface1Color
    border.width: input.activeFocus ? 1 : 0
    border.color: Qt.alpha(Config.accentColor, 0.6)

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Config.padding * 2 + root.leftInset
        anchors.rightMargin: Config.padding * 2 + root.rightInset
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        font.family: Config.font
        font.pixelSize: root.compact ? Config.fontSizeSmall : Config.fontSizeNormal
        color: root.textColor
        selectionColor: Qt.alpha(Config.accentColor, 0.4)
        selectByMouse: true
        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()
        onTextEdited: root.textEdited()
        // Before the window's shortcuts see it
        Keys.onShortcutOverride: event => event.accepted = event.key === Qt.Key_Escape && root.catchEscape
        Keys.onEscapePressed: event => {
            event.accepted = root.catchEscape;
            if (root.catchEscape)
                root.escapePressed();
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            elide: Text.ElideRight
            visible: input.text === "" && input.preeditText === ""
            text: root.placeholder
            font: input.font
            color: Config.subtextColor
        }
    }

    // A click anywhere in the box focuses the field; the TextInput handles
    // the clicks after that
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        enabled: !input.activeFocus
        onClicked: input.forceActiveFocus()
    }
}
