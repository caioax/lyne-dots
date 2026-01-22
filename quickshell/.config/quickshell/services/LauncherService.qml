pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // ========================================================================
    // PROPRIEDADES
    // ========================================================================

    property bool visible: false
    property string query: ""
    property int selectedIndex: 0
    property int maxItems: 50

    // Lista de apps filtrada
    readonly property var filteredApps: {
        let apps = DesktopEntries.applications.values;

        if (query === "") {
            return apps.slice(0, maxItems);
        }

        const q = query.toLowerCase();
        let result = apps.filter(app => {
            const name = (app.name || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const genericName = (app.genericName || "").toLowerCase();
            return name.includes(q) || comment.includes(q) || genericName.includes(q);
        });

        return result.slice(0, maxItems);
    }

    // ========================================================================
    // FUNÇÕES PÚBLICAS
    // ========================================================================

    function show() {
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
        if (visible) hide();
        else show();
    }

    function launch(entry) {
        if (!entry) return;

        console.log("[Launcher] Launching:", entry.name);

        // Remove field codes do .desktop (%u, %U, %f, %F, %i, %c, %k, etc)
        let cmd = entry.execString;
        cmd = cmd.replace(/%[uUfFdDnNickvm]/g, "").trim();
        cmd = cmd.replace(/\s+/g, " "); // Remove espaços extras

        Quickshell.execDetached(["sh", "-c", cmd]);
        hide();
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launch(filteredApps[selectedIndex]);
        }
    }

    // ========================================================================
    // NAVEGAÇÃO
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

    // Reset selectedIndex quando query muda
    onQueryChanged: {
        selectedIndex = 0;
    }
}
