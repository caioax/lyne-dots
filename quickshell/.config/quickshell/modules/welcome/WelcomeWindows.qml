pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"
import "../settings/pages/"

// Windows step: how tiled windows are laid out (Settings › Windows ›
// Tiling has the same choice and each layout's options)
ColumnLayout {
    id: root

    readonly property string cycleKeys: KeybindsService.binds.find(b => b.id === "cycle-layout")?.keys ?? ""

    spacing: Config.spacing * 3

    // md-view_quilt
    WelcomeHeader {
        icon: "\u{f0574}"
        title: "Windows"
        description: "How windows share the screen. Settings › Windows has more options for each layout."
    }

    SettingsGroup {
        title: "Tiling"

        TemplatePicker {
            label: "Layout"
            description: ({
                    dwindle: "Each new window splits the focused one in two, so they spiral inwards",
                    master: "One main window on the left, the others stacked beside it",
                    scrolling: "Windows in columns on a strip you scroll through, as wide as you like"
                })[value] ?? ""
            path: "hyprland.general.layout"
            options: HyprlandSettingsService.tilingLayouts
            thumbHeight: Config.fontSizeIconLarge * 4
            preview: TilingPreview {}
        }

        SettingRow {
            visible: root.cycleKeys !== ""
            label: "Switch any time"
            description: "Cycles Dwindle, Master and Scrolling, with the layout shown on screen"

            WelcomeKeys {
                combos: [root.cycleKeys]
            }
        }
    }
}
