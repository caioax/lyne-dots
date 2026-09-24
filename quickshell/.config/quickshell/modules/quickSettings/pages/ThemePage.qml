pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    // Height the page may use; the preset grid scrolls within what's left
    property real availableHeight: 0

    signal backRequested
    signal closeWindow

    readonly property var previews: ThemeService.themePreviews
    readonly property bool auto: ThemeService.isAutoMode
    readonly property string currentName: previews[ThemeService.currentThemeName]?.name ?? ThemeService.currentThemeName
    readonly property int thumbHeight: Config.fontSizeIconLarge * 2 + Config.spacing * 2

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        // Everything above the preset grid, measured to size that grid
        ColumnLayout {
            id: top

            Layout.fillWidth: true
            spacing: Config.spacing

            PageHeader {
                Layout.bottomMargin: Config.padding
                icon: "󰏘"
                title: "Theme"
                subtitle: (root.auto ? "Material You" : root.currentName) + " · " + (ThemeService.isDarkMode ? "Dark" : "Light")
                onBackClicked: root.backRequested()
            }

            // ========== APPEARANCE ==========
            Card {
                Layout.fillWidth: true

                SectionLabel {
                    text: "Colors"
                }

                SegmentedControl {
                    options: [
                        {
                            "label": "Preset",
                            "icon": "󰏘"
                        },
                        {
                            "label": "Material You",
                            "icon": "󰸉"
                        }
                    ]
                    currentIndex: root.auto ? 1 : 0
                    onSelected: index => {
                        if (index === 1)
                            ThemeService.setAutoMode();
                        else
                            ThemeService.setPresetMode(ThemeService.currentThemeName);
                    }
                }

                SectionLabel {
                    Layout.topMargin: Config.padding
                    text: "Mode"
                }

                SegmentedControl {
                    options: [
                        {
                            "label": "Dark",
                            "icon": "󰖔"
                        },
                        {
                            "label": "Light",
                            "icon": "󰖨"
                        }
                    ]
                    currentIndex: ThemeService.isDarkMode ? 0 : 1
                    onSelected: index => ThemeService.setColorScheme(index === 0 ? "dark" : "light")
                }
            }

            // ========== MATERIAL YOU ==========
            Card {
                visible: root.auto
                Layout.fillWidth: true
                border.width: 1
                border.color: Qt.alpha(Config.accentColor, 0.6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing + Config.padding

                    ClippingRectangle {
                        implicitWidth: root.thumbHeight * 16 / 9
                        implicitHeight: root.thumbHeight
                        radius: Config.radius
                        color: Config.surface1Color

                        Image {
                            anchors.fill: parent
                            // Only loaded while the page is open
                            source: root.visible && WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(width * 2, height * 2)
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Config.padding

                        Text {
                            Layout.fillWidth: true
                            text: "Colors follow your wallpaper"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.textColor
                            wrapMode: Text.Wrap
                        }

                        PaletteDots {
                            colors: [Config.accentColor, Config.successColor, Config.warningColor, Config.errorColor]
                        }
                    }
                }

                ActionButton {
                    Layout.fillWidth: true
                    size: Config.fontSizeIconSmall * 2
                    icon: "󰸉"
                    text: "Change wallpaper"
                    onClicked: {
                        root.closeWindow();
                        WallpaperService.toggle();
                    }
                }
            }
        }

        // ========== PRESETS ==========
        Card {
            id: presetsCard

            Layout.fillWidth: true

            CardHeader {
                id: presetsHeader
                icon: "󰉦"
                title: "Presets"
                subtitle: ThemeService.displayThemes.length + (ThemeService.isDarkMode ? " dark" : " light") + " themes"
            }

            Flickable {
                id: list

                readonly property real maxHeight: Math.max(root.thumbHeight * 2, root.availableHeight - top.implicitHeight - main.spacing - presetsCard.padding * 2 - presetsHeader.implicitHeight - presetsCard.spacing)

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(grid.implicitHeight, maxHeight)
                contentHeight: grid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: Math.round(Config.padding * 2 / 3)
                        radius: width / 2
                        color: Config.surface2Color
                        opacity: parent.active ? 0.8 : 0
                    }
                }

                GridLayout {
                    id: grid

                    width: list.width
                    columns: 2
                    columnSpacing: Config.spacing
                    rowSpacing: Config.spacing

                    Repeater {
                        model: ThemeService.displayThemes

                        ThemeTile {
                            thumbHeight: root.thumbHeight
                            loadImage: root.visible
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // INLINE COMPONENTS
    // ========================================================================

    component SectionLabel: Text {
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: Config.subtextColor
    }
}
