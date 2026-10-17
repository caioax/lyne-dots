pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Footer: the countdown of a destructive action with how to run it now or
// cancel it. Keeps its height while idle, so the panel doesn't jump
RowLayout {
    id: root

    readonly property var pending: PowerService.pendingAction
    readonly property color tone: pending?.tone === "error" ? Config.errorColor : Config.warningColor

    spacing: Config.spacing * 2
    opacity: pending !== null ? 1 : 0

    Text {
        text: root.pending ? I18n.tr("%1 in %2s", root.pending.progress, Math.ceil(PowerService.remaining / 1000)) : ""
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: root.tone
    }

    KeyHint {
        keys: "⏎"
        label: I18n.trc("key hint", "now")
    }

    KeyHint {
        keys: "esc"
        label: I18n.trc("key hint", "cancel")
    }
}
