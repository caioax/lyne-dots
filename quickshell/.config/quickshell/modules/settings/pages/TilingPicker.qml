pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../rows/"

// Window layout (hyprland.general.layout) with drawn previews: Settings ›
// Windows and the welcome screen
TemplatePicker {
    id: root

    // Also say which keys cycle the layouts (the welcome screen shows them
    // as keycaps instead)
    property bool showCycleKeys: false

    readonly property string cycleKeys: {
        const keys = KeybindsService.binds.find(b => b.id === "cycle-layout")?.keys ?? "";
        return KeybindsService.split(keys).map(p => p.length > 1 ? p.charAt(0).toUpperCase() + p.slice(1).toLowerCase() : p).join(" + ");
    }

    label: I18n.tr("Layout")
    description: {
        const text = ({
                dwindle: I18n.tr("Each new window splits the focused one in two, so they spiral inwards"),
                master: I18n.tr("One main window on the left, the others stacked beside it"),
                scrolling: I18n.tr("Windows in columns on a strip you scroll through, as wide as you like")
            })[value] ?? "";
        return showCycleKeys && cycleKeys !== "" ? I18n.tr("%1. %2 cycles them", text, cycleKeys) : text;
    }
    path: "hyprland.general.layout"
    options: HyprlandSettingsService.tilingLayouts
    thumbHeight: Config.fontSizeIconLarge * 4
    preview: TilingPreview {}
}
