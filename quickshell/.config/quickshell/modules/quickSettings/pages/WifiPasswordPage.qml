pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    property string targetSsid: ""
    readonly property bool valid: input.text.length >= 8
    readonly property int controlSize: Config.fontSizeIconSmall * 2

    signal cancelled
    signal connectClicked(string password)

    function submit() {
        if (!valid)
            return;
        root.connectClicked(input.text);
        input.text = "";
    }

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    onVisibleChanged: {
        input.text = "";
        input.showPassword = false;
        if (visible)
            input.forceActiveFocus();
    }

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            Layout.bottomMargin: Config.padding
            icon: "󰌾"
            title: "Password required"
            subtitle: root.targetSsid
            onBackClicked: root.cancelled()
        }

        Card {
            Layout.fillWidth: true
            spacing: Config.spacing + Config.padding

            Text {
                Layout.fillWidth: true
                text: "Enter the password for <b>" + root.targetSsid + "</b>"
                textFormat: Text.StyledText
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                wrapMode: Text.Wrap
            }

            // Password field
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.controlSize
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
                    anchors.leftMargin: Config.spacing + Config.padding
                    anchors.rightMargin: Config.padding
                    spacing: Config.padding

                    TextInput {
                        id: input

                        property bool showPassword: false

                        Layout.fillWidth: true
                        echoMode: showPassword ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                        selectionColor: Config.accentColor
                        selectedTextColor: Config.textReverseColor
                        clip: true
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancelled()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: "Password"
                            font: input.font
                            color: Qt.alpha(Config.subtextColor, 0.6)
                        }
                    }

                    ActionButton {
                        size: root.controlSize - Config.padding * 2
                        icon: input.showPassword ? "󰈉" : "󰈈"
                        iconSize: Config.fontSizeNormal
                        baseColor: "transparent"
                        textColor: Config.subtextColor
                        hoverTextColor: Config.textColor
                        onClicked: input.showPassword = !input.showPassword
                    }
                }
            }

            Text {
                visible: input.text.length > 0 && !root.valid
                text: "At least 8 characters"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.warningColor
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                ActionButton {
                    Layout.fillWidth: true
                    size: root.controlSize
                    icon: "󰜺"
                    text: "Cancel"
                    textColor: Config.subtextColor
                    onClicked: root.cancelled()
                }

                ActionButton {
                    Layout.fillWidth: true
                    size: root.controlSize
                    icon: "󰖩"
                    text: "Connect"
                    opacity: root.valid ? 1 : 0.5
                    baseColor: Config.accentColor
                    hoverColor: root.valid ? Qt.lighter(Config.accentColor, 1.1) : Config.accentColor
                    textColor: Config.textReverseColor
                    onClicked: root.submit()
                }
            }
        }
    }
}
