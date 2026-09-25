pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// Spectrum bars standing out of the edge of a rounded square (the cover,
// placed in the middle as the content). The bars run around it from the
// top center both ways, mirrored: bass at the top, treble at the bottom
Item {
    id: root

    // Side and corner radius of the square in the middle
    property real coverSize: 200
    property real coverRadius: Config.radiusLarge
    // Room for the bars on each side
    property real ring: Config.spacing * 3
    property bool running: false

    default property alias content: center.data

    readonly property real gap: Config.padding
    readonly property real barWidth: Math.max(2, Config.padding / 2)
    readonly property real maxLength: ring - gap

    implicitWidth: coverSize + ring * 2
    implicitHeight: coverSize + ring * 2

    // Base point and outward angle (degrees, 0 = right, 90 = down) of each
    // bar, spaced evenly along the edge of the square grown by `gap`
    readonly property var anchors_: {
        const count = CavaService.bars * 2;
        const side = coverSize + gap * 2;
        const r = Math.min(coverRadius + gap, side / 2);
        const c = width / 2;
        const h = side / 2;
        const straight = side - r * 2;
        const arc = Math.PI * r / 2;

        // Clockwise from the top center
        const segments = [
            {
                len: straight / 2,
                at: t => [c + t, c - h, -90]
            },
            {
                len: arc,
                at: t => corner(c + h - r, c - h + r, -90, t)
            },
            {
                len: straight,
                at: t => [c + h, c - h + r + t, 0]
            },
            {
                len: arc,
                at: t => corner(c + h - r, c + h - r, 0, t)
            },
            {
                len: straight,
                at: t => [c + h - r - t, c + h, 90]
            },
            {
                len: arc,
                at: t => corner(c - h + r, c + h - r, 90, t)
            },
            {
                len: straight,
                at: t => [c - h, c + h - r - t, 180]
            },
            {
                len: arc,
                at: t => corner(c - h + r, c - h + r, 180, t)
            },
            {
                len: straight / 2,
                at: t => [c - h + r + t, c - h, 270]
            }
        ];
        function corner(cx, cy, fromDeg, t) {
            const a = fromDeg + (t / r) * 180 / Math.PI;
            const rad = a * Math.PI / 180;
            return [cx + r * Math.cos(rad), cy + r * Math.sin(rad), a];
        }

        const perimeter = segments.reduce((sum, s) => sum + s.len, 0);
        const list = [];
        for (let k = 0; k < count; k++) {
            let s = (k + 0.5) * perimeter / count;
            let seg = 0;
            while (seg < segments.length - 1 && s > segments[seg].len) {
                s -= segments[seg].len;
                seg++;
            }
            const p = segments[seg].at(s);
            list.push({
                x: p[0],
                y: p[1],
                angle: p[2],
                // Mirrored halves: both sides start with the bass at the top
                band: k < count / 2 ? k : count - 1 - k
            });
        }
        return list;
    }

    Item {
        anchors.fill: parent
        opacity: root.running ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationLong
            }
        }

        Repeater {
            model: root.anchors_

            Rectangle {
                required property var modelData
                readonly property real level: CavaService.values[modelData.band] ?? 0

                // Stands on its base point, rotated to point outward
                x: modelData.x - width / 2
                y: modelData.y - height
                width: root.barWidth
                height: Math.max(root.barWidth, level * root.maxLength)
                radius: width / 2
                transformOrigin: Item.Bottom
                rotation: modelData.angle + 90
                color: Qt.alpha(Config.accentColor, 0.5 + level * 0.5)
            }
        }
    }

    Item {
        id: center
        anchors.centerIn: parent
        width: root.coverSize
        height: root.coverSize
    }
}
