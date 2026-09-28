pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Add / edit a special workspace: the app (a preset or any command), its
// badge (name, icon, color) and the toggle / move shortcuts
Popup {
    id: root

    // Index in specials.list; -1 = new
    property int index: -1
    readonly property var entry: index >= 0 ? SpecialsService.list[index] ?? null : null
    readonly property string specialId: entry?.id ?? ""

    property string icon: "\u{f0018}"
    property string colorName: "accent"
    property string keys: ""
    property string moveKeys: ""
    // "" | "keys" | "moveKeys"
    property string recording: ""

    readonly property var preset: SpecialsService.presetFor(commandField.text.trim())
    readonly property string binary: SpecialsService.binaryOf(commandField.text)
    readonly property bool missing: SpecialsService.isMissing(commandField.text)
    readonly property var keyConflicts: KeybindsService.conflicts(keys, "special-" + specialId, -1)
    readonly property var moveConflicts: KeybindsService.conflicts(moveKeys, "move-to-" + specialId, -1)
    readonly property bool valid: nameField.text.trim() !== ""

    function openFor(specialIndex: int) {
        index = specialIndex;
        const item = entry;
        nameField.text = item?.name ?? "";
        commandField.text = item?.command ?? "";
        classField.text = item?.["class"] ?? "";
        icon = item?.icon ?? "\u{f0018}";
        colorName = item?.color ?? "accent";
        keys = item ? SpecialsService.keysOf(item, "special") : "";
        moveKeys = item ? SpecialsService.keysOf(item, "move-to") : "";
        open();
        nameField.forceActiveFocus();
    }

    function applyPreset(p) {
        // Keep a name the user typed; replace an empty or preset one
        const name = nameField.text.trim();
        if (name === "" || SpecialsService.presets.some(x => x.name === name))
            nameField.text = p.name;
        commandField.text = p.command;
        classField.text = p.cls;
        icon = p.icon;
    }

    function save() {
        if (!valid)
            return;
        SpecialsService.save(index, {
            name: nameField.text.trim(),
            icon,
            color: colorName,
            command: commandField.text.trim(),
            class: classField.text.trim(),
            keys,
            moveKeys
        });
        close();
    }

    function startRecording(which: string) {
        stopRecording();
        recording = which;
        KeybindsService.startCapture();
    }

    function stopRecording() {
        if (recording === "")
            return;
        recording = "";
        KeybindsService.stopCapture();
    }

    onClosed: stopRecording()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 38)
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

    // The window checks the typed command a moment after typing stops
    Timer {
        id: checkDebounce
        interval: 400
        onTriggered: SpecialsService.checkInstalled(commandField.text)
    }

    contentItem: ColumnLayout {
        spacing: Config.spacing + Config.padding

        Text {
            text: root.index >= 0 ? "Edit special workspace" : "New special workspace"
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        // ================= APP =================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.padding

            FieldLabel {
                text: "App"
            }

            Flow {
                Layout.fillWidth: true
                spacing: Config.padding

                Repeater {
                    model: SpecialsService.presets

                    Chip {
                        required property var modelData

                        icon: modelData.icon
                        text: modelData.label
                        selected: root.preset?.key === modelData.key
                        onClicked: root.applyPreset(modelData)
                    }
                }
            }
        }

        Field {
            id: commandField
            label: "Command"
            placeholder: "Opened when the workspace is shown empty (none for a scratchpad)"
            onTextChanged: checkDebounce.restart()
            onAccepted: root.save()
        }

        Text {
            visible: root.missing
            Layout.fillWidth: true
            Layout.topMargin: -Config.padding
            text: root.binary + " isn't installed" + (root.preset?.pkg ? " (package " + root.preset.pkg + ")" : "")
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.warningColor
        }

        Field {
            id: classField
            label: "Window class (optional)"
            placeholder: "Regex; keeps the app's windows here when reopened from the tray"
            onAccepted: root.save()
        }

        // ================= BADGE =================
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing * 2

            Field {
                id: nameField
                label: "Name"
                placeholder: "WhatsApp"
                onAccepted: root.save()
            }

            ColumnLayout {
                spacing: Config.padding

                FieldLabel {
                    text: "Color"
                }

                RowLayout {
                    Layout.preferredHeight: Config.fontSizeIconSmall + Config.padding * 3
                    spacing: Config.padding

                    Repeater {
                        model: SpecialsService.colorNames

                        Rectangle {
                            id: dot

                            required property string modelData
                            readonly property bool selected: root.colorName === modelData

                            implicitWidth: Config.fontSizeIconSmall + Config.padding
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: SpecialsService.colorFor(modelData)
                            border.width: selected ? 2 : 0
                            border.color: Config.textColor
                            scale: dotMouse.containsMouse && !selected ? 1.1 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            MouseArea {
                                id: dotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.colorName = dot.modelData
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.padding

            FieldLabel {
                text: "Icon"
            }

            Flow {
                Layout.fillWidth: true
                spacing: Config.padding

                Repeater {
                    model: SpecialsService.icons

                    Rectangle {
                        id: iconTile

                        required property string modelData
                        readonly property bool selected: root.icon === modelData
                        readonly property color tint: SpecialsService.colorFor(root.colorName)

                        implicitWidth: Config.fontSizeIconSmall + Config.padding * 3
                        implicitHeight: implicitWidth
                        radius: Config.radius
                        color: selected ? Qt.alpha(tint, 0.2) : iconMouse.containsMouse ? Config.surface2Color : Config.surface1Color

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: iconTile.modelData
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconSmall
                            color: iconTile.selected ? iconTile.tint : Config.subtextColor
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.icon = iconTile.modelData
                        }
                    }
                }
            }
        }

        // ================= SHORTCUTS =================
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing * 2

            ShortcutField {
                label: "Show / hide"
                which: "keys"
                keys: root.keys
                conflicts: root.keyConflicts
            }

            ShortcutField {
                label: "Move window here"
                which: "moveKeys"
                keys: root.moveKeys
                conflicts: root.moveConflicts
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

    component Chip: Rectangle {
        id: chip

        property string icon
        property string text
        property bool selected: false

        signal clicked

        implicitWidth: chipRow.implicitWidth + Config.padding * 3
        implicitHeight: Config.fontSizeIconSmall + Config.padding * 2
        radius: height / 2
        color: selected ? Config.accentColor : chipMouse.containsMouse ? Config.surface2Color : Config.surface1Color

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Config.padding

            Text {
                text: chip.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: chip.selected ? Config.textReverseColor : Config.subtextColor
            }

            Text {
                text: chip.text
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: chip.selected ? Config.textReverseColor : Config.textColor
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component ShortcutField: ColumnLayout {
        id: shortcut

        property string label
        property string which
        property string keys
        property var conflicts: []

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Config.padding

        FieldLabel {
            text: shortcut.label
        }

        KeyCombo {
            Layout.fillWidth: true
            keys: shortcut.keys
            emptyText: "Click to record"
            recording: root.recording === shortcut.which
            onRecordRequested: root.startRecording(shortcut.which)
            onRecorded: combo => {
                root[shortcut.which] = combo;
                root.stopRecording();
            }
        }

        Text {
            visible: shortcut.conflicts.length > 0
            Layout.fillWidth: true
            text: "Also used by " + shortcut.conflicts.join(", ")
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.warningColor
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

        FieldLabel {
            text: field.label
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
                    width: parent.width
                    elide: Text.ElideRight
                    visible: input.text === ""
                    text: field.placeholder
                    font: input.font
                    color: Config.subtextColor
                }
            }
        }
    }
}
