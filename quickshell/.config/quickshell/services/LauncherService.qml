pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
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

    // Runs .desktop entries marked Terminal=true
    readonly property string terminal: StateService.get("launcher.terminal", "kitty") || "kitty"
    // Most used apps first; off keeps the list alphabetical
    readonly property bool rankByUsage: StateService.get("launcher.rankByUsage", true)

    // Persisted app ids. Usage is a list of { id, count, last } (not a map:
    // lyne's state sync keeps lists whole but drops keys missing from defaults)
    readonly property var favorites: StateService.get("launcher.favorites", [])
    readonly property var hidden: StateService.get("launcher.hidden", [])
    readonly property var usage: StateService.get("launcher.usage", [])

    // Layout template: "spotlight" (default), "sidebar", "dropdown" or "grid"
    readonly property string style: StateService.get("launcher.style", "spotlight")
    // Where the template sits, when it has a choice: spotlight "center",
    // "top" or "bottom" (against that screen edge, or the bar when it's
    // there), sidebar "left" or "right". Falls back to the template's first
    // option when the saved one belongs to another template
    readonly property var positions: ({
            spotlight: ["center", "top", "bottom"],
            sidebar: ["left", "right"]
        })
    readonly property string position: positionFor(style)
    // Search field "top", "bottom", or "auto": by the bottom edge when the
    // panel hangs from it, so it stays put and the list grows away from it
    readonly property string order: StateService.get("launcher.order", "top")

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
        },
        {
            id: "clipboard",
            prefix: ";",
            label: "Clipboard",
            icon: "\u{f014d}",
            placeholder: "Search the clipboard…"
        }
    ]
    readonly property var mode: modes.find(m => m.prefix !== "" && query.startsWith(m.prefix)) ?? modes[0]
    // Changes only when the mode does (`mode` re-evaluates on every key)
    readonly property string modeId: mode.id
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
        return _search(appIndex, id => (rankByUsage ? 15 * Math.log2(1 + (scores[id] ?? 0)) : 0) + (pinned.has(id) ? 25 : 0));
    }

    // Apps below the favorites: most used first, then alphabetical. While
    // searching, the best matches first
    readonly property var filteredApps: {
        if (term !== "")
            return appMatches.map(m => m.item);

        const byName = (a, b) => (a.name || "").localeCompare(b.name || "");
        const byRank = (a, b) => (rankByUsage ? (scores[appId(b)] ?? 0) - (scores[appId(a)] ?? 0) : 0) || byName(a, b);
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
    // CLIPBOARD
    // ========================================================================

    // History entries as launcher items: the preview as the name, a line of
    // details as the comment; `clip` is the ClipboardService entry
    readonly property var clipItems: ClipboardService.entries.map(entry => _clipItem(entry))

    // Kinds of entry the clipboard mode shows: "all", "text" (text, paths,
    // colors), "image" or "link". Back to "all" on each open
    property string clipFilter: "all"
    readonly property var clipFilters: [
        {
            id: "all",
            label: "All",
            icon: "\u{f014d}"
        },
        {
            id: "text",
            label: "Text",
            icon: "\u{f09a8}"
        },
        {
            id: "image",
            label: "Images",
            icon: "\u{f0976}"
        },
        {
            id: "link",
            label: "Links",
            icon: "\u{f0337}"
        }
    ]

    readonly property var shownClips: clipFilter === "all" ? clipItems : clipItems.filter(item => {
        const kind = item.clip.kind;
        return clipFilter === "text" ? kind !== "image" && kind !== "link" : kind === clipFilter;
    })

    readonly property var clipIndex: shownClips.map(item => ({
                item: item,
                id: item.id,
                fields: [_field(item.name, 1, false)]
            }))

    readonly property var clipMatches: mode.id === "clipboard" ? _search(clipIndex, () => 0) : []

    readonly property var filteredClips: term !== "" ? clipMatches.map(m => m.item) : shownClips

    // Glyph per entry kind
    readonly property var clipGlyphs: ({
            text: "\u{f09a8}",
            link: "\u{f0337}",
            color: "\u{f03d8}",
            path: "\u{f024b}",
            image: "\u{f021f}"
        })

    // ========================================================================
    // RESULTS
    // ========================================================================

    // The list for the current mode
    readonly property var results: {
        switch (mode.id) {
        case "actions":
            return filteredActions;
        case "calc":
            return calcItems;
        case "clipboard":
            return filteredClips;
        default:
            return filteredApps;
        }
    }

    readonly property int favoriteCount: favoriteApps.length
    // Everything that can be selected, in keyboard order
    readonly property var entries: [...favoriteApps, ...results]

    // Matched name chars per item id, for highlighting
    readonly property var namePositions: {
        const map = {};
        for (const m of [...appMatches, ...actionMatches, ...clipMatches])
            map[m.id] = m.positions;
        return map;
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    // Saved position if the template offers it, else its first option
    function positionFor(template: string): string {
        const options = positions[template] ?? [];
        let saved = StateService.get("launcher.position", "bottom");
        // Spotlight "bar" (next to the bar) became the bar's edge
        if (saved === "bar")
            saved = Config.barOnBottom ? "bottom" : "top";
        return options.includes(saved) ? saved : options[0] ?? "";
    }

    // Whether the template in that position hangs from the bottom edge:
    // dropdown and sidebar follow the bar, spotlight its own position
    function atBottomEdge(template: string, position: string): bool {
        if (template === "spotlight")
            return position === "bottom";
        return (template === "dropdown" || template === "sidebar") && Config.barOnBottom;
    }

    // Upside-down panel: search at the bottom, the list growing upward
    function isReversed(template: string, position: string): bool {
        return order === "bottom" || (order === "auto" && atBottomEdge(template, position));
    }

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

    function setClipFilter(id: string) {
        clipFilter = id;
        selectedIndex = 0;
    }

    // Deletes a clipboard entry from the history
    function removeClip(item) {
        ClipboardService.remove(item?.clip);
        _clampSelection();
    }

    function openClipLink(item) {
        const text = item?.clip?.text ?? "";
        Qt.openUrlExternally(/^www\./i.test(text) ? "https://" + text : text);
        hide();
    }

    // Switches to the next (or previous) mode, keeping what was typed
    function cycleMode(step: int) {
        const index = modes.indexOf(mode);
        const next = modes[(index + step + modes.length) % modes.length];
        query = next.prefix + query.slice(mode.prefix.length);
    }

    function show() {
        showMode("apps");
    }

    // Opens in a mode, e.g. "clipboard" (SUPER+V)
    function showMode(id: string) {
        _refreshToken++;
        query = modes.find(m => m.id === id)?.prefix ?? "";
        selectedIndex = 0;
        clipFilter = "all";
        visible = true;
        if (id === "clipboard")
            ClipboardService.refresh();
    }

    // Closes if open in that mode, else opens (or switches) to it
    function toggleMode(id: string) {
        if (visible && modeId === id)
            hide();
        else if (visible)
            query = modes.find(m => m.id === id)?.prefix ?? "";
        else
            showMode(id);
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

    // Opens an app, or runs an action / calculator result / clipboard
    // entry. Actions marked `confirm` need a second call while selected;
    // `stay` ones run right away and keep the launcher open
    function activate(item) {
        if (!item)
            return;
        if (isApp(item)) {
            launch(item);
            return;
        }
        if (item.stay) {
            item.run();
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

    // Moves a favorite `delta` places in the tiles' order
    function moveFavorite(id: string, delta: int) {
        const from = favorites.indexOf(id);
        const to = from + delta;
        if (from === -1 || to < 0 || to >= favorites.length)
            return;
        const list = [...favorites];
        list.splice(from, 1);
        list.splice(to, 0, id);
        StateService.set("launcher.favorites", list);
    }

    function unpin(id: string) {
        StateService.set("launcher.favorites", favorites.filter(f => f !== id));
    }

    function clearUsage() {
        StateService.set("launcher.usage", []);
    }

    // Desktop entry for an id, hidden or not (null once uninstalled)
    function entryById(id: string): var {
        return DesktopEntries.applications.values.find(app => appId(app) === id) ?? null;
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

    function _clipItem(entry): var {
        const image = entry.kind === "image";
        const size = entry.width > 0 ? entry.width + "×" + entry.height + "  ·  " : "";
        return {
            id: "clip-" + entry.id,
            name: image ? "Image" : entry.text,
            comment: image ? size + entry.format.toUpperCase() + "  ·  " + entry.size : entry.kind === "link" ? "Link" : entry.kind === "color" ? "Color" : entry.kind === "path" ? "Path" : "",
            glyph: clipGlyphs[entry.kind],
            clip: entry,
            run: () => ClipboardService.copy(entry)
        };
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

    // The history is read when the clipboard mode opens (not while typing)
    onModeIdChanged: {
        if (modeId === "clipboard" && visible)
            ClipboardService.refresh();
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
