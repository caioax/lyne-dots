pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Special workspaces: hidden workspaces toggled with a shortcut, each with
// the app opened when it's shown empty (WhatsApp, music, a scratchpad...)
ColumnLayout {
    id: root

    // "<index>:keys" / "<index>:moveKeys" while recording from a card
    property string recordingId: ""

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

    function recorded(index: int, field: string, keys: string) {
        SpecialsService.save(index, {
            [field]: keys
        });
        stopRecording();
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (dialog.recording !== "") {
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
        return false;
    }

    Component.onCompleted: {
        SpecialsService.checkInstalled("");
        KeybindsService.refreshExternal();
    }
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

    SpecialDialog {
        id: dialog
    }

    ContextMenu {
        id: menu

        // { index, item }
        items: {
            if (!target)
                return [];
            const list = [
                {
                    label: "Edit",
                    icon: "\u{f03eb}",
                    action: "edit"
                },
                {
                    label: "Change move shortcut",
                    icon: "\u{f030c}",
                    action: "record-move"
                }
            ];
            if (target.item.command !== "")
                list.push({
                    label: "Start in the background",
                    icon: "\u{f040a}",
                    action: "start"
                });
            if (target.index > 0)
                list.push({
                    label: "Move up",
                    icon: "\u{f005d}",
                    action: "up"
                });
            if (target.index < SpecialsService.list.length - 1)
                list.push({
                    label: "Move down",
                    icon: "\u{f0045}",
                    action: "down"
                });
            list.push({
                label: "Delete",
                icon: "\u{f09e7}",
                action: "delete",
                danger: true
            });
            return list;
        }

        onTriggered: (action, target) => {
            switch (action) {
            case "edit":
                dialog.openFor(target.index);
                break;
            case "record-move":
                root.startRecording(target.index + ":moveKeys");
                break;
            case "start":
                SpecialsService.startHidden(target.item.id);
                break;
            case "up":
                SpecialsService.move(target.index, -1);
                break;
            case "down":
                SpecialsService.move(target.index, 1);
                break;
            case "delete":
                SpecialsService.remove(target.index);
                break;
            }
        }
    }

    // ================= TOOLBAR =================
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Text {
            Layout.fillWidth: true
            text: "Each one shows over the current workspace. Its app opens the first time it's shown"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        // md-plus
        ActionButton {
            size: Config.fontSizeIconSmall * 2
            icon: "\u{f0415}"
            text: "Add special"
            baseColor: Config.accentColor
            hoverColor: Qt.lighter(Config.accentColor, 1.1)
            textColor: Config.textReverseColor
            onClicked: dialog.openFor(-1)
        }
    }

    SettingsGroup {
        visible: SpecialsService.list.length === 0

        SettingRow {
            label: "No special workspaces"
            description: "Add one for an app you want a shortcut away, like WhatsApp or a music player"
        }
    }

    // ================= SPECIALS =================
    Repeater {
        model: SpecialsService.list

        SettingsGroup {
            id: group

            required property var modelData
            required property int index

            readonly property string toggleKeys: SpecialsService.keysOf(modelData, "special")
            readonly property string moveKeys: SpecialsService.keysOf(modelData, "move-to")
            readonly property var conflicts: KeybindsService.conflicts(toggleKeys, "special-" + modelData.id, -1)
            readonly property bool missing: SpecialsService.isMissing(modelData.command)
            readonly property var preset: SpecialsService.presetFor(modelData.command)

            SettingRow {
                id: row

                resettable: false
                label: group.modelData.name
                descriptionColor: group.missing || group.conflicts.length > 0 ? Config.warningColor : Config.subtextColor
                description: {
                    if (group.missing)
                        return SpecialsService.binaryOf(group.modelData.command) + " isn't installed" + (group.preset?.pkg ? " (package " + group.preset.pkg + ")" : "");
                    if (group.conflicts.length > 0)
                        return "Also used by " + group.conflicts.join(", ");
                    const app = group.modelData.command || "No app, an empty scratchpad";
                    return app + (group.moveKeys ? "  ·  " + group.moveKeys + " moves a window here" : "");
                }

                leading: Rectangle {
                    readonly property color tint: SpecialsService.colorFor(group.modelData.color)

                    implicitWidth: Config.fontSizeIconSmall * 2
                    implicitHeight: implicitWidth
                    radius: Config.radius
                    color: Qt.alpha(tint, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: group.modelData.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: parent.tint
                    }
                }

                KeyCombo {
                    keys: group.toggleKeys
                    baseColor: row.controlColor
                    recording: root.recordingId === group.index + ":keys"
                    onRecordRequested: root.startRecording(group.index + ":keys")
                    onRecorded: combo => root.recorded(group.index, "keys", combo)
                }

                // Recording the move keys from the menu shows up here
                KeyCombo {
                    visible: root.recordingId === group.index + ":moveKeys"
                    keys: group.moveKeys
                    baseColor: row.controlColor
                    recording: visible
                    onRecorded: combo => root.recorded(group.index, "moveKeys", combo)
                }

                // md-dots_vertical
                ActionButton {
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f01d9}"
                    baseColor: row.controlColor
                    onClicked: menu.openAt(this, {
                        index: group.index,
                        item: group.modelData
                    })
                }
            }

            ToggleRow {
                visible: group.modelData.command !== ""
                label: "Start at login"
                description: "Opens the app hidden, so it's ready (and notifies) before the first toggle"
                checked: group.modelData.autostart === true
                onToggled: value => SpecialsService.setAutostart(group.index, value)
            }
        }
    }
}
