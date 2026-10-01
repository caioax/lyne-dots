pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Zen Browser following the shell theme, for Settings › Theme › Zen Browser.
// ThemeService hands every palette to applyPalette(), which writes
// ~/.cache/lyne/zen.json and the CSS of the profiles where the theme is on
// (scripts/zen.sh, from lyne's zen.sh lib; also `lyne zen`). Zen reads it at
// startup, so an open Zen shows changes after a restart. Options in
// state.json: zen.themeBackground (the theme background over workspace
// gradients), zen.transparent (the window follows the theme opacity)
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/zen.sh").toString().replace("file://", "")

    // Profiles Zen has opened at least once (plus any with the theme on)
    property var profiles: []
    property bool loaded: false
    readonly property bool installed: profiles.length > 0
    readonly property var enabledProfiles: profiles.filter(p => p.enabled)
    // Something changed while a themed Zen was open
    property bool restartNeeded: false
    readonly property bool openThemed: enabledProfiles.some(p => p.running)

    readonly property bool themeBackground: StateService.get("zen.themeBackground", true)
    readonly property bool transparent: StateService.get("zen.transparent", false)
    readonly property real opacity: StateService.get("opacity.background", 1)

    property var _palette: null
    property bool _pending: false

    // Options changed (Settings, a reset, lyne state): rewrite the CSS. Only
    // the window background uses the opacity, and only when transparent
    onThemeBackgroundChanged: optionsDebounce.restart()
    onTransparentChanged: optionsDebounce.restart()
    onOpacityChanged: if (transparent)
        opacityDebounce.restart()

    function refresh() {
        if (!jsonProc.running)
            jsonProc.running = true;
    }

    function applyPalette(pal) {
        if (!pal)
            return;
        _palette = pal;
        if (paletteProc.running) {
            _pending = true;
            return;
        }
        paletteProc.environment = _env();
        paletteProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | \"$2\" palette", "bash", JSON.stringify({
                palette: pal,
                opacity: opacity
            }, null, 2), script];
        paletteProc.running = true;
    }


    function setEnabled(dir: string, on: bool) {
        _changedDir = dir;
        _run([on ? "enable" : "disable", dir]);
    }

    // The options as they are now (state.json is saved a moment later)
    function _env() {
        return {
            LYNE_ZEN_OPTIONS: JSON.stringify({
                themeBackground: themeBackground,
                transparent: transparent
            })
        };
    }

    function _run(args) {
        const proc = runComponent.createObject(root, {
            environment: _env(),
            command: [script, ...args]
        });
        proc.running = true;
    }

    Timer {
        id: optionsDebounce
        interval: 200
        onTriggered: root._run(["apply"])
    }

    Timer {
        id: opacityDebounce
        interval: 600
        onTriggered: root.applyPalette(root._palette)
    }

    Process {
        id: paletteProc
        stderr: SplitParser {
            onRead: data => console.error("[Zen] " + data)
        }
        onExited: code => {
            if (code === 0 && root.openThemed)
                root.restartNeeded = true;
            if (root._pending) {
                root._pending = false;
                Qt.callLater(() => root.applyPalette(root._palette));
            }
        }
    }

    Component {
        id: runComponent

        Process {
            id: runProc
            stderr: SplitParser {
                onRead: data => console.error("[Zen] " + data)
            }
            onExited: code => {
                if (code !== 0)
                    console.error("[Zen] zen.sh " + runProc.command.slice(1).join(" ") + " failed: " + code);
                root._afterChange = true;
                root.refresh();
                runProc.destroy();
            }
        }
    }

    // After enable/disable/apply: a themed Zen that's open (or the profile
    // just turned off) needs a restart
    property bool _afterChange: false
    property string _changedDir: ""

    Process {
        id: jsonProc
        command: [root.script, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.profiles = JSON.parse(text).filter(p => p.used || p.enabled);
                    root.loaded = true;
                } catch (e) {
                    console.error("[Zen] zen.sh json:", e);
                }
                if (root._afterChange && root.profiles.some(p => p.running && (p.enabled || p.dir === root._changedDir)))
                    root.restartNeeded = true;
                root._afterChange = false;
                root._changedDir = "";
                if (!root.profiles.some(p => p.running))
                    root.restartNeeded = false;
            }
        }
    }
}
