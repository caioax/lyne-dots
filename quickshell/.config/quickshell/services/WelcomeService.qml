pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Welcome screen: a few first choices, step by step. The installer sets
// welcome.pending in the state.json it creates, so it opens on the first
// login; closing it in any way clears it. Reopen with `lyne welcome` or
// Settings › About
Singleton {
    id: root

    property bool visible: false
    property int currentStep: 0

    // Each id needs a component in WelcomeWindow.stepComponents
    readonly property var steps: [
        {
            id: "intro",
            label: "Welcome"
        },
        {
            id: "done",
            label: "All set"
        }
    ]
    readonly property var currentEntry: steps[Math.max(0, Math.min(currentStep, steps.length - 1))]
    readonly property bool isFirst: currentStep === 0
    readonly property bool isLast: currentStep === steps.length - 1

    readonly property bool pending: StateService.get("welcome.pending", false)

    function open() {
        currentStep = 0;
        visible = true;
    }

    function close() {
        visible = false;
        StateService.set("welcome.pending", false);
    }

    function next() {
        if (isLast)
            close();
        else
            currentStep++;
    }

    function back() {
        if (!isFirst)
            currentStep--;
    }

    // First login after the install: wait for the shell to settle (bar,
    // wallpaper) before opening. Once per shell start, when the state has
    // loaded (this singleton may be created before or after that)
    property bool _checked: false

    function _checkFirstRun() {
        if (_checked || StateService.isLoading)
            return;
        _checked = true;
        if (pending)
            firstRunTimer.start();
    }

    Component.onCompleted: _checkFirstRun()

    Connections {
        target: StateService

        function onIsLoadingChanged() {
            root._checkFirstRun();
        }
    }

    Timer {
        id: firstRunTimer

        interval: 1500
        onTriggered: root.open()
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }
}
