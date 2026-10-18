pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The mouse cursor theme and size (CursorService; also `lyne cursor`)
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // Themes may have been installed or removed since
    Component.onCompleted: CursorService.refresh()

    // While the page is open, themes installed elsewhere (a package, a copy
    // into the folder) show up by themselves
    Instantiator {
        model: [CursorService.installDir, Quickshell.env("HOME") + "/.icons", "/usr/share/icons"]

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
        onTriggered: CursorService.refresh()
    }

    SettingsGroup {
        title: I18n.tr("Theme")

        // The theme in use; reset goes back to Bibata
        SettingRow {
            label: CursorService.nameOf(CursorService.theme)
            description: CursorService.missing ? I18n.tr("%1 isn't installed: apps fall back to another cursor", CursorService.theme) : I18n.tr("Hyprland and most apps change at once; X11 apps when you reopen them")
            descriptionColor: CursorService.missing ? Config.warningColor : Config.subtextColor
            path: "cursor.theme"
        }

        Rectangle {
            id: themesCard

            // As many cards as fit, at least two
            readonly property int columns: Math.max(2, Math.floor((width - Config.padding * 4 + grid.columnSpacing) / (Config.fontSizeNormal * 14 + grid.columnSpacing)))

            visible: CursorService.themes.length > 0
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
                    model: CursorService.themes

                    CursorTile {
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
            description: CursorService.status ? CursorService.status.text : I18n.tr("A .tar.gz, .tar.xz or .zip with the theme's folder, like the ones on gnome-look.org or GitHub")
            descriptionColor: !CursorService.status ? Config.subtextColor : CursorService.status.ok ? Config.successColor : Config.warningColor

            // md-download
            ActionButton {
                icon: "\u{f01da}"
                text: CursorService.installing ? I18n.tr("Waiting…") : I18n.tr("Install")
                opacity: CursorService.installing ? 0.6 : 1
                baseColor: installRow.controlColor
                onClicked: CursorService.install()
            }
        }

        SettingRow {
            id: folderRow

            label: I18n.tr("Your themes folder")
            description: I18n.tr("Themes copied to %1 show up here by themselves", CursorService.installDir.replace(Quickshell.env("HOME"), "~"))

            // md-folder_open
            ActionButton {
                icon: "\u{f0770}"
                text: I18n.tr("Open folder")
                baseColor: folderRow.controlColor
                onClicked: CursorService.openFolder()
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Size")

        SelectRow {
            id: sizeRow

            label: I18n.tr("Cursor size")
            description: I18n.tr("Cursor themes are drawn at these sizes, so they stay sharp")
            path: "cursor.size"
            segmentWidth: Config.fontSizeNormal * 4
            options: CursorService.sizes.map(s => ({
                        label: String(s),
                        value: s
                    }))

            // The theme's cursors at their real size
            below: Rectangle {
                width: parent.width
                height: CursorService.sizes[CursorService.sizes.length - 1] + Config.padding * 2
                radius: Config.radius
                color: sizeRow.controlColor

                Row {
                    anchors.centerIn: parent
                    spacing: Config.spacing * 4

                    Repeater {
                        model: CursorService.shapes

                        Image {
                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            // Real pixels: what the cursor will look like
                            width: CursorService.size
                            height: CursorService.size
                            source: CursorService.previewUrl(CursorService.theme, modelData, CursorService.size)
                            fillMode: Image.PreserveAspectFit
                            cache: false
                        }
                    }
                }
            }
        }
    }
}
