pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland keybinds for Settings. The catalog (binds declared with bind() in
// hypr/conf/keybinds.lua, with their default keys) is exported by Hyprland to
// $XDG_RUNTIME_DIR/lyne-keybinds.json on every config load; changes live in
// state.json (keybinds.overrides / keybinds.custom) and reach Hyprland
// through HyprlandSettingsService (hypr/local/settings.lua)
Singleton {
    id: root

    readonly property string catalogPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lyne-keybinds.json"

    // [{ id, group, description, keys }] with default keys
    property var catalog: []

    readonly property var overrides: StateService.get("keybinds.overrides", [])
    readonly property var custom: StateService.get("keybinds.custom", [])

    // Catalog with the user's keys: [{ id, group, description, keys, defaultKeys, changed }]
    readonly property var binds: catalog.map(b => {
        const o = overrides.find(x => x.id === b.id);
        return {
            id: b.id,
            group: b.group,
            description: b.description,
            keys: o ? o.keys : b.keys,
            defaultKeys: b.keys,
            changed: o !== undefined
        };
    })
    readonly property var groups: [...new Set(catalog.map(b => b.group))]

    // Binds Hyprland has that Settings doesn't manage (local/extra_keybinds.lua,
    // mouse binds...): [{ combo, label }], refreshed by refreshExternal()
    property var external: []

    // A shortcut is being recorded (Hyprland is in the empty capture submap)
    property bool capturing: false

    // ========================================================================
    // KEYS
    // ========================================================================

    readonly property var _modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]
    readonly property var _modAliases: ({
            SUPER: "SUPER",
            WIN: "SUPER",
            MOD4: "SUPER",
            META: "SUPER",
            CTRL: "CTRL",
            CONTROL: "CTRL",
            ALT: "ALT",
            MOD1: "ALT",
            SHIFT: "SHIFT"
        })

    // "super + q" / "SUPER+Q" -> "SUPER+Q": to compare combos
    function normalize(keys: string): string {
        if (!keys)
            return "";
        const parts = keys.split("+").map(p => p.trim().toUpperCase()).filter(p => p !== "");
        const mods = [];
        let key = "";
        for (const p of parts) {
            const mod = _modAliases[p];
            if (mod)
                mods.push(mod);
            else
                key = p === "ENTER" ? "RETURN" : p;
        }
        mods.sort((a, b) => _modOrder.indexOf(a) - _modOrder.indexOf(b));
        return [...mods, key].join("+");
    }

    // For keycaps: ["SUPER", "SHIFT", "Q"]
    function split(keys: string): var {
        return keys ? keys.split("+").map(p => p.trim()).filter(p => p !== "") : [];
    }

    // Labels of the other binds using `keys` (id / custom index excluded)
    function conflicts(keys: string, exceptId: string, exceptCustom: int): var {
        const combo = normalize(keys);
        if (combo === "")
            return [];
        const result = [];
        for (const b of binds) {
            if (b.id !== exceptId && normalize(b.keys) === combo)
                result.push(b.description);
        }
        custom.forEach((c, i) => {
            if (i !== exceptCustom && normalize(c.keys) === combo)
                result.push(c.description || c.command);
        });
        for (const e of external) {
            if (e.combo === combo)
                result.push(e.label);
        }
        return result;
    }

    // ========================================================================
    // CHANGES
    // ========================================================================

    function setKeys(id: string, keys: string) {
        const bind = catalog.find(b => b.id === id);
        if (!bind)
            return;
        // Same keys as the default: no override needed
        const list = overrides.filter(o => o.id !== id);
        if (normalize(keys) !== normalize(bind.keys))
            list.push({
                id,
                keys
            });
        StateService.set("keybinds.overrides", list);
    }

    function reset(id: string) {
        StateService.set("keybinds.overrides", overrides.filter(o => o.id !== id));
    }

    function resetAll() {
        StateService.set("keybinds.overrides", []);
    }

    function saveCustom(index: int, entry) {
        const list = [...custom];
        if (index >= 0 && index < list.length)
            list[index] = entry;
        else
            list.push(entry);
        StateService.set("keybinds.custom", list);
    }

    function removeCustom(index: int) {
        StateService.set("keybinds.custom", custom.filter((_, i) => i !== index));
    }

    // ========================================================================
    // RECORDING
    // ========================================================================

    function startCapture() {
        capturing = true;
        captureTimeout.restart();
        submapProc.command = ["hyprctl", "dispatch", 'hl.dsp.submap("lyne_capture")'];
        submapProc.running = true;
    }

    function stopCapture() {
        if (!capturing)
            return;
        capturing = false;
        captureTimeout.stop();
        resetProc.running = true;
    }

    // Never leave Hyprland stuck without binds
    Timer {
        id: captureTimeout
        interval: 20000
        onTriggered: root.stopCapture()
    }

    Process {
        id: submapProc
    }

    Process {
        id: resetProc
        command: ["hyprctl", "dispatch", 'hl.dsp.submap("reset")']
    }

    // ========================================================================
    // SOURCES
    // ========================================================================

    FileView {
        id: catalogFile

        path: root.catalogPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                root.catalog = JSON.parse(text());
            } catch (e) {
                console.warn("[Keybinds] Invalid catalog:", e);
            }
        }
    }

    // Binds without a description aren't declared with bind() (Settings adds
    // descriptions to its own), so they come from local files
    readonly property var _modBits: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]

    function refreshExternal() {
        if (!bindsProc.running)
            bindsProc.running = true;
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    root.external = list.filter(b => !b.has_description && b.submap === "" && !b.mouse).map(b => {
                        const mods = root._modBits.filter(m => (b.modmask & m[0]) !== 0).map(m => m[1]);
                        const keys = [...mods, b.key].join(" + ");
                        return {
                            combo: root.normalize(keys),
                            label: "a bind in hypr/local (" + keys + ")"
                        };
                    });
                } catch (e) {
                    console.warn("[Keybinds] Couldn't read hyprctl binds:", e);
                }
            }
        }
    }
}
