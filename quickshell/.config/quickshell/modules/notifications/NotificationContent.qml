pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Icon, texts, action buttons and inline reply of one notification (the
// popups), looking like a history conversation: "Name • time", the newest
// message, and the pill that opens the earlier messages of the conversation.
ColumnLayout {
    id: root

    required property var notif
    property bool showIcon: true
    // The badge on the picture already shows the app
    property bool showAppName: false
    property bool expanded: false
    // The X shows (on the popup's hover) and was clicked
    property bool closeShown: false
    signal closeClicked

    // Earlier messages of its conversation, oldest first
    readonly property var earlier: NotificationService.conversationOf(NotificationService.conversationKey(notif)).filter(n => n !== notif && n.time.getTime() <= notif.time.getTime()).reverse()
    readonly property bool canExpand: expanded || summaryText.truncated || bodyText.truncated || earlier.length > 0
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
            showImage: !preview.wide
        }

        // A Column (not a ColumnLayout) so wrapped text reports its real height
        Column {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Math.round(Config.padding / 3)

            // Name • time (the badge shows the app)
            RowLayout {
                width: texts.width
                spacing: Config.padding

                // Shrinks first, the app and time keep their room
                Text {
                    id: summaryText
                    Layout.fillWidth: true
                    // Rounded up: a fraction short and the bold text elides
                    Layout.maximumWidth: Math.ceil(implicitWidth) + 1
                    visible: text !== ""
                    text: root.notif.summary
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: root.notif.isCritical ? Config.errorColor : Config.textColor
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                }

                Text {
                    Layout.minimumWidth: implicitWidth
                    text: [summaryText.visible ? "" : null, root.showAppName || !summaryText.visible ? root.notif.appName : null, NotificationService.relativeTime(root.notif.time)].filter(t => t !== null).join(" • ").trim()
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
                        visible: root.closeShown
                        onClicked: root.closeClicked()
                    }
                }
            }

            // Earlier messages, while open
            Repeater {
                model: root.expanded ? root.earlier : []

                Text {
                    required property var modelData
                    width: texts.width
                    visible: text !== ""
                    text: modelData.body
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    linkColor: root.tint
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
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

        NotificationPill {
            visible: root.canExpand
            Layout.alignment: Qt.AlignTop
            // Level with the picture's middle, open or closed: it doesn't jump
            Layout.topMargin: Math.max(0, Math.round((Config.notifImageSize - implicitHeight) / 2))
            count: root.earlier.length + 1
            expanded: root.expanded
            onClicked: root.expanded = !root.expanded
        }
    }

    // Images that aren't square (screenshots...) as a preview across the
    // card; square ones (covers, avatars) stay the round icon
    ClippingRectangle {
        id: preview

        readonly property real ratio: previewImage.implicitHeight > 0 ? previewImage.implicitWidth / previewImage.implicitHeight : 1
        readonly property bool wide: previewImage.status === Image.Ready && Math.abs(ratio - 1) > 0.15

        visible: wide
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(width / ratio, Config.notifImageSize * 4)
        radius: Config.radius
        color: Config.surface1Color

        Image {
            id: previewImage
            anchors.fill: parent
            source: NotificationService.iconSource(root.notif.image)
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Config.notifWidth * 2
            mipmap: true
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
        placeholder: root.notif.inlineReplyPlaceholder || I18n.tr("Reply")
        onSubmitted: text => {
            root.notif.sendReply(text);
            root.actionTriggered();
        }
    }
}
