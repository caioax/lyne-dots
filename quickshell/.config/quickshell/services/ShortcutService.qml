pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // ========================================================================
    // CONFIGURAÇÃO CENTRALIZADA DE ATALHOS
    // ========================================================================

    // Aqui você define todos os atalhos do sistema
    // Formato: { name: string, description: string }

    readonly property var shortcuts: ({
            screenshot: {
                name: "take_screenshot",
                description: "Captura de tela (região/janela/tela)"
            },
            power: {
                name: "power_menu",
                description: "Menu de energia (desligar/reiniciar/etc)"
            },
            quickSettings: {
                name: "quick_settings",
                description: "Configurações rápidas"
            },
            notifications: {
                name: "notifications",
                description: "Central de notificações"
            }
        })

    // ========================================================================
    // SINAIS PARA AÇÕES
    // ========================================================================

    signal screenshotRequested
    signal powerMenuRequested
    signal quickSettingsRequested
    signal notificationsRequested

    // ========================================================================
    // FUNÇÕES PÚBLICAS
    // ========================================================================

    function triggerAction(shortcutName: string) {
        console.log("[Shortcuts] Triggered:", shortcutName);

        switch (shortcutName) {
        case "take_screenshot":
            screenshotRequested();
            break;
        case "power_menu":
            powerMenuRequested();
            break;
        case "quick_settings":
            quickSettingsRequested();
            break;
        case "notifications":
            notificationsRequested();
            break;
        default:
            console.warn("[Shortcuts] Unknown shortcut:", shortcutName);
        }
    }

    function getShortcutName(key: string): string {
        if (shortcuts.hasOwnProperty(key)) {
            return shortcuts[key].name;
        }
        return "";
    }

    function getDescription(key: string): string {
        if (shortcuts.hasOwnProperty(key)) {
            return shortcuts[key].description;
        }
        return "";
    }
}
