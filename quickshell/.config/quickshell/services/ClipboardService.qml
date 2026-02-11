pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    property string query: ""
    property int selectedIndex: 0

    // Raw entries from cliphist
    property var entries: []

    // Filtered entries based on query
    readonly property var filteredEntries: {
        if (query === "")
            return entries.slice(0, entries.length);

        const q = query.toLowerCase();
        return entries.filter(entry => {
            return entry.text.toLowerCase().includes(q);
        }).slice(0, entries.length);
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function show() {
        refresh();
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

    function selectItem(index) {
        if (index < 0 || index >= filteredEntries.length)
            return;

        const entry = filteredEntries[index];
        console.log("[Clipboard] Selecting entry:", entry.line.substring(0, 50));

        // Pipe the full line to cliphist decode, then to wl-copy
        selectProc.command = ["sh", "-c", "echo " + shellEscape(entry.line) + " | cliphist decode | wl-copy"];
        selectProc.running = true;
    }

    function selectCurrent() {
        selectItem(selectedIndex);
    }

    function deleteItem(index) {
        if (index < 0 || index >= filteredEntries.length)
            return;

        const entry = filteredEntries[index];
        console.log("[Clipboard] Deleting entry:", entry.line.substring(0, 50));

        deleteProc.command = ["sh", "-c", "echo " + shellEscape(entry.line) + " | cliphist delete"];
        deleteProc.running = true;
    }

    function clearAll() {
        console.log("[Clipboard] Clearing all entries");
        clearProc.running = true;
    }

    function refresh() {
        listProc.running = true;
    }

    // ========================================================================
    // NAVIGATION
    // ========================================================================

    function navigateUp() {
        if (selectedIndex > 0)
            selectedIndex--;
    }

    function navigateDown() {
        if (selectedIndex < filteredEntries.length - 1)
            selectedIndex++;
    }

    onQueryChanged: {
        selectedIndex = 0;
    }

    // ========================================================================
    // INTERNAL
    // ========================================================================

    function shellEscape(str) {
        // Escape single quotes for shell: replace ' with '\''
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    // List clipboard entries
    Process {
        id: listProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                var items = [];

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line)
                        continue;

                    // cliphist format: "id\ttext"
                    const tabIndex = line.indexOf("\t");
                    if (tabIndex === -1)
                        continue;

                    const id = line.substring(0, tabIndex);
                    const content = line.substring(tabIndex + 1);

                    items.push({
                        id: id,
                        text: content,
                        line: line  // Full line needed for decode/delete
                    });
                }

                root.entries = items;
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[Clipboard] " + data)
        }
    }

    // Select/copy entry
    Process {
        id: selectProc

        onExited: code => {
            if (code === 0) {
                console.log("[Clipboard] Entry copied to clipboard");
                root.hide();
            } else {
                console.error("[Clipboard] Failed to copy entry, exit code:", code);
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[Clipboard] " + data)
        }
    }

    // Delete entry
    Process {
        id: deleteProc

        onExited: code => {
            if (code === 0) {
                console.log("[Clipboard] Entry deleted");
                root.refresh();
            } else {
                console.error("[Clipboard] Failed to delete entry, exit code:", code);
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[Clipboard] " + data)
        }
    }

    // Clear all entries
    Process {
        id: clearProc
        command: ["cliphist", "wipe"]

        onExited: code => {
            if (code === 0) {
                console.log("[Clipboard] All entries cleared");
                root.entries = [];
            } else {
                console.error("[Clipboard] Failed to clear entries, exit code:", code);
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[Clipboard] " + data)
        }
    }
}
