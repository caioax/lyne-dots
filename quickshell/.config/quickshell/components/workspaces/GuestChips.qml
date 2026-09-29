pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Workspaces of other monitors shown on this one (their monitor is
// disconnected; they go back when it returns): a thin divider, the owner
// monitor's icon and one chip per workspace with its number in that
// monitor's block. The active one sits on an accent pill.
Row {
    id: root

    required property WorkspacesModel model
    readonly property bool shown: model.guests.length > 0

    readonly property int chipHeight: Config.fontSizeSmall + Config.padding
    readonly property int chipMinWidth: Math.round(Config.fontSizeSmall * 1.5)

    spacing: Math.round(Config.padding / 3)

    Rectangle {
        width: 1
        height: Config.fontSizeSmall
        anchors.verticalCenter: parent.verticalCenter
        color: Config.surface2Color
    }

    // Spacer after the divider
    Item {
        width: Math.round(Config.padding / 3)
        height: 1
    }

    Repeater {
        model: root.model.guests

        Row {
            id: guest

            required property var modelData
            required property int index

            readonly property bool active: root.model.activeId === modelData.id
            // The owner's icon starts each group
            readonly property bool firstOfOwner: index === 0 || root.model.guests[index - 1].owner?.slot !== modelData.owner?.slot

            spacing: Math.round(Config.padding / 3)
            anchors.verticalCenter: parent?.verticalCenter

            // md-laptop / md-monitor
            Text {
                visible: guest.firstOfOwner
                anchors.verticalCenter: parent.verticalCenter
                text: WorkspacesService.isInternal(guest.modelData.owner) ? "\u{f0322}" : "\u{f0379}"
                font {
                    family: Config.font
                    pixelSize: Config.fontSizeNormal
                }
                color: Config.subtextColor
            }

            Rectangle {
                id: chip

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(root.chipMinWidth, label.implicitWidth + Config.padding)
                height: root.chipHeight
                radius: Config.radius
                color: guest.active ? Config.accentColor : hover.hovered ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

                Behavior on color {
                    enabled: !Config.themeTransitioning
                    ColorAnimation {
                        duration: Config.animDuration
                    }
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: guest.modelData.position
                    font {
                        family: Config.font
                        pixelSize: Config.fontSizeSmall
                        bold: guest.active
                    }
                    color: guest.active ? Config.textReverseColor : Config.textColor
                }

                TapHandler {
                    onTapped: root.model.focus(guest.modelData.id)
                }
                HoverHandler {
                    id: hover
                    cursorShape: guest.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
            }
        }
    }
}
