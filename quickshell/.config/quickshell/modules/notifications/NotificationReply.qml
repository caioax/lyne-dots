pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import "../../components/"

// Inline reply field (chat apps that support org.freedesktop.Notifications inline-reply)
QsTextField {
    id: root

    readonly property bool inputFocused: focused
    // Clicking the field gives it focus even while its window has no
    // keyboard; the popup overlay uses this to ask for keyboard focus
    readonly property bool wantsKeyboard: input.focus

    signal submitted(string text)

    function submit() {
        const value = text.trim();
        if (value === "")
            return;
        root.submitted(value);
        text = "";
    }

    compact: true
    placeholder: "Reply"
    rightInset: sendButton.width
    catchEscape: true
    onEscapePressed: input.focus = false
    onAccepted: submit()
    // Clicking another window takes the keyboard away: drop the request
    onFocusedChanged: {
        if (!focused)
            input.focus = false;
    }

    NotificationIconButton {
        id: sendButton

        anchors.right: parent.right
        anchors.rightMargin: Config.padding
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰒊"
        iconColor: root.text.trim() !== "" ? Config.accentColor : Config.subtextColor
        onClicked: root.submit()
    }
}
