pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// Faint cava spectrum rising from the bottom of its area, mirrored with the
// bass in the middle and clipped to `radius`. Holds cava while `running`
// (callers also check CavaService.enabled/available) and fades out otherwise
ClippingRectangle {
    id: root

    property bool running: false
    property color barColor: Qt.alpha(Config.accentColor, 0.25)

    // Bars on each side of the center
    readonly property int half: 18
    // The highest cava bands stay near zero; they'd be dead bars at the edges
    readonly property int usedBands: 30

    // Levels 0-1, center first: the peak of each slice of bands
    readonly property var levels: {
        const values = CavaService.values;
        const out = [];
        for (let k = 0; k < half; k++) {
            const from = Math.floor(k * usedBands / half);
            const to = Math.max(from + 1, Math.floor((k + 1) * usedBands / half));
            out.push(Math.pow(Math.max(...values.slice(from, to)), 0.6));
        }
        return out;
    }

    // acquire/release only on real changes (a handler doesn't run for the
    // initial value)
    property bool held: false
    function sync(): void {
        if (running === held)
            return;
        held = running;
        running ? CavaService.acquire() : CavaService.release();
    }
    onRunningChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held)
            CavaService.release();
    }

    color: Qt.alpha(barColor, 0)
    opacity: running ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationLong
        }
    }

    Row {
        anchors.fill: parent
        spacing: 1

        Repeater {
            model: root.half * 2

            Rectangle {
                required property int index
                // Distance from the center: 0 = bass
                readonly property int band: index < root.half ? root.half - 1 - index : index - root.half

                anchors.bottom: parent.bottom
                width: (root.width - (root.half * 2 - 1)) / (root.half * 2)
                height: root.height * (root.levels[band] ?? 0)
                color: root.barColor

                Behavior on height {
                    NumberAnimation {
                        duration: Config.animDurationShort
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
