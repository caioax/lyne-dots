pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Add / edit an app started at login: its name, command, a delay and the
// workspace it opens on
Popup {
    id: root

    // Index in autostart.apps; -1 = new
    property int index: -1
    readonly property var entry: index >= 0 ? AutostartService.apps[index] ?? null : null

    readonly property string binary: AutostartService.binaryOf(commandField.text)
    readonly property bool missing: AutostartService.isMissing(commandField.text)
    readonly property int delay: Math.max(0, parseInt(delayField.text) || 0)
    readonly property bool valid: commandField.text.trim() !== ""

    function openFor(appIndex: int) {
        index = appIndex;
        nameField.text = entry?.name ?? "";
        commandField.text = entry?.command ?? "";
        delayField.text = entry && entry.delay > 0 ? String(entry.delay) : "";
        workspaceField.text = entry?.workspace ?? "";
        open();
        nameField.forceActiveFocus();
    }

    // A command typed in the app picker
    function openNew(command: string) {
        openFor(-1);
        commandField.text = command;
        nameField.text = AutostartService.nameFor(command);
        nameField.forceActiveFocus();
    }

    function save() {
        if (!valid)
            return;
        const command = commandField.text.trim();
        const fields = {
            name: nameField.text.trim() || AutostartService.nameFor(command),
            command,
            delay: root.delay,
            workspace: workspaceField.text.trim()
        };
        // Another command: no longer the .desktop entry it came from
        if (entry && entry.command !== command)
            fields.desktop = "";
        AutostartService.save(index, fields);
        close();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 34)
    modal: true
    // Escape is handled by the page
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

    // Checks the typed command a moment after typing stops
    Timer {
        id: checkDebounce
        interval: 400
        onTriggered: AutostartService.checkInstalled(commandField.text)
    }

    contentItem: ColumnLayout {
        spacing: Config.spacing + Config.padding

        Text {
            text: root.index >= 0 ? "Edit app" : "New app"
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        Field {
            id: nameField
            label: "Name"
            placeholder: "Shown in this list"
            onAccepted: root.save()
        }

        Field {
            id: commandField
            label: "Command"
            placeholder: "Run by the shell, like discord --start-minimized"
            onTextChanged: checkDebounce.restart()
            onAccepted: root.save()
        }

        Text {
            visible: root.missing
            Layout.fillWidth: true
            Layout.topMargin: -Config.padding
            text: root.binary + " isn't installed"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.warningColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing * 2

            Field {
                id: delayField
                Layout.preferredWidth: 1
                label: "Delay (seconds)"
                placeholder: "None"
                validator: IntValidator {
                    bottom: 0
                    top: 600
                }
                onAccepted: root.save()
            }

            Field {
                id: workspaceField
                Layout.preferredWidth: 2
                label: "Workspace"
                placeholder: "Where you are, or like 3 silent"
                onAccepted: root.save()
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

    component FieldLabel: Text {
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: Config.subtextColor
    }

    component Field: ColumnLayout {
        id: field

        property string label
        property string placeholder
        property alias text: box.text
        property alias validator: box.validator

        signal accepted

        function forceActiveFocus() {
            box.focusInput();
        }

        Layout.fillWidth: true
        spacing: Config.padding

        FieldLabel {
            text: field.label
        }

        QsTextField {
            id: box

            Layout.fillWidth: true
            placeholder: field.placeholder
            onAccepted: field.accepted()
        }
    }
}
