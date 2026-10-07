pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "xkb.js" as Lib

// Keyboard layouts and options (Settings › Hyprland › Keyboard).
// The values live in the "hyprland" block of state.json (input.kb_layout,
// kb_variant, kb_options, kb_model, numlock_by_default), so
// HyprlandSettingsService applies them live and writes them to
// hypr/local/settings.lua like any other input option. Every layout, variant
// and option is checked against xkeyboard-config's list first: Hyprland
// silently falls back to plain US on an unknown one.
// Keyboards with their own layouts are kept in keyboard.devices
// ([{ name, names, layout, variant, options?, model? }], name = the keyboard,
// names = every interface it shows up as) and written by
// HyprlandSettingsService as hl.device() lines. A hand-written
// hypr/local/extra_input.lua keeps working until it's imported: Hyprland reads
// it with a stand-in `hl` (lyne_keyboard_import in conf/input.lua)
Singleton {
    id: root

    // ========================================================================
    // XKB LISTS
    // ========================================================================

    property var db: ({
            models: [],
            layouts: [],
            variants: {},
            groups: []
        })
    readonly property bool ready: db.layouts.length > 0
    readonly property var allEntries: ready ? Lib.allEntries(db) : []
    readonly property int maxLayouts: Lib.MAX_LAYOUTS

    FileView {
        id: lstFile

        path: "/usr/share/X11/xkb/rules/evdev.lst"
        printErrors: false
        onLoaded: root.db = Lib.parseLst(text())
        onLoadFailed: {
            if (path !== "/usr/share/xkeyboard-config-2/rules/evdev.lst")
                path = "/usr/share/xkeyboard-config-2/rules/evdev.lst";
            else
                console.warn("[Keyboard] xkeyboard-config's evdev.lst not found");
        }
    }

    function describe(entry): string {
        return Lib.describe(db, entry);
    }

    function shortName(entry): string {
        return Lib.shortName(entry);
    }

    function isValid(entry): bool {
        return Lib.isValid(db, entry);
    }

    function matches(entry, query: string): bool {
        return Lib.matches(entry, query);
    }

    function optionDescription(option: string): string {
        return Lib.findOption(db, option)?.description ?? option;
    }

    // "Compose: Right Alt", for lists of the options in use
    readonly property var _groupNames: ({
            caps: "Caps Lock",
            compose: "Compose",
            ctrl: "Ctrl",
            grp: "Switch layout",
            lv3: "3rd level",
            altwin: "Alt and Super"
        })

    function optionSummary(option: string): string {
        const group = option.split(":")[0];
        const prefix = _groupNames[group] ?? db.groups.find(g => g.name === group)?.description ?? group;
        return prefix + ": " + optionDescription(option);
    }

    // ========================================================================
    // SETTINGS
    // ========================================================================

    function _get(key: string, fallback) {
        const path = "hyprland.input." + key;
        return StateService.get(path, StateService.getDefault(path, fallback));
    }

    readonly property var layouts: Lib.parseLayouts(_get("kb_layout", "us"), _get("kb_variant", ""))
    readonly property var options: Lib.parseOptions(_get("kb_options", ""))
    readonly property string model: _get("kb_model", "")

    // Refuses lists with an unknown layout (never sent to Hyprland)
    function setLayouts(list): bool {
        _hush();
        if (!ready || list.length === 0 || list.length > maxLayouts || !Lib.acceptable(db, list, layouts)) {
            console.warn("[Keyboard] refused layouts", JSON.stringify(list));
            return false;
        }
        const joined = Lib.joinLayouts(list);
        StateService.set("hyprland.input.kb_layout", joined.layout);
        StateService.set("hyprland.input.kb_variant", joined.variant);
        return true;
    }

    function addLayout(entry): bool {
        if (layouts.length >= maxLayouts || layouts.some(l => l.layout === entry.layout && l.variant === entry.variant))
            return false;
        return setLayouts([...layouts, {
                layout: entry.layout,
                variant: entry.variant ?? ""
            }]);
    }

    function replaceLayout(index: int, entry): bool {
        const next = [...layouts];
        next[index] = {
            layout: entry.layout,
            variant: entry.variant ?? ""
        };
        return setLayouts(next);
    }

    function removeLayout(index: int): bool {
        if (layouts.length <= 1)
            return false;
        return setLayouts(layouts.filter((_, i) => i !== index));
    }

    function moveLayout(index: int, direction: int): bool {
        const to = index + direction;
        if (to < 0 || to >= layouts.length)
            return false;
        const next = [...layouts];
        [next[index], next[to]] = [next[to], next[index]];
        return setLayouts(next);
    }

    function setOptions(list) {
        _hush();
        if (!ready)
            return;
        StateService.set("hyprland.input.kb_options", Lib.validOptions(db, list).join(","));
    }

    function toggleOption(option: string, on: bool) {
        setOptions(Lib.toggleOption(options, option, on));
    }

    function optionIn(group: string): string {
        return Lib.optionIn(options, group);
    }

    function setGroupOption(group: string, option: string) {
        setOptions(Lib.setGroupOption(options, group, option));
    }

    // Layouts the system is set to (localectl: X11 layouts, else the
    // console keymap), for the welcome screen; [] until detected or when
    // none is listed
    readonly property var systemLayouts: ready && _localeText !== "" ? Lib.systemLayouts(db, _localeText) : []
    property string _localeText: ""

    function detectSystemLayouts() {
        if (!localeProc.running)
            localeProc.running = true;
    }

    Process {
        id: localeProc

        command: ["localectl", "status", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root._localeText = text
        }
    }

    function setModel(name: string) {
        _hush();
        if (name !== "" && !db.models.some(m => m.name === name))
            return;
        StateService.set("hyprland.input.kb_model", name);
    }

    // ========================================================================
    // KEYBOARDS
    // ========================================================================

    // hyprctl devices -j keyboards
    property var keyboards: []
    readonly property var mainKeyboard: keyboards.find(k => k.main) ?? null
    // What you're typing with now ("English (US, alt. intl.)")
    readonly property string activeKeymap: mainKeyboard?.active_keymap ?? ""
    // Layouts of the keyboard typed on last, and the one in use
    readonly property var activeLayouts: mainKeyboard ? Lib.parseLayouts(mainKeyboard.layout, mainKeyboard.variant) : []
    readonly property int activeIndex: mainKeyboard?.active_layout_index ?? 0
    readonly property var activeEntry: activeLayouts[activeIndex] ?? activeLayouts[0] ?? null
    readonly property string activeShort: activeEntry ? Lib.shortName(activeEntry) : ""

    // Switches the keyboard typed on last, and the others with the same
    // layouts, to the layout at `index` ("next" / "prev" work too)
    function switchLayout(index) {
        if (!mainKeyboard)
            return;
        const targets = keyboards.filter(k => k.layout === mainKeyboard.layout && k.variant === mainKeyboard.variant).map(k => k.name);
        const commands = targets.map(n => "switchxkblayout " + n + " " + index);
        Quickshell.execDetached(["hyprctl", "--batch", commands.join(" ; ")]);
    }

    // ========================================================================
    // OSD ON SWITCH
    // ========================================================================

    // Keymap each keyboard had: the OSD shows when the SAME keyboard changes
    // (typing on another keyboard isn't a switch)
    property var _lastKeymap: ({})
    property string _osdKeyboard: ""
    // Settings changing the layouts also changes keymaps: no OSD for that
    property bool _quiet: false

    Timer {
        id: quietTimer
        interval: 2500
        onTriggered: root._quiet = false
    }

    function _hush() {
        _quiet = true;
        quietTimer.restart();
    }

    // Values settle while the shell starts
    Timer {
        id: armTimer
        interval: 3000
        running: true
    }

    function refreshDevices() {
        if (!devicesProc.running)
            devicesProc.running = true;
    }

    Component.onCompleted: refreshDevices()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root._hush();
            if (event.name === "activelayout") {
                const comma = event.data.indexOf(",");
                const name = event.data.slice(0, comma);
                const keymap = event.data.slice(comma + 1);
                const before = root._lastKeymap[name];
                root._lastKeymap[name] = keymap;
                if (before !== undefined && before !== keymap && !root._quiet && !armTimer.running)
                    root._osdKeyboard = name;
            }
            if (event.name === "activelayout" || event.name === "configreloaded")
                root.refreshDevices();
        }
    }

    // Settings change the keymap through `hyprctl eval`: no event for that
    onLayoutsChanged: devicesDebounce.restart()
    onOptionsChanged: devicesDebounce.restart()

    Timer {
        id: devicesDebounce
        interval: 400
        onTriggered: root.refreshDevices()
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keyboards = JSON.parse(text).keyboards ?? [];
                } catch (e) {
                    root.keyboards = [];
                }
                // Keymaps known before any switch, so the first one shows too
                for (const k of root.keyboards) {
                    if (root._lastKeymap[k.name] === undefined)
                        root._lastKeymap[k.name] = k.active_keymap;
                }
                // The switch the OSD waits for: its layout's short name
                if (root._osdKeyboard !== "") {
                    const k = root.keyboards.find(x => x.name === root._osdKeyboard);
                    root._osdKeyboard = "";
                    if (k) {
                        const list = Lib.parseLayouts(k.layout, k.variant);
                        const entry = list[k.active_layout_index] ?? list[0];
                        OsdService.showLayout(k.active_keymap, entry ? Lib.shortName(entry) : "");
                    }
                }
            }
        }
    }

    // ========================================================================
    // KEYBOARDS WITH THEIR OWN LAYOUTS
    // ========================================================================

    // One entry per keyboard (its interfaces grouped): Lib.keyboardGroups
    readonly property var groups: Lib.keyboardGroups(keyboards)
    readonly property var devices: StateService.get("keyboard.devices", StateService.getDefault("keyboard.devices", []))

    function deviceEntry(name: string): var {
        return devices.find(d => d.name === name) ?? null;
    }

    function deviceLayouts(name: string): var {
        const entry = deviceEntry(name);
        return entry && entry.layout ? Lib.parseLayouts(entry.layout, entry.variant ?? "") : [];
    }

    // What the hand-written extra_input.lua sets for a keyboard (null: nothing)
    function legacyFor(name: string): var {
        if (!legacyExists || !legacy)
            return null;
        return (legacy.devices ?? []).find(d => Lib.baseName(d.name) === name) ?? null;
    }

    function parseLayoutsOf(layout: string, variant: string): var {
        return Lib.parseLayouts(layout, variant);
    }

    function labelFor(name: string): string {
        return Lib.labelFor(name);
    }

    function _saveDevice(name: string, list): bool {
        _hush();
        const previous = deviceLayouts(name);
        if (!ready || list.length === 0 || list.length > maxLayouts || !Lib.acceptable(db, list, previous)) {
            console.warn("[Keyboard] refused layouts for", name, JSON.stringify(list));
            return false;
        }
        const joined = Lib.joinLayouts(list);
        const group = groups.find(g => g.name === name);
        const old = deviceEntry(name);
        const names = [...new Set([...(old?.names ?? []), ...(group?.names ?? []), name])];
        const entry = Object.assign({}, old ?? {
            name
        }, {
            names,
            layout: joined.layout,
            variant: joined.variant
        });
        StateService.set("keyboard.devices", old ? devices.map(d => d.name === name ? entry : d) : [...devices, entry]);
        return true;
    }

    // index -1 adds a layout
    function setDeviceLayout(name: string, index: int, entry): bool {
        const list = [...deviceLayouts(name)];
        const item = {
            layout: entry.layout,
            variant: entry.variant ?? ""
        };
        if (index < 0) {
            if (list.some(l => l.layout === item.layout && l.variant === item.variant))
                return false;
            list.push(item);
        } else {
            list[index] = item;
        }
        return _saveDevice(name, list);
    }

    function removeDeviceLayout(name: string, index: int): bool {
        const list = deviceLayouts(name);
        if (list.length <= 1)
            return false;
        return _saveDevice(name, list.filter((_, i) => i !== index));
    }

    // Back to the layouts of every keyboard (also forgets a disconnected one)
    function followGlobal(name: string) {
        _hush();
        StateService.set("keyboard.devices", devices.filter(d => d.name !== name));
    }

    // A saved keyboard seen with interfaces it didn't have yet
    onGroupsChanged: {
        let changed = false;
        const next = devices.map(d => {
            const group = groups.find(g => g.name === d.name);
            const missing = group ? group.names.filter(n => !(d.names ?? []).includes(n)) : [];
            if (missing.length === 0)
                return d;
            changed = true;
            return Object.assign({}, d, {
                names: [...(d.names ?? [d.name]), ...missing]
            });
        });
        if (changed && !StateService.isLoading)
            StateService.set("keyboard.devices", next);
    }

    // ========================================================================
    // HAND-WRITTEN local/extra_input.lua
    // ========================================================================

    readonly property string legacyPath: Quickshell.env("HOME") + "/.config/hypr/local/extra_input.lua"
    property bool legacyExists: false
    // { ok, error, devices: [{ name, kb_layout?, kb_variant?, kb_options?, kb_model? }], notes, other }
    property var legacy: null
    readonly property bool legacyImportable: legacy !== null && legacy.ok === true && legacy.other === 0
    property bool importing: false
    readonly property string _importOut: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lyne-keyboard-import.json"

    // Called by the page when it opens (new or renamed files aren't watched)
    function refreshLegacy() {
        legacyFile.reload();
    }

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

    function _preview() {
        if (previewProc.running)
            return;
        const lua = "if lyne_keyboard_import then lyne_keyboard_import(" + JSON.stringify(legacyPath) + ", " + JSON.stringify(_importOut) + ", " + JSON.stringify(lstFile.path) + ") end";
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
                        devices: [],
                        notes: [],
                        other: 0
                    };
                }
            }
        }
    }

    // Adds the file's keyboards (grouping interfaces; keyboards already set
    // up here stay as they are) and renames it to extra_input.lua.imported,
    // which Hyprland no longer loads
    function importLegacy() {
        if (!legacyImportable || importing)
            return;
        const next = [...devices];
        for (const d of legacy.devices) {
            const base = Lib.baseName(d.name);
            let entry = next.find(e => e.name === base);
            if (entry && !entry.imported)
                continue;
            if (!entry) {
                entry = {
                    name: base,
                    names: [],
                    imported: true
                };
                next.push(entry);
            }
            if (!entry.names.includes(d.name))
                entry.names.push(d.name);
            if (d.kb_layout !== undefined) {
                entry.layout = d.kb_layout;
                entry.variant = d.kb_variant ?? "";
            }
            if (d.kb_options !== undefined)
                entry.options = d.kb_options;
            if (d.kb_model !== undefined)
                entry.model = d.kb_model;
        }
        StateService.set("keyboard.devices", next.map(e => {
            const copy = Object.assign({}, e);
            delete copy.imported;
            return copy;
        }));
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
}
