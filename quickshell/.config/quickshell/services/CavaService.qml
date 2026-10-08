pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum from cava (raw ascii output, one frame per line). cava only
// runs while something watches (acquire/release) and dashboard.visualizer is
// on; `values` holds one 0-1 level per bar, lowest frequencies first
Singleton {
    id: root

    readonly property int bars: 36
    readonly property int framerate: 60

    readonly property bool enabled: StateService.get("dashboard.visualizer", true)
    // False once cava turned out to be missing
    property bool available: true

    property var values: _zeros()
    // Last raw frame: silence repeats the same line every frame
    property string _lastFrame: ""

    property int _watchers: 0
    readonly property bool running: _watchers > 0 && enabled && available

    function acquire() {
        _watchers++;
    }

    function release() {
        _watchers = Math.max(0, _watchers - 1);
    }

    function _zeros() {
        return new Array(bars).fill(0);
    }

    onRunningChanged: {
        if (!running) {
            values = _zeros();
            _lastFrame = "";
        }
    }

    // sleep_timer: after a second of silence cava stops writing frames until
    // sound comes back (a player can be "playing" silence, and every frame
    // woke the shell 60 times a second)
    readonly property string _config: `[general]
framerate = ${framerate}
bars = ${bars}
autosens = 1
sleep_timer = 1
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
channels = mono
[smoothing]
noise_reduction = 60
`

    Process {
        running: root.running
        // The config goes to a file next to the other runtime files
        command: ["sh", "-c", 'command -v cava >/dev/null || exit 127; f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava.conf"; printf "%s" "$1" > "$f" && exec cava -p "$f"', "sh", root._config]

        stdout: SplitParser {
            onRead: data => {
                if (data === root._lastFrame)
                    return;
                root._lastFrame = data;
                const parts = data.split(";");
                const levels = new Array(root.bars);
                for (let i = 0; i < root.bars; i++)
                    levels[i] = (parseInt(parts[i]) || 0) / 100;
                root.values = levels;
            }
        }

        onExited: code => {
            if (code === 127) {
                console.warn("[Cava] cava isn't installed; the visualizer stays off");
                root.available = false;
            }
        }
    }
}
