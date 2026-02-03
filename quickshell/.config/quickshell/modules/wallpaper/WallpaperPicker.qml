pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../components/"
import qs.services
import qs.config

PanelWindow {
    id: root

    visible: WallpaperService.pickerVisible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs_modules"

    color: "transparent"

    // Whether we're in a theme's wallpaper page
    readonly property bool inThemePage: WallpaperService.currentCategory === "themes" && WallpaperService.themeFilter !== ""

    // Click on background closes or clears selection
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (WallpaperService.selectedCount > 0) {
                WallpaperService.clearSelection();
            } else {
                WallpaperService.hide();
            }
        }
    }

    // Main content
    Rectangle {
        id: content
        anchors.centerIn: parent
        width: Math.min(900, root.width - 100)
        height: Math.min(650, root.height - 100)
        radius: Config.radiusLarge
        color: Config.backgroundTransparentColor
        border.color: Qt.alpha(Config.accentColor, 0.2)
        border.width: 1

        // Entry animation
        scale: WallpaperService.pickerVisible ? 1 : 0.9
        opacity: WallpaperService.pickerVisible ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing + 8
            spacing: Config.spacing

            // ========== HEADER ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                Text {
                    text: "󰸉"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: Config.accentColor
                }

                Text {
                    text: root.inThemePage ? WallpaperService.themeFilter : "Wallpapers"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Config.textColor
                }

                Item {
                    Layout.fillWidth: true
                }

                // Counter
                Rectangle {
                    Layout.preferredWidth: countText.implicitWidth + 16
                    Layout.preferredHeight: 26
                    radius: height / 2
                    color: Config.surface1Color

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: WallpaperService.filteredWallpapers.length + " images"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }
                }

                // Dynamic wallpaper toggle
                ActionButton {
                    icon: WallpaperService.dynamicWallpaper ? "󰥶" : "󱪱"
                    text: "Auto"
                    baseColor: WallpaperService.dynamicWallpaper ? Config.accentColor : Config.surface1Color
                    hoverColor: WallpaperService.dynamicWallpaper ? Config.accentColor : Config.surface2Color
                    textColor: WallpaperService.dynamicWallpaper ? Config.textReverseColor : Config.subtextColor
                    hoverTextColor: WallpaperService.dynamicWallpaper ? Config.textReverseColor : Config.textColor
                    onClicked: WallpaperService.toggleDynamicWallpaper()
                }

                // Add button
                ActionButton {
                    icon: "󰐕"
                    text: "Add"
                    textColor: Config.successColor
                    hoverTextColor: Config.successColor
                    onClicked: WallpaperService.addWallpapers()
                }

                // Random button
                ActionButton {
                    icon: "󰒝"
                    text: "Random"
                    textColor: Config.accentColor
                    hoverTextColor: Config.accentColor
                    onClicked: WallpaperService.setRandomWallpaper()
                }

                // Close button
                ActionButton {
                    icon: "󰅖"
                    iconSize: Config.fontSizeNormal
                    hoverColor: Config.errorColor
                    textColor: Config.subtextColor
                    hoverTextColor: Config.textColor
                    onClicked: WallpaperService.hide()
                }
            }

            // ========== SEARCH BAR ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Config.radius
                color: Config.surface1Color

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                        clip: true
                        onTextChanged: WallpaperService.searchQuery = text

                        Text {
                            visible: !parent.text
                            text: "Search wallpapers..."
                            font: parent.font
                            color: Config.mutedColor
                        }
                    }

                    ActionButton {
                        visible: searchInput.text !== ""
                        icon: "󰅖"
                        size: 24
                        iconSize: Config.fontSizeSmall
                        textColor: Config.subtextColor
                        hoverTextColor: Config.textColor
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // ========== TAB BAR ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ActionButton {
                    icon: "󰉖"
                    text: "All"
                    baseColor: WallpaperService.currentCategory === "all" ? Config.accentColor : Config.surface1Color
                    hoverColor: WallpaperService.currentCategory === "all" ? Config.accentColor : Config.surface2Color
                    textColor: WallpaperService.currentCategory === "all" ? Config.textReverseColor : Config.subtextColor
                    hoverTextColor: WallpaperService.currentCategory === "all" ? Config.textReverseColor : Config.textColor
                    onClicked: {
                        WallpaperService.currentCategory = "all";
                        WallpaperService.themeFilter = "";
                    }
                }

                ActionButton {
                    icon: "󰋑"
                    text: "Favorites"
                    baseColor: WallpaperService.currentCategory === "favorites" ? Config.accentColor : Config.surface1Color
                    hoverColor: WallpaperService.currentCategory === "favorites" ? Config.accentColor : Config.surface2Color
                    textColor: WallpaperService.currentCategory === "favorites" ? Config.textReverseColor : Config.subtextColor
                    hoverTextColor: WallpaperService.currentCategory === "favorites" ? Config.textReverseColor : Config.textColor
                    onClicked: {
                        WallpaperService.currentCategory = "favorites";
                        WallpaperService.themeFilter = "";
                    }
                }

                ActionButton {
                    icon: "󰏘"
                    text: "Themes"
                    baseColor: WallpaperService.currentCategory === "themes" ? Config.accentColor : Config.surface1Color
                    hoverColor: WallpaperService.currentCategory === "themes" ? Config.accentColor : Config.surface2Color
                    textColor: WallpaperService.currentCategory === "themes" ? Config.textReverseColor : Config.subtextColor
                    hoverTextColor: WallpaperService.currentCategory === "themes" ? Config.textReverseColor : Config.textColor
                    onClicked: {
                        WallpaperService.currentCategory = "themes";
                        WallpaperService.themeFilter = "";
                    }
                }

                // Theme sub-filter chips
                Repeater {
                    model: WallpaperService.currentCategory === "themes" ? ThemeService.availableThemes : []

                    delegate: Rectangle {
                        id: themeChip
                        required property string modelData

                        Layout.preferredHeight: 28
                        Layout.preferredWidth: chipText.implicitWidth + 16
                        radius: Config.radius
                        color: {
                            if (WallpaperService.themeFilter === modelData)
                                return Qt.alpha(Config.accentColor, 0.3);
                            return chipMouse.containsMouse ? Config.surface2Color : Qt.alpha(Config.surface1Color, 0.6);
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: themeChip.modelData
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: WallpaperService.themeFilter === themeChip.modelData ? Config.accentColor : Config.subtextColor
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (WallpaperService.themeFilter === themeChip.modelData)
                                    WallpaperService.themeFilter = "";
                                else
                                    WallpaperService.themeFilter = themeChip.modelData;
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            // ========== SEPARATOR ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.surface1Color
            }

            // ========== WALLPAPER GRID ==========
            GridView {
                id: wallpaperGrid
                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                cellWidth: 200
                cellHeight: 150

                cacheBuffer: 600

                model: WallpaperService.filteredWallpapers

                delegate: Item {
                    id: wallpaperItem
                    required property int index
                    required property string modelData

                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    property bool isHovered: itemMouse.containsMouse || fileNameMouse.containsMouse
                    property bool isCurrent: modelData === WallpaperService.currentWallpaper
                    property bool isSelected: WallpaperService.isSelected(modelData)
                    property bool isFav: WallpaperService.isFavorite(modelData)
                    property bool isActiveForTheme: root.inThemePage && WallpaperService.isActiveThemeWallpaper(modelData, WallpaperService.themeFilter)
                    property string overviewThemeName: (!root.inThemePage && WallpaperService.currentCategory === "themes") ? WallpaperService.themeForActiveWallpaper(modelData) : ""
                    property string displayName: {
                        const name = WallpaperService.fileName(modelData);
                        const dot = name.lastIndexOf(".");
                        return dot > 0 ? name.substring(0, dot) : name;
                    }

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.bottomMargin: 22
                        radius: Config.radius
                        color: Config.surface0Color
                        border.width: wallpaperItem.isActiveForTheme ? 2 : (wallpaperItem.isSelected ? 2 : (wallpaperItem.isCurrent ? 2 : (wallpaperItem.isHovered ? 1 : 0)))
                        border.color: wallpaperItem.isActiveForTheme ? Config.successColor : (wallpaperItem.isSelected ? Config.accentColor : (wallpaperItem.isCurrent ? Config.accentColor : Config.surface2Color))

                        Behavior on border.width {
                            NumberAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        // Main click area — defined FIRST so badges render on top
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: mouse => {
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    WallpaperService.toggleSelection(wallpaperItem.modelData);
                                } else {
                                    WallpaperService.selectOnly(wallpaperItem.modelData);
                                }
                            }

                            onDoubleClicked: {
                                if (root.inThemePage) {
                                    // Double-click in theme page sets this as the active wallpaper for the theme
                                    WallpaperService.setActiveThemeWallpaper(wallpaperItem.modelData, WallpaperService.themeFilter);
                                } else {
                                    WallpaperService.setWallpaper(wallpaperItem.modelData);
                                }
                            }
                        }

                        // Rounded clip thumbnail
                        Item {
                            anchors.fill: parent
                            anchors.margins: 4

                            Rectangle {
                                anchors.fill: parent
                                radius: Config.radiusSmall
                                clip: true

                                Image {
                                    id: thumbnail
                                    anchors.fill: parent
                                    source: "file://" + wallpaperItem.modelData
                                    sourceSize: Qt.size(256, 144)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }
                            }
                        }

                        // Loading overlay
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Config.radiusSmall
                            color: Config.surface1Color
                            visible: thumbnail.status === Image.Loading

                            Text {
                                anchors.centerIn: parent
                                text: "󰑓"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeIcon
                                color: Config.mutedColor

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: thumbnail.status === Image.Loading
                                }
                            }
                        }

                        // Selection overlay
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Config.radiusSmall
                            color: Qt.alpha(Config.accentColor, 0.2)
                            visible: wallpaperItem.isSelected
                        }

                        // Current wallpaper badge (top-left)
                        Rectangle {
                            visible: wallpaperItem.isCurrent && !root.inThemePage
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            width: 24
                            height: 24
                            radius: height / 2
                            color: Config.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: Config.font
                                font.pixelSize: 12
                                color: Config.textReverseColor
                            }
                        }

                        // Active theme wallpaper badge (top-left, in theme page)
                        Rectangle {
                            visible: wallpaperItem.isActiveForTheme
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            width: activeLabel.implicitWidth + 12
                            height: 22
                            radius: height / 2
                            color: Config.successColor

                            Text {
                                id: activeLabel
                                anchors.centerIn: parent
                                text: "󰄬 Active"
                                font.family: Config.font
                                font.pixelSize: 10
                                font.bold: true
                                color: Config.textReverseColor
                            }
                        }

                        // Favorite badge (top-right) — clickable
                        Rectangle {
                            id: favBadge
                            visible: wallpaperItem.isHovered || wallpaperItem.isFav
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 24
                            height: 24
                            radius: height / 2
                            color: wallpaperItem.isFav ? Config.errorColor : Qt.alpha(Config.surface0Color, 0.8)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: wallpaperItem.isFav ? "󰋑" : "󰋕"
                                font.family: Config.font
                                font.pixelSize: 12
                                color: wallpaperItem.isFav ? Config.textReverseColor : Config.subtextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.toggleFavorite(wallpaperItem.modelData)
                            }
                        }

                        // Theme badge (bottom-left, themes overview)
                        Rectangle {
                            visible: wallpaperItem.overviewThemeName !== ""
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 8
                            height: 20
                            width: themeBadgeText.implicitWidth + 12
                            radius: height / 2
                            color: Qt.alpha(Config.surface0Color, 0.85)

                            Text {
                                id: themeBadgeText
                                anchors.centerIn: parent
                                text: "󰏘 " + wallpaperItem.overviewThemeName
                                font.family: Config.font
                                font.pixelSize: 10
                                color: Config.accentColor
                            }
                        }

                        // Scale effect on hover
                        scale: wallpaperItem.isHovered ? 1.02 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animDurationShort
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Filename label
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: wallpaperItem.displayName
                        font.family: Config.font
                        font.pixelSize: 10
                        color: wallpaperItem.isHovered ? Config.textColor : Config.subtextColor
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            id: fileNameMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: mouse => {
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    WallpaperService.toggleSelection(wallpaperItem.modelData);
                                } else {
                                    WallpaperService.selectOnly(wallpaperItem.modelData);
                                }
                            }

                            onDoubleClicked: {
                                if (root.inThemePage) {
                                    WallpaperService.setActiveThemeWallpaper(wallpaperItem.modelData, WallpaperService.themeFilter);
                                } else {
                                    WallpaperService.setWallpaper(wallpaperItem.modelData);
                                }
                            }
                        }
                    }
                }

                // Empty state (per category)
                Column {
                    anchors.centerIn: parent
                    spacing: Config.spacing
                    visible: wallpaperGrid.count === 0

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        radius: 32
                        color: Config.surface1Color

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (WallpaperService.currentCategory === "favorites")
                                    return "󰋑";
                                if (WallpaperService.currentCategory === "themes")
                                    return "󰏘";
                                return "󰸉";
                            }
                            font.family: Config.font
                            font.pixelSize: 28
                            color: Config.subtextColor
                            opacity: 0.5
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (WallpaperService.searchQuery)
                                return "No results";
                            if (root.inThemePage)
                                return "No wallpapers for " + WallpaperService.themeFilter;
                            if (WallpaperService.currentCategory === "favorites")
                                return "No favorites yet";
                            if (WallpaperService.currentCategory === "themes")
                                return "Select a theme above";
                            return "No wallpapers found";
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (WallpaperService.searchQuery)
                                return "Try a different search term";
                            if (root.inThemePage)
                                return "Add wallpapers from the All tab";
                            if (WallpaperService.currentCategory === "favorites")
                                return "Click the 󰋕 on any wallpaper";
                            if (WallpaperService.currentCategory === "themes")
                                return "Pick a theme to manage its wallpapers";
                            return "Add images to ~/.local/wallpapers";
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.mutedColor
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Config.surface2Color
                        opacity: parent.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }
                }
            }

            // ========== ACTION BAR ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: WallpaperService.selectedCount > 0 ? 50 : 0
                radius: Config.radius
                color: Config.surface0Color
                visible: Layout.preferredHeight > 0
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Config.spacing + 4
                    anchors.rightMargin: Config.spacing + 4
                    spacing: Config.spacing

                    // Selection info
                    Text {
                        text: WallpaperService.selectedCount + " selected"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Delete confirmation
                    Row {
                        visible: WallpaperService.confirmDelete
                        spacing: Config.spacing

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Delete " + WallpaperService.selectedCount + " wallpapers?"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.warningColor
                        }

                        ClearButton {
                            icon: "󰄬"
                            text: "Yes"
                            onClicked: WallpaperService.deleteSelected()
                        }

                        ActionButton {
                            icon: "󰅖"
                            text: "No"
                            size: 32
                            onClicked: WallpaperService.cancelDelete()
                        }
                    }

                    // Action buttons (hidden during confirmation)
                    Row {
                        visible: !WallpaperService.confirmDelete
                        spacing: Config.spacing

                        // In theme page: "Set Active" button
                        ActionButton {
                            visible: root.inThemePage && WallpaperService.selectedCount === 1
                            icon: "󰄬"
                            text: "Set Active"
                            size: 32
                            baseColor: Config.surface1Color
                            hoverColor: Config.successColor
                            textColor: Config.successColor
                            hoverTextColor: Config.textReverseColor
                            onClicked: {
                                WallpaperService.setActiveThemeWallpaper(WallpaperService.selectedWallpapers[0], WallpaperService.themeFilter);
                                WallpaperService.clearSelection();
                            }
                        }

                        // Normal mode: Apply button
                        ActionButton {
                            visible: !root.inThemePage && WallpaperService.selectedCount === 1
                            icon: "󰄬"
                            text: "Apply"
                            size: 32
                            baseColor: Config.surface1Color
                            hoverColor: Config.accentColor
                            textColor: Config.accentColor
                            hoverTextColor: Config.textReverseColor
                            onClicked: WallpaperService.applySelected()
                        }

                        // "Add to theme" button (NOT in theme page, 1 selected)
                        ActionButton {
                            id: addToThemeBtn
                            visible: !root.inThemePage && WallpaperService.selectedCount === 1
                            icon: "󰏘"
                            text: "Add to Theme"
                            size: 32
                            textColor: Config.accentColor
                            hoverTextColor: Config.accentColor
                            onClicked: addToThemePopup.open()
                        }

                        // "Add to theme" popup
                        Popup {
                            id: addToThemePopup
                            x: addToThemeBtn.x
                            y: -height - 8
                            width: 180
                            height: addToThemeColumn.implicitHeight + 10
                            padding: 0

                            background: Rectangle {
                                color: Config.surface0Color
                                border.color: Config.surface2Color
                                border.width: 1
                                radius: Config.radius
                            }

                            ColumnLayout {
                                id: addToThemeColumn
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 2

                                Text {
                                    text: "Add to theme:"
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.subtextColor
                                    Layout.leftMargin: 8
                                    Layout.topMargin: 4
                                    Layout.bottomMargin: 2
                                }

                                Repeater {
                                    model: ThemeService.availableThemes

                                    delegate: Rectangle {
                                        id: addThemeItem
                                        required property string modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        radius: Config.radiusSmall
                                        color: addThemeItemMouse.containsMouse ? Config.surface1Color : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: "󰏘"
                                                font.family: Config.font
                                                font.pixelSize: Config.fontSizeNormal
                                                color: ThemeService.currentThemeName === addThemeItem.modelData ? Config.accentColor : Config.subtextColor
                                            }

                                            Text {
                                                text: addThemeItem.modelData
                                                font.family: Config.font
                                                font.pixelSize: Config.fontSizeSmall
                                                font.bold: ThemeService.currentThemeName === addThemeItem.modelData
                                                color: Config.textColor
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: addThemeItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addToThemePopup.close();
                                                if (WallpaperService.selectedCount === 1) {
                                                    WallpaperService.addToTheme(WallpaperService.selectedWallpapers[0], addThemeItem.modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Delete button
                        ClearButton {
                            icon: "󰅖"
                            text: "Delete"
                            onClicked: WallpaperService.requestDelete()
                        }

                        // Clear selection
                        ActionButton {
                            icon: "󰜺"
                            size: 32
                            textColor: Config.subtextColor
                            hoverTextColor: Config.textColor
                            onClicked: WallpaperService.clearSelection()
                        }
                    }
                }
            }
        }

        // Keyboard shortcuts
        Keys.onEscapePressed: {
            if (addToThemePopup.opened) {
                addToThemePopup.close();
            } else if (WallpaperService.confirmDelete) {
                WallpaperService.cancelDelete();
            } else if (WallpaperService.selectedCount > 0) {
                WallpaperService.clearSelection();
            } else {
                WallpaperService.hide();
            }
        }
        Keys.onDeletePressed: WallpaperService.requestDelete()
        Keys.onReturnPressed: {
            if (root.inThemePage && WallpaperService.selectedCount === 1) {
                WallpaperService.setActiveThemeWallpaper(WallpaperService.selectedWallpapers[0], WallpaperService.themeFilter);
                WallpaperService.clearSelection();
            } else {
                WallpaperService.applySelected();
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_R) {
                WallpaperService.setRandomWallpaper();
                event.accepted = true;
            } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                WallpaperService.selectedWallpapers = [...WallpaperService.filteredWallpapers];
                event.accepted = true;
            } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                searchInput.forceActiveFocus();
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()
    }

    // Focus grab
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: WallpaperService.hide()
    }
}
