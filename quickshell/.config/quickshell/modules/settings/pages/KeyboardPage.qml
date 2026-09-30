pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Keyboard layouts, key options and typing (KeyboardService). Saved to the
// "hyprland" block of state.json and applied live like the Input page
ColumnLayout {
    id: root

    readonly property var layouts: KeyboardService.layouts
    readonly property var options: KeyboardService.options
    readonly property string globalLayout: layouts.map(l => l.layout).join(",")
    // Keyboards set up on their own (hypr/local/extra_input.lua)
    readonly property var ownLayouts: KeyboardService.keyboards.filter(k => k.layout !== root.globalLayout)

    readonly property var capsChoices: [
        {
            value: "",
            label: "Caps Lock"
        },
        {
            value: "ctrl:nocaps",
            label: "Ctrl"
        },
        {
            value: "caps:escape",
            label: "Escape"
        },
        {
            value: "caps:escape_shifted_capslock",
            label: "Escape, Shift + Caps Lock for Caps Lock"
        },
        {
            value: "caps:swapescape",
            label: "Swapped with Escape"
        },
        {
            value: "caps:backspace",
            label: "Backspace"
        },
        {
            value: "caps:none",
            label: "Nothing"
        }
    ]
    readonly property string capsValue: KeyboardService.optionIn("caps") || (options.includes("ctrl:nocaps") ? "ctrl:nocaps" : "")

    readonly property var composeChoices: [
        {
            value: "",
            label: "None"
        },
        {
            value: "compose:ralt",
            label: "Right Alt"
        },
        {
            value: "compose:rctrl",
            label: "Right Ctrl"
        },
        {
            value: "compose:rwin",
            label: "Right Super"
        },
        {
            value: "compose:menu",
            label: "Menu"
        },
        {
            value: "compose:caps",
            label: "Caps Lock"
        }
    ]
    readonly property string composeValue: KeyboardService.optionIn("compose")

    function labelOf(choices, value): string {
        return (choices.find(c => c.value === value) ?? {
                label: KeyboardService.optionDescription(value)
            }).label;
    }

    function setCaps(value: string) {
        const list = options.filter(o => !o.startsWith("caps:") && o !== "ctrl:nocaps");
        if (value !== "")
            list.push(value);
        KeyboardService.setOptions(list);
    }

    // Index of the layout the picker changes; -1 = adds one
    property int pickerIndex: -1

    function openLayoutPicker(index: int) {
        pickerIndex = index;
        layoutPicker.openWith(index >= 0 ? layouts[index].layout : "");
    }

    // Called by SettingsWindow before Escape closes the window
    function handleEscape(): bool {
        for (const popup of [layoutPicker, modelPicker, optionPicker, menu]) {
            if (popup.opened) {
                popup.close();
                return true;
            }
        }
        return false;
    }

    Component.onCompleted: KeyboardService.refreshDevices()

    spacing: Config.spacing * 3

    // ================= PICKERS =================
    XkbPicker {
        id: layoutPicker

        title: root.pickerIndex >= 0 ? "Change layout" : "Add a layout"
        placeholder: "Search layouts, languages and variants"
        items: KeyboardService.allEntries.map(e => ({
                    key: e.layout + "(" + e.variant + ")",
                    label: e.description,
                    detail: e.variant ? e.layout + " · " + e.variant : e.layout,
                    entry: e
                }))
        selected: root.pickerIndex >= 0 ? [root.layouts[root.pickerIndex].layout + "(" + root.layouts[root.pickerIndex].variant + ")"] : root.layouts.map(l => l.layout + "(" + l.variant + ")")
        onPicked: item => {
            if (root.pickerIndex >= 0)
                KeyboardService.replaceLayout(root.pickerIndex, item.entry);
            else
                KeyboardService.addLayout(item.entry);
        }
    }

    XkbPicker {
        id: modelPicker

        title: "Keyboard model"
        placeholder: "Search models"
        items: [
            {
                key: "",
                label: "Default",
                detail: "Generic 105-key PC (pc105), right for almost every keyboard"
            }
        ].concat(KeyboardService.db.models.map(m => ({
                    key: m.name,
                    label: m.description,
                    detail: m.name
                })))
        selected: [KeyboardService.model]
        onPicked: item => KeyboardService.setModel(item.key)
    }

    XkbPicker {
        id: optionPicker

        title: "Key options"
        placeholder: "Search options"
        multi: true
        items: KeyboardService.db.groups.reduce((out, g) => out.concat([
                {
                    key: g.name,
                    label: g.description,
                    detail: "",
                    header: true
                }
            ], g.options.map(o => ({
                        key: o.name,
                        label: o.description,
                        detail: o.name
                    }))), [])
        selected: root.options
        onToggled: (item, on) => KeyboardService.toggleOption(item.key, on)
    }

    ContextMenu {
        id: menu

        // layout | caps | compose
        property string kind

        onTriggered: (action, target) => {
            if (kind === "caps") {
                root.setCaps(action);
            } else if (kind === "compose") {
                KeyboardService.setGroupOption("compose", action);
            } else if (action === "change") {
                root.openLayoutPicker(target);
            } else if (action === "up") {
                KeyboardService.moveLayout(target, -1);
            } else if (action === "down") {
                KeyboardService.moveLayout(target, 1);
            } else if (action === "remove") {
                KeyboardService.removeLayout(target);
            }
        }

        function openChoices(button: Item, which: string, choices, current: string) {
            kind = which;
            items = choices.map(c => ({
                        label: c.label,
                        icon: c.value === current ? "\u{f012c}" : "",
                        action: c.value
                    }));
            openAt(button, null);
        }
    }

    HyprlandErrorGroup {}

    // ================= LAYOUTS =================
    SettingsGroup {
        title: "Layouts"

        Repeater {
            model: root.layouts

            SettingRow {
                id: layoutRow

                required property var modelData
                required property int index
                readonly property string layoutName: KeyboardService.describe(modelData)
                readonly property bool active: root.layouts.length > 1 && KeyboardService.activeKeymap === layoutName

                resettable: false
                label: layoutName
                description: (modelData.variant ? modelData.layout + " · " + modelData.variant : modelData.layout) + (active ? "  ·  in use" : "")

                leading: Rectangle {
                    implicitWidth: Config.fontSizeIconSmall * 2
                    implicitHeight: implicitWidth
                    radius: Config.radius
                    color: layoutRow.active ? Qt.alpha(Config.accentColor, 0.2) : Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: KeyboardService.shortName(layoutRow.modelData)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: layoutRow.active ? Config.accentColor : Config.subtextColor
                    }
                }

                // md-dots_vertical
                ActionButton {
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f01d9}"
                    baseColor: layoutRow.controlColor
                    onClicked: {
                        const list = [
                            {
                                label: "Change layout or variant",
                                icon: "\u{f03eb}",
                                action: "change"
                            }
                        ];
                        if (layoutRow.index > 0)
                            list.push({
                                label: "Move up",
                                icon: "\u{f005d}",
                                action: "up"
                            });
                        if (layoutRow.index < root.layouts.length - 1)
                            list.push({
                                label: "Move down",
                                icon: "\u{f0045}",
                                action: "down"
                            });
                        if (root.layouts.length > 1)
                            list.push({
                                label: "Remove",
                                icon: "\u{f09e7}",
                                action: "remove",
                                danger: true
                            });
                        menu.kind = "layout";
                        menu.items = list;
                        menu.openAt(this, layoutRow.index);
                    }
                }
            }
        }

        SettingRow {
            resettable: false
            label: root.layouts.length >= KeyboardService.maxLayouts ? "Four layouts at most" : "Another layout"
            description: root.layouts.length > 1 ? "The first one is used when you log in" : "For another language or keyboard"
            enabled: KeyboardService.ready

            // md-plus
            ActionButton {
                icon: "\u{f0415}"
                text: "Add layout"
                opacity: root.layouts.length < KeyboardService.maxLayouts ? 1 : 0.4
                onClicked: {
                    if (root.layouts.length < KeyboardService.maxLayouts)
                        root.openLayoutPicker(-1);
                }
            }
        }
    }

    // ================= TRY IT =================
    SettingsGroup {
        title: "Try it"

        SettingRow {
            resettable: false
            label: "Type here"
            description: KeyboardService.activeKeymap !== "" ? "Typing with " + KeyboardService.activeKeymap : ""

            below: Rectangle {
                width: parent ? parent.width : 0
                implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                radius: Config.radius
                color: Config.surface1Color
                border.width: tryInput.activeFocus ? 1 : 0
                border.color: Qt.alpha(Config.accentColor, 0.6)

                TextInput {
                    id: tryInput

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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tryInput.text === ""
                        text: "Accents, symbols: ç ã é ~ ^ ` ´ \" @ # |"
                        font: tryInput.font
                        color: Config.subtextColor
                    }
                }
            }
        }
    }

    // ================= KEYS =================
    SettingsGroup {
        title: "Keys"

        SettingRow {
            id: capsRow

            label: "Caps Lock key"
            description: "What the Caps Lock key does"
            resettable: false
            enabled: KeyboardService.ready

            ActionButton {
                id: capsButton
                text: root.labelOf(root.capsChoices, root.capsValue)
                baseColor: capsRow.controlColor
                onClicked: menu.openChoices(capsButton, "caps", root.capsChoices, root.capsValue)
            }
        }

        SettingRow {
            id: composeRow

            label: "Compose key"
            description: "Press it, then two keys, to type characters like é, ñ or €"
            resettable: false
            enabled: KeyboardService.ready

            ActionButton {
                id: composeButton
                text: root.labelOf(root.composeChoices, root.composeValue)
                baseColor: composeRow.controlColor
                onClicked: menu.openChoices(composeButton, "compose", root.composeChoices, root.composeValue)
            }
        }

        ToggleRow {
            label: "Num Lock on at login"
            path: "hyprland.input.numlock_by_default"
        }

        SettingRow {
            id: optionsRow

            label: "All key options"
            description: root.options.length === 0 ? "Everything xkb offers: Alt and Super, Ctrl position, numpad, Euro sign..." : root.options.map(o => KeyboardService.optionSummary(o)).join(" · ")
            path: "hyprland.input.kb_options"
            enabled: KeyboardService.ready

            ActionButton {
                text: root.options.length === 0 ? "Choose" : root.options.length + " on"
                baseColor: optionsRow.controlColor
                onClicked: optionPicker.openWith("")
            }
        }
    }

    // ================= TYPING =================
    SettingsGroup {
        title: "Typing"

        SliderRow {
            label: "Repeat delay"
            description: "How long a key is held before it repeats"
            path: "hyprland.input.repeat_delay"
            from: 150
            to: 800
            stepSize: 25
            format: v => v + " ms"
        }

        SliderRow {
            label: "Repeat rate"
            description: "Repeats per second while a key is held"
            path: "hyprland.input.repeat_rate"
            from: 10
            to: 80
            format: v => v + "/s"
        }
    }

    // ================= ADVANCED =================
    SettingsGroup {
        title: "Advanced"

        SettingRow {
            id: modelRow

            label: "Keyboard model"
            description: "Only matters for a few special keyboards (some Apple, Japanese and Brazilian ABNT2 ones)"
            path: "hyprland.input.kb_model"
            enabled: KeyboardService.ready

            ActionButton {
                text: KeyboardService.model === "" ? "Default" : KeyboardService.model
                baseColor: modelRow.controlColor
                onClicked: modelPicker.openWith("")
            }
        }
    }

    // ================= PER KEYBOARD =================
    SettingsGroup {
        title: "Keyboards with their own layout"
        visible: root.ownLayouts.length > 0

        Repeater {
            model: root.ownLayouts

            InfoRow {
                required property var modelData

                label: modelData.name
                description: "Set in hypr/local/extra_input.lua, so the layouts above don't apply to it"
                value: modelData.active_keymap
            }
        }
    }
}
