pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Search field: a QsTextField with the magnifier, a `hint` at the right
// while empty and unfocused (a shortcut), and a clear button while there's
// text. Escape clears the text first; on an empty field it goes on to the
// window (closing it or the dialog)
QsTextField {
    id: root

    property string hint

    radius: Config.radiusLarge
    leftInset: magnifier.width + Config.spacing
    rightInset: clearButton.visible ? clearButton.width + Config.spacing : hintText.visible ? hintText.width + Config.spacing : 0
    catchEscape: text !== ""
    onEscapePressed: text = ""

    // md-magnify
    Text {
        id: magnifier

        anchors.left: parent.left
        anchors.leftMargin: Config.padding * 2
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0349}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeLarge
        color: root.focused ? Config.accentColor : Config.subtextColor
    }

    Text {
        id: hintText

        anchors.right: parent.right
        anchors.rightMargin: Config.padding * 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hint !== "" && root.text === "" && !root.focused
        text: root.hint
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.mutedColor
    }

    // md-close
    Text {
        id: clearButton

        anchors.right: parent.right
        anchors.rightMargin: Config.padding * 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.text !== ""
        text: "\u{f0156}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeLarge
        color: clearMouse.containsMouse ? Config.textColor : Config.subtextColor

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            anchors.margins: -Config.padding
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.text = "";
                root.focusInput();
            }
        }
    }
}
