pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../power/"

// Suspend, reboot and shut down from the lock screen. They count down here
// (the power menu can't show above the lock); Esc cancels
ColumnLayout {
    id: root

    property bool vertical: false
    // Full-width rows with the labels, for narrow cards
    property bool rows: false

    readonly property var actions: PowerService.availableActions.filter(a => ["suspend", "reboot", "shutdown"].includes(a.id))
    readonly property var pending: PowerService.pendingAction

    spacing: Config.padding

    GridLayout {
        id: buttons

        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: root.rows
        columns: root.vertical || root.rows ? 1 : root.actions.length
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: root.actions

            PowerButton {
                required property var modelData

                Layout.fillWidth: root.rows
                action: modelData
                variant: root.rows ? "row" : "square"
                inPlace: true
                showKey: false
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: buttons.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        // Rows show the seconds on the pending one already
        visible: root.pending !== null && !root.rows
        text: root.pending ? root.pending.progress + " in " + Math.ceil(PowerService.remaining / 1000) + "s · esc cancels" : ""
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: root.pending?.tone === "error" ? Config.errorColor : Config.warningColor
    }
}
