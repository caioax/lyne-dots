import QtQuick
import Quickshell.Io

// A Process for requests that can come in bursts. Quickshell's Process
// already reruns with the newest command once a run exits, but its handlers
// then read whatever the newest call left in shared properties (a theme
// name, a buffer cleared mid-run), and every run in between is applied.
// run() while it runs keeps only the newest request and starts it after
// this run has exited; `superseded` tells the handlers this run's result is
// already stale
//
//   QueuedProcess { id: proc; onExited: code => { if (!superseded) use(proc.request) } }
//   proc.run(["cmd", arg], { what: arg })
//
// `request` is what the caller passed for the run in flight. Output buffers
// are cleared in onStarted, not when calling run()
Process {
    id: root

    property var request: null
    // A newer request waits: the result of this run is already stale, and
    // a handler can skip applying it
    readonly property bool superseded: _hasNext

    property var _next: null
    property bool _hasNext: false

    function run(command: var, request: var): void {
        if (running) {
            _next = {
                command,
                request
            };
            _hasNext = true;
            return;
        }
        _start(command, request);
    }

    function _start(command: var, request: var): void {
        root.request = request ?? null;
        root.command = command;
        running = true;
    }

    // Deferred: the owner's onExited (and its stdout handlers) still see
    // this run's request
    onExited: {
        if (_hasNext)
            Qt.callLater(_startNext);
    }

    function _startNext(): void {
        if (running || !_hasNext)
            return;
        const next = _next;
        _next = null;
        _hasNext = false;
        _start(next.command, next.request);
    }
}
