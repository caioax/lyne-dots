pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Panel that grows out of a screen edge or the bar, like a drawer: the sides
// in `edges` are flush (square corners, no border) and every end of a flush
// side that doesn't meet another flush side gets a concave fillet
// (ConcaveCorner) flowing into that edge. It slides out from behind the
// first edge in `edges`, clipped there.
//
// The item's geometry is the panel body; the fillets hang outside it. Put the
// content in it (`body` is the parent of the children)
Item {
    id: root

    // Flush sides: "top", "bottom", "left", "right". The first one is the
    // edge the panel slides out of
    property var edges: ["top"]
    property bool shown: false
    property color color: Config.backgroundTransparentColor
    // Radius of the free corners
    property real radius: Config.radiusLarge
    property real filletSize: Config.radiusLarge

    default property alias content: body.data
    readonly property alias body: body

    readonly property bool _top: edges.includes("top")
    readonly property bool _bottom: edges.includes("bottom")
    readonly property bool _left: edges.includes("left")
    readonly property bool _right: edges.includes("right")
    readonly property string _main: edges[0] ?? "top"

    // Fillets: square at (x, y) with the filled corner touching both the
    // flush side and the panel. ConcaveCorner fills its top-left by default;
    // mirrored → top-right, flipped → bottom-left, both → bottom-right
    readonly property var _fillets: {
        const s = filletSize;
        const w = width;
        const h = height;
        const list = [];
        const add = (x, y, mirrored, flipped) => list.push({
                x: x,
                y: y,
                mirrored: mirrored,
                flipped: flipped
            });
        if (_top) {
            if (!_left)
                add(-s, 0, true, false);
            if (!_right)
                add(w, 0, false, false);
        }
        if (_bottom) {
            if (!_left)
                add(-s, h - s, true, true);
            if (!_right)
                add(w, h - s, false, true);
        }
        if (_left) {
            if (!_top)
                add(0, -s, false, true);
            if (!_bottom)
                add(0, h, false, false);
        }
        if (_right) {
            if (!_top)
                add(w - s, -s, true, true);
            if (!_bottom)
                add(w - s, h, true, false);
        }
        return list;
    }

    // 0 = hidden behind the main edge, 1 = out
    property real _progress: 0
    property bool _ready: false
    Component.onCompleted: Qt.callLater(() => _ready = true)

    on_ReadyChanged: _progress = Qt.binding(() => root.shown && root._ready ? 1 : 0)

    Behavior on _progress {
        NumberAnimation {
            duration: root.shown ? Config.animDurationLong : Config.animDuration
            easing.type: Config.animPopupEasing
        }
    }

    // Clips at the main edge, with room for the fillets on the other sides
    Item {
        id: clipper

        readonly property real s: root.filletSize

        x: root._main === "left" ? 0 : -s
        y: root._main === "top" ? 0 : -s
        width: root.width + (root._main === "left" || root._main === "right" ? s : s * 2)
        height: root.height + (root._main === "top" || root._main === "bottom" ? s : s * 2)
        clip: true

        Item {
            id: slide

            // How far the panel travels to get fully behind the main edge
            readonly property real hiddenOffset: (root._main === "top" || root._main === "bottom" ? root.height : root.width) + clipper.s
            readonly property real offset: (1 - root._progress) * hiddenOffset

            x: -clipper.x + (root._main === "left" ? -offset : root._main === "right" ? offset : 0)
            y: -clipper.y + (root._main === "top" ? -offset : root._main === "bottom" ? offset : 0)
            width: root.width
            height: root.height
            opacity: Math.min(1, root._progress * 2)

            Repeater {
                model: root._fillets

                ConcaveCorner {
                    required property var modelData

                    x: modelData.x
                    y: modelData.y
                    size: root.filletSize
                    color: root.color
                    mirrored: modelData.mirrored
                    flipped: modelData.flipped
                }
            }

            Rectangle {
                id: body

                anchors.fill: parent
                color: root.color
                topLeftRadius: root._top || root._left ? 0 : root.radius
                topRightRadius: root._top || root._right ? 0 : root.radius
                bottomLeftRadius: root._bottom || root._left ? 0 : root.radius
                bottomRightRadius: root._bottom || root._right ? 0 : root.radius
            }
        }
    }
}
