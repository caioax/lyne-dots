pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// Keycaps of one or more binds, read-only: one combo ("SUPER + Q"), or binds
// that share their modifiers shown once with every key ("Super + H J K L").
// A modifier tapped alone says so
Row {
    id: root

    // Hyprland combos, in the order their keys should show
    property var combos: []
    // Keys as a range in one cap: the first and the last ("1–0")
    property bool range: false

    readonly property var _names: ({
            SUPER: "Super",
            CTRL: "Ctrl",
            CONTROL: "Ctrl",
            ALT: "Alt",
            SHIFT: "Shift",
            RETURN: "Enter",
            LEFT: "←",
            RIGHT: "→",
            UP: "↑",
            DOWN: "↓",
            TAB: "Tab",
            SPACE: "Space",
            ESCAPE: "Esc",
            COMMA: ",",
            PERIOD: ".",
            EQUAL: "=",
            MINUS: "-",
            SLASH: "/"
        })

    function _name(part: string): string {
        return _names[part.toUpperCase()] ?? (part.length === 1 ? part.toUpperCase() : part);
    }

    // Modifiers of a combo ("SUPER+CTRL") and its key
    function _mods(combo: string): string {
        return KeybindsService.normalize(combo).split("+").slice(0, -1).join("+");
    }

    readonly property var _list: combos.filter(c => c !== "")
    readonly property bool _lone: _list.length === 1 && KeybindsService.isLoneModifier(_list[0])
    // Caps to draw: modifiers once, then each key, when every combo shares them
    readonly property var caps: {
        if (_list.length === 0)
            return [];
        const shared = _list.every(c => _mods(c) === _mods(_list[0]));
        const first = KeybindsService.split(_list[0]).map(p => _name(p));
        if (_list.length === 1 || !shared)
            return first;
        const keys = _list.map(c => _name(KeybindsService.split(c).pop()));
        return [...first.slice(0, -1), ...(range ? [keys[0] + "\u2013" + keys[keys.length - 1]] : keys)];
    }

    spacing: Math.round(Config.padding / 2)

    Repeater {
        model: root.caps

        Rectangle {
            id: cap

            required property string modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(implicitHeight, capText.implicitWidth + Config.padding * 2)
            implicitHeight: Config.fontSizeIconSmall + Config.padding
            width: implicitWidth
            height: implicitHeight
            radius: Config.radiusSmall
            color: Config.surface3Color

            Text {
                id: capText
                anchors.centerIn: parent
                text: cap.modelData
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }
        }
    }

    Text {
        visible: root._list.length === 0
        anchors.verticalCenter: parent.verticalCenter
        text: "No keys"
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.italic: true
        color: Config.subtextColor
    }
}
