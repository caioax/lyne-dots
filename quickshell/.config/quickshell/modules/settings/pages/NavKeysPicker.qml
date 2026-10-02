pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../rows/"

// Navigation keys preset (KeybindsService.preset): H J K L, the arrow keys
// or both for focus, moving, resizing and workspace steps. Used by Settings ›
// Keybinds and the welcome screen
TemplatePicker {
    id: root

    readonly property var conflicts: KeybindsService.presetConflicts

    label: "Navigation keys"
    description: {
        if (conflicts.length > 0)
            return "Also used by other shortcuts: " + conflicts.map(c => c.description + " (" + c.others.join(", ") + ")").join("; ");
        return ({
                vim: "Super + H J K L move the focus, with Shift the window, with Alt its size; Super + Ctrl + H / L switch workspaces",
                arrows: "Super + arrow keys move the focus, with Shift the window, with Alt its size; Super + Ctrl + ← / → switch workspaces",
                both: "H J K L and the arrow keys both work, with the same modifiers"
            })[value] + ". Keys you changed yourself stay";
    }
    descriptionColor: conflicts.length > 0 ? Config.warningColor : Config.subtextColor
    path: "keybinds.preset"
    options: KeybindsService.presets
    // Three rows of keycaps ("Both")
    thumbHeight: (Config.fontSizeIconSmall + Config.padding) * 3 + Config.padding * 4
    preview: NavKeysPreview {}
}
