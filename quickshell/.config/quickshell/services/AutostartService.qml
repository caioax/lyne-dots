pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "autostart.js" as Lib

// Programs started at login (Settings › System › Autostart).
// Your apps live in state.json (autostart.apps: [{ name, command, desktop,
// delay, workspace, enabled }]) and reach Hyprland through
// HyprlandSettingsService, which writes them to hypr/local/settings.lua as a
// lyne_autostart() call (hypr/conf/autostart.lua). The essential programs of
// conf/autostart.lua are read from $XDG_RUNTIME_DIR/lyne-autostart.json.
// A hand-written hypr/local/autostart.lua (from before this page) keeps
// running until it's imported: Hyprland reads it with a stand-in `hl`
// (lyne_autostart_import) so the exact commands come out without running.
// XDG autostart entries (~/.config/autostart, /etc/xdg/autostart) are
// started by systemd in uwsm sessions; they're listed with scripts/autostart.sh
// and only switched on or off here
Singleton {
    id: root

    readonly property var apps: StateService.get("autostart.apps", StateService.getDefault("autostart.apps", []))
    readonly property var system: _systemData.system ?? []
    property var _systemData: ({})

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string legacyPath: Quickshell.env("HOME") + "/.config/hypr/local/autostart.lua"

    // The hand-written file exists
    property bool legacyExists: false
    // What it starts: { ok, error, apps: [{ command, workspace, delay }], other }
    property var legacy: null
    readonly property bool legacyImportable: legacy !== null && legacy.ok === true && legacy.other === 0
    property bool importing: false

    readonly property string script: Qt.resolvedUrl("../scripts/autostart.sh").toString().replace("file://", "")

    // Called by the page when it opens (new or renamed files aren't watched)
    function refresh() {
        systemFile.reload();
        legacyFile.reload();
        refreshXdg();
        psProc.running = true;
    }

    // Set by the page while it's shown: which programs run is checked then
    property bool watching: false

    // ========================================================================
    // CHANGES
    // ========================================================================

    function _set(list) {
        StateService.set("autostart.apps", list);
    }

    function _newEntry(fields) {
        return Object.assign({
            name: "",
            command: "",
            desktop: "",
            delay: 0,
            workspace: "",
            enabled: true
        }, fields);
    }

    // Adds an app from its .desktop entry
    function addEntry(entry) {
        _set([...apps, _newEntry({
                name: entry.name,
                command: commandOf(entry),
                desktop: entry.id
            })]);
    }

    // Saves `fields` at `index` (-1 = new)
    function save(index: int, fields) {
        const next = [...apps];
        if (index >= 0 && index < next.length)
            next[index] = Object.assign({}, next[index], fields);
        else
            next.push(_newEntry(fields));
        _set(next);
    }

    function setEnabled(index: int, value: bool) {
        save(index, {
            enabled: value
        });
    }

    function remove(index: int) {
        _set(apps.filter((_, i) => i !== index));
    }

    function move(index: int, direction: int) {
        const to = index + direction;
        if (to < 0 || to >= apps.length)
            return;
        const next = [...apps];
        [next[index], next[to]] = [next[to], next[index]];
        _set(next);
    }

    // Starts it now, the way login does (without the delay)
    function runNow(index: int) {
        const app = apps[index];
        if (!app || app.command === "")
            return;
        const opts = app.workspace ? ", { workspace = " + JSON.stringify(app.workspace) + " }" : "";
        Quickshell.execDetached(["hyprctl", "eval", "hl.exec_cmd(" + JSON.stringify(app.command) + opts + ")"]);
    }

    // ========================================================================
    // NAMES AND ICONS
    // ========================================================================

    function binaryOf(command: string): string {
        return binaries.binaryOf(command);
    }

    // Field codes (%U...) of the entry's Exec dropped
    function commandOf(entry): string {
        return (entry?.execString ?? "").replace(/%[uUfFdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
    }

    function entryOf(app): var {
        const all = DesktopEntries.applications.values;
        if (app.desktop)
            return all.find(e => e.id === app.desktop) ?? null;
        return DesktopEntries.heuristicLookup(binaryOf(app.command).split("/").pop()) ?? null;
    }

    function iconOf(app): string {
        return entryOf(app)?.icon ?? "";
    }

    // For display: the home folder as ~
    function shortCommand(command: string): string {
        return (command ?? "").split(Quickshell.env("HOME") + "/").join("~/");
    }

    // "~/.local/bin/sync_notes.sh --quiet" -> "Sync notes"
    function nameFor(command: string): string {
        const entry = DesktopEntries.heuristicLookup(binaryOf(command).split("/").pop());
        if (entry)
            return entry.name;
        const base = binaryOf(command).split("/").pop().replace(/\.[a-z0-9]+$/i, "").replace(/[-_]+/g, " ").trim();
        return base === "" ? command : base.charAt(0).toUpperCase() + base.slice(1);
    }

    // ========================================================================
    // INSTALLED APPS
    // ========================================================================

    // Which apps' first words are installed
    BinaryCheck {
        id: binaries
    }

    function isMissing(command: string): bool {
        return binaries.isMissing(command);
    }

    // The apps' commands plus `extra` (the dialog's field)
    function checkInstalled(extra: string) {
        binaries.check([...apps.map(a => a.command), extra]);
    }

    onAppsChanged: checkInstalled("")

    // ========================================================================
    // SYSTEM LIST
    // ========================================================================

    FileView {
        id: systemFile

        path: root.runtimeDir + "/lyne-autostart.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root._systemData = JSON.parse(text());
            } catch (e) {
                root._systemData = {};
            }
        }
        onLoadFailed: root._systemData = {}
    }

    // ========================================================================
    // HAND-WRITTEN local/autostart.lua
    // ========================================================================

    FileView {
        id: legacyFile

        path: root.legacyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.legacyExists = true;
            root._preview();
        }
        onLoadFailed: {
            root.legacyExists = false;
            root.legacy = null;
        }
    }

    readonly property string _importOut: runtimeDir + "/lyne-autostart-import.json"

    function _preview() {
        if (previewProc.running)
            return;
        const lua = "if lyne_autostart_import then lyne_autostart_import(" + JSON.stringify(legacyPath) + ", " + JSON.stringify(_importOut) + ") end";
        previewProc.command = ["sh", "-c", 'rm -f "$2"; hyprctl eval "$1" >/dev/null 2>&1; cat "$2" 2>/dev/null; rm -f "$2"', "sh", lua, _importOut];
        previewProc.running = true;
    }

    Process {
        id: previewProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.legacy = JSON.parse(text);
                } catch (e) {
                    root.legacy = {
                        ok: false,
                        error: "Hyprland couldn't read it (config not reloaded yet?)",
                        apps: [],
                        other: 0
                    };
                }
            }
        }
    }

    // Adds the file's apps (skipping commands already listed) and renames it
    // to autostart.lua.imported, which Hyprland no longer loads
    function importLegacy() {
        if (!legacyImportable || importing)
            return;
        const known = new Set(apps.map(a => a.command));
        const added = legacy.apps.filter(a => !known.has(a.command)).map(a => _newEntry({
                name: nameFor(a.command),
                command: a.command,
                delay: a.delay ?? 0,
                workspace: a.workspace ?? ""
            }));
        if (added.length > 0)
            _set([...apps, ...added]);
        importing = true;
        importProc.command = ["mv", "-f", legacyPath, legacyPath + ".imported"];
        importProc.running = true;
    }

    Process {
        id: importProc

        onExited: {
            root.importing = false;
            legacyFile.reload();
        }
    }

    // ========================================================================
    // RUNNING PROGRAMS
    // ========================================================================

    // Program basenames running now (Lib.runningPrograms)
    property var running: ({})

    function isRunning(command: string): bool {
        return Lib.isRunning(command, running);
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.watching
        onTriggered: {
            if (!psProc.running)
                psProc.running = true;
        }
    }

    Process {
        id: psProc

        command: ["ps", "-eo", "args="]
        stdout: StdioCollector {
            onStreamFinished: root.running = Lib.runningPrograms(text)
        }
    }

    // ========================================================================
    // XDG AUTOSTART
    // ========================================================================

    property var _xdg: ({
            user: [],
            system: [],
            units: "",
            target: ""
        })
    // Lib.entries plus `status` ("running" | "exited" | "failed" | "")
    readonly property var xdgEntries: {
        const units = Lib.parseUnits(_xdg.units);
        return Lib.entries(_xdg.user, _xdg.system, Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland").map(e => Object.assign(e, {
                    status: Lib.unitStatus(units[e.path])
                }));
    }
    // This session starts them (uwsm's xdg-desktop-autostart.target)
    readonly property bool xdgActive: _xdg.target === "active"
    property bool xdgLoaded: false

    function refreshXdg() {
        if (listProc.running)
            return;
        listProc.command = ["bash", script, "list"];
        listProc.running = true;
    }

    // Takes effect from the next login
    function setXdgEnabled(id: string, value: bool) {
        if (toggleProc.running)
            return;
        toggleProc.command = ["bash", script, value ? "show" : "hide", id];
        toggleProc.running = true;
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                root._xdg = Lib.parseList(text);
                root.xdgLoaded = true;
            }
        }
    }

    Process {
        id: toggleProc

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Autostart]", text.trim());
            }
        }
        onExited: Qt.callLater(root.refreshXdg)
    }
}
