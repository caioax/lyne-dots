pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland options edited from Settings. The "hyprland" block of state.json
// mirrors the hl.config() table; every change is applied live with
// `hyprctl eval` and written to hypr/local/settings.lua, which hyprland.lua
// loads after conf/*.lua, so the values survive reloads and reboots.
// Writing the file makes Hyprland reload its config, so it waits until the
// values stop changing (ThemeService re-sends its colors after a reload)
Singleton {
    id: root

    readonly property string settingsPath: Quickshell.env("HOME") + "/.config/hypr/local/settings.lua"

    // defaults.json with the user's values on top (keys missing in state
    // still get written)
    readonly property var settings: _merge(StateService.getDefault("hyprland", {}), StateService.get("hyprland", {}))
    readonly property string lua: "hl.config(" + _toLua(settings, 0) + ")\n"

    // Last `hyprctl eval` error, shown by the settings pages
    property string error: ""

    onLuaChanged: {
        if (!StateService.isLoading) {
            evalDebounce.restart();
            writeDebounce.restart();
        }
    }

    // First load (the initial change happens while isLoading) and external
    // edits of state.json
    Connections {
        target: StateService

        function onStateLoaded() {
            writeDebounce.restart();
        }
    }

    function _merge(base, over) {
        const result = {};
        for (const key of Object.keys(base))
            result[key] = base[key];
        for (const key of Object.keys(over)) {
            const b = result[key], o = over[key];
            const bothObjects = b && o && typeof b === "object" && typeof o === "object" && !Array.isArray(b) && !Array.isArray(o);
            result[key] = bothObjects ? _merge(b, o) : o;
        }
        return result;
    }

    function _toLua(value, depth: int): string {
        if (typeof value === "string")
            return JSON.stringify(value);
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        if (value === null || typeof value !== "object")
            return "nil";

        const indent = "    ".repeat(depth + 1);
        const entries = Object.keys(value).map(key => {
            const luaKey = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : "[" + JSON.stringify(key) + "]";
            return indent + luaKey + " = " + _toLua(value[key], depth + 1) + ",";
        });
        return "{\n" + entries.join("\n") + "\n" + "    ".repeat(depth) + "}";
    }

    readonly property string _fileContent: "-- Managed by Quickshell (Settings > Hyprland). Changes here are overwritten;\n" + "-- edit the values from the settings window or in state.json instead.\n\n" + lua

    // Live: only the in-memory config, no reload
    function applyLive() {
        evalProc.command = ["bash", "-c", 'hyprctl eval "$1" 2>&1', "_", lua];
        evalProc.running = true;
    }

    // Persist; Hyprland reloads and picks the file up
    function write() {
        // Already on disk (e.g. on startup): don't trigger a reload
        if (settingsFile.loaded && settingsFile.text() === _fileContent)
            return;
        settingsFile.setText(_fileContent);
    }

    Timer {
        id: evalDebounce
        interval: 100
        onTriggered: root.applyLive()
    }

    Timer {
        id: writeDebounce
        interval: 1500
        onTriggered: root.write()
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        printErrors: false
    }

    Process {
        id: evalProc

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.error = out === "ok" || out === "" ? "" : out;
                if (root.error !== "")
                    console.warn("[HyprlandSettings]", root.error);
            }
        }
    }
}
