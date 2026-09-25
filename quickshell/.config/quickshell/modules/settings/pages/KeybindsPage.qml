pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Hyprland keybinds: change the keys of the binds in hypr/conf/keybinds.lua,
// disable them, and add custom shortcuts that run a command
ColumnLayout {
    id: root

    property string query: ""
    // Bind id (or "custom:N") whose keys are being recorded
    property string recordingId: ""

    readonly property bool hasChanges: KeybindsService.overrides.length > 0

    function matches(description: string, keys: string): bool {
        if (query === "")
            return true;
        const q = query.toLowerCase();
        return description.toLowerCase().includes(q) || keys.toLowerCase().includes(q);
    }

    function startRecording(id: string) {
        recordingId = id;
        KeybindsService.startCapture();
    }

    function stopRecording() {
        if (recordingId === "")
            return;
        recordingId = "";
        KeybindsService.stopCapture();
    }

    function recorded(id: string, keys: string) {
        if (id.startsWith("custom:")) {
            const index = parseInt(id.slice(7));
            const entry = KeybindsService.custom[index];
            KeybindsService.saveCustom(index, {
                description: entry.description,
                command: entry.command,
                keys
            });
        } else {
            KeybindsService.setKeys(id, keys);
        }
        stopRecording();
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (dialog.recording) {
            dialog.stopRecording();
            return true;
        }
        if (dialog.opened) {
            dialog.close();
            return true;
        }
        if (recordingId !== "") {
            stopRecording();
            return true;
        }
        if (menu.opened) {
            menu.close();
            return true;
        }
        if (search.text !== "") {
            search.text = "";
            return true;
        }
        return false;
    }

    Component.onCompleted: KeybindsService.refreshExternal()
    // Never leave Hyprland in the capture submap
    Component.onDestruction: stopRecording()

    spacing: Config.spacing * 3

    Connections {
        target: KeybindsService

        // The service's safety timeout ended the capture
        function onCapturingChanged() {
            if (!KeybindsService.capturing)
                root.recordingId = "";
        }
    }

    CustomBindDialog {
        id: dialog
    }

    ContextMenu {
        id: menu

        // { id, keys, defaultKeys, changed } for binds, { custom: index } for custom
        readonly property bool isCustom: target?.custom !== undefined

        items: {
            if (!target)
                return [];
            if (isCustom)
                return [
                    {
                        label: "Change shortcut",
                        icon: "\u{f030c}",
                        action: "record"
                    },
                    {
                        label: "Edit",
                        icon: "\u{f03eb}",
                        action: "edit"
                    },
                    {
                        label: "Delete",
                        icon: "\u{f09e7}",
                        action: "delete",
                        danger: true
                    }
                ];
            const list = [
                {
                    label: "Change shortcut",
                    icon: "\u{f030c}",
                    action: "record"
                }
            ];
            if (target.keys !== "")
                list.push({
                    label: "Disable",
                    icon: "\u{f0156}",
                    action: "disable"
                });
            if (target.changed)
                list.push({
                    label: "Reset to " + (target.defaultKeys || "none"),
                    icon: "\u{f099b}",
                    action: "reset"
                });
            return list;
        }

        onTriggered: (action, target) => {
            switch (action) {
            case "record":
                root.startRecording(isCustom ? "custom:" + target.custom : target.id);
                break;
            case "disable":
                KeybindsService.setKeys(target.id, "");
                break;
            case "reset":
                KeybindsService.reset(target.id);
                break;
            case "edit":
                dialog.openFor(target.custom);
                break;
            case "delete":
                KeybindsService.removeCustom(target.custom);
                break;
            }
        }
    }

    // ================= TOOLBAR =================
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.fontSizeIconSmall * 2
            radius: Config.radiusLarge
            color: Config.cardColor
            border.width: search.activeFocus ? 1 : 0
            border.color: Qt.alpha(Config.accentColor, 0.6)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.padding * 2
                anchors.rightMargin: Config.padding * 2
                spacing: Config.spacing

                // md-magnify
                Text {
                    text: "\u{f0349}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.subtextColor
                }

                TextInput {
                    id: search

                    Layout.fillWidth: true
                    clip: true
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.textColor
                    selectionColor: Qt.alpha(Config.accentColor, 0.4)
                    onTextChanged: root.query = text

                    Text {
                        visible: search.text === ""
                        text: "Search actions or keys"
                        font: search.font
                        color: Config.subtextColor
                    }
                }
            }
        }

        // md-restore
        ActionButton {
            visible: root.hasChanges
            size: Config.fontSizeIconSmall * 2
            icon: "\u{f099b}"
            text: "Reset all"
            baseColor: Config.surface0Color
            onClicked: KeybindsService.resetAll()
        }

        // md-plus
        ActionButton {
            size: Config.fontSizeIconSmall * 2
            icon: "\u{f0415}"
            text: "Add shortcut"
            baseColor: Config.accentColor
            hoverColor: Qt.lighter(Config.accentColor, 1.1)
            textColor: Config.textReverseColor
            onClicked: dialog.openFor(-1)
        }
    }

    // Hyprland hasn't exported its binds (e.g. conf/keybinds.lua failed)
    SettingsGroup {
        visible: KeybindsService.catalog.length === 0

        SettingRow {
            label: "No keybinds found"
            description: "Hyprland writes them to " + KeybindsService.catalogPath + " when it loads hypr/conf/keybinds.lua. Check hyprctl configerrors"
        }
    }

    // ================= CUSTOM =================
    SettingsGroup {
        title: "Custom"
        visible: KeybindsService.custom.length > 0

        Repeater {
            model: KeybindsService.custom

            BindRow {
                required property var modelData
                required property int index

                visible: root.matches(modelData.description + " " + modelData.command, modelData.keys)
                label: modelData.description || modelData.command
                command: modelData.command
                keys: modelData.keys
                recordId: "custom:" + index
                conflicts: KeybindsService.conflicts(modelData.keys, "", index)
                menuTarget: ({
                        custom: index
                    })
            }
        }
    }

    // ================= CATALOG =================
    Repeater {
        model: KeybindsService.groups

        SettingsGroup {
            id: group

            required property string modelData
            readonly property var groupBinds: KeybindsService.binds.filter(b => b.group === modelData && root.matches(b.description, b.keys))

            title: modelData
            visible: groupBinds.length > 0

            Repeater {
                model: group.groupBinds

                BindRow {
                    required property var modelData

                    label: modelData.description
                    keys: modelData.keys
                    defaultKeys: modelData.defaultKeys
                    changed: modelData.changed
                    recordId: modelData.id
                    conflicts: KeybindsService.conflicts(modelData.keys, modelData.id, -1)
                    menuTarget: modelData
                }
            }
        }
    }

    component BindRow: SettingRow {
        id: row

        property string command
        property string keys
        property string defaultKeys
        property bool changed: false
        property string recordId
        property var conflicts: []
        property var menuTarget

        resettable: false
        descriptionColor: conflicts.length > 0 ? Config.warningColor : Config.subtextColor
        description: {
            if (conflicts.length > 0)
                return "Also used by " + conflicts.join(", ");
            if (command !== "")
                return command;
            if (changed)
                return "Default: " + (defaultKeys || "none");
            return "";
        }

        KeyCombo {
            keys: row.keys
            baseColor: row.controlColor
            recording: root.recordingId === row.recordId
            onRecordRequested: root.startRecording(row.recordId)
            onRecorded: combo => root.recorded(row.recordId, combo)
        }

        // md-dots_vertical
        ActionButton {
            size: Config.fontSizeIconSmall + Config.padding * 3
            icon: "\u{f01d9}"
            baseColor: row.controlColor
            onClicked: menu.openAt(this, row.menuTarget)
        }
    }
}
