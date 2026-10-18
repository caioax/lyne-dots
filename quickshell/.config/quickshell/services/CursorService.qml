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
// ~/.cache/lyne/cursors (only again when a theme's folder changes).
// install() picks an archive with zenity and unpacks its themes into
// ~/.local/share/icons (cursor_install in the lib); remove() deletes one of
// those
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/cursor.sh").toString().replace("file://", "")
    readonly property string previewScript: Qt.resolvedUrl("../scripts/cursor-preview.py").toString().replace("file://", "")
    readonly property string installDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/icons"
    readonly property string previewDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/lyne/cursors"

    // Sizes xcursor themes come in: others are scaled and blur
    readonly property var sizes: [24, 32, 48, 64]
    // Shapes shown in the previews, as cursor-preview.py names them
    readonly property var shapes: ["default", "pointer", "text", "wait"]

    readonly property string theme: StateService.get("cursor.theme", StateService.getDefault("cursor.theme", "Bibata-Modern-Classic"))
    readonly property int size: StateService.get("cursor.size", StateService.getDefault("cursor.size", 24))

    // Installed themes: [{ id, name, path, hyprcursor, removable }], sorted
    // by name
    property var themes: []
    property bool loaded: false
    readonly property var current: themes.find(t => t.id === theme) ?? null
    // The saved theme isn't installed (apps fall back to another one)
    readonly property bool missing: loaded && current === null
    // { id: [shapes with a preview] }; empty until the previews are made
    property var previews: ({})

    property bool installing: false
    // Outcome of the last install or removal, for Settings: { ok, text }
    // (null until there's one)
    property var status: null

    property string _applied: ""
    property bool _pending: false
    property bool _refreshAgain: false
    property bool _previewsAgain: false
    // Ids just installed, for the status
    property var _installed: []

    onThemeChanged: applyDebounce.restart()
    onSizeChanged: applyDebounce.restart()

    function refresh() {
        if (listProc.running)
            _refreshAgain = true;
        else
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

    function install() {
        if (installProc.running)
            return;
        installing = true;
        status = null;
        installProc.running = true;
    }

    function remove(id: string) {
        if (id === theme || removeProc.running)
            return;
        removeProc.removing = nameOf(id);
        removeProc.command = [script, "remove", id];
        removeProc.running = true;
    }

    function openFolder() {
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && xdg-open "$1"', "bash", installDir]);
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
        if (previewProc.running) {
            _previewsAgain = true;
            return;
        }
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
                if (root._installed.length > 0) {
                    const names = root._installed.map(id => root.nameOf(id));
                    root._installed = [];
                    root.status = {
                        ok: true,
                        text: names.length === 1 ? I18n.tr("Installed %1: pick it above", names[0]) : I18n.tr("Installed %1: pick one above", names.join(", "))
                    };
                }
                if (root._refreshAgain) {
                    root._refreshAgain = false;
                    Qt.callLater(root.refresh);
                }
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
                if (root._previewsAgain) {
                    root._previewsAgain = false;
                    Qt.callLater(root._makePreviews);
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

    // zenity's dialog texts come translated as $2..$5; the lib's lines
    // ("installed <id>", "updated <id>") on stdout, its exit code tells why
    // it failed
    Process {
        id: installProc

        property var lines: []

        command: ["bash", "-c", `
            if ! command -v zenity >/dev/null; then
                notify-send "$4" "$5"
                exit 10
            fi
            file=$(zenity --file-selection --title="$2" --filename="$HOME/" --file-filter="$3 | *.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tar.zst *.tar *.zip *.7z") || exit 11
            "$1" install "$file"
        `, "bash", root.script, I18n.tr("Install a cursor theme"), I18n.tr("Archives"), I18n.tr("Cursor"), I18n.tr("Install zenity to pick a file")]
        stdout: SplitParser {
            onRead: data => installProc.lines.push(data.trim())
        }
        onStarted: lines = []
        onExited: code => {
            root.installing = false;
            switch (code) {
            case 0:
                // Said once the list is read again, with the themes' names
                root._installed = installProc.lines.map(l => l.split(" ").slice(1).join(" ")).filter(id => id !== "");
                break;
            case 2:
                root.status = {
                    ok: false,
                    text: I18n.tr("Couldn't open that file: use a .tar.gz, .tar.xz or .zip archive")
                };
                break;
            case 3:
                root.status = {
                    ok: false,
                    text: I18n.tr("No cursor theme in that file (a folder with a cursors folder inside)")
                };
                break;
            case 4:
                root.status = {
                    ok: false,
                    text: I18n.tr("That file only has hyprcursor themes: apps need the xcursor version")
                };
                break;
            default:
                // Cancelled, or no zenity (it said so in a notification)
                break;
            }
            root.refresh();
        }
    }

    Process {
        id: removeProc

        property string removing: ""

        onExited: code => {
            root.status = code === 0 ? {
                ok: true,
                text: I18n.tr("Removed %1", removing)
            } : {
                ok: false,
                text: I18n.tr("Couldn't remove %1", removing)
            };
            root.refresh();
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
