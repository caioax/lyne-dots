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

    // state is mutated in place, which QML can't observe by itself: get()
    // reads a counter of the path's top-level key (bumped when anything
    // under it changes) and `revision` (bumped when defaults.json loads), so
    // a set() only reevaluates the bindings of its own key
    property int revision: 0
    // Top-level key -> notifier; filled in place, never reassigned (that
    // would notify every binding)
    property var _notifiers: ({})

    Component {
        id: notifierComponent

        QtObject {
            property int rev: 0
        }
    }

    function _depend(path: string): void {
        const top = path.split(".")[0];
        let notifier = _notifiers[top];
        if (!notifier) {
            notifier = notifierComponent.createObject(root);
            _notifiers[top] = notifier;
        }
        notifier.rev;
    }

    function _bump(top: string): void {
        const notifier = _notifiers[top];
        if (notifier)
            notifier.rev++;
    }

    // Emitted on the first load and when state.json changes outside the shell
    // (e.g. lyne CLI); `keys` are the top-level keys that changed (all of
    // them on the first load)
    signal stateLoaded(var keys)

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

    // A key missing in state.json takes its defaults.json value, as
    // isDefault() and "Restore default" in Settings see it; the literal is
    // only for keys defaults.json doesn't have (or before it's read)
    function get(path: string, defaultValue) {
        root.revision; // dependency for bindings
        _depend(path);
        const value = _lookup(state, path);
        if (value !== undefined)
            return value;
        const def = _lookup(defaults, path);
        return def === undefined ? defaultValue : def;
    }

    function getDefault(path: string, fallback) {
        root.revision;
        const value = _lookup(defaults, path);
        return value === undefined ? fallback : value;
    }

    // Missing keys count as default: get() falls back to defaults.json
    function isDefault(path: string): bool {
        root.revision;
        _depend(path);
        const def = _lookup(defaults, path);
        const value = _lookup(state, path);
        return def === undefined || value === undefined || JSON.stringify(value) === JSON.stringify(def);
    }

    // Paths set here since the last save, merged over an external edit that
    // arrives before the save (not a reactive property: no bindings on it)
    property var _unsaved: ({})

    function _assign(obj, path: string, value): void {
        const keys = path.split('.');
        let current = obj;
        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (!(key in current) || typeof current[key] !== 'object' || current[key] === null)
                current[key] = {};
            current = current[key];
        }
        current[keys[keys.length - 1]] = value;
    }

    function set(path: string, value) {
        if (JSON.stringify(_lookup(state, path)) === JSON.stringify(value))
            return;

        _assign(state, path, value);
        _bump(path.split('.')[0]);
        if (!isLoading) {
            _unsaved[path] = value;
            saveDebounce.restart();
        }
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
            // An external edit before our pending save: theirs, with ours on top
            for (const path of Object.keys(_unsaved))
                _assign(newState, path, JSON.parse(JSON.stringify(_unsaved[path])));
            const changed = [];
            for (const key of new Set([...Object.keys(state), ...Object.keys(newState)])) {
                if (JSON.stringify(state[key]) !== JSON.stringify(newState[key]))
                    changed.push(key);
            }
            state = newState;
            isLoading = false;
            if (changed.length > 0) {
                for (const key of changed)
                    _bump(key);
                stateLoaded(changed);
            }
        } catch (e) {
            console.error("[StateService] JSON Parse Error:", e);
            isLoading = false;
        }
    }

    function saveState() {
        saveDebounce.stop();
        _unsaved = {};
        stateFile.setText(JSON.stringify(state, null, 2) + "\n");
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
            // Local changes not saved yet go on top of it (_apply) and the
            // pending save writes the result. The echo of our own save
            // changes no key, so _apply does nothing with it (comparing with
            // the last text we wrote also ignored an external edit that
            // brought the file back to it: lyne theme set A, B, then A)
            root._apply(text());
        }
        onLoadFailed: error => {
            missing = true;
            if (root.isLoading && defaultsFile.loaded)
                root._apply(defaultsFile.text());
        }
    }
}
