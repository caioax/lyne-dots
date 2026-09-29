pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import "../../../services/monitors.js" as Lib

// Monitors laid out as Hyprland places them, scaled to fit. Drag one to
// move it: it snaps to the edges of the others and turns red where it would
// cover one (dropping there puts it back). Arrow keys move the selected one
// (Shift: 10× further), Tab picks the next. Only reports moves: the page
// owns the rules.
Item {
    id: root

    // One per rule: { x, y, width, height } in layout pixels, null for
    // monitors that take no room (off, mirroring, lid closed)
    property var rects: []
    // One per rule: { label, detail, internal }
    property var infos: []
    property int selected: -1
    property bool interactive: true

    signal picked(int index)
    signal moved(int index, int x, int y)

    // Snap distance on the map, in screen pixels
    readonly property real snapDistance: Config.spacing * 3
    readonly property real margin: Config.padding * 2

    readonly property var bounds: {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const r of rects) {
            if (!r)
                continue;
            minX = Math.min(minX, r.x);
            minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.width);
            maxY = Math.max(maxY, r.y + r.height);
        }
        if (minX === Infinity)
            return { x: 0, y: 0, width: 1920, height: 1080 };
        return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
    }
    // Map pixels per layout pixel, leaving room to drag a monitor beside the
    // others (15% of the layout on each side)
    readonly property real factor: Math.max(0.01, Math.min((width - margin * 2) / (bounds.width * 1.3), (height - margin * 2) / (bounds.height * 1.3)))
    readonly property real originX: (width - bounds.width * factor) / 2 - bounds.x * factor
    readonly property real originY: (height - bounds.height * factor) / 2 - bounds.y * factor

    function nudge(dx: int, dy: int) {
        const r = rects[selected];
        if (!r || !interactive)
            return;
        if (!Lib.overlaps(rects, selected, r.x + dx, r.y + dy))
            moved(selected, r.x + dx, r.y + dy);
    }

    function cycle(step: int) {
        const count = rects.length;
        for (let i = 1; i <= count; i++) {
            const next = ((selected + step * i) % count + count) % count;
            if (rects[next]) {
                picked(next);
                return;
            }
        }
    }

    activeFocusOnTab: true
    Keys.onPressed: event => {
        const step = event.modifiers & Qt.ShiftModifier ? 100 : 10;
        if (event.key === Qt.Key_Left)
            nudge(-step, 0);
        else if (event.key === Qt.Key_Right)
            nudge(step, 0);
        else if (event.key === Qt.Key_Up)
            nudge(0, -step);
        else if (event.key === Qt.Key_Down)
            nudge(0, step);
        else if (event.key === Qt.Key_Tab)
            cycle(1);
        else if (event.key === Qt.Key_Backtab)
            cycle(-1);
        else
            return;
        event.accepted = true;
    }

    // Click on the empty map: focus for the arrow keys
    TapHandler {
        onTapped: root.forceActiveFocus()
    }

    Repeater {
        model: root.rects.length

        Rectangle {
            id: tile

            required property int index

            readonly property var rect: root.rects[index]
            readonly property var info: root.infos[index] ?? { label: "", detail: "", internal: false }
            readonly property bool isSelected: root.selected === index
            // While dragging: where the pointer puts it, and where it lands
            property bool dragging: false
            property real rawX: 0
            property real rawY: 0
            property var landing: null
            readonly property bool blocked: dragging && landing !== null && landing.overlap
            readonly property bool apart: !dragging && rect !== null && !Lib.touches(root.rects, index)

            visible: rect !== null
            x: dragging ? rawX : (rect ? root.originX + rect.x * root.factor : 0)
            y: dragging ? rawY : (rect ? root.originY + rect.y * root.factor : 0)
            width: rect ? rect.width * root.factor : 0
            height: rect ? rect.height * root.factor : 0
            z: dragging ? 2 : isSelected ? 1 : 0
            radius: Config.radius
            color: blocked ? Qt.alpha(Config.errorColor, 0.25) : isSelected ? Qt.alpha(Config.accentColor, 0.2) : tileMouse.containsMouse ? Config.surface2Color : Config.surface1Color
            border.width: isSelected || blocked ? 2 : 1
            border.color: blocked ? Config.errorColor : isSelected ? Config.accentColor : Config.surface2Color

            Behavior on color {
                enabled: !Config.themeTransitioning
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            // Where it lands when dropped (snapped)
            Rectangle {
                visible: tile.dragging && tile.landing !== null && !tile.landing.overlap
                x: tile.landing ? root.originX + tile.landing.x * root.factor - tile.x : 0
                y: tile.landing ? root.originY + tile.landing.y * root.factor - tile.y : 0
                width: tile.width
                height: tile.height
                radius: tile.radius
                color: Qt.alpha(Config.accentColor, 0)
                border.width: 1
                border.color: Qt.alpha(Config.accentColor, 0.7)
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Config.padding * 2
                spacing: Math.round(Config.padding / 3)
                visible: tile.height > Config.fontSizeNormal * 2.5

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    // md-laptop / md-monitor
                    text: tile.info.internal ? "\u{f0322}" : "\u{f0379}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: tile.isSelected ? Config.accentColor : Config.subtextColor
                    visible: tile.height > Config.fontSizeNormal * 6
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.info.label
                    elide: Text.ElideMiddle
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.info.detail
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    visible: tile.height > Config.fontSizeNormal * 4
                }
            }

            // md-alert: not touching another monitor (the cursor can't cross)
            Text {
                visible: tile.apart
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Math.round(Config.padding / 2)
                text: "\u{f0026}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: Config.warningColor
            }

            MouseArea {
                id: tileMouse

                property point pressAt
                property point startAt

                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactive
                cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true

                onPressed: mouse => {
                    root.forceActiveFocus();
                    root.picked(tile.index);
                    pressAt = mapToItem(root, mouse.x, mouse.y);
                    startAt = Qt.point(tile.x, tile.y);
                    tile.rawX = tile.x;
                    tile.rawY = tile.y;
                    tile.landing = null;
                    tile.dragging = true;
                }
                onPositionChanged: mouse => {
                    if (!tile.dragging)
                        return;
                    const at = mapToItem(root, mouse.x, mouse.y);
                    tile.rawX = startAt.x + at.x - pressAt.x;
                    tile.rawY = startAt.y + at.y - pressAt.y;
                    const lx = (tile.rawX - root.originX) / root.factor;
                    const ly = (tile.rawY - root.originY) / root.factor;
                    tile.landing = Lib.snap(root.rects, tile.index, lx, ly, root.snapDistance / root.factor);
                }
                onReleased: {
                    const landing = tile.landing;
                    tile.dragging = false;
                    tile.landing = null;
                    if (landing && !landing.overlap && (landing.x !== tile.rect.x || landing.y !== tile.rect.y))
                        root.moved(tile.index, landing.x, landing.y);
                }
                onCanceled: {
                    tile.dragging = false;
                    tile.landing = null;
                }
            }
        }
    }
}
