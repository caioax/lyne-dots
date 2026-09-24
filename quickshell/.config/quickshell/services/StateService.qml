pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state.json"
    readonly property string defaultsPath: Quickshell.env("HOME") + "/.lyne-dots/.data/quickshell/defaults.json"

    property var state: ({})
    property var defaults: ({})
    property bool isLoading: true

    // Bumped on every change so bindings that call get() re-evaluate
    // (state is mutated in place, which QML can't observe by itself)
    property int revision: 0

    // Last text written by us, to ignore the watcher echo of our own saves
    property string _lastWritten: ""

    // Emitted on the first load and when state.json changes outside the shell (e.g. lyne CLI)
    signal stateLoaded

    // --- Dot Notation Functions ---
    function _lookup(obj, path: string) {
        const keys = path.split('.');
        let current = obj;
        for (const key of keys) {
            if (current !== null && typeof current === 'object' && key in current)
                current = current[key];
            else
                return undefined;
        }
        return current;
    }

    function get(path: string, defaultValue) {
        root.revision; // dependency for bindings
        const value = _lookup(state, path);
        return value === undefined ? defaultValue : value;
    }

    function getDefault(path: string, fallback) {
        root.revision;
        const value = _lookup(defaults, path);
        return value === undefined ? fallback : value;
    }

    // Missing keys count as default: get() falls back to it
    function isDefault(path: string): bool {
        root.revision;
        const def = _lookup(defaults, path);
        const value = _lookup(state, path);
        return def === undefined || value === undefined || JSON.stringify(value) === JSON.stringify(def);
    }

    function set(path: string, value) {
        if (JSON.stringify(_lookup(state, path)) === JSON.stringify(value))
            return;

        const keys = path.split('.');
        let current = state;
        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (!(key in current) || typeof current[key] !== 'object')
                current[key] = {};
            current = current[key];
        }
        current[keys[keys.length - 1]] = value;
        revision++;
        if (!isLoading)
            saveDebounce.restart();
    }

    function reset(path: string) {
        const def = _lookup(defaults, path);
        if (def !== undefined)
            set(path, JSON.parse(JSON.stringify(def)));
    }

    // --- IO Logic ---
    function _apply(text: string) {
        try {
            const newState = JSON.parse(text);
            const changed = JSON.stringify(state) !== JSON.stringify(newState);
            state = newState;
            isLoading = false;
            if (changed) {
                revision++;
                stateLoaded();
            }
        } catch (e) {
            console.error("[StateService] JSON Parse Error:", e);
            isLoading = false;
        }
    }

    function saveState() {
        saveDebounce.stop();
        _lastWritten = JSON.stringify(state, null, 2) + "\n";
        stateFile.setText(_lastWritten);
    }

    // Coalesces bursts of set() calls (e.g. dragging a slider) into one write
    Timer {
        id: saveDebounce
        interval: 300
        onTriggered: root.saveState()
    }

    FileView {
        id: defaultsFile
        path: root.defaultsPath
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.defaults = JSON.parse(text());
                root.revision++;
            } catch (e) {
                console.error("[StateService] defaults.json Parse Error:", e);
            }
            // No state.json yet: start from the defaults
            if (root.isLoading && stateFile.missing)
                root._apply(text());
        }
    }

    FileView {
        id: stateFile

        property bool missing: false

        path: root.statePath
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            missing = false;
            const content = text();
            if (content === root._lastWritten)
                return;
            // Local changes not yet written win over an external edit
            if (saveDebounce.running)
                return;
            root._apply(content);
        }
        onLoadFailed: error => {
            missing = true;
            if (root.isLoading && defaultsFile.loaded)
                root._apply(defaultsFile.text());
        }
    }
}
