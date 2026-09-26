pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Shared base of the workspace styles: a row of slots showing `count`
// workspaces, scrolling only when the active one leaves them, with an accent
// indicator that slides to the active slot (its leading edge quick, its tail
// lagging, so it stretches along the way). Styles set the slot widths and
// the `slotContent` drawn in each slot, above the indicator.
Item {
    id: root

    required property WorkspacesModel model
    property int count: 10

    // Width of slot `index`; styles override it (it may read the model, e.g.
    // to fit a workspace's app icons)
    property var slotWidth: (index, active) => active ? activeWidth : itemWidth
    property int itemWidth: Config.fontSizeSmall + Math.round(Config.padding / 2)
    property int activeWidth: itemWidth * 2
    property int itemSpacing: Math.round(Config.padding * 2 / 3)

    // Created in every slot with `slot` set to it (index, workspaceId,
    // isActive, isEmpty, isUrgent, hovered)
    property Component slotContent: null
    // Slot content drawn over the indicator (labels) or under it (shapes the
    // indicator should cover as it slides)
    property bool contentOverIndicator: true
    // Created once under the indicator with `strip` set to this item, for
    // styles that draw across slots
    property Component underlay: null

    property int indicatorHeight: Config.fontSizeSmall + Config.padding
    property int indicatorRadius: Config.radius
    property color indicatorColor: Config.accentColor

    readonly property int activeIndex: model.relativeActiveId - 1
    readonly property int total: model.totalWorkspaces

    // Left edge of every slot, plus the end of the last one
    readonly property var xs: {
        let out = [];
        let x = 0;
        for (let i = 0; i < total; i++) {
            out.push(x);
            x += slotWidth(i, i === activeIndex) + itemSpacing;
        }
        out.push(x);
        return out;
    }

    function slotX(index) {
        return xs[Math.max(0, Math.min(index, total))];
    }
    // Right edge of slot `index`
    function slotEnd(index) {
        return slotX(index + 1) - itemSpacing;
    }

    implicitWidth: slotEnd(firstVisible + count - 1) - slotX(firstVisible)
    // Same height in every style, so small shapes keep a comfortable hit area
    implicitHeight: Config.fontSizeSmall + Config.padding + Math.round(Config.padding * 2 / 3)
    clip: true

    // --- Scroll Logic ---
    // First slot in view; switching within the window never moves the strip
    property int firstVisible: 0
    function scrollToActive() {
        let first = firstVisible;
        if (activeIndex < first)
            first = activeIndex;
        else if (activeIndex > first + count - 1)
            first = activeIndex - count + 1;
        firstVisible = Math.max(0, Math.min(first, total - count));
    }

    // --- Indicator Placement ---
    // Batched with callLater: a switch changes both activeIndex and xs, and
    // the direction must be read once, against the previous index
    function placeIndicator() {
        indicator.direction = Math.sign(activeIndex - indicator.lastIndex);
        indicator.lastIndex = activeIndex;
        indicator.leftEdge = slotX(activeIndex);
        indicator.rightEdge = slotEnd(activeIndex);
    }

    onActiveIndexChanged: {
        scrollToActive();
        Qt.callLater(placeIndicator);
    }
    onXsChanged: Qt.callLater(placeIndicator)
    onCountChanged: scrollToActive()
    Component.onCompleted: scrollToActive()

    Item {
        id: content
        x: -root.slotX(root.firstVisible)
        width: root.slotX(root.total)
        height: parent.height

        // Same timing as the indicator, so strip and pill move together
        Behavior on x {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Loader {
            anchors.fill: parent
            active: root.underlay !== null
            sourceComponent: root.underlay
            onLoaded: item.strip = root
        }

        Rectangle {
            id: indicator

            // Set by placeIndicator(), so the direction is known before the
            // edges move
            property real leftEdge: root.slotX(root.activeIndex)
            property real rightEdge: root.slotEnd(root.activeIndex)
            // -1 left, 1 right, 0 same slot (a resize): both edges ease alike
            property int direction: 0
            property int lastIndex: 0
            Component.onCompleted: lastIndex = root.activeIndex

            readonly property int fast: Math.round(Config.animDuration * 0.6)
            readonly property int slow: Config.animDuration

            z: 1
            x: leftEdge
            width: rightEdge - leftEdge
            height: root.indicatorHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: root.indicatorRadius
            color: root.indicatorColor

            Behavior on leftEdge {
                NumberAnimation {
                    duration: indicator.direction < 0 ? indicator.fast : indicator.slow
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on rightEdge {
                NumberAnimation {
                    duration: indicator.direction > 0 ? indicator.fast : indicator.slow
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
        }

        Repeater {
            model: root.total
            delegate: Item {
                id: slot
                required property int index
                readonly property int workspaceId: root.model.monitorOffset + index + 1
                readonly property bool isActive: index === root.activeIndex
                readonly property bool isEmpty: !root.model.isOccupied(workspaceId)
                readonly property bool isUrgent: root.model.isUrgent(workspaceId)
                readonly property bool hovered: hover.hovered

                z: root.contentOverIndicator ? 2 : 0
                x: root.slotX(index)
                width: root.slotWidth(index, isActive)
                height: parent.height
                opacity: !isActive && hovered ? 0.8 : 1.0

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
                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Component.onCompleted: root.slotContent?.createObject(slot, {
                    slot: slot
                })

                TapHandler {
                    onTapped: root.model.focus(slot.workspaceId)
                }

                HoverHandler {
                    id: hover
                    cursorShape: slot.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
            }
        }
    }
}
