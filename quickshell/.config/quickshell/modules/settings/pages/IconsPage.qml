pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The icon theme (IconService; also `lyne icons`)
ColumnLayout {
    spacing: Config.spacing * 3

    // Themes may have been installed or removed since
    Component.onCompleted: IconService.refresh()

    // While the page is open, themes installed elsewhere (a package, a copy
    // into the folder) show up by themselves
    Instantiator {
        model: [IconService.installDir, Quickshell.env("HOME") + "/.icons", "/usr/share/icons"]

        FolderListModel {
            required property string modelData

            folder: "file://" + modelData
            showFiles: false
            showHidden: false
            onCountChanged: watchDebounce.restart()
        }
    }

    Timer {
        id: watchDebounce
        interval: 500
        onTriggered: IconService.refresh()
    }

    SettingsGroup {
        title: I18n.tr("Theme")

        // The theme in use; reset goes back to Tela
        SettingRow {
            label: IconService.nameOf(IconService.theme)
            description: IconService.missing ? I18n.tr("%1 isn't installed: apps fall back to another icon theme", IconService.theme) : I18n.tr("Themes with dark and light versions follow the shell's theme. Apps change at once; X11 apps when you reopen them")
            descriptionColor: IconService.missing ? Config.warningColor : Config.subtextColor
            path: "icons.theme"
        }

        Rectangle {
            id: themesCard

            // As many cards as fit, at least two
            readonly property int columns: Math.max(2, Math.floor((width - Config.padding * 4 + grid.columnSpacing) / (Config.fontSizeNormal * 16 + grid.columnSpacing)))

            visible: IconService.themes.length > 0
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.cardColor

            GridLayout {
                id: grid

                anchors.fill: parent
                anchors.margins: Config.padding * 2
                columns: themesCard.columns
                columnSpacing: Config.spacing
                rowSpacing: Config.spacing

                Repeater {
                    model: IconService.themes

                    IconTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: (grid.width - grid.columnSpacing * (themesCard.columns - 1)) / themesCard.columns
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("More themes")

        SettingRow {
            id: installRow

            label: I18n.tr("Install from a file")
            description: IconService.status ? IconService.status.text : I18n.tr("A .tar.gz, .tar.xz or .zip with the theme's folder, like the ones on gnome-look.org or GitHub")
            descriptionColor: !IconService.status ? Config.subtextColor : IconService.status.ok ? Config.successColor : Config.warningColor

            // md-download
            ActionButton {
                icon: "\u{f01da}"
                text: IconService.installing ? I18n.tr("Waiting…") : I18n.tr("Install")
                opacity: IconService.installing ? 0.6 : 1
                baseColor: installRow.controlColor
                onClicked: IconService.install()
            }
        }

        SettingRow {
            id: folderRow

            label: I18n.tr("Your themes folder")
            description: I18n.tr("Themes copied to %1 show up here by themselves", IconService.installDir.replace(Quickshell.env("HOME"), "~"))

            // md-folder_open
            ActionButton {
                icon: "\u{f0770}"
                text: I18n.tr("Open folder")
                baseColor: folderRow.controlColor
                onClicked: IconService.openFolder()
            }
        }
    }
}
