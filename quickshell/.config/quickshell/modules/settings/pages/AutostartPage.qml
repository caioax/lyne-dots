pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Programs started at login: your apps (AutostartService), the special
// workspaces opened hidden (SpecialsService) and the essential ones of
// hypr/conf/autostart.lua, which always start
ColumnLayout {
    id: root

    // Special workspaces that have an app to open
    readonly property var specials: SpecialsService.list.map((s, i) => ({
                item: s,
                index: i
            })).filter(s => (s.item.command ?? "") !== "")

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        if (picker.opened) {
            picker.close();
            return true;
        }
        if (dialog.opened) {
            dialog.close();
            return true;
        }
        if (menu.opened) {
            menu.close();
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        AutostartService.refresh();
        AutostartService.checkInstalled("");
    }

    spacing: Config.spacing * 3

    AppPicker {
        id: picker
        title: "Start at login"
        allowCustom: true
        customPlaceholder: "Any command, like ~/.local/scripts/fans.sh"
        onPicked: entry => AutostartService.addEntry(entry)
        onCustomPicked: command => dialog.openNew(command)
    }

    AutostartDialog {
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
                    label: "Run now",
                    icon: "\u{f040a}",
                    action: "run"
                }
            ];
            if (target.index > 0)
                list.push({
                    label: "Move up",
                    icon: "\u{f005d}",
                    action: "up"
                });
            if (target.index < AutostartService.apps.length - 1)
                list.push({
                    label: "Move down",
                    icon: "\u{f0045}",
                    action: "down"
                });
            list.push({
                label: "Remove",
                icon: "\u{f09e7}",
                action: "remove",
                danger: true
            });
            return list;
        }

        onTriggered: (action, target) => {
            switch (action) {
            case "edit":
                dialog.openFor(target.index);
                break;
            case "run":
                AutostartService.runNow(target.index);
                break;
            case "up":
                AutostartService.move(target.index, -1);
                break;
            case "down":
                AutostartService.move(target.index, 1);
                break;
            case "remove":
                AutostartService.remove(target.index);
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
            text: "Started once, when you log in. Changes apply from the next login; Run now starts one right away"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        // md-plus
        ActionButton {
            size: Config.fontSizeIconSmall * 2
            icon: "\u{f0415}"
            text: "Add app"
            baseColor: Config.accentColor
            hoverColor: Qt.lighter(Config.accentColor, 1.1)
            textColor: Config.textReverseColor
            onClicked: picker.openWith("")
        }
    }

    // ================= HAND-WRITTEN FILE =================
    SettingsGroup {
        title: "Your autostart.lua"
        visible: AutostartService.legacyExists && AutostartService.legacy !== null && (AutostartService.legacy.apps.length > 0 || AutostartService.legacy.other > 0 || !AutostartService.legacy.ok)

        SettingRow {
            resettable: false
            label: "hypr/local/autostart.lua"
            descriptionColor: AutostartService.legacyImportable ? Config.subtextColor : Config.warningColor
            description: {
                const legacy = AutostartService.legacy;
                if (!legacy)
                    return "";
                if (!legacy.ok)
                    return "It couldn't be read: " + legacy.error;
                if (legacy.other > 0)
                    return "It also sets up other things (binds, options...), so it stays as it is. Move those to another hypr/local/*.lua file to import it";
                return "Written by hand before this page. It keeps starting these until you import them here, then it's renamed to autostart.lua.imported";
            }

            // md-file_import
            ActionButton {
                visible: AutostartService.legacyImportable
                icon: "\u{f0220}"
                text: AutostartService.importing ? "Importing..." : "Import"
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: AutostartService.importLegacy()
            }
        }

        Repeater {
            model: AutostartService.legacy?.apps ?? []

            SettingRow {
                required property var modelData

                resettable: false
                label: AutostartService.nameFor(modelData.command)
                description: AutostartService.shortCommand(modelData.command) + (modelData.delay > 0 ? "  ·  after " + modelData.delay + " s" : "") + (modelData.workspace ? "  ·  on " + modelData.workspace : "")
            }
        }
    }

    // ================= YOUR APPS =================
    SettingsGroup {
        title: "Your apps"

        SettingRow {
            visible: AutostartService.apps.length === 0
            resettable: false
            label: "Nothing yet"
            description: "Add apps or scripts to start with the session, like a chat app, a sync client or a fan script"
        }

        Repeater {
            model: AutostartService.apps

            ToggleRow {
                id: appRow

                required property var modelData
                required property int index

                readonly property bool missing: AutostartService.isMissing(modelData.command)
                readonly property string iconName: AutostartService.iconOf(modelData)

                resettable: false
                label: modelData.name || AutostartService.nameFor(modelData.command)
                descriptionColor: missing ? Config.warningColor : Config.subtextColor
                description: {
                    if (missing)
                        return AutostartService.binaryOf(modelData.command) + " isn't installed";
                    let text = AutostartService.shortCommand(modelData.command);
                    if (modelData.delay > 0)
                        text += "  ·  after " + modelData.delay + " s";
                    if (modelData.workspace)
                        text += "  ·  on " + modelData.workspace;
                    return text;
                }
                checked: modelData.enabled !== false
                onToggled: value => AutostartService.setEnabled(index, value)

                leading: Rectangle {
                    implicitWidth: Config.fontSizeIconSmall * 2
                    implicitHeight: implicitWidth
                    radius: Config.radius
                    color: Config.surface1Color

                    Image {
                        visible: appRow.iconName !== ""
                        anchors.centerIn: parent
                        width: Config.fontSizeIconSmall + Config.padding
                        height: width
                        sourceSize.width: width
                        sourceSize.height: height
                        source: appRow.iconName !== "" ? "image://icon/" + appRow.iconName : ""
                    }

                    // md-console for scripts and commands
                    Text {
                        visible: appRow.iconName === ""
                        anchors.centerIn: parent
                        text: "\u{f018d}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.subtextColor
                    }
                }

                // md-dots_vertical
                ActionButton {
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f01d9}"
                    baseColor: appRow.controlColor
                    onClicked: menu.openAt(this, {
                        index: appRow.index,
                        item: appRow.modelData
                    })
                }
            }
        }
    }

    // ================= SPECIAL WORKSPACES =================
    SettingsGroup {
        title: "Special workspaces"
        visible: root.specials.length > 0

        Repeater {
            model: root.specials

            ToggleRow {
                id: specialRow

                required property var modelData

                resettable: false
                label: modelData.item.name
                description: "Opens " + modelData.item.command + " hidden in its workspace"
                checked: modelData.item.autostart === true
                onToggled: value => SpecialsService.setAutostart(modelData.index, value)

                leading: Rectangle {
                    readonly property color tint: SpecialsService.colorFor(specialRow.modelData.item.color)

                    implicitWidth: Config.fontSizeIconSmall * 2
                    implicitHeight: implicitWidth
                    radius: Config.radius
                    color: Qt.alpha(tint, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: specialRow.modelData.item.icon ?? ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: parent.tint
                    }
                }
            }
        }

        SettingRow {
            resettable: false
            label: "Special workspaces"
            description: "Their apps, shortcuts and badges are set in Hyprland › Specials"

            // md-chevron_right
            ActionButton {
                icon: "\u{f0142}"
                text: "Open"
                onClicked: SettingsService.currentPage = "specials"
            }
        }
    }

    // ================= SYSTEM =================
    SettingsGroup {
        title: "System"
        visible: AutostartService.system.length > 0

        Repeater {
            model: AutostartService.system

            SettingRow {
                required property var modelData

                resettable: false
                label: modelData.name
                description: modelData.about

                // md-lock_outline
                Text {
                    text: "\u{f0341}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    color: Config.subtextColor
                }
            }
        }
    }

    Text {
        visible: AutostartService.system.length > 0
        Layout.fillWidth: true
        Layout.topMargin: -Config.spacing * 2
        text: "The shell needs these, so they always start (hypr/conf/autostart.lua)"
        wrapMode: Text.WordWrap
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.subtextColor
    }
}
