pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "fuzzy.js" as Fuzzy

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    property string query: ""
    // Index into `entries` (favorites first, then the results)
    property int selectedIndex: 0

    // Runs .desktop entries marked Terminal=true (same as the SUPER+Return bind)
    readonly property string terminal: "kitty"

    // Persisted app ids. Usage is a list of { id, count, last } (not a map:
    // lyne's state sync keeps lists whole but drops keys missing from defaults)
    readonly property var favorites: StateService.get("launcher.favorites", [])
    readonly property var hidden: StateService.get("launcher.hidden", [])
    readonly property var usage: StateService.get("launcher.usage", [])

    // Usage keeps at most this many apps, the least recently used go first
    readonly property int usageLimit: 200

    // Incremented on each open to force re-evaluation of the app list
    property int _refreshToken: 0

    // ========================================================================
    // MODES
    // ========================================================================

    // Picked by the first char of the query; Ctrl+Tab cycles through them
    readonly property var modes: [
        {
            id: "apps",
            prefix: "",
            label: "Apps",
            icon: "\u{f0349}",
            placeholder: "Search apps…  (> actions, = calculator)"
        },
        {
            id: "actions",
            prefix: ">",
            label: "Actions",
            icon: "\u{f140b}",
            placeholder: "Run an action…"
        },
        {
            id: "calc",
            prefix: "=",
            label: "Calculator",
            icon: "\u{f00ec}",
            placeholder: "Calculate…  (2^10, 5 km to mi, 20% of 150)"
        }
    ]
    readonly property var mode: modes.find(m => m.prefix !== "" && query.startsWith(m.prefix)) ?? modes[0]
    // The query without the mode prefix
    readonly property string term: query.slice(mode.prefix.length).trim()

    // Id of a `confirm` action waiting for a second Enter
    property string pendingConfirm: ""

    // ========================================================================
    // APPS
    // ========================================================================

    // Every visible app, deduplicated
    readonly property var apps: {
        void root._refreshToken;
        const hiddenIds = new Set(root.hidden);
        const seen = new Set();
        return DesktopEntries.applications.values.filter(app => {
            const id = appId(app);
            if (seen.has(id) || hiddenIds.has(id))
                return false;
            seen.add(id);
            return true;
        });
    }

    // Frecency per app id: launches, halved every two weeks since the last one
    readonly property var scores: {
        const now = Date.now();
        const result = {};
        for (const u of root.usage) {
            const days = (now - u.last) / 86400000;
            result[u.id] = u.count * Math.pow(0.5, days / 14);
        }
        return result;
    }

    // Pinned apps, shown as tiles above the list while nothing is typed
    readonly property var favoriteApps: {
        if (mode.id !== "apps" || term !== "")
            return [];
        const byId = {};
        for (const app of apps)
            byId[appId(app)] = app;
        return favorites.map(id => byId[id]).filter(app => app !== undefined);
    }

    // Prepared search fields per app (see fuzzy.js). Only the name and the
    // command allow scattered letters; the rest must contain the term
    readonly property var appIndex: apps.map(app => ({
                item: app,
                id: appId(app),
                fields: [
                    _field(app.name, 1, true),
                    _field(_commandName(app), 0.7, true),
                    _field(app.genericName, 0.6, false),
                    _field(app.comment, 0.35, false),
                    ...(app.keywords || []).map(k => _field(k, 0.6, false))
                ]
            }))

    readonly property var appMatches: {
        if (mode.id !== "apps")
            return [];
        const pinned = new Set(favorites);
        // Usage and pins break ties within a tier
        return _search(appIndex, id => 15 * Math.log2(1 + (scores[id] ?? 0)) + (pinned.has(id) ? 25 : 0));
    }

    // Apps below the favorites: most used first, then alphabetical. While
    // searching, the best matches first
    readonly property var filteredApps: {
        if (term !== "")
            return appMatches.map(m => m.item);

        const byRank = (a, b) => (scores[appId(b)] ?? 0) - (scores[appId(a)] ?? 0) || (a.name || "").localeCompare(b.name || "");
        const pinned = new Set(favorites);
        return apps.filter(app => !pinned.has(appId(app))).sort(byRank);
    }

    // ========================================================================
    // ACTIONS
    // ========================================================================

    readonly property var actionIndex: LauncherActions.items.map(action => ({
                item: action,
                id: action.id,
                fields: [
                    _field(action.name, 1, true),
                    _field(action.comment, 0.35, false),
                    ...action.keywords.map(k => _field(k, 0.6, false))
                ]
            }))

    readonly property var actionMatches: mode.id === "actions" ? _search(actionIndex, () => 0) : []

    readonly property var filteredActions: term !== "" ? actionMatches.map(m => m.item) : LauncherActions.items

    // ========================================================================
    // CALCULATOR
    // ========================================================================

    property string calcResult: ""
    property string calcError: ""
    // The expression calcResult belongs to
    property string calcExpression: ""

    readonly property var calcItems: {
        if (mode.id !== "calc" || term === "" || calcResult === "")
            return [];
        return [
            {
                id: "calc-result",
                name: calcResult,
                comment: calcExpression + "  ·  Enter copies the result",
                glyph: "\u{f018f}",
                run: () => Quickshell.execDetached(["wl-copy", root.calcResult])
            }
        ];
    }

    // ========================================================================
    // RESULTS
    // ========================================================================

    // The list for the current mode
    readonly property var results: mode.id === "actions" ? filteredActions : mode.id === "calc" ? calcItems : filteredApps

    readonly property int favoriteCount: favoriteApps.length
    // Everything that can be selected, in keyboard order
    readonly property var entries: [...favoriteApps, ...results]

    // Matched name chars per item id, for highlighting
    readonly property var namePositions: {
        const map = {};
        for (const m of [...appMatches, ...actionMatches])
            map[m.id] = m.positions;
        return map;
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    // Apps have no `run`; actions and calculator results do
    function isApp(item): bool {
        return item?.run === undefined;
    }

    function appId(app): string {
        return app?.id || app?.execString || app?.name || "";
    }

    // Name as styled text with the chars matched by the search in accent
    function highlightedName(item, color): string {
        const name = item?.name ?? "";
        const positions = new Set(namePositions[appId(item)] ?? []);
        const escape = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
        let out = "";
        for (let i = 0; i < name.length; i++)
            out += positions.has(i) ? "<b><font color=\"" + color + "\">" + escape(name[i]) + "</font></b>" : escape(name[i]);
        return out;
    }

    // Switches to the next (or previous) mode, keeping what was typed
    function cycleMode(step: int) {
        const index = modes.indexOf(mode);
        const next = modes[(index + step + modes.length) % modes.length];
        query = next.prefix + query.slice(mode.prefix.length);
    }

    function show() {
        _refreshToken++;
        query = "";
        selectedIndex = 0;
        visible = true;
    }

    function hide() {
        visible = false;
        query = "";
        selectedIndex = 0;
    }

    function toggle() {
        if (visible)
            hide();
        else
            show();
    }

    // Opens an app, or runs an action / calculator result. Actions marked
    // `confirm` need a second call while selected
    function activate(item) {
        if (!item)
            return;
        if (isApp(item)) {
            launch(item);
            return;
        }
        if (item.confirm && pendingConfirm !== item.id) {
            pendingConfirm = item.id;
            return;
        }
        console.log("[Launcher] Running:", item.id);
        _pendingRun = item.run;
        hide();
        runDelay.restart();
    }

    function activateSelected() {
        activate(entries[selectedIndex]);
    }

    function launch(entry) {
        if (!entry)
            return;

        console.log("[Launcher] Launching:", entry.name);
        _recordUsage(appId(entry));

        // Remove field codes from .desktop (%u, %U, %f, %F, %i, %c, %k, etc)
        let cmd = entry.execString;
        cmd = cmd.replace(/%[uUfFdDnNickvm]/g, "").trim();
        cmd = cmd.replace(/\s+/g, " "); // Remove extra spaces

        // Start in the entry's Path= (or home) instead of the shell's cwd.
        // execDetached here only takes an argv, so the cd goes in the script
        const dir = entry.workingDirectory || Quickshell.env("HOME");
        const script = "cd '" + dir.replace(/'/g, "'\\''") + "' 2>/dev/null; " + cmd;
        const command = entry.runInTerminal ? [terminal, "-e", "sh", "-c", script] : ["sh", "-c", script];
        Quickshell.execDetached(command);
        hide();
    }

    // --- Favorites and hidden apps ---

    function isFavorite(app): bool {
        return favorites.includes(appId(app));
    }

    function toggleFavorite(app) {
        const id = appId(app);
        const list = favorites.includes(id) ? favorites.filter(f => f !== id) : [...favorites, id];
        StateService.set("launcher.favorites", list);
        _clampSelection();
    }

    function hideApp(app) {
        const id = appId(app);
        if (hidden.includes(id))
            return;
        StateService.set("launcher.hidden", [...hidden, id]);
        if (favorites.includes(id))
            StateService.set("launcher.favorites", favorites.filter(f => f !== id));
        _clampSelection();
    }

    function unhideApp(id: string) {
        StateService.set("launcher.hidden", hidden.filter(h => h !== id));
    }

    // ========================================================================
    // NAVIGATION
    // ========================================================================

    // Moves the selection by `delta` entries, clamped to the list
    function move(delta: int) {
        select(selectedIndex + delta);
    }

    function select(index: int) {
        selectedIndex = Math.max(0, Math.min(entries.length - 1, index));
    }

    function selectFirst() {
        selectedIndex = 0;
    }

    function selectLast() {
        select(entries.length - 1);
    }

    function _clampSelection() {
        select(selectedIndex);
    }

    // ========================================================================
    // INTERNALS
    // ========================================================================

    function _field(text, weight: real, fuzzy: bool): var {
        return {
            target: Fuzzy.prepare(text || ""),
            weight: weight,
            fuzzy: fuzzy
        };
    }

    // Fuzzy search over an index of { item, id, fields } (the first field is
    // the name). Every term must match some field and the best one counts.
    // Returns [{ item, id, score, positions }] best first, where positions
    // are the matched chars of the name
    function _search(index, bonus): var {
        const terms = Fuzzy.normalize(term).text.split(/\s+/).filter(t => t !== "");
        if (terms.length === 0)
            return [];

        const results = [];
        for (const entry of index) {
            let total = 0;
            let positions = [];
            let matched = true;

            for (const t of terms) {
                let best = null;
                entry.fields.forEach((field, i) => {
                    const result = Fuzzy.score(t, field.target, field.fuzzy);
                    if (result && (!best || result.score * field.weight > best.value))
                        best = {
                            value: result.score * field.weight,
                            fromName: i === 0,
                            positions: result.positions
                        };
                });
                if (!best) {
                    matched = false;
                    break;
                }
                total += best.value;
                if (best.fromName)
                    positions = positions.concat(best.positions);
            }
            if (!matched)
                continue;

            results.push({
                item: entry.item,
                id: entry.id,
                score: total + bonus(entry.id),
                positions: positions
            });
        }

        return results.sort((a, b) => b.score - a.score || (a.item.name || "").localeCompare(b.item.name || ""));
    }

    // Executable name, or the last part of the id, so "code" finds VS Code
    function _commandName(app): string {
        const words = (app.execString || "").split(/\s+/).filter(w => w !== "env" && !w.includes("="));
        const exec = (words[0] || "").split("/").pop();
        const idTail = (app.id || "").split(".").pop();
        return exec === idTail ? exec : exec + " " + idTail;
    }

    function _recordUsage(id: string) {
        const now = Date.now();
        const previous = usage.find(u => u.id === id);
        const updated = {
            id: id,
            count: (previous?.count ?? 0) + 1,
            last: now
        };
        const list = [updated, ...usage.filter(u => u.id !== id)];
        StateService.set("launcher.usage", list.slice(0, usageLimit));
    }

    // Actions run after the launcher is gone, so overlays they open (power
    // menu, screenshot, clipboard) get the keyboard and aren't captured
    property var _pendingRun: null

    Timer {
        id: runDelay
        interval: 300
        onTriggered: {
            const run = root._pendingRun;
            root._pendingRun = null;
            if (run)
                run();
        }
    }

    // --- Calculator: qalc runs a moment after typing stops ---

    onTermChanged: {
        if (mode.id === "calc" && term !== "")
            calcDelay.restart();
        else if (term === "") {
            calcResult = "";
            calcError = "";
        }
    }

    Timer {
        id: calcDelay
        interval: 150
        onTriggered: {
            // One run at a time: try again once the current one is done
            if (calcProc.running) {
                restart();
                return;
            }
            calcProc.expression = root.term;
            calcProc.running = true;
        }
    }

    Process {
        id: calcProc

        property string expression

        // 127 = qalc isn't installed
        command: ["sh", "-c", "command -v qalc >/dev/null || exit 127; qalc -t -- \"$1\"", "sh", expression]

        stdout: StdioCollector {
            id: calcOut
        }

        onExited: code => {
            // A newer expression was typed meanwhile: its run comes next
            if (expression !== root.term)
                return;
            if (code === 127) {
                root.calcResult = "";
                root.calcError = "qalc isn't installed (package libqalculate)";
                return;
            }
            const lines = calcOut.text.trim().split("\n").filter(l => l.trim() !== "");
            const last = lines[lines.length - 1] ?? "";
            if (code !== 0 || last === "" || /^error/i.test(last)) {
                root.calcResult = "";
                root.calcError = last.replace(/^error:\s*/i, "") || "Can't calculate that";
                return;
            }
            root.calcError = "";
            root.calcResult = last;
            root.calcExpression = expression;
        }
    }

    // Reset selection and confirmation when the query or selection changes
    onQueryChanged: {
        selectedIndex = 0;
        pendingConfirm = "";
    }

    onSelectedIndexChanged: pendingConfirm = ""

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            root.toggle();
        }
    }
}
