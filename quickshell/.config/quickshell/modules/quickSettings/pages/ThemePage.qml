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

                        ThemeTile {}
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

    component PaletteDots: Row {
        id: dots

        property var colors: []

        spacing: Math.round(Config.padding / 2)

        Repeater {
            model: dots.colors.filter(c => c !== undefined && c !== "")

            Rectangle {
                required property var modelData
                width: Config.padding * 2
                height: width
                radius: width / 2
                color: modelData
                border.width: 1
                border.color: Qt.alpha(Config.textColor, 0.15)
            }
        }
    }

    // Wallpaper thumbnail with the theme name and its palette
    component ThemeTile: Item {
        id: tile

        required property string modelData
        readonly property var preview: root.previews[modelData] ?? {}
        readonly property var palette: preview.palette ?? {}
        readonly property bool isCurrent: !root.auto && modelData === ThemeService.currentThemeName

        Layout.fillWidth: true
        implicitHeight: root.thumbHeight + footer.implicitHeight + Config.padding * 2
        opacity: root.auto && !tileMouse.containsMouse ? 0.55 : 1
        scale: tileMouse.pressed ? 0.97 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: Config.radiusLarge
            color: tileMouse.containsMouse ? Config.surface2Color : Config.surface1Color

            Image {
                width: parent.width
                height: root.thumbHeight
                // Only loaded while the page is open
                source: root.visible && tile.preview.wallpaper ? "file://" + ThemeService.wallpaperDir + "/" + tile.preview.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
            }

            RowLayout {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Config.padding + Config.padding / 2
                spacing: Config.padding

                Text {
                    Layout.fillWidth: true
                    text: tile.preview.name ?? tile.modelData
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: tile.isCurrent
                    color: tile.isCurrent ? Config.accentColor : Config.textColor
                    elide: Text.ElideRight
                }

                PaletteDots {
                    colors: [tile.palette.accent, tile.palette.success, tile.palette.warning, tile.palette.error]
                }
            }
        }

        // Selection outline and check, above the clipped content
        Rectangle {
            anchors.fill: parent
            radius: Config.radiusLarge
            color: "transparent"
            border.width: tile.isCurrent ? 2 : 0
            border.color: Config.accentColor
        }

        Rectangle {
            visible: tile.isCurrent
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Config.padding
            width: Config.fontSizeLarge + Config.padding
            height: width
            radius: width / 2
            color: Config.accentColor

            Text {
                anchors.centerIn: parent
                text: "󰄬"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textReverseColor
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: tile.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (!tile.isCurrent)
                    ThemeService.setPresetMode(tile.modelData);
            }
        }
    }
}
