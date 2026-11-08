pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The login screen (lyne-sddm) following the shell, for Settings › Theme ›
// Login screen. Copies the applied palette (~/.cache/lyne/nvim.json, which
// ThemeService reports through paletteWritten()), the background opacity,
// the wallpaper, the profile picture and the chosen layout (sddm.layout)
// into /var/lib/lyne-sddm, which
// lyne-sddm creates (scripts/sddm.sh, from lyne's sddm.sh lib; also `lyne
// sddm`). Changes are gathered for a moment, so a theme switch that also
// brings a wallpaper is one sync; files are only rewritten when they change.
// Shows on the next login. Option in state.json: sddm.sync (off: the theme's
// own defaults, or what lyne-sddm --preset/--layout chose). The dir and the
// theme's layouts are checked again before each sync and by check()
// (Settings › Theme), so running or updating lyne-sddm needs no reload
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/sddm.sh").toString().replace("file://", "")

    // ok, absent (theme not installed), missing (lyne-sddm not run yet) or
    // foreign (another user owns the dir); "" until the first check
    property string state: ""
    // Who owns the dir when it's foreign
    property string owner: ""
    readonly property bool installed: state === "ok"

    // The theme's layouts (layouts/<Name>.qml): [{ id, thumbnail }], center
    // first, then the lock screen's order, then by name
    property var layouts: []

    readonly property bool sync: StateService.get("sddm.sync", true)
    readonly property string layout: StateService.get("sddm.layout", "center")
    readonly property real opacity: StateService.get("opacity.background", 0.9)
    readonly property string wallpaper: WallpaperService.currentWallpaper
    readonly property string avatar: ProfileService.avatar

    onSyncChanged: schedule()
    onLayoutChanged: schedule()
    onOpacityChanged: schedule()
    onWallpaperChanged: schedule()
    onAvatarChanged: schedule()

    // ThemeService wrote a new palette (preset or auto)
    function paletteWritten() {
        schedule();
    }

    function schedule() {
        debounce.restart();
    }

    // The dir may have appeared or changed hands since the last look
    function check() {
        if (!stateProc.running)
            stateProc.running = true;
        if (!layoutsProc.running)
            layoutsProc.running = true;
    }

    // Shown for a saved value: one the theme doesn't have reads as center,
    // as the theme falls back to it
    function shownLayout(id) {
        return layouts.some(l => l.id === id) ? id : "center";
    }

    Process {
        id: layoutsProc
        command: [root.script, "layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                const order = ["center", "cards", "wallpaper"];
                const rank = id => order.includes(id) ? order.indexOf(id) : order.length;
                root.layouts = text.split("\n").filter(l => l.trim() !== "").map(l => {
                    const [id, thumbnail] = l.trim().split(" ");
                    return {
                        id: id,
                        thumbnail: thumbnail ?? ""
                    };
                }).sort((a, b) => rank(a.id) - rank(b.id) || a.id.localeCompare(b.id));
            }
        }
    }

    Component.onCompleted: check()

    // Set by _apply: sync once the check says the dir is writable
    property bool _applyAfterCheck: false

    Process {
        id: stateProc
        command: [root.script, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [state, owner] = text.trim().split(" ");
                const was = root.installed;
                root.state = state ?? "";
                root.owner = owner ?? "";
                if (root._applyAfterCheck) {
                    root._applyAfterCheck = false;
                    if (root.installed)
                        root._run();
                } else if (root.installed && !was) {
                    // At start, or lyne-sddm ran since: write it all now
                    root.schedule();
                }
            }
        }
    }

    Timer {
        id: debounce
        interval: 1000
        onTriggered: root._apply()
    }

    property bool _pending: false

    function _apply() {
        if (applyProc.running) {
            _pending = true;
            return;
        }
        _applyAfterCheck = true;
        check();
    }

    function _run() {
        // The values as they are now (state.json is saved a moment later)
        applyProc.environment = {
            LYNE_SDDM_OPTIONS: JSON.stringify({
                sync: sync,
                layout: layout,
                opacity: opacity,
                wallpaper: wallpaper,
                avatar: avatar
            })
        };
        applyProc.running = true;
    }

    Process {
        id: applyProc
        command: [root.script, "apply"]
        stderr: SplitParser {
            onRead: data => console.error("[Sddm] " + data)
        }
        onExited: code => {
            if (code !== 0)
                console.error("[Sddm] sddm.sh apply failed: " + code);
            if (root._pending) {
                root._pending = false;
                Qt.callLater(root._apply);
            }
        }
    }
}
