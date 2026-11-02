pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // Main boolean property for other modules to query
    readonly property bool anyModuleOpen: openWindowsCount > 0
    property int openWindowsCount: 0

    // List to know EXACTLY what is open
    property var activeModules: ({})

    function registerOpen(moduleName) {
        if (!activeModules[moduleName]) {
            // A new object: reassigning the same one doesn't notify bindings
            let copy = Object.assign({}, activeModules);
            copy[moduleName] = true;
            activeModules = copy;
            openWindowsCount++;
        }
    }

    function registerClose(moduleName) {
        if (activeModules[moduleName]) {
            // A new object: reassigning the same one doesn't notify bindings
            let copy = Object.assign({}, activeModules);
            delete copy[moduleName];
            activeModules = copy;
            openWindowsCount--;
        }
    }

    // ========================================================================
    // ONE POPUP AT A TIME
    // ========================================================================
    // A popup closes on a timer while its exit animation plays. Creating a
    // window in the same frames (the launcher, Settings, the power menu)
    // stalls that animation and the popup vanishes halfway. Shortcuts that
    // open something go through openAfterClose: the other popups close
    // first and it opens once their surfaces are gone

    // Time a popup takes to go away: its exit animation, then a little room
    // before the surface is unmapped so the last frame is the hidden one
    readonly property int closeDuration: Config.animDuration + Config.animDurationShort / 2

    // Popups on screen, closing ones included: { name: count }. Separate from
    // activeModules, which keeps an auto-hiding bar shown
    property var mappedPopups: ({})

    // Asks every popup but `except` to close
    signal closeRequested(string except)

    function popupMapped(name: string): void {
        const copy = Object.assign({}, mappedPopups);
        copy[name] = (copy[name] ?? 0) + 1;
        mappedPopups = copy;
    }

    function popupUnmapped(name: string): void {
        if (!mappedPopups[name])
            return;
        const copy = Object.assign({}, mappedPopups);
        if (--copy[name] <= 0)
            delete copy[name];
        mappedPopups = copy;
    }

    function othersMapped(name: string): bool {
        return Object.keys(mappedPopups).some(m => m !== name);
    }

    // Runs `open` (which may also close `name`, a toggle) right away when no
    // other popup is on screen; otherwise closes them and runs it when the
    // last one is gone. `minDelay` waits at least that long (a screenshot
    // waits for the scale animation too)
    function openAfterClose(name: string, open: var, minDelay: int): void {
        if (!othersMapped(name) && !(minDelay > 0)) {
            _pending = null;
            pendingTimeout.stop();
            open();
            return;
        }
        _pending = open;
        _pendingFor = name;
        closeRequested(name);
        minDelayTimer.interval = minDelay > 0 ? minDelay : 0;
        minDelayTimer.restart();
        pendingTimeout.restart();
        _tryPending();
    }

    property var _pending: null
    property string _pendingFor: ""

    function _tryPending(): void {
        if (_pending && !minDelayTimer.running && !othersMapped(_pendingFor))
            Qt.callLater(_runPending);
    }

    function _runPending(): void {
        if (!_pending)
            return;
        const open = _pending;
        _pending = null;
        pendingTimeout.stop();
        open();
    }

    onMappedPopupsChanged: _tryPending()

    Timer {
        id: minDelayTimer
        onTriggered: root._tryPending()
    }

    // A popup that never reports going away doesn't block the shortcut
    Timer {
        id: pendingTimeout
        interval: root.closeDuration * 3
        onTriggered: root._runPending()
    }
}
