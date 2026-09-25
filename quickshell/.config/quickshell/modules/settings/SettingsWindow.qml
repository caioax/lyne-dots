pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "./pages/"
import "../../components/"

// Settings app: sidebar with the pages of SettingsService on the left, the
// current page on the right. A regular window (floated by a Hyprland rule)
// so it can stay open while the changes are tried out
FloatingWindow {
    id: root

    readonly property int sidebarWidth: Config.fontSizeNormal * 16
    readonly property int maxContentWidth: Config.fontSizeNormal * 48
    readonly property int boxSize: Config.fontSizeIconSmall * 2

    // Page id (SettingsService.pages) -> component. Pages are imported
    // statically: Quickshell only resolves directories it can reach that way
    readonly property var pageComponents: ({
            theme: themePage,
            wallpaper: wallpaperPage,
            layout: layoutPage,
            typography: typographyPage,
            bar: barPage,
            launcher: launcherPage,
            clipboard: clipboardPage,
            dashboard: dashboardPage,
            power: powerPage,
            notifications: notificationsPage,
            windows: windowsPage,
            input: inputPage,
            keybinds: keybindsPage,
            idle: idlePage,
            profile: profilePage,
            about: aboutPage
        })

    // Scrolls the sidebar so the given nav item is fully visible
    function showNavItem(item: Item) {
        const y = item.mapToItem(navColumn, 0, 0).y;
        // Room above for a category title, so the first page shows its heading
        const headroom = Config.fontSizeSmall * 2 + Config.padding;
        if (y - headroom < navFlick.contentY)
            navFlick.contentY = Math.max(0, y - headroom);
        else if (y + item.height > navFlick.contentY + navFlick.height)
            navFlick.contentY = y + item.height - navFlick.height;
    }

    Component {
        id: themePage
        ThemePage {}
    }

    Component {
        id: launcherPage
        LauncherPage {}
    }

    Component {
        id: powerPage
        PowerPage {}
    }

    Component {
        id: clipboardPage
        ClipboardPage {}
    }

    Component {
        id: dashboardPage
        DashboardPage {}
    }

    Component {
        id: wallpaperPage
        WallpaperPage {}
    }

    Component {
        id: layoutPage
        LayoutPage {}
    }

    Component {
        id: typographyPage
        TypographyPage {}
    }

    Component {
        id: barPage
        BarPage {}
    }

    Component {
        id: notificationsPage
        NotificationsPage {}
    }

    Component {
        id: windowsPage
        WindowsPage {}
    }

    Component {
        id: inputPage
        InputPage {}
    }

    Component {
        id: keybindsPage
        KeybindsPage {}
    }

    Component {
        id: idlePage
        IdlePage {}
    }

    Component {
        id: profilePage
        ProfilePage {}
    }

    Component {
        id: aboutPage
        AboutPage {}
    }

    title: "Settings"
    implicitWidth: 960
    implicitHeight: 680
    minimumSize: Qt.size(720, 480)
    color: Config.backgroundTransparentColor
    visible: true

    onVisibleChanged: {
        if (!visible)
            SettingsService.close();
    }

    // Pages may use Escape first (close a popup, clear a selection) through
    // an optional handleEscape(): bool
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (pageLoader.item?.handleEscape?.())
                return;
            SettingsService.close();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.padding * 2
        spacing: Config.padding * 2

        // ================= SIDEBAR =================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarWidth
            radius: Config.radiusLarge
            color: Config.cardColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.padding * 2
                spacing: Config.spacing

                // Title
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Config.spacing
                    spacing: Config.spacing + Config.padding

                    Rectangle {
                        implicitWidth: root.boxSize
                        implicitHeight: root.boxSize
                        radius: Config.radiusLarge
                        color: Qt.alpha(Config.accentColor, 0.15)

                        // md-cog
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f0493}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: Config.accentColor
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Settings"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        font.bold: true
                        color: Config.textColor
                    }
                }

                // Scrolls when the pages don't fit the window height
                Flickable {
                    id: navFlick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: navColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: navColumn

                        width: navFlick.width
                        spacing: Config.spacing

                        Repeater {
                            model: SettingsService.categories

                            ColumnLayout {
                                id: category

                                required property string modelData

                                Layout.fillWidth: true
                                spacing: Math.round(Config.padding / 3)

                                Text {
                                    Layout.leftMargin: Config.padding
                                    Layout.bottomMargin: Config.padding
                                    text: category.modelData.toUpperCase()
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Config.subtextColor
                                }

                                Repeater {
                                    model: SettingsService.pages.filter(p => p.category === category.modelData)

                                    Rectangle {
                                        id: navItem

                                        required property var modelData
                                        readonly property bool active: SettingsService.currentPage === modelData.id

                                onActiveChanged: {
                                    if (active)
                                        Qt.callLater(root.showNavItem, navItem);
                                }
                                Component.onCompleted: {
                                    if (active)
                                        Qt.callLater(root.showNavItem, navItem);
                                }

                                        Layout.fillWidth: true
                                        implicitHeight: navRow.implicitHeight + Config.padding * 2
                                        radius: Config.radiusLarge
                                        color: active ? Qt.alpha(Config.accentColor, 0.15) : navMouse.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Config.animDurationShort
                                            }
                                        }

                                        RowLayout {
                                            id: navRow

                                            anchors.fill: parent
                                            anchors.margins: Config.padding
                                            spacing: Config.spacing + Config.padding

                                            Rectangle {
                                                implicitWidth: root.boxSize
                                                implicitHeight: root.boxSize
                                                radius: Config.radiusLarge
                                                color: navItem.active ? Config.accentColor : Config.surface1Color

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: Config.animDurationShort
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: navItem.modelData.icon
                                                    font.family: Config.font
                                                    font.pixelSize: Config.fontSizeLarge
                                                    color: navItem.active ? Config.textReverseColor : Config.textColor
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: navItem.modelData.label
                                                elide: Text.ElideRight
                                                font.family: Config.font
                                                font.pixelSize: Config.fontSizeNormal
                                                font.bold: navItem.active
                                                color: navItem.active ? Config.accentColor : Config.textColor
                                            }
                                        }

                                        MouseArea {
                                            id: navMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SettingsService.currentPage = navItem.modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================= PAGE =================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.spacing * 2

            // Header
            ColumnLayout {
                Layout.preferredWidth: Math.min(parent.width, root.maxContentWidth)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Config.padding * 2
                spacing: Math.round(Config.padding / 3)

                Text {
                    Layout.fillWidth: true
                    text: SettingsService.currentEntry.label
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    Layout.fillWidth: true
                    text: SettingsService.currentEntry.description
                    wrapMode: Text.WordWrap
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }
            }

            Flickable {
                id: flick

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageLoader.implicitHeight + Config.padding * 4
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: QsScrollBar {}

                Loader {
                    id: pageLoader

                    x: Math.round((flick.width - width) / 2)
                    width: Math.min(flick.width, root.maxContentWidth)
                    sourceComponent: root.pageComponents[SettingsService.currentEntry.id]

                    // Pages slide up and fade in when switching
                    onLoaded: {
                        flick.contentY = 0;
                        enterAnim.restart();
                    }

                    ParallelAnimation {
                        id: enterAnim

                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Config.animDuration
                        }

                        NumberAnimation {
                            target: pageLoader
                            property: "y"
                            from: Config.spacing * 3
                            to: 0
                            duration: Config.animDurationLong
                            easing.type: Easing.OutExpo
                        }
                    }
                }
            }
        }
    }
}
