pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Workspace blocks per monitor, owned by hypr/conf/workspaces.lua: each
// monitor it knows (also disconnected ones) has a slot, and slot N holds the
// workspace ids N*100+1..N*100+99. Read from the JSON the Lua side exports;
// reordering and forgetting monitors call back into it with `hyprctl eval`.
Singleton {
    id: root

    readonly property string exportPath: Quickshell.env("XDG_RUNTIME_DIR") + "/lyne-workspaces.json"

    property int block: 100
    property int max: 99
    // [{ slot, base, desc, name, connected }] sorted by slot; `connected` is
    // the port it's on now ("" = disconnected)
    property var monitors: []
    // Last `hyprctl eval` error, shown by the settings page
    property string error: ""

    // First id of a connected monitor's block minus one, or -1 when the Lua
    // side doesn't know it (yet)
    function baseFor(monitorName: string): int {
        const entry = monitors.find(m => m.connected === monitorName);
        return entry ? entry.base : -1;
    }

    // Known monitor owning a workspace id (null for ids outside every block)
    function ownerOf(id: int): var {
        const slot = Math.floor((id - 1) / block);
        return monitors.find(m => m.slot === slot) ?? null;
    }

    // Built-in panels (eDP, LVDS, DSI) get the laptop icon
    function isInternal(entry): bool {
        return /^(eDP|LVDS|DSI)/.test(entry?.connected || entry?.name || "");
    }

    // Model and serial from the description ("LG Electronics LG ULTRAGEAR
    // 507AZNKQ4247"), else the port
    function labelOf(entry): string {
        if (!entry)
            return "";
        return entry.desc !== "" ? entry.desc : entry.name;
    }

    // Swaps a monitor's block with its neighbour's in slot order (-1 up,
    // 1 down); open workspaces are renumbered by Hyprland
    function move(index: int, direction: int) {
        const other = index + direction;
        if (index < 0 || other < 0 || index >= monitors.length || other >= monitors.length)
            return;
        _eval("lyne_workspaces_swap(" + monitors[index].slot + ", " + monitors[other].slot + ")");
    }

    // Only disconnected monitors (the Lua side refuses connected ones)
    function forget(slot: int) {
        _eval("lyne_workspaces_forget(" + slot + ")");
    }

    function _eval(code: string) {
        evalProc.command = ["hyprctl", "eval", "if lyne_workspaces_swap then " + code + " end"];
        evalProc.running = true;
    }

    function _parse(text: string) {
        try {
            const data = JSON.parse(text);
            block = data.block ?? 100;
            max = data.max ?? 99;
            monitors = (data.monitors ?? []).slice().sort((a, b) => a.slot - b.slot);
        } catch (e) {
            // Read while Hyprland was writing it: the watcher fires again
        }
    }

    FileView {
        id: exportFile
        path: root.exportPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._parse(text())
    }

    // Backup for missed file events: the Lua side rewrites the file on
    // these
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: exportFile.reload()
    }

    Process {
        id: evalProc

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.error = out === "ok" || out === "" ? "" : out;
                if (root.error !== "")
                    console.warn("[Workspaces]", root.error);
                exportFile.reload();
            }
        }
    }
}
