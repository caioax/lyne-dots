pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Default apps (terminal, file manager, browser, editor) shared by the whole
// shell, chosen in Settings › System › Apps. Each is a command plus the id of
// its .desktop file (apps.<slot> in state.json; the editor stays in
// system.editor for `lyne state`). They reach:
//   * the Apps keybinds: HyprlandSettingsService writes lyne_apps() to
//     hypr/local/settings.lua (hypr/conf/keybinds.lua)
//   * apps run in a terminal (launcher, lyne update): terminalArgv()
//   * xdg-open and Dolphin: scripts/default-apps.sh sets mimeapps.list and
//     kdeglobals when a slot changes here
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/default-apps.sh"

    // `mimes` mirror scripts/default-apps.sh; `bindId` is the keybind that
    // opens the app (hypr/conf/keybinds.lua)
    readonly property var slots: [
        {
            key: "terminal",
            label: "Terminal",
            icon: "\u{f018d}",
            category: "TerminalEmulator",
            path: "apps.terminal",
            bindId: "terminal",
            luaKey: "terminal",
            mimes: [],
            usage: "Terminal apps from the launcher, lyne update, Dolphin's \"Open terminal here\""
        },
        {
            key: "fileManager",
            label: "File manager",
            icon: "\u{f024b}",
            category: "FileManager",
            path: "apps.fileManager",
            bindId: "file-manager",
            luaKey: "file_manager",
            mimes: ["inode/directory"],
            usage: "Folders opened by xdg-open (screenshots, Settings)"
        },
        {
            key: "browser",
            label: "Browser",
            icon: "\u{f059f}",
            category: "WebBrowser",
            path: "apps.browser",
            bindId: "browser",
            luaKey: "browser",
            mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"],
            usage: "Links opened by xdg-open (captive portal, notifications)"
        },
        {
            key: "editor",
            label: "Editor",
            icon: "\u{f0dc8}",
            category: "TextEditor",
            path: "system.editor",
            bindId: "",
            luaKey: "",
            mimes: ["text/plain"],
            usage: "Text files, lyne state and $EDITOR in new shells (GUI editors may need a flag like code --wait)"
        }
    ]

    // Every mime type of the slots (V4 has no Array.flatMap)
    readonly property var allMimes: slots.reduce((all, s) => all.concat(s.mimes), [])

    // { command, desktop } per slot
    readonly property var terminal: _read("terminal")
    readonly property var fileManager: _read("fileManager")
    readonly property var browser: _read("browser")
    readonly property var editor: _read("editor")

    // Terminal apps without a .desktop file that says so (custom commands)
    readonly property var _terminalApps: ["nvim", "vim", "vi", "nano", "hx", "helix", "micro", "kak", "emacs", "yazi", "ranger", "lf", "nnn", "mc", "btop", "htop"]

    function slot(key: string): var {
        return slots.find(s => s.key === key) ?? null;
    }

    function _read(key: string): var {
        const path = slot(key).path;
        const value = StateService.get(path, StateService.getDefault(path, null));
        if (typeof value === "string")
            return {
                command: value,
                desktop: ""
            };
        return {
            command: value?.command ?? "",
            desktop: value?.desktop ?? ""
        };
    }

    // ========================================================================
    // INSTALLED APPS
    // ========================================================================

    // Filled in asynchronously after startup
    readonly property var _entries: DesktopEntries.applications.values

    function binaryOf(command: string): string {
        return binaries.binaryOf(command);
    }

    function _basename(path: string): string {
        return path.split("/").pop();
    }

    // .desktop entry of a slot's app: the saved id, else one whose id or
    // command matches the binary
    function entryFor(key: string): var {
        const value = root[key];
        if (value.desktop !== "") {
            const byId = _entries.find(e => e.id === value.desktop);
            if (byId)
                return byId;
        }
        const bin = _basename(binaryOf(value.command));
        if (bin === "")
            return null;
        return _entries.find(e => e.id === bin || _basename(e.command[0] ?? "") === bin) ?? null;
    }

    // Installed apps of a slot's category, by name
    function candidates(key: string): var {
        const category = slot(key).category;
        const seen = new Set();
        return _entries.filter(e => {
            if (!e.categories.includes(category) || seen.has(e.id))
                return false;
            seen.add(e.id);
            return true;
        }).sort((a, b) => a.name.localeCompare(b.name));
    }

    // Command of a .desktop entry, without the field codes (%U, %F...)
    function commandOf(entry): string {
        return (entry?.execString ?? "").replace(/%[uUfFdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
    }

    function nameOf(key: string): string {
        return entryFor(key)?.name ?? binaryOf(root[key].command);
    }

    function needsTerminal(key: string): bool {
        const entry = entryFor(key);
        if (entry)
            return entry.runInTerminal;
        return _terminalApps.includes(_basename(binaryOf(root[key].command)));
    }

    // ========================================================================
    // RUNNING
    // ========================================================================

    // argv running `argv` in the default terminal
    function terminalArgv(argv): var {
        return [script, "term", ...argv];
    }

    // Shell command opening a slot's app (terminal ones through the terminal)
    function commandFor(key: string): string {
        const command = root[key].command;
        if (command === "" || key === "terminal" || !needsTerminal(key))
            return command;
        return script + " term " + command;
    }

    // Shell command opening a .desktop entry (for custom shortcuts); ~ keeps
    // it readable and Hyprland runs it through sh
    function shellCommandOf(entry): string {
        const command = commandOf(entry);
        return entry?.runInTerminal ? "~/.config/quickshell/scripts/default-apps.sh term " + command : command;
    }

    // What a slot's shortcut runs, for display
    function describe(key: string): string {
        const command = root[key].command;
        if (command === "" || key === "terminal" || !needsTerminal(key))
            return command;
        return command + " in " + nameOf("terminal");
    }

    function open(key: string) {
        const command = commandFor(key);
        if (command !== "")
            Quickshell.execDetached(["sh", "-c", command]);
    }

    // ========================================================================
    // CHANGES
    // ========================================================================

    // Picks an app for a slot: a .desktop entry, or a command (entry null)
    function set(key: string, command: string, entry) {
        const path = slot(key).path;
        if (key === "editor")
            StateService.set(path, command);
        else
            StateService.set(path, {
                command,
                desktop: entry?.id ?? ""
            });
        apply(key);
    }

    // Makes a slot's app the system default (mimeapps, kdeglobals). Only
    // when it's picked here: other apps may have changed the defaults since,
    // so nothing is applied at startup (the Apps page shows the mismatch)
    function apply(key: string) {
        const value = root[key];
        if (value.command === "")
            return;
        const entry = entryFor(key);
        _run(["apply", key, value.command, entry?.id ?? "", needsTerminal(key) ? "1" : "0"]);
    }

    // ========================================================================
    // STATUS
    // ========================================================================

    // mime type -> .desktop file xdg-open uses now
    property var mimeDefaults: ({})
    // Which slots' binaries are installed
    BinaryCheck {
        id: binaries
    }

    // .desktop file a slot's mime types should open with
    function expectedDesktop(key: string): string {
        const entry = entryFor(key);
        return entry && !needsTerminal(key) ? entry.id + ".desktop" : "lyne-" + key + ".desktop";
    }

    // What xdg-open uses instead of the slot's app ("" = it's the app)
    function mimeMismatch(key: string): string {
        const mimes = slot(key).mimes;
        if (mimes.length === 0 || root[key].command === "")
            return "";
        const expected = expectedDesktop(key);
        for (const mime of mimes) {
            const current = mimeDefaults[mime];
            if (current !== undefined && current !== expected)
                return current || "nothing";
        }
        return "";
    }

    function isMissing(key: string): bool {
        return binaries.isMissing(root[key].command);
    }

    // Reads mimeapps and checks the slots' binaries (the Apps page calls it)
    function refresh() {
        _readStatus();
        binaries.check(slots.map(s => root[s.key].command));
    }

    function _readStatus() {
        if (statusProc.running) {
            statusProc.again = true;
            return;
        }
        statusProc.command = [script, "status", ...allMimes];
        statusProc.running = true;
    }

    // Applies run one at a time, then the status is read again
    property var _pending: []

    function _run(args) {
        _pending = [..._pending, args];
        _nextApply();
    }

    function _nextApply() {
        if (applyProc.running)
            return;
        if (_pending.length === 0) {
            _readStatus();
            return;
        }
        applyProc.command = [script, ..._pending[0]];
        _pending = _pending.slice(1);
        applyProc.running = true;
    }

    Process {
        id: applyProc

        // Still `running` inside the handler
        onExited: Qt.callLater(root._nextApply)

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Apps] " + text.trim());
            }
        }
    }

    Process {
        id: statusProc

        property bool again: false

        onExited: {
            if (again) {
                again = false;
                Qt.callLater(root._readStatus);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const space = line.indexOf(" ");
                    if (space > 0)
                        next[line.slice(0, space)] = line.slice(space + 1).trim();
                }
                root.mimeDefaults = next;
            }
        }
    }
}
