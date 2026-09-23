pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// One line of a history group: avatar, summary + body preview and time.
// Clicking expands it with the full text, actions and inline reply.
Item {
    id: root

    required property var notif
    property bool expanded: false

    signal actionTriggered

    readonly property int avatarSize: Config.fontSizeNormal * 2
    readonly property bool hasAvatar: notif.image !== "" && avatarImage.status !== Image.Error

    implicitHeight: Math.max(hasAvatar ? avatarSize : 0, texts.implicitHeight, trailing.height)

    HoverHandler {
        id: hover
    }

    // Hover highlight, bleeding into the group padding
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Math.round(Config.padding / 2)
        anchors.leftMargin: -Config.padding
        anchors.rightMargin: -Config.padding
        radius: Config.radiusSmall
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    ClippingRectangle {
        id: avatar
        visible: root.hasAvatar
        width: root.avatarSize
        height: root.avatarSize
        radius: width / 2
        color: Config.surface1Color

        Image {
            id: avatarImage
            anchors.fill: parent
            source: NotificationService.iconSource(root.notif.image)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.avatarSize * 2, root.avatarSize * 2)
            asynchronous: true
        }
    }

    Column {
        id: texts

        anchors.left: root.hasAvatar ? avatar.right : parent.left
        anchors.leftMargin: root.hasAvatar ? Config.spacing : 0
        anchors.right: trailing.left
        anchors.rightMargin: Config.spacing
        // Collapsed next to an avatar, the single line sits in the middle of it
        y: !root.expanded && root.hasAvatar ? (root.avatarSize - preview.height) / 2 : 0
        spacing: Config.padding

        // Collapsed: "Summary  body…" on one line
        Text {
            id: preview
            visible: !root.expanded
            width: texts.width
            text: "<b><font color='" + Config.textColor + "'>" + root.notif.summary + "</font></b>  " + root.notif.body.replace(/\n+/g, " ")
            textFormat: Text.StyledText
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Text {
            visible: root.expanded
            width: texts.width
            text: root.notif.summary
            textFormat: Text.StyledText
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
            wrapMode: Text.Wrap
        }

        Text {
            id: body
            visible: root.expanded && text !== ""
            width: texts.width
            text: root.notif.body
            textFormat: Text.StyledText
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
            linkColor: Config.accentColor
            wrapMode: Text.Wrap
            onLinkActivated: link => Qt.openUrlExternally(link)

            HoverHandler {
                cursorShape: body.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        NotificationActions {
            visible: root.expanded && actions.length > 0
            width: texts.width
            notif: root.notif
            includeDefault: true
            onTriggered: root.actionTriggered()
        }

        NotificationReply {
            visible: root.expanded && root.notif.hasInlineReply
            width: texts.width
            placeholder: root.notif.inlineReplyPlaceholder || "Reply"
            onSubmitted: text => {
                root.notif.sendReply(text);
                root.actionTriggered();
            }
        }
    }

    // Time, swapped for a dismiss button on hover
    Item {
        id: trailing

        anchors.right: parent.right
        y: texts.y + (preview.visible ? (preview.height - height) / 2 : 0)
        width: Math.max(time.implicitWidth, dismiss.implicitWidth)
        height: dismiss.implicitHeight

        Text {
            id: time
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !hover.hovered
            text: NotificationService.relativeTime(root.notif.time)
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        NotificationIconButton {
            id: dismiss
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: hover.hovered
            icon: "󰅖"
            onClicked: root.notif.close()
        }
    }
}
