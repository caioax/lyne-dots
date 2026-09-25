pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Notifications of one app (newest first), inside the history card: app icon
// box on the left, the rows on the right. Collapsed it shows the newest one;
// the chevron shows them all (or asks for the full page in `preview`).
Item {
    id: root

    required property string appName
    // Dashboard preview: the chevron opens the notifications page instead
    property bool preview: false
    property bool expanded: false

    signal actionTriggered
    signal openRequested

    readonly property var notifs: NotificationService.notificationsOf(appName)
    readonly property bool critical: notifs.some(n => n.isCritical)
    readonly property string appIconSource: notifs.length > 0 ? NotificationService.iconSource(notifs[0].appIcon) : ""
    readonly property int boxSize: Config.fontSizeIconSmall * 2
    readonly property color tint: critical ? Config.errorColor : Config.accentColor

    implicitHeight: layout.implicitHeight

    RowLayout {
        id: layout

        width: parent.width
        spacing: Config.spacing + Config.padding

        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.boxSize
            implicitHeight: root.boxSize
            radius: Config.radiusLarge
            color: root.critical ? Qt.alpha(Config.errorColor, 0.15) : Config.surface1Color

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                visible: root.appIconSource !== "" && status !== Image.Error
                implicitSize: Config.fontSizeIconSmall
                source: root.appIconSource
            }

            // md-alert / md-bell
            Text {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: root.critical ? "\u{f0026}" : "\u{f009a}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: root.tint
            }
        }

        Column {
            id: column

            Layout.fillWidth: true
            spacing: Config.spacing

            // ========== HEADER ==========
            RowLayout {
                width: column.width
                spacing: Config.padding

                Text {
                    Layout.maximumWidth: column.width / 2
                    text: root.appName
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: root.critical ? Config.errorColor : Config.subtextColor
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.notifs.length > 1
                    text: "· " + root.notifs.length
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                // md-chevron_up / md-chevron_down
                NotificationIconButton {
                    visible: root.notifs.length > 1
                    icon: root.expanded ? "\u{f0143}" : "\u{f0140}"
                    onClicked: {
                        if (root.preview)
                            root.openRequested();
                        else
                            root.expanded = !root.expanded;
                    }
                }

                MenuButton {
                    id: groupMenuButton
                    onClicked: groupMenu.openAt(groupMenuButton, root.appName)
                }
            }

            // ========== ROWS ==========
            Repeater {
                model: ScriptModel {
                    values: root.expanded ? root.notifs : root.notifs.slice(0, 1)
                }

                NotificationRow {
                    required property var modelData
                    width: column.width
                    notif: modelData
                    onActionTriggered: root.actionTriggered()
                }
            }
        }
    }

    ContextMenu {
        id: groupMenu

        items: [
            {
                label: root.notifs.length > 1 ? "Dismiss all " + root.notifs.length : "Dismiss",
                // md-notification_clear_all
                icon: "\u{f039f}",
                action: "dismiss",
                danger: true
            }
        ]

        onTriggered: action => {
            if (action === "dismiss")
                NotificationService.dismissGroup(root.appName);
        }
    }
}
