pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Notification history section (Quick Settings dashboard): header plus the
// app groups, scrolling once they are taller than maxHeight
Item {
    id: root

    property real maxHeight: 0

    signal actionTriggered

    readonly property real listHeight: Math.max(0, Math.min(groups.implicitHeight, maxHeight - header.implicitHeight - Config.spacing))

    implicitHeight: header.implicitHeight + Config.spacing + listHeight

    RowLayout {
        id: header

        width: parent.width
        spacing: Config.padding

        Text {
            text: "Notifications"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: Config.textColor
        }

        Text {
            text: NotificationService.count
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Item {
            Layout.fillWidth: true
        }

        ClearButton {
            icon: "󰎟"
            text: "Clear"
            implicitHeight: Config.fontSizeSmall + Config.padding * 3
            onClicked: NotificationService.clearAll()
        }
    }

    // Flickable + Column (not ListView): groups change height when rows expand,
    // and a Column always relayouts for that
    Flickable {
        id: flick

        anchors.top: header.bottom
        anchors.topMargin: Config.spacing
        width: parent.width
        height: root.listHeight
        contentHeight: groups.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: QsScrollBar {}

        Column {
            id: groups

            width: flick.width
            spacing: Config.spacing

            Repeater {
                model: ScriptModel {
                    values: NotificationService.groupNames
                }

                NotificationGroup {
                    required property string modelData
                    width: groups.width
                    appName: modelData
                    onActionTriggered: root.actionTriggered()
                }
            }
        }
    }
}
