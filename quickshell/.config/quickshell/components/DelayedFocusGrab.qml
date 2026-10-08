import QtQuick
import Quickshell.Hyprland

// A focus grab taken a moment after `wanted` turns true: Hyprland clears a
// grab activated in the same tick its surface maps (or is shown again while
// an exit animation keeps it alive), which closed popups as soon as they
// opened. `taken` fires once the grab is set, to focus an input. rearm()
// drops it and takes it again after the delay, for a window shown again
// without unmapping or one that let another grab it
HyprlandFocusGrab {
    id: root

    property bool wanted: false

    signal taken

    function rearm() {
        delay.stop();
        active = false;
        if (wanted)
            delay.start();
    }

    active: false
    onWantedChanged: rearm()
    Component.onCompleted: rearm()

    readonly property Timer delay: Timer {
        interval: 50
        onTriggered: {
            if (!root.wanted)
                return;
            root.active = true;
            root.taken();
        }
    }
}
