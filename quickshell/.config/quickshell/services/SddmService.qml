pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The login screen (lyne-sddm) following the shell, for Settings › Theme ›
// Login screen. Copies the applied palette (~/.cache/lyne/nvim.json, which
// ThemeService reports through paletteWritten()), the background opacity,
// the wallpaper and the profile picture into the theme's user/ dir
// (scripts/sddm.sh, from lyne's sddm.sh lib; also `lyne sddm`). Changes are
// gathered for a moment, so a theme switch that also brings a wallpaper is
// one sync; files are only rewritten when they change. Shows on the next
// login. Option in state.json: sddm.sync (off: the theme's own defaults)
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/sddm.sh").toString().replace("file://", "")

    // lyne-sddm's user/ dir is there and writable
    property bool installed: false

    readonly property bool sync: StateService.get("sddm.sync", true)
    readonly property real opacity: StateService.get("opacity.background", 0.9)
    readonly property string wallpaper: WallpaperService.currentWallpaper
    readonly property string avatar: ProfileService.avatar

    onSyncChanged: schedule()
    onOpacityChanged: schedule()
    onWallpaperChanged: schedule()
    onAvatarChanged: schedule()

    // ThemeService wrote a new palette (preset or auto)
    function paletteWritten() {
        schedule();
    }

    function schedule() {
        if (installed)
            debounce.restart();
    }

    Component.onCompleted: installedProc.running = true

    Process {
        id: installedProc
        command: [root.script, "installed"]
        onExited: code => {
            root.installed = code === 0;
            root.schedule();
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
        // The values as they are now (state.json is saved a moment later)
        applyProc.environment = {
            LYNE_SDDM_OPTIONS: JSON.stringify({
                sync: sync,
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
