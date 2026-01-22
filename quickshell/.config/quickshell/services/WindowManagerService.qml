pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Propriedade booleana principal para outros módulos consultarem
    readonly property bool anyModuleOpen: openWindowsCount > 0
    property int openWindowsCount: 0

    // Lista para saber EXATAMENTE o que está aberto
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

    onAnyModuleOpenChanged: {
        if (anyModuleOpen) {
            createFile.running = true;
        } else {
            removeFile.running = true;
        }
    }

    // Limpeza incial para evidar resquícios em casos de erros
    Component.onCompleted: {
        removeFile.running = true;
    }

    // Arquivo de controle
    Process {
        id: createFile
        command: ["touch", "/tmp/QsAnyModuleIsOpen"]
    }

    Process {
        id: removeFile
        command: ["rm", "-f", "/tmp/QsAnyModuleIsOpen"]
    }
}
