pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Screenshot requests from anywhere in the shell (shell.qml opens it)
    signal screenshotRequested

    // For callers that close first (so they aren't captured) and are
    // destroyed with their window: the wait lives here
    function requestScreenshotAfter(ms: int) {
        screenshotDelay.interval = ms;
        screenshotDelay.restart();
    }

    Timer {
        id: screenshotDelay
        onTriggered: root.screenshotRequested()
    }
}
