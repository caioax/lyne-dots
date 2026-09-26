pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Pill strip: the active slot is wider and an accent indicator slides to it,
// stretching toward the new workspace before its tail catches up. Occupied
// pills are solid, empty ones faint. Shows `count` pills and scrolls only
// when the active workspace leaves them.
Item {
    id: root

    required property WorkspacesModel model
    property int count: 10

    readonly property int activeIndex: model.relativeActiveId - 1

    // --- Sizing Properties ---
    readonly property int itemWidth: Config.fontSizeSmall + Math.round(Config.padding / 2)
    readonly property int itemHeight: itemWidth
    readonly property int activeWidth: itemWidth * 2
    readonly property int activeHeight: Config.fontSizeSmall + Config.padding
    readonly property int itemSpacing: Math.round(Config.padding * 2 / 3)
    readonly property real itemStep: itemWidth + itemSpacing

    implicitWidth: (itemWidth * count) + (activeWidth - itemWidth) + (itemSpacing * (count - 1))
    implicitHeight: activeHeight + itemSpacing
    clip: true

    function slotX(index) {
        return index * itemStep + (index > activeIndex ? activeWidth - itemWidth : 0);
    }

    // --- Scroll Logic ---
    // First pill in view; switching within the window never moves the strip
    property int firstVisible: 0
    function scrollToActive() {
        let first = firstVisible;
        if (activeIndex < first)
            first = activeIndex;
        else if (activeIndex > first + count - 1)
            first = activeIndex - count + 1;
        firstVisible = Math.max(0, Math.min(first, model.totalWorkspaces - count));
    }

    // --- Sliding Indicator ---
    // Its edges animate separately: the leading edge is quick and the
    // trailing one lags, so the pill stretches along the way
    function placeIndicator() {
        indicator.movingRight = activeIndex > indicator.lastIndex;
        indicator.lastIndex = activeIndex;
        indicator.leftEdge = slotX(activeIndex);
        indicator.rightEdge = slotX(activeIndex) + activeWidth;
    }

    onActiveIndexChanged: {
        scrollToActive();
        placeIndicator();
    }
    onCountChanged: scrollToActive()
    onItemStepChanged: placeIndicator()
    onActiveWidthChanged: placeIndicator()
    Component.onCompleted: scrollToActive()

    Item {
        id: strip
        x: -root.firstVisible * root.itemStep
        width: (root.model.totalWorkspaces * root.itemStep) + (root.activeWidth - root.itemWidth)
        height: parent.height

        // Same timing as the indicator, so strip and pill move together
        Behavior on x {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root.model.totalWorkspaces
            delegate: Rectangle {
                id: pill
                required property int index
                readonly property int workspaceId: root.model.monitorOffset + index + 1
                readonly property bool isActive: index === root.activeIndex
                readonly property bool isEmpty: !root.model.isOccupied(workspaceId)

                x: root.slotX(index)
                anchors.verticalCenter: parent.verticalCenter
                width: isActive ? root.activeWidth : root.itemWidth
                height: root.itemHeight
                radius: Config.radius
                color: !isEmpty ? Config.surface3Color : Qt.alpha(Config.surface2Color, 0.65)
                opacity: !isActive && hover.hovered ? 0.8 : 1.0

                // Same timing as the indicator, so the slots open as it arrives
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
                    onTapped: root.model.focus(pill.workspaceId)
                }

                HoverHandler {
                    id: hover
                    cursorShape: pill.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
            }
        }

        Rectangle {
            id: indicator

            // Set by placeIndicator(), so the direction is known before the
            // edges move
            property real leftEdge: root.slotX(root.activeIndex)
            property real rightEdge: root.slotX(root.activeIndex) + root.activeWidth
            property bool movingRight: true
            property int lastIndex: 0
            Component.onCompleted: lastIndex = root.activeIndex

            readonly property int fast: Math.round(Config.animDuration * 0.6)
            readonly property int slow: Config.animDuration

            x: leftEdge
            width: rightEdge - leftEdge
            height: root.activeHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: Config.radius
            color: Config.accentColor

            Behavior on leftEdge {
                NumberAnimation {
                    duration: indicator.movingRight ? indicator.slow : indicator.fast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on rightEdge {
                NumberAnimation {
                    duration: indicator.movingRight ? indicator.fast : indicator.slow
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
