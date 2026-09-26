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
    // Only workspaces with windows (and the active one) get a slot; the
    // others collapse and nothing scrolls
    property bool hideEmpty: false

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
    // Horizontal gap between the indicator and its slot's edges
    property int indicatorInset: 0
    property color indicatorColor: Config.accentColor

    readonly property int activeIndex: model.relativeActiveId - 1
    readonly property int total: model.totalWorkspaces

    function isShown(index) {
        return !hideEmpty || index === activeIndex || model.isOccupied(model.monitorOffset + index + 1);
    }

    // Left edge (xs, plus the end of the last slot) and width (ws) of every
    // slot; hidden slots take no width and no gap
    readonly property var layout: {
        let xs = [];
        let ws = [];
        let x = 0;
        for (let i = 0; i < total; i++) {
            const w = isShown(i) ? slotWidth(i, i === activeIndex) : 0;
            xs.push(x);
            ws.push(w);
            if (w > 0)
                x += w + itemSpacing;
        }
        xs.push(x);
        return {
            xs: xs,
            ws: ws
        };
    }

    function slotX(index) {
        return layout.xs[Math.max(0, Math.min(index, total))];
    }
    // Right edge of slot `index`
    function slotEnd(index) {
        return index < 0 || index >= total ? slotX(index) : slotX(index) + layout.ws[index];
    }

    implicitWidth: hideEmpty ? Math.max(0, slotX(total) - itemSpacing) : slotEnd(firstVisible + count - 1) - slotX(firstVisible)
    // Eases the bar around a style whose slots change size (app icons)
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    // Same height in every style, so small shapes keep a comfortable hit area
    implicitHeight: Config.fontSizeSmall + Config.padding + Math.round(Config.padding * 2 / 3)
    clip: true

    // --- Scroll Logic ---
    // First slot in view; switching within the window never moves the strip
    property int firstVisible: 0
    function scrollToActive() {
        if (hideEmpty) {
            firstVisible = 0;
            return;
        }
        let first = firstVisible;
        if (activeIndex < first)
            first = activeIndex;
        else if (activeIndex > first + count - 1)
            first = activeIndex - count + 1;
        firstVisible = Math.max(0, Math.min(first, total - count));
    }

    // --- Indicator Placement ---
    // Batched on a zero timer: a switch changes both activeIndex and layout,
    // and the direction must be read once, against the previous index (a
    // timer rather than Qt.callLater, which could fire after a style swap
    // destroyed this strip)
    function placeIndicator() {
        indicator.direction = Math.sign(activeIndex - indicator.lastIndex);
        indicator.lastIndex = activeIndex;
        indicator.leftEdge = slotX(activeIndex) + indicatorInset;
        indicator.rightEdge = slotEnd(activeIndex) - indicatorInset;
    }

    Timer {
        id: placeTimer
        interval: 0
        onTriggered: root.placeIndicator()
    }

    onActiveIndexChanged: {
        scrollToActive();
        placeTimer.restart();
    }
    onLayoutChanged: placeTimer.restart()
    onCountChanged: scrollToActive()
    onHideEmptyChanged: scrollToActive()
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
            property real leftEdge: root.slotX(root.activeIndex) + root.indicatorInset
            property real rightEdge: root.slotEnd(root.activeIndex) - root.indicatorInset
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
                readonly property bool shown: root.isShown(index)

                z: root.contentOverIndicator ? 2 : 0
                x: root.slotX(index)
                width: root.layout.ws[index]
                height: parent.height
                visible: opacity > 0
                opacity: !shown ? 0 : !isActive && hovered ? 0.8 : 1.0

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

                // Urgent: a pulsing error pill, over the slot's shape (styles
                // whose content sits under the indicator) or under its label
                Rectangle {
                    z: root.contentOverIndicator ? -1 : 1
                    anchors.centerIn: parent
                    width: parent.width
                    height: root.indicatorHeight
                    radius: root.indicatorRadius
                    color: Config.errorColor
                    visible: slot.isUrgent && !slot.isActive
                    opacity: 0

                    SequentialAnimation on opacity {
                        running: slot.isUrgent && !slot.isActive
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 1
                            duration: Config.animDurationLong
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0.35
                            duration: Config.animDurationLong
                            easing.type: Easing.InOutSine
                        }
                    }
                }

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
