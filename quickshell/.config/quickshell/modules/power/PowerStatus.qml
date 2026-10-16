pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Footer: the key hints, or the countdown of a destructive action with how
// to run it now or cancel it. `vertical` is the arrow hint of the strip
RowLayout {
    id: root

    property bool vertical: false

    readonly property var pending: PowerService.pendingAction
    readonly property color tone: pending?.tone === "error" ? Config.errorColor : Config.warningColor
    readonly property string letters: PowerService.actions.map(a => a.key).join(" ")

    spacing: Config.spacing * 2

    Text {
        visible: root.pending !== null
        text: root.pending ? I18n.tr("%1 in %2s", root.pending.progress, Math.ceil(PowerService.remaining / 1000)) : ""
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: root.tone
    }

    KeyHint {
        visible: root.pending !== null
        keys: "⏎"
        label: I18n.trc("key hint", "now")
    }

    KeyHint {
        visible: root.pending !== null
        keys: "esc"
        label: I18n.trc("key hint", "cancel")
    }

    KeyHint {
        visible: root.pending === null
        keys: root.vertical ? "↑↓" : "←→"
        label: I18n.trc("key hint", "move")
    }

    KeyHint {
        visible: root.pending === null
        keys: "⏎"
        label: I18n.trc("key hint", "run")
    }

    KeyHint {
        visible: root.pending === null
        keys: root.letters
        label: I18n.trc("key hint", "direct")
    }

    KeyHint {
        visible: root.pending === null
        keys: "esc"
        label: I18n.trc("key hint", "close")
    }
}
