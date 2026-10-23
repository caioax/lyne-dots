pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "input.js" as Lib

// Turns the touchpad off and on (Settings › Input). Hyprland has no global
// option for it, only `enabled` in a device rule, so HyprlandSettingsService
// writes one hl.device() per touchpad to hypr/local/settings.lua. The names
// seen are kept in touchpad.names: the rule stays in the file even before
// `hyprctl devices` answers at startup (a rule taken away would leave the
// touchpad as it was until the next login).
Singleton {
    id: root

    // Touchpads connected now (hyprctl devices -j)
    property var present: []
    readonly property bool available: present.length > 0

    readonly property bool enabled: StateService.get("touchpad.enabled", StateService.getDefault("touchpad.enabled", true))
    readonly property var names: StateService.get("touchpad.names", StateService.getDefault("touchpad.names", []))

    function setEnabled(value: bool) {
        StateService.set("touchpad.enabled", value);
    }

    function refresh() {
        if (!devicesProc.running)
            devicesProc.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.refresh();
        }
    }

    // The names are saved once the state is there to save them to
    Connections {
        target: StateService

        function onStateLoaded() {
            root._remember();
        }
    }

    function _remember() {
        if (StateService.isLoading)
            return;
        const merged = Lib.mergeNames(names, present);
        if (merged.length !== names.length)
            StateService.set("touchpad.names", merged);
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.present = Lib.touchpadNames(text);
                root._remember();
            }
        }
    }
}
