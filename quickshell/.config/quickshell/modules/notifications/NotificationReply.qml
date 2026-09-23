pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Inline reply field (chat apps that support org.freedesktop.Notifications inline-reply)
Rectangle {
    id: root

    property string placeholder: "Reply"
    readonly property bool inputFocused: input.activeFocus

    signal submitted(string text)

    function submit() {
        const text = input.text.trim();
        if (text === "")
            return;
        root.submitted(text);
        input.text = "";
    }

    implicitHeight: Config.fontSizeSmall + Config.padding * 3
    radius: Config.radius
    color: Config.surface1Color
    border.width: 1
    border.color: input.activeFocus ? Config.accentColor : "transparent"

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding * 2
        anchors.rightMargin: Config.padding
        spacing: Config.padding

        TextInput {
            id: input
            Layout.fillWidth: true
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.textColor
            selectionColor: Config.accentColor
            selectedTextColor: Config.textReverseColor
            clip: true
            onAccepted: root.submit()
            Keys.onEscapePressed: focus = false

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: root.placeholder
                font: input.font
                color: Config.subtextColor
                opacity: 0.6
            }
        }

        NotificationIconButton {
            icon: "󰒊"
            iconColor: input.text.trim() !== "" ? Config.accentColor : Config.subtextColor
            onClicked: root.submit()
        }
    }
}
