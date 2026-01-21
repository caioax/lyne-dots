import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var targetScreen: {
        const monitor = Hyprland.focusedMonitor;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === (monitor ? monitor.name : "")) {
                return Quickshell.screens[i];
            }
        }
        return Quickshell.screens[0];
    }

    screen: targetScreen

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    ScreencopyView {
        captureSource: root.screen
        anchors.fill: parent
        z: -1
    }
}
