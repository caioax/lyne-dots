pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Icon, texts, action buttons and inline reply of one notification.
// Shared by the popups and the history groups.
ColumnLayout {
    id: root

    required property var notif
    property bool showIcon: true
    property bool showAppName: true
    property bool expanded: false
    default property alias trailing: trailingSlot.data

    readonly property bool canExpand: expanded || summaryText.truncated || bodyText.truncated
    readonly property bool replyFocused: reply.inputFocused
    readonly property bool replyWantsKeyboard: reply.wantsKeyboard
    readonly property color tint: notif.isCritical ? Config.errorColor : Config.accentColor

    // An action was invoked or a reply was sent
    signal actionTriggered

    spacing: Config.spacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing + Config.padding

        NotificationIcon {
            visible: root.showIcon
            Layout.alignment: Qt.AlignTop
            notif: root.notif
        }

        // A Column (not a ColumnLayout) so wrapped text reports its real height
        Column {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Math.round(Config.padding / 3)

            // App name · time, expand and trailing buttons
            RowLayout {
                width: texts.width
                spacing: Config.padding

                Text {
                    visible: root.showAppName
                    Layout.maximumWidth: root.width / 2
                    text: root.notif.appName
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: root.tint
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.showAppName
                    text: "•"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Text {
                    text: NotificationService.relativeTime(root.notif.time)
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                NotificationIconButton {
                    visible: root.canExpand
                    icon: "󰅀"
                    rotation: root.expanded ? 180 : 0
                    onClicked: root.expanded = !root.expanded

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                RowLayout {
                    id: trailingSlot
                    spacing: Config.padding
                }
            }

            Text {
                id: summaryText
                width: texts.width
                visible: text !== ""
                text: root.notif.summary
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? undefined : 1
                elide: Text.ElideRight
            }

            Text {
                id: bodyText
                width: texts.width
                visible: text !== ""
                text: root.notif.body
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? undefined : 2
                elide: Text.ElideRight
                linkColor: root.tint
                onLinkActivated: link => Qt.openUrlExternally(link)

                HoverHandler {
                    cursorShape: bodyText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            // Progress hint (volume, downloads...)
            Item {
                visible: root.notif.progressValue >= 0
                width: texts.width
                height: track.height + Config.padding

                Rectangle {
                    id: track
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.round(Config.padding * 2 / 3)
                    radius: height / 2
                    color: Config.surface1Color
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width * root.notif.progressValue / 100
                    height: track.height
                    radius: height / 2
                    color: root.tint

                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    NotificationActions {
        Layout.fillWidth: true
        notif: root.notif
        onTriggered: root.actionTriggered()
    }

    NotificationReply {
        id: reply
        visible: root.notif.hasInlineReply
        Layout.fillWidth: true
        placeholder: root.notif.inlineReplyPlaceholder || "Reply"
        onSubmitted: text => {
            root.notif.sendReply(text);
            root.actionTriggered();
        }
    }
}
