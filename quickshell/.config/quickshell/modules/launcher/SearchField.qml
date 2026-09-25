pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// Pill search input: icon, optional mode chip, text field, result count and a
// clear button.
// Keys the field doesn't use itself are passed on through `keyPressed`
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search apps…"
    property string icon: "\u{f0349}"
    // Shown as a chip before the text when not empty
    property string chip: ""
    property int count: 0
    readonly property bool focused: input.activeFocus

    signal keyPressed(var event)

    function focusInput() {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    implicitHeight: Config.fontSizeLarge + Config.padding * 5
    radius: Config.radiusLarge
    color: Config.cardColor
    border.width: 1
    border.color: root.focused ? Qt.alpha(Config.accentColor, 0.6) : Config.surface1Color

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding * 3
        anchors.rightMargin: Config.padding * 2
        spacing: Config.spacing

        Text {
            text: root.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: root.focused ? Config.accentColor : Config.subtextColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }
        }

        Rectangle {
            visible: root.chip !== ""
            implicitWidth: chipText.implicitWidth + Config.padding * 3
            implicitHeight: chipText.implicitHeight + Config.padding
            radius: height / 2
            color: Qt.alpha(Config.accentColor, 0.15)

            Text {
                id: chipText
                anchors.centerIn: parent
                text: root.chip
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.accentColor
            }
        }

        TextField {
            id: input

            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Config.textColor
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            placeholderText: root.placeholder
            placeholderTextColor: Config.mutedColor
            background: null

            Keys.onPressed: event => root.keyPressed(event)
        }

        Text {
            visible: root.count > 0
            text: root.count
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.mutedColor
        }

        // md-close-circle
        Text {
            visible: input.text !== ""
            text: "\u{f0159}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: clearMouse.containsMouse ? Config.textColor : Config.subtextColor

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -Config.padding
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
        }
    }
}
