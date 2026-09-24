pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Add / edit a custom shortcut: a name, a shell command and the keys
Popup {
    id: root

    // Index in keybinds.custom; -1 = new
    property int index: -1
    property string keys: ""
    property bool recording: false

    readonly property var conflicts: KeybindsService.conflicts(keys, "", index)
    readonly property bool valid: commandField.text.trim() !== "" && keys !== ""

    function openFor(customIndex: int) {
        const entry = customIndex >= 0 ? KeybindsService.custom[customIndex] : null;
        index = customIndex;
        nameField.text = entry?.description ?? "";
        commandField.text = entry?.command ?? "";
        keys = entry?.keys ?? "";
        open();
        nameField.forceActiveFocus();
    }

    function save() {
        if (!valid)
            return;
        KeybindsService.saveCustom(index, {
            description: nameField.text.trim(),
            command: commandField.text.trim(),
            keys
        });
        close();
    }

    function stopRecording() {
        if (!recording)
            return;
        recording = false;
        KeybindsService.stopCapture();
    }

    onClosed: stopRecording()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 34)
    modal: true
    // Escape is handled by the page (stops recording first)
    closePolicy: Popup.CloseOnPressOutside
    padding: Config.padding * 3

    Overlay.modal: Rectangle {
        color: Qt.alpha(Config.backgroundColor, 0.6)
    }

    background: Rectangle {
        radius: Config.radiusLarge
        color: Config.surface0Color
        border.width: 1
        border.color: Config.surface1Color
    }

    contentItem: ColumnLayout {
        spacing: Config.spacing + Config.padding

        Text {
            text: root.index >= 0 ? "Edit shortcut" : "New shortcut"
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        Field {
            id: nameField
            label: "Name"
            placeholder: "Open btop"
        }

        Field {
            id: commandField
            label: "Command"
            placeholder: "kitty -e btop"
            onAccepted: root.save()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.padding

            Text {
                text: "Shortcut"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            KeyCombo {
                Layout.fillWidth: true
                keys: root.keys
                emptyText: "Click to record"
                recording: root.recording
                onRecordRequested: {
                    root.recording = true;
                    KeybindsService.startCapture();
                }
                onRecorded: combo => {
                    root.keys = combo;
                    root.stopRecording();
                }
            }

            Text {
                visible: root.conflicts.length > 0
                Layout.fillWidth: true
                text: "Also used by " + root.conflicts.join(", ")
                wrapMode: Text.WordWrap
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.warningColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Config.padding
            spacing: Config.spacing

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                text: "Cancel"
                onClicked: root.close()
            }

            ActionButton {
                icon: "\u{f012c}"
                text: "Save"
                opacity: root.valid ? 1 : 0.4
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: root.save()
            }
        }
    }

    component Field: ColumnLayout {
        id: field

        property string label
        property string placeholder
        property alias text: input.text

        signal accepted

        function forceActiveFocus() {
            input.forceActiveFocus();
        }

        Layout.fillWidth: true
        spacing: Config.padding

        Text {
            text: field.label
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.subtextColor
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
            radius: Config.radius
            color: Config.surface1Color
            border.width: input.activeFocus ? 1 : 0
            border.color: Qt.alpha(Config.accentColor, 0.6)

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Config.padding * 2
                anchors.rightMargin: Config.padding * 2
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.textColor
                selectionColor: Qt.alpha(Config.accentColor, 0.4)
                selectByMouse: true
                onAccepted: field.accepted()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: field.placeholder
                    font: input.font
                    color: Config.subtextColor
                }
            }
        }
    }
}
