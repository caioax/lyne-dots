pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Pill strip: the active workspace grows into a wider accent pill, occupied
// ones are solid and empty ones faint. Scrolls only when the active
// workspace leaves the visible window.
Item {
    id: root

    required property WorkspacesModel model
    property int visibleCount: 9

    // --- Sizing Properties ---
    readonly property int itemWidth: Config.fontSizeSmall + Math.round(Config.padding / 2)
    readonly property int itemHeight: itemWidth
    readonly property int activeWidth: itemWidth * 2
    readonly property int activeHeight: Config.fontSizeSmall + Config.padding
    readonly property int itemSpacing: Math.round(Config.padding * 2 / 3)
    readonly property real itemStep: itemWidth + itemSpacing

    readonly property real viewportWidth: (itemWidth * visibleCount) + (activeWidth - itemWidth) + (itemSpacing * (visibleCount - 1))

    implicitWidth: viewportWidth
    implicitHeight: activeHeight + itemSpacing
    clip: true

    // --- Scroll Logic ---
    readonly property int targetIndex: model.relativeActiveId - 1

    // The strip only scrolls when the active workspace leaves the visible
    // window, so switching among 1-9 never moves the other pills
    property int firstVisible: 0
    onTargetIndexChanged: {
        if (targetIndex < firstVisible)
            firstVisible = targetIndex;
        else if (targetIndex > firstVisible + visibleCount - 1)
            firstVisible = Math.min(targetIndex - visibleCount + 1, model.totalWorkspaces - visibleCount);
    }

    property real animatedScrollX: firstVisible * itemStep
    Behavior on animatedScrollX {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: container
        x: -root.animatedScrollX
        width: (root.model.totalWorkspaces * root.itemStep) + (root.activeWidth - root.itemWidth)
        height: parent.height

        Repeater {
            model: root.model.totalWorkspaces
            delegate: Rectangle {
                id: workspaceItem
                required property int index
                readonly property int workspaceId: root.model.monitorOffset + index + 1
                readonly property bool isActive: workspaceId === root.model.activeId
                readonly property bool isEmpty: !root.model.isOccupied(workspaceId)

                x: (index > root.targetIndex) ? (index * root.itemStep) + (root.activeWidth - root.itemWidth) : (index * root.itemStep)
                anchors.verticalCenter: parent.verticalCenter
                width: isActive ? root.activeWidth : root.itemWidth
                height: isActive ? root.activeHeight : root.itemHeight
                radius: Config.radius
                color: isActive ? Config.accentColor : (!isEmpty ? Config.surface3Color : Qt.alpha(Config.surface2Color, 0.65))
                opacity: !isActive ? (workspaceHover.hovered ? 0.8 : 1.0) : 1

                // Same timing as the strip scroll, so pill and strip move together
                Behavior on x {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDuration
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                TapHandler {
                    onTapped: root.model.focus(workspaceItem.workspaceId)
                }

                HoverHandler {
                    id: workspaceHover
                    cursorShape: workspaceItem.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
            }
        }
    }
}
