pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// One conversation of the history (an app's notifications with the same
// summary: a chat's sender, a recurring alert): the picture on the left with
// the app as a badge, "Name • time" on top and the newest message below; the
// pill on the right (count and chevron) or a click opens all of them, oldest
// first, with the newest one's actions and reply. The X (on hover)
// dismisses the conversation.
Item {
    id: root

    required property string key
    property bool expanded: false

    signal actionTriggered

    // Newest first
    readonly property var notifs: NotificationService.conversationOf(key)
    readonly property var newest: notifs.length > 0 ? notifs[0] : null
    // The one still on D-Bus: its actions and reply serve the conversation
    readonly property var live: notifs.find(n => !n.frozen) ?? null
    readonly property bool critical: notifs.some(n => n.isCritical)
    readonly property int collapsedCount: 1
    // Oldest first, like a chat
    readonly property var shown: (expanded ? notifs : notifs.slice(0, collapsedCount)).slice().reverse()
    readonly property var actions: live ? live.listedActions : []
    readonly property bool hasMore: notifs.length > collapsedCount
    readonly property bool expandable: expanded || hasMore || truncated || actions.length > 0 || (live?.hasInlineReply ?? false)
    // Messages cut short right now (each one counts itself in and out)
    property int truncatedCount: 0
    readonly property bool truncated: truncatedCount > 0

    // Opening and closing ease the height; clipped only meanwhile, so the
    // hover highlight can bleed out at rest
    implicitHeight: layout.implicitHeight
    clip: heightAnim.running

    Behavior on implicitHeight {
        NumberAnimation {
            id: heightAnim
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hover
    }

    // Hover highlight, bleeding into the card padding
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Config.padding
        radius: Config.radius
        color: Config.surface1Color
        opacity: hover.hovered ? 0.6 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.expandable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    RowLayout {
        id: layout

        width: parent.width
        spacing: Config.spacing + Config.padding

        NotificationIcon {
            visible: root.newest !== null
            Layout.alignment: Qt.AlignTop
            notif: root.newest
        }

        // A Column (not a ColumnLayout) so wrapped text reports its real height
        Column {
            id: texts

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Math.round(Config.padding / 2)

            // ========== HEADER: Name • time (the badge shows the app) ==========
            RowLayout {
                width: texts.width
                spacing: Config.padding

                Text {
                    id: name
                    Layout.fillWidth: true
                    // Rounded up: a fraction short and the bold text elides
                    Layout.maximumWidth: Math.ceil(implicitWidth) + 1
                    visible: text !== ""
                    text: root.newest?.summary ?? ""
                    textFormat: Text.StyledText
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: root.critical ? Config.errorColor : Config.textColor
                    elide: Text.ElideRight
                }

                Text {
                    Layout.minimumWidth: implicitWidth
                    text: (name.visible ? "• " : (root.newest?.appName ?? "") + " • ") + (root.newest ? NotificationService.relativeTime(root.newest.time) : "")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                // The X (on hover): the line keeps its room, so nothing moves when it
                // shows, and the messages below use the whole width
                Item {
                    Layout.preferredWidth: closeButton.implicitWidth

                    // md-close: dismisses the whole conversation
                    MenuButton {
                        id: closeButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "\u{f0156}"
                        danger: true
                        visible: hover.hovered
                        onClicked: NotificationService.dismissConversation(root.key)
                    }
                }
            }

            // ========== MESSAGES ==========
            Repeater {
                model: ScriptModel {
                    values: root.shown
                }

                Message {
                    required property var modelData
                    width: texts.width
                    notif: modelData
                }
            }

            // Chips below the messages, with a little air above them
            Item {
                visible: root.expanded && root.actions.length > 0
                width: texts.width
                height: chips.implicitHeight + Config.padding

                NotificationActions {
                    id: chips
                    anchors.bottom: parent.bottom
                    notif: root.live ?? root.newest
                    includeDefault: true
                    compact: true
                    onTriggered: root.actionTriggered()
                }
            }

            NotificationReply {
                visible: root.expanded && (root.live?.hasInlineReply ?? false)
                width: texts.width
                placeholder: root.live?.inlineReplyPlaceholder || I18n.tr("Reply")
                onSubmitted: text => {
                    root.live.sendReply(text);
                    root.actionTriggered();
                }
            }
        }

        NotificationPill {
            visible: root.expandable
            Layout.alignment: Qt.AlignTop
            // Level with the picture's middle, open or closed: it doesn't jump
            Layout.topMargin: Math.max(0, Math.round((Config.notifImageSize - implicitHeight) / 2))
            count: root.notifs.length
            expanded: root.expanded
            onClicked: root.expanded = !root.expanded
        }
    }

    // One message: its text (or its summary when it has none)
    component Message: Text {
        id: message

        required property var notif

        visible: text !== ""
        text: notif.body !== "" ? notif.body : (root.newest?.summary === notif.summary ? "" : notif.summary)
        textFormat: Text.StyledText
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.subtextColor
        linkColor: Config.accentColor
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? undefined : 1
        elide: Text.ElideRight
        onLinkActivated: link => Qt.openUrlExternally(link)
        onTruncatedChanged: root.truncatedCount += truncated ? 1 : -1
        Component.onDestruction: if (truncated) root.truncatedCount--

        HoverHandler {
            cursorShape: message.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
