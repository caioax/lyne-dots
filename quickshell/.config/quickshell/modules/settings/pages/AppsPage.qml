pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Default apps (terminal, file manager, browser, editor) used by the whole
// shell and by xdg-open, plus the shortcuts that open them
ColumnLayout {
    id: root

    // Bind id whose keys are being recorded
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

    function recorded(id: string, keys: string) {
        KeybindsService.setKeys(id, keys);
        stopRecording();
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (defaults.handleEscape())
            return true;
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

    ContextMenu {
        id: menu

        // A bind of KeybindsService.binds
        items: {
            if (!target)
                return [];
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
                root.startRecording(target.id);
                break;
            case "disable":
                KeybindsService.setKeys(target.id, "");
                break;
            case "reset":
                KeybindsService.reset(target.id);
                break;
            }
        }
    }

    // ================= DEFAULT APPS =================
    // Title repeated here for the Settings search (it reads the page source)
    AppDefaultsGroup {
        id: defaults

        title: "Default apps"
    }

    // ================= SHORTCUTS =================
    SettingsGroup {
        title: "Shortcuts"

        Repeater {
            model: AppsService.slots.filter(s => s.bindId !== "")

            SettingRow {
                id: bindRow

                required property var modelData
                readonly property var bind: KeybindsService.binds.find(b => b.id === modelData.bindId) ?? null
                readonly property string keys: bind?.keys ?? ""
                readonly property var conflicts: KeybindsService.conflicts(keys, modelData.bindId, -1)
                readonly property string command: AppsService[modelData.key].command

                resettable: false
                label: "Open " + modelData.label.toLowerCase()
                descriptionColor: conflicts.length > 0 ? Config.warningColor : Config.subtextColor
                description: {
                    if (!bind)
                        return "Not found in hypr/conf/keybinds.lua";
                    if (conflicts.length > 0)
                        return "Also used by " + conflicts.join(", ");
                    if (command === "")
                        return "No app set";
                    return AppsService.describe(modelData.key);
                }

                KeyCombo {
                    visible: bindRow.bind !== null
                    keys: bindRow.keys
                    baseColor: bindRow.controlColor
                    recording: root.recordingId === bindRow.modelData.bindId
                    onRecordRequested: root.startRecording(bindRow.modelData.bindId)
                    onRecorded: combo => root.recorded(bindRow.modelData.bindId, combo)
                }

                // md-dots_vertical
                ActionButton {
                    visible: bindRow.bind !== null
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f01d9}"
                    baseColor: bindRow.controlColor
                    onClicked: menu.openAt(this, bindRow.bind)
                }
            }
        }
    }
}
