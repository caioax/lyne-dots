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
    // Index into `entries` (favorites first, then the list)
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
        if (query.trim() !== "")
            return [];
        const byId = {};
        for (const app of apps)
            byId[appId(app)] = app;
        return favorites.map(id => byId[id]).filter(app => app !== undefined);
    }

    // Prepared search fields per app (see fuzzy.js). Only the name and the
    // command allow scattered letters; the rest must contain the term
    readonly property var searchIndex: apps.map(app => ({
                app: app,
                id: appId(app),
                name: Fuzzy.prepare(app.name || ""),
                command: Fuzzy.prepare(_commandName(app)),
                generic: Fuzzy.prepare(app.genericName || ""),
                keywords: (app.keywords || []).map(k => Fuzzy.prepare(k)),
                comment: Fuzzy.prepare(app.comment || "")
            }))

    // Search results: [{ app, positions }] best first, where positions are
    // the matched chars of the name (for highlighting)
    readonly property var matches: {
        const terms = Fuzzy.normalize(query.trim()).text.split(/\s+/).filter(t => t !== "");
        if (terms.length === 0)
            return [];

        const pinned = new Set(favorites);
        const results = [];

        for (const entry of searchIndex) {
            let total = 0;
            let positions = [];
            let matched = true;

            // Every term must match some field; the best field counts
            for (const term of terms) {
                const name = Fuzzy.score(term, entry.name, true);
                // [result, weight]
                const candidates = [
                    [name, 1],
                    [Fuzzy.score(term, entry.command, true), 0.7],
                    [Fuzzy.score(term, entry.generic, false), 0.6],
                    [Fuzzy.score(term, entry.comment, false), 0.35],
                    ...entry.keywords.map(k => [Fuzzy.score(term, k, false), 0.6])
                ];
                let best = null;
                for (const [result, weight] of candidates) {
                    if (result && (!best || result.score * weight > best.value))
                        best = {
                            value: result.score * weight,
                            fromName: result === name,
                            positions: result.positions
                        };
                }
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

            // Usage and pins break ties within a tier
            total += 15 * Math.log2(1 + (scores[entry.id] ?? 0)) + (pinned.has(entry.id) ? 25 : 0);
            results.push({
                app: entry.app,
                score: total,
                positions: positions
            });
        }

        return results.sort((a, b) => b.score - a.score || (a.app.name || "").localeCompare(b.app.name || ""));
    }

    // Matched name chars per app id, for highlighting
    readonly property var namePositions: {
        const map = {};
        for (const m of matches)
            map[appId(m.app)] = m.positions;
        return map;
    }

    // The list below the favorites: most used first, then alphabetical.
    // While searching, the fuzzy matches best first
    readonly property var filteredApps: {
        if (query.trim() !== "")
            return matches.map(m => m.app);

        const byRank = (a, b) => (scores[appId(b)] ?? 0) - (scores[appId(a)] ?? 0) || (a.name || "").localeCompare(b.name || "");
        const pinned = new Set(favorites);
        return apps.filter(app => !pinned.has(appId(app))).sort(byRank);
    }

    readonly property int favoriteCount: favoriteApps.length
    // Everything that can be selected, in keyboard order
    readonly property var entries: [...favoriteApps, ...filteredApps]

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function appId(app): string {
        return app?.id || app?.execString || app?.name || "";
    }

    // App name as styled text with the chars matched by the search in accent
    function highlightedName(app, color): string {
        const name = app?.name ?? "";
        const positions = new Set(namePositions[appId(app)] ?? []);
        const escape = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
        let out = "";
        for (let i = 0; i < name.length; i++)
            out += positions.has(i) ? "<b><font color=\"" + color + "\">" + escape(name[i]) + "</font></b>" : escape(name[i]);
        return out;
    }

    // Executable name, or the last part of the id, so "code" finds VS Code
    function _commandName(app): string {
        const words = (app.execString || "").split(/\s+/).filter(w => w !== "env" && !w.includes("="));
        const exec = (words[0] || "").split("/").pop();
        const idTail = (app.id || "").split(".").pop();
        return exec === idTail ? exec : exec + " " + idTail;
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

    function launchSelected() {
        launch(entries[selectedIndex]);
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

    // Reset selectedIndex when query changes
    onQueryChanged: {
        selectedIndex = 0;
    }

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
