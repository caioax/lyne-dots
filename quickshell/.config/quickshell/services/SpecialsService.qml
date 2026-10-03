pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Special workspaces (WhatsApp, music, scratchpad...): toggleable hidden
// workspaces, each with an app opened when shown empty. The list lives in
// state.json (specials.list); HyprlandSettingsService writes it to
// hypr/local/settings.lua as a lyne_specials() call (hypr/conf/specials.lua),
// which sets the workspace rules, binds and login autostart. Keys set here
// are the binds' defaults; Settings › Keybinds can still override them
Singleton {
    id: root

    // [{ id, name, icon, color, command, class, keys, moveKeys, autostart }]
    readonly property var list: StateService.get("specials.list", StateService.getDefault("specials.list", []))

    // Badge colors by name (stored as names so they follow the theme)
    readonly property var colors: ({
            accent: Config.accentColor,
            success: Config.successColor,
            warning: Config.warningColor,
            error: Config.errorColor,
            subtext: Config.subtextColor
        })
    readonly property var colorNames: Object.keys(colors)

    function colorFor(name: string): color {
        return colors[name] ?? Config.accentColor;
    }

    function find(id: string): var {
        return list.find(s => s.id === id) ?? null;
    }

    // Keys in effect (Settings › Keybinds overrides included) of a special's
    // toggle ("special") or move ("move-to") bind
    function keysOf(item, kind: string): string {
        const bind = KeybindsService.binds.find(b => b.id === kind + "-" + item.id);
        if (bind)
            return bind.keys;
        return kind === "special" ? item.keys ?? "" : item.moveKeys ?? "";
    }

    // Apps the dialog offers; `pkg` is only a hint for the "not installed"
    // warning. Classes are left empty where the app's class isn't known
    readonly property var presets: [
        {
            // WhatsApp Web as a Chromium app with its own profile (the
            // default; lyne whatsapp warns when chromium is missing)
            key: "whatsapp-web",
            label: "WhatsApp Web",
            category: "Chat",
            name: "WhatsApp",
            icon: "\u{f05a3}",
            command: "lyne whatsapp",
            cls: "^(chrome-web\\.whatsapp\\.com__-Default)$",
            pkg: "chromium"
        },
        {
            key: "zapzap",
            label: "ZapZap",
            category: "Chat",
            name: "WhatsApp",
            icon: "\u{f05a3}",
            command: "zapzap",
            cls: "^(com\\.rtosta\\.zapzap)$",
            pkg: "zapzap (AUR)"
        },
        {
            key: "telegram",
            label: "Telegram",
            category: "Chat",
            name: "Telegram",
            icon: "\u{f2c6}",
            command: "Telegram",
            cls: "^(org\\.telegram\\.desktop)$",
            pkg: "telegram-desktop"
        },
        {
            key: "vesktop",
            label: "Vesktop",
            category: "Chat",
            name: "Discord",
            icon: "\u{f066f}",
            command: "vesktop",
            cls: "^(vesktop)$",
            pkg: "vesktop-bin (AUR)"
        },
        {
            key: "spotify",
            label: "Spotify",
            category: "Music",
            name: "Music",
            icon: "\u{f04c7}",
            command: "spotify",
            cls: "^([Ss]potify)$",
            pkg: "spotify (AUR)"
        },
        {
            key: "spotube",
            label: "Spotube",
            category: "Music",
            name: "Music",
            icon: "\u{f075a}",
            command: "spotube",
            cls: "",
            pkg: "spotube-bin (AUR)"
        },
        {
            key: "youtube-music",
            label: "YouTube Music",
            category: "Music",
            name: "Music",
            icon: "\u{f05c3}",
            command: "youtube-music",
            cls: "",
            pkg: "pear-desktop-bin (AUR)"
        },
        {
            key: "feishin",
            label: "Feishin",
            category: "Music",
            name: "Music",
            icon: "\u{f075a}",
            command: "feishin",
            cls: "^(feishin)$",
            pkg: "feishin-bin (AUR)"
        },
        {
            key: "tidal",
            label: "Tidal",
            category: "Music",
            name: "Music",
            icon: "\u{f075a}",
            command: "tidal-hifi",
            cls: "",
            pkg: "tidal-hifi-bin (AUR)"
        },
        {
            key: "scratchpad",
            label: "Scratchpad",
            category: "Other",
            name: "Scratchpad",
            icon: "\u{f0018}",
            command: "",
            cls: "",
            pkg: ""
        }
    ]

    function presetFor(command: string): var {
        return presets.find(p => p.command === command) ?? null;
    }

    // Icons offered for the badge
    readonly property var icons: ["\u{f05a3}", "\u{f2c6}", "\u{f066f}", "\u{f0b79}", "\u{f0369}", "\u{f01ee}", "\u{f04c7}", "\u{f075a}", "\u{f05c3}", "\u{f02cb}", "\u{f0994}", "\u{f0567}", "\u{f059f}", "\u{f018d}", "\u{f039e}", "\u{f00ed}", "\u{f0297}", "\u{f06a9}", "\u{f024b}", "\u{f0018}"]

    // ========================================================================
    // CHANGES
    // ========================================================================

    // "My Notes" -> "my-notes", unique among the specials
    function _newId(name: string): string {
        const base = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "special";
        let id = base;
        for (let n = 2; list.some(s => s.id === id); n++)
            id = base + "-" + n;
        return id;
    }

    // Saves `entry` (any fields) at `index` (-1 = new). Keys passed here
    // replace any override from Settings › Keybinds for the same bind, since
    // this page shows the keys in effect
    function save(index: int, entry) {
        const next = [...list];
        const old = index >= 0 && index < next.length ? next[index] : null;
        const item = Object.assign({}, old ?? {
            command: "",
            class: "",
            keys: "",
            moveKeys: "",
            autostart: false
        }, entry);
        item.id = old ? old.id : _newId(entry.name);

        const dropped = [];
        if (entry.keys !== undefined)
            dropped.push("special-" + item.id);
        if (entry.moveKeys !== undefined)
            dropped.push("move-to-" + item.id);
        _dropOverrides(dropped);

        if (old)
            next[index] = item;
        else
            next.push(item);
        StateService.set("specials.list", next);
    }

    function setAutostart(index: int, value: bool) {
        const next = [...list];
        next[index] = Object.assign({}, next[index], {
            autostart: value
        });
        StateService.set("specials.list", next);
    }

    function remove(index: int) {
        const item = list[index];
        if (!item)
            return;
        _dropOverrides(["special-" + item.id, "move-to-" + item.id]);
        StateService.set("specials.list", list.filter((_, i) => i !== index));
    }

    function move(index: int, direction: int) {
        const to = index + direction;
        if (to < 0 || to >= list.length)
            return;
        const next = [...list];
        [next[index], next[to]] = [next[to], next[index]];
        StateService.set("specials.list", next);
    }

    function _dropOverrides(ids) {
        const overrides = StateService.get("keybinds.overrides", []);
        const kept = overrides.filter(o => !ids.includes(o.id));
        if (kept.length !== overrides.length)
            StateService.set("keybinds.overrides", kept);
    }

    // ========================================================================
    // ACTIONS
    // ========================================================================

    function toggle(id: string) {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + id + "\")");
    }

    // Opens the app hidden in its workspace, like the login autostart
    function startHidden(id: string) {
        const item = find(id);
        if (!item || item.command === "")
            return;
        const lua = "hl.exec_cmd(" + JSON.stringify(item.command) + ", { workspace = " + JSON.stringify("special:" + id + " silent") + " })";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // ========================================================================
    // INSTALLED APPS
    // ========================================================================

    // First word of each command -> installed (missing commands aren't keys
    // until checked)
    property var installed: ({})

    function binaryOf(command: string): string {
        return (command ?? "").trim().split(/\s+/)[0] ?? "";
    }

    function isMissing(command: string): bool {
        const bin = binaryOf(command);
        return bin !== "" && installed[bin] === false;
    }

    // Checks the commands of the list plus `extra` (the dialog's field)
    function checkInstalled(extra: string) {
        const bins = [...new Set([...list.map(s => binaryOf(s.command)), binaryOf(extra)].filter(b => b !== ""))];
        if (bins.length === 0)
            return;
        // Never change a running Process's command: check again when done
        if (checkProc.running) {
            checkProc.again = true;
            checkProc.againExtra = extra;
            return;
        }
        checkProc.command = ["sh", "-c", 'for b in "$@"; do if command -v "$b" >/dev/null 2>&1; then echo "1 $b"; else echo "0 $b"; fi; done', "sh", ...bins];
        checkProc.running = true;
    }

    onListChanged: checkInstalled("")

    Process {
        id: checkProc

        property bool again: false
        property string againExtra: ""

        onExited: {
            if (again) {
                again = false;
                root.checkInstalled(againExtra);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.installed);
                for (const line of text.split("\n")) {
                    if (line.length > 2)
                        next[line.slice(2)] = line[0] === "1";
                }
                root.installed = next;
            }
        }
    }
}
