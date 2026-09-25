pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Template "strip": a column of icon buttons growing out of the left or
// right screen edge, vertically centered, with the selected action's name
// and the countdown below
AttachedPanel {
    id: root

    readonly property var selected: PowerService.find(PowerService.selectedId)
    readonly property var pending: PowerService.pendingAction

    edges: [PowerService.side === "left" ? "left" : "right"]
    implicitWidth: content.implicitWidth + Config.padding * 4
    implicitHeight: content.implicitHeight + Config.padding * 6

    // Swallows clicks so they don't reach the backdrop (which closes)
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Config.spacing

        PowerAvatar {
            Layout.alignment: Qt.AlignHCenter
            size: Config.fontSizeIcon * 2
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: PowerService.uptime
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        // Apps blocking sleep or shutdown, by name
        Text {
            visible: PowerService.inhibitors.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Config.fontSizeIcon * 3
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "\u{f0026} " + PowerService.inhibitors.map(i => i.who).join(", ")
            font.family: Config.font
            font.pixelSize: Math.round(Config.fontSizeSmall * 0.85)
            color: Config.warningColor
        }

        Item {
            implicitHeight: Config.padding
        }

        Repeater {
            model: PowerService.actions

            PowerButton {
                required property var modelData

                Layout.alignment: Qt.AlignHCenter
                action: modelData
                variant: "square"
            }
        }

        Item {
            implicitHeight: Config.padding
        }

        // Selected action, or the countdown
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Config.fontSizeIcon * 3
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.pending ? "esc to\ncancel" : root.selected?.label ?? ""
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: root.pending ? (root.pending.tone === "error" ? Config.errorColor : Config.warningColor) : Config.textColor
        }
    }
}
