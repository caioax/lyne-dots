pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// One notification of a history group: summary, body preview and the image
// as a thumbnail on the right (so text columns stay aligned). Clicking
// expands it with the full text, action chips and inline reply; ⋮ on hover
// offers the actions, copy and dismiss.
Item {
    id: root

    required property var notif
    property bool expanded: false

    signal actionTriggered

    readonly property int thumbSize: Config.fontSizeIconSmall * 2
    readonly property bool hasImage: notif.image !== "" && thumbImage.status !== Image.Error
    // Default action first (as "Open"): a click here only expands the row
    readonly property var actions: {
        const def = notif.defaultAction;
        return def ? [def, ...notif.buttonActions] : notif.buttonActions;
    }
    readonly property bool expandable: expanded || summary.truncated || body.truncated || actions.length > 0 || notif.hasInlineReply
    readonly property bool active: hover.hovered || menu.opened

    implicitHeight: row.implicitHeight

    HoverHandler {
        id: hover
    }

    // Hover highlight, bleeding into the card padding like DeviceRow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Config.padding
        radius: Config.radius
        color: Config.surface1Color
        opacity: root.active ? 0.6 : 0

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
        id: row

        width: parent.width
        spacing: Config.spacing

        // A Column (not a ColumnLayout) so wrapped text reports its real height
        Column {
            id: texts

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Math.round(Config.padding / 2)

            RowLayout {
                width: texts.width
                spacing: Config.padding

                Text {
                    id: summary
                    Layout.fillWidth: true
                    text: root.notif.summary
                    textFormat: Text.StyledText
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: root.notif.isCritical ? Config.errorColor : Config.textColor
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? undefined : 1
                    elide: Text.ElideRight
                }

                // Time, swapped for ⋮ on hover
                Item {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Math.max(time.implicitWidth, menuButton.implicitWidth)
                    implicitHeight: Math.max(summary.font.pixelSize * 1.3, time.implicitHeight)

                    Text {
                        id: time
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.active
                        text: NotificationService.relativeTime(root.notif.time)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }

                    MenuButton {
                        id: menuButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.active
                        onClicked: menu.openAt(menuButton, root.notif)
                    }
                }
            }

            Text {
                id: body
                visible: text !== ""
                width: texts.width
                text: root.notif.body
                textFormat: Text.StyledText
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                linkColor: Config.accentColor
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? undefined : 2
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)

                HoverHandler {
                    cursorShape: body.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            // Chips below the text, with a little air above them
            Item {
                visible: root.expanded && root.actions.length > 0
                width: texts.width
                height: chips.implicitHeight + Config.padding

                NotificationActions {
                    id: chips
                    anchors.bottom: parent.bottom
                    notif: root.notif
                    includeDefault: true
                    compact: true
                    onTriggered: root.actionTriggered()
                }
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

        ClippingRectangle {
            visible: root.hasImage
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.thumbSize
            implicitHeight: root.thumbSize
            radius: Config.radius
            color: Config.surface1Color

            Image {
                id: thumbImage
                anchors.fill: parent
                source: NotificationService.iconSource(root.notif.image)
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.thumbSize * 2, root.thumbSize * 2)
                asynchronous: true
                mipmap: true
            }
        }
    }

    ContextMenu {
        id: menu

        items: [
            ...root.actions.map((a, i) => ({
                        label: a.text || "Open",
                        // md-open_in_new
                        icon: "\u{f03cc}",
                        action: "invoke:" + i
                    })),
            {
                label: "Copy text",
                // md-content_copy
                icon: "\u{f018f}",
                action: "copy"
            },
            {
                label: "Dismiss",
                // md-close
                icon: "\u{f0156}",
                action: "dismiss",
                danger: true
            }
        ]

        onTriggered: action => {
            if (action.startsWith("invoke:")) {
                root.notif.invokeAction(root.actions[Number(action.slice(7))]);
                root.actionTriggered();
            } else if (action === "copy") {
                // Summary and body are StyledText: copy them without the markup
                const text = [root.notif.summary, root.notif.body].filter(t => t !== "").join("\n").replace(/<[^>]*>/g, "");
                Quickshell.execDetached(["wl-copy", "--", text]);
            } else if (action === "dismiss") {
                root.notif.close();
            }
        }
    }
}
