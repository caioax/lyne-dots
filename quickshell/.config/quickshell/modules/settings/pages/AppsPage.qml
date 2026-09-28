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

    function pickFor(key: string) {
        const slot = AppsService.slot(key);
        picker.slotKey = key;
        picker.title = slot.label;
        picker.category = slot.category;
        picker.categoryLabel = slot.label.toLowerCase() + " apps";
        picker.currentId = AppsService.entryFor(key)?.id ?? "";
        picker.customPlaceholder = {
            terminal: "wezterm, foot…",
            fileManager: "yazi, thunar…",
            browser: "firefox --private-window…",
            editor: "hx, code --wait…"
        }[key];
        picker.openWith(AppsService[key].command);
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (picker.opened) {
            picker.close();
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
        AppsService.refresh();
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

    AppPicker {
        id: picker

        property string slotKey: ""

        allowCustom: true
        onPicked: entry => AppsService.set(slotKey, AppsService.commandOf(entry), entry)
        onCustomPicked: command => AppsService.set(slotKey, command, null)
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
    SettingsGroup {
        title: "Default apps"

        Repeater {
            model: AppsService.slots

            SettingRow {
                id: slotRow

                required property var modelData
                readonly property string key: modelData.key
                readonly property var entry: AppsService.entryFor(key)
                readonly property string command: AppsService[key].command
                readonly property bool missing: AppsService.isMissing(key)
                readonly property string mismatch: AppsService.mimeMismatch(key)

                label: modelData.label
                path: modelData.path
                onResetRequested: AppsService.apply(key)
                descriptionColor: missing || mismatch !== "" ? Config.warningColor : Config.subtextColor
                description: {
                    if (command === "")
                        return "None: " + modelData.usage.charAt(0).toLowerCase() + modelData.usage.slice(1) + " won't open";
                    if (missing)
                        return AppsService.binaryOf(command) + " isn't installed";
                    if (mismatch !== "")
                        return "xdg-open still uses " + mismatch.replace(/\.desktop$/, "");
                    return modelData.usage;
                }

                leading: Rectangle {
                    implicitWidth: Config.fontSizeIconSmall * 2
                    implicitHeight: implicitWidth
                    radius: Config.radius
                    color: Qt.alpha(Config.accentColor, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: slotRow.modelData.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.accentColor
                    }
                }

                // md-link_variant
                ActionButton {
                    visible: slotRow.mismatch !== "" && !slotRow.missing
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f0339}"
                    text: "Use for xdg-open"
                    baseColor: slotRow.controlColor
                    onClicked: AppsService.apply(slotRow.key)
                }

                // The app: click to pick another
                Rectangle {
                    id: appButton

                    // Same width on every row, unless a name is longer
                    implicitWidth: Math.max(appRow.implicitWidth + Config.padding * 4, Config.fontSizeNormal * 10)
                    implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                    radius: Config.radius
                    color: appMouse.containsMouse ? Config.surface2Color : slotRow.controlColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        id: appRow

                        anchors.centerIn: parent
                        spacing: Config.padding + Config.padding / 2

                        Image {
                            visible: slotRow.entry !== null
                            Layout.preferredWidth: Config.fontSizeIconSmall
                            Layout.preferredHeight: Config.fontSizeIconSmall
                            sourceSize.width: width
                            sourceSize.height: height
                            source: slotRow.entry ? "image://icon/" + (slotRow.entry.icon || "application-x-executable") : ""
                        }

                        Text {
                            text: slotRow.command === "" ? "None" : AppsService.nameOf(slotRow.key)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: slotRow.command === "" ? Config.subtextColor : Config.textColor
                        }

                        // md-chevron_down
                        Text {
                            text: "\u{f0140}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.subtextColor
                        }
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickFor(slotRow.key)
                    }
                }
            }
        }
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
