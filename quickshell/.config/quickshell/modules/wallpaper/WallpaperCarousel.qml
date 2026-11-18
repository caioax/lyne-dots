pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.config
import "../../components/"

// The wallpaper picker's row of tiles, the selected one in the middle and
// bigger. When the tiles overflow the width it loops (the last one is
// followed by the first again) and the tiles cut at the ends fade out; when
// they fit, they stand as a centered row.
//
// It keeps its own position (the item at the center, fractional while it
// moves) instead of a ListView: no snapping fights a flick, and a fixed set
// of slots is recycled, a tile changing its wallpaper only while it's out of
// sight at an end. Drag (with momentum) and clicks move the selection
// through selectRequested; the owner sets currentIndex
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property int tileWidth: Config.fontSizeNormal * 18
    readonly property int tileHeight: Math.round(tileWidth * 9 / 16)
    // Tiles beside the selected one are drawn smaller
    property real sideScale: 0.8

    signal selectRequested(int index)
    // A click on the selected tile
    signal activated
    signal menuRequested(Item anchor, string path)

    readonly property int count: model.length
    // The same gap between every two tiles, as drawn (scaled)
    readonly property real gap: Config.spacing * 2
    // From one side tile's center to the next
    readonly property real pitch: tileWidth * sideScale + gap
    // From the selected tile's center to a neighbor's
    readonly property real nearPitch: tileWidth * (1 + sideScale) / 2 + gap
    // The whole row laid out, as drawn
    readonly property real rowWidth: count > 0 ? tileWidth + (count - 1) * pitch : 0
    // Tiles the width shows whole, for PageUp/PageDown
    readonly property int visibleCount: Math.max(1, Math.floor((width - tileWidth) / pitch) + 1)
    readonly property bool looping: rowWidth > width
    // Slots from the middle to past an end, so a dragged row never shows a gap
    readonly property int _half: Math.ceil(width / 2 / pitch) + 1
    readonly property int _slots: looping ? Math.min(count, _half * 2 + 1) : count
    // Where tiles start fading at the ends (looping only)
    readonly property real fadeWidth: pitch * 0.6

    // Item at the center, as a virtual index (looping: any integer, item
    // _mod(v)); `_target` is where it's headed
    property real position: 0
    property real _target: 0

    implicitHeight: tileHeight

    function _mod(v: int): int {
        return count > 0 ? ((v % count) + count) % count : 0;
    }

    // Distance from the center of the tile at `position` to the center of
    // one `d` items away: a neighbor sits a near pitch away, the rest a
    // pitch apart, so the drawn gaps stay equal while the sizes change
    function _offset(d: real): real {
        const a = Math.abs(d);
        const f = a <= 1 ? a * nearPitch : nearPitch + (a - 1) * pitch;
        return d < 0 ? -f : f;
    }

    // The virtual index of `index` closest to where the row is headed
    function _nearest(index: int): int {
        if (!looping)
            return index;
        const base = Math.round(_target);
        let d = index - _mod(base);
        if (d > count / 2)
            d -= count;
        else if (d < -count / 2)
            d += count;
        return base + d;
    }

    function _goTo(v: real, animate: bool) {
        _target = v;
        slide.stop();
        if (animate) {
            slide.to = v;
            slide.start();
        } else {
            position = v;
        }
    }

    // A new list (filter, search) or layout: straight to the selection
    function _reset() {
        _goTo(Math.max(0, Math.min(count - 1, currentIndex)), false);
    }

    onCurrentIndexChanged: {
        if (!drag.active)
            _goTo(_nearest(currentIndex), true);
    }
    onModelChanged: _reset()
    onLoopingChanged: _reset()
    Component.onCompleted: _reset()

    NumberAnimation {
        id: slide

        target: root
        property: "position"
        duration: Config.animDuration
        easing.type: Easing.OutCubic
    }

    Item {
        id: row

        anchors.fill: parent
        clip: true
        // The ends fade out where tiles are cut
        layer.enabled: root.looping
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            // smoothstep(0, 1, mask alpha): the gradient as it is
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Repeater {
            model: root._slots

            Item {
                id: slot

                required property int index
                // Looping: the virtual index this slot holds, the one among
                // the shown range that falls on it. Otherwise slot = item
                readonly property int virtualIndex: {
                    if (!root.looping)
                        return index;
                    const low = Math.round(root.position) - root._half;
                    return low + ((index - low) % root._slots + root._slots) % root._slots;
                }
                readonly property int item: root._mod(virtualIndex)
                readonly property string path: root.model[item] ?? ""
                readonly property bool selected: item === root.currentIndex
                // 0 at the center, 1 a tile or more away
                readonly property real away: Math.min(1, Math.abs(virtualIndex - root.position))
                // Looping rows move under a fixed center. A centered row
                // keeps its width (one tile is big at any time) and its first
                // tile's place, the others following at equal gaps
                readonly property real centerX: {
                    if (root.looping)
                        return root.width / 2 + root._offset(virtualIndex - root.position);
                    const firstScale = 1 - (1 - root.sideScale) * Math.min(1, Math.abs(root.position));
                    const firstCenter = (root.width - root.rowWidth) / 2 + root.tileWidth * firstScale / 2;
                    return firstCenter + root._offset(index - root.position) - root._offset(-root.position);
                }

                x: Math.round(centerX - root.tileWidth / 2)
                width: root.tileWidth
                height: root.tileHeight

                WallpaperTile {
                    anchors.fill: parent
                    path: slot.path
                    current: slot.path === WallpaperService.currentWallpaper
                    highlighted: slot.selected
                    showName: false
                    scale: 1 - (1 - root.sideScale) * slot.away
                    opacity: 1 - 0.4 * slot.away

                    // First click selects, a click on the selected one applies it
                    onActivated: {
                        if (slot.selected) {
                            root.activated();
                        } else {
                            root._goTo(slot.virtualIndex, true);
                            root.selectRequested(slot.item);
                        }
                    }
                    onMenuRequested: anchor => root.menuRequested(anchor, slot.path)
                }
            }
        }
    }

    // Opaque in the middle, clear at both ends
    Item {
        id: fadeMask

        anchors.fill: parent
        visible: false
        layer.enabled: root.looping

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Config.textColor, 0)
                }
                GradientStop {
                    position: root.width > 0 ? root.fadeWidth / root.width : 0
                    color: Config.textColor
                }
                GradientStop {
                    position: root.width > 0 ? 1 - root.fadeWidth / root.width : 1
                    color: Config.textColor
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Config.textColor, 0)
                }
            }
        }
    }

    // Drag the row; let go and it carries on a little, settling on a tile
    DragHandler {
        id: drag

        property real startPosition: 0

        target: null
        yAxis.enabled: false
        enabled: root.count > 1

        onActiveChanged: {
            if (active) {
                slide.stop();
                startPosition = root.position;
                return;
            }
            // Momentum: where the speed would carry it in a moment, a few
            // tiles at most
            const carried = Math.max(-4, Math.min(4, -centroid.velocity.x * 0.1 / root.pitch));
            let v = Math.round(root.position + carried);
            if (!root.looping)
                v = Math.max(0, Math.min(root.count - 1, v));
            root._goTo(v, true);
            root.selectRequested(root._mod(v));
        }
        onTranslationChanged: {
            if (!active)
                return;
            let p = startPosition - translation.x / root.pitch;
            // A centered row gives a little past its ends
            if (!root.looping)
                p = Math.max(-0.3, Math.min(root.count - 0.7, p));
            root.position = p;
            root._target = p;
        }
    }
}
