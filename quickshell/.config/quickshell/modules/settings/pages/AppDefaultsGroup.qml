pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The default apps (terminal, file manager, browser, editor) with their
// picker: Settings › Apps and the welcome screen
SettingsGroup {
    id: root

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

    // The page's Escape goes here first
    function handleEscape(): bool {
        if (picker.opened) {
            picker.close();
            return true;
        }
        return false;
    }

    Component.onCompleted: AppsService.refresh()

    title: "Default apps"

    AppPicker {
        id: picker

        property string slotKey: ""

        allowCustom: true
        onPicked: entry => AppsService.set(slotKey, AppsService.commandOf(entry), entry)
        onCustomPicked: command => AppsService.set(slotKey, command, null)
    }

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
                        enabled: !Config.themeTransitioning
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
