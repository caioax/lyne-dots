pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    property string query: ""
    property int selectedIndex: 0

    // Incremented on each open to force re-evaluation of the app list
    property int _refreshToken: 0

    // Filtered app list
    readonly property var filteredApps: {
        void root._refreshToken;
        let apps = DesktopEntries.applications.values;

        // Sort alphabetically
        apps = apps.slice().sort((a, b) => {
            const nameA = (a.name || "").toLowerCase();
            const nameB = (b.name || "").toLowerCase();
            return nameA.localeCompare(nameB);
        });

        if (query === "") {
            return apps.slice(0, apps.length);
        }

        const q = query.toLowerCase();

        // Separate into two groups: name match vs description match
        let nameMatches = [];
        let descMatches = [];

        for (const app of apps) {
            const name = (app.name || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const genericName = (app.genericName || "").toLowerCase();

            if (name.includes(q)) {
                nameMatches.push(app);
            } else if (comment.includes(q) || genericName.includes(q)) {
                descMatches.push(app);
            }
        }

        // Name first, then description
        return [...nameMatches, ...descMatches].slice(0, apps.length);
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

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

        // Remove field codes from .desktop (%u, %U, %f, %F, %i, %c, %k, etc)
        let cmd = entry.execString;
        cmd = cmd.replace(/%[uUfFdDnNickvm]/g, "").trim();
        cmd = cmd.replace(/\s+/g, " "); // Remove extra spaces

        Quickshell.execDetached(["sh", "-c", cmd]);
        hide();
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launch(filteredApps[selectedIndex]);
        }
    }

    // ========================================================================
    // NAVIGATION
    // ========================================================================

    function navigateUp() {
        if (selectedIndex > 0) {
            selectedIndex--;
        }
    }

    function navigateDown() {
        if (selectedIndex < filteredApps.length - 1) {
            selectedIndex++;
        }
    }

    // Reset selectedIndex when query changes
    onQueryChanged: {
        selectedIndex = 0;
    }
}
