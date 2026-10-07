pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Main boolean property for other modules to query
    readonly property bool anyModuleOpen: openWindowsCount > 0
    property int openWindowsCount: 0

    // List to know EXACTLY what is open
    property var activeModules: ({})

    function registerOpen(moduleName) {
        if (!activeModules[moduleName]) {
            let copy = activeModules;
            copy[moduleName] = true;
            activeModules = copy;
            openWindowsCount++;
        }
    }

    function registerClose(moduleName) {
        if (activeModules[moduleName]) {
            let copy = activeModules;
            delete copy[moduleName];
            activeModules = copy;
            openWindowsCount--;
        }
    }
}
