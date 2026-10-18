pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The mouse cursor theme and size (Settings › Cursor; also `lyne cursor`).
// scripts/cursor.sh (lyne's cursor.sh lib) lists the installed themes and
// switches the running Hyprland, GSettings and the default theme apps
// inherit; HyprlandSettingsService writes the XCURSOR_* variables new apps
// start with to hypr/local/settings.lua. Applied on start and on every
// change (Settings, `lyne cursor`, an edit of state.json). Previews: PNGs of
// a few shapes per theme and size, made by scripts/cursor-preview.py in
// ~/.cache/lyne/cursors (only again when a theme's folder changes)
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/cursor.sh").toString().replace("file://", "")
    readonly property string previewScript: Qt.resolvedUrl("../scripts/cursor-preview.py").toString().replace("file://", "")
    readonly property string previewDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/lyne/cursors"

    // Sizes xcursor themes come in: others are scaled and blur
    readonly property var sizes: [24, 32, 48, 64]
    // Shapes shown in the previews, as cursor-preview.py names them
    readonly property var shapes: ["default", "pointer", "text", "wait"]

    readonly property string theme: StateService.get("cursor.theme", StateService.getDefault("cursor.theme", "Bibata-Modern-Classic"))
    readonly property int size: StateService.get("cursor.size", StateService.getDefault("cursor.size", 24))

    // Installed themes: [{ id, name, path, hyprcursor }], sorted by name
    property var themes: []
    property bool loaded: false
    readonly property var current: themes.find(t => t.id === theme) ?? null
    // The saved theme isn't installed (apps fall back to another one)
    readonly property bool missing: loaded && current === null
    // { id: [shapes with a preview] }; empty until the previews are made
    property var previews: ({})

    property string _applied: ""
    property bool _pending: false

    onThemeChanged: applyDebounce.restart()
    onSizeChanged: applyDebounce.restart()

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function setTheme(id: string) {
        StateService.set("cursor.theme", id);
    }

    function setSize(value: int) {
        StateService.set("cursor.size", value);
    }

    // The preview of a theme's shape at a size, "" when there's none
    function previewUrl(id: string, shape: string, size: int): string {
        if (!(previews[id] ?? []).includes(shape))
            return "";
        return "file://" + previewDir + "/" + encodeURIComponent(id) + "/" + shape + "-" + size + ".png";
    }

    function nameOf(id: string): string {
        return themes.find(t => t.id === id)?.name ?? id;
    }

    function apply() {
        if (StateService.isLoading)
            return;
        const key = theme + " " + size;
        if (key === _applied)
            return;
        if (applyProc.running) {
            _pending = true;
            return;
        }
        _applied = key;
        applyProc.command = [script, "apply", theme, String(size)];
        applyProc.running = true;
    }

    function _makePreviews() {
        if (previewProc.running)
            return;
        const args = [];
        for (const t of themes)
            args.push(t.id, t.path);
        previewProc.command = ["python3", previewScript, previewDir].concat(args);
        previewProc.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: StateService

        function onStateLoaded() {
            applyDebounce.restart();
        }
    }

    // A size picked right after a theme goes out as one call
    Timer {
        id: applyDebounce
        interval: 150
        onTriggered: root.apply()
    }

    Process {
        id: listProc
        command: [root.script, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    console.warn("[Cursor] couldn't read the themes:", e);
                    root.themes = [];
                }
                root.loaded = true;
                root._makePreviews();
            }
        }
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.previews = JSON.parse(text);
                } catch (e) {
                    root.previews = {};
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Cursor] previews:", text.trim());
            }
        }
    }

    Process {
        id: applyProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Cursor]", text.trim());
            }
        }
        onExited: {
            if (root._pending) {
                root._pending = false;
                Qt.callLater(root.apply);
            }
        }
    }
}
