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
// silently falls back to plain US on an unknown one
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

    function variantsOf(layout: string): var {
        const base = Lib.findLayout(db, layout);
        return base ? [
            {
                layout,
                variant: "",
                description: base.description
            }
        ].concat((db.variants[layout] ?? []).map(v => ({
                    layout,
                    variant: v.name,
                    description: v.description
                }))) : [];
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
        if (!ready || list.length === 0 || list.length > maxLayouts || !list.every(e => Lib.isValid(db, e))) {
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

    function setModel(name: string) {
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

    function refreshDevices() {
        if (!devicesProc.running)
            devicesProc.running = true;
    }

    Component.onCompleted: refreshDevices()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
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
            }
        }
    }
}
