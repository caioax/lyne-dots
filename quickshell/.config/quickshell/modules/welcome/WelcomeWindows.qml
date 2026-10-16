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
        title: I18n.tr("Windows")
        description: I18n.tr("How windows share the screen. Settings › %1 has more options for each layout.", I18n.translate("Windows"))
    }

    SettingsGroup {
        title: I18n.tr("Tiling")

        TilingPicker {}

        SettingRow {
            visible: root.cycleKeys !== ""
            label: I18n.tr("Switch any time")
            description: I18n.tr("Cycles Dwindle, Master and Scrolling, with the layout shown on screen")

            WelcomeKeys {
                combos: [root.cycleKeys]
            }
        }
    }
}
