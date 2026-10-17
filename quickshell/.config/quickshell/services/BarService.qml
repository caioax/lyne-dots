pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Whether the bar can be seen on each screen, so the panels that touch it
// (attached popups, launcher, wallpaper picker, OSD) go to the screen edge
// instead of leaving the bar's room empty
Singleton {
    id: root

    // Screens whose active workspace shows a fullscreen window: it covers
    // the bar (a layer below it). Maximized windows leave the bar in view,
    // and Hyprland counts them in hasFullscreen, so the Wayland state decides
    readonly property var coveredScreens: {
        const names = [];
        for (const monitor of Hyprland.monitors.values) {
            const workspace = monitor.activeWorkspace;
            if (workspace?.hasFullscreen && workspace.toplevels.values.some(t => t.wayland?.fullscreen))
                names.push(monitor.name);
        }
        return names;
    }

    // Screen name -> true while an auto-hiding bar is slid away (set by Bar)
    property var autoHidden: ({})

    // A fullscreen window covers the bar. Panels that keep an auto-hiding
    // bar shown while open (WindowManagerService) only need this
    function coveredOn(screenName: string): bool {
        return coveredScreens.includes(screenName);
    }

    // Covered, or slid away by auto hide
    function hiddenOn(screenName: string): bool {
        return coveredOn(screenName) || autoHidden[screenName] === true;
    }

    function setAutoHidden(screenName: string, hidden: bool): void {
        if ((autoHidden[screenName] === true) === hidden)
            return;
        // A new object: reassigning the same one doesn't notify bindings
        const copy = Object.assign({}, autoHidden);
        if (hidden)
            copy[screenName] = true;
        else
            delete copy[screenName];
        autoHidden = copy;
    }
}
