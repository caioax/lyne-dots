pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Keycaps for a Hyprland combo ("SUPER + SHIFT + Q"). Click to record a new
// one: KeybindsService puts Hyprland in an empty submap so every combo
// reaches this item; Escape cancels (handled by the page)
Rectangle {
    id: root

    property string keys
    property bool recording: false
    property string emptyText: "Disabled"
    // Background when idle (the row's control color)
    property color baseColor: Config.surface1Color

    signal recordRequested
    signal recorded(string keys)

    readonly property var parts: KeybindsService.split(keys)

    // Qt key -> Hyprland (xkb) key name; "" = not supported
    readonly property var _names: ({
            [Qt.Key_Return]: "return",
            [Qt.Key_Enter]: "return",
            [Qt.Key_Space]: "Space",
            [Qt.Key_Tab]: "TAB",
            [Qt.Key_Backtab]: "TAB",
            [Qt.Key_Backspace]: "BackSpace",
            [Qt.Key_Delete]: "Delete",
            [Qt.Key_Insert]: "Insert",
            [Qt.Key_Home]: "Home",
            [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Page_Up",
            [Qt.Key_PageDown]: "Page_Down",
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Print]: "Print",
            [Qt.Key_Pause]: "Pause",
            [Qt.Key_Minus]: "minus",
            [Qt.Key_Underscore]: "minus",
            [Qt.Key_Equal]: "equal",
            [Qt.Key_Plus]: "equal",
            [Qt.Key_Slash]: "slash",
            [Qt.Key_Question]: "slash",
            [Qt.Key_Comma]: "comma",
            [Qt.Key_Less]: "comma",
            [Qt.Key_Period]: "period",
            [Qt.Key_Greater]: "period",
            [Qt.Key_Semicolon]: "semicolon",
            [Qt.Key_Colon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe",
            [Qt.Key_QuoteDbl]: "apostrophe",
            [Qt.Key_BracketLeft]: "bracketleft",
            [Qt.Key_BraceLeft]: "bracketleft",
            [Qt.Key_BracketRight]: "bracketright",
            [Qt.Key_BraceRight]: "bracketright",
            [Qt.Key_Backslash]: "backslash",
            [Qt.Key_Bar]: "backslash",
            [Qt.Key_QuoteLeft]: "grave",
            [Qt.Key_AsciiTilde]: "grave",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume",
            [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute",
            [Qt.Key_MediaNext]: "XF86AudioNext",
            [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaPause]: "XF86AudioPause",
            [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
            [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
            [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
        })
    readonly property var _modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock, Qt.Key_NumLock]

    function _keyName(event): string {
        const key = event.key;
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key);
        // Digits by physical key: with Shift, Qt reports the symbol (!, @...)
        const code = event.nativeScanCode;
        if (code >= 10 && code <= 19)
            return String((code - 9) % 10);
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
            return "F" + (key - Qt.Key_F1 + 1);
        return _names[key] ?? "";
    }

    function _combo(event): string {
        const name = _keyName(event);
        if (name === "")
            return "";
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        return [...mods, name].join(" + ");
    }

    // Last key that couldn't be used, shown while recording
    property string _hint: ""

    onRecordingChanged: {
        _hint = "";
        if (recording)
            catcher.forceActiveFocus();
    }

    implicitWidth: content.implicitWidth + Config.padding * 2
    implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
    radius: Config.radius
    color: recording ? Qt.alpha(Config.accentColor, 0.15) : mouse.containsMouse ? Config.surface2Color : baseColor
    border.width: recording ? 1 : 0
    border.color: Config.accentColor

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Item {
        id: catcher

        focus: root.recording
        Keys.onPressed: event => {
            if (!root.recording)
                return;
            event.accepted = true;
            if (root._modifierKeys.includes(event.key))
                return;
            const combo = root._combo(event);
            if (combo === "") {
                root._hint = "That key can't be used";
                return;
            }
            root.recorded(combo);
        }
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: Math.round(Config.padding / 2)

        Text {
            visible: root.recording
            text: root._hint !== "" ? root._hint : "Press a shortcut… Esc to cancel"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: root._hint !== "" ? Config.warningColor : Config.accentColor

            SequentialAnimation on opacity {
                running: root.recording
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 0.5
                    duration: Config.animDurationLong * 2
                }
                NumberAnimation {
                    to: 1
                    duration: Config.animDurationLong * 2
                }
            }
        }

        Text {
            visible: !root.recording && root.parts.length === 0
            text: root.emptyText
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.italic: true
            color: Config.subtextColor
        }

        Repeater {
            model: root.recording ? [] : root.parts

            Rectangle {
                id: cap

                required property string modelData

                implicitWidth: Math.max(implicitHeight, capText.implicitWidth + Config.padding * 2)
                implicitHeight: Config.fontSizeIconSmall + Config.padding
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
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.recording
        onClicked: root.recordRequested()
    }
}
