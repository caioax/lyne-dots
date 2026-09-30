pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
    // Room on both sides of the page column, so the scrollbar never covers it
    readonly property int pageGutter: Config.padding * 2

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
            osd: osdPage,
            screenshot: screenshotPage,
            windows: windowsPage,
            input: inputPage,
            keyboard: keyboardPage,
            specials: specialsPage,
            monitors: monitorsPage,
            workspaces: workspacesPage,
            keybinds: keybindsPage,
            lock: lockPage,
            idle: idlePage,
            brightness: brightnessPage,
            apps: appsPage,
            autostart: autostartPage,
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

    // Page slot showing the current page (the other one is fading out)
    property bool _onB: false
    readonly property Loader pageLoader: _onB ? slotB : slotA
    // 1 when the new page sits below the old one in the sidebar, -1 above
    property int _direction: 1
    property int _pageIndex: -1

    function showPage() {
        const id = SettingsService.currentEntry.id;
        const index = SettingsService.pageOrder.indexOf(id);
        _direction = index >= _pageIndex ? 1 : -1;
        const first = _pageIndex < 0;
        _pageIndex = index;
        const old = pageLoader;
        if (!first) {
            // The old page leaves from where it's seen, the new one starts at the top
            exitAnim.stop();
            old.y -= flick.contentY;
            exitAnim.slot = old;
            exitAnim.toY = old.y - _direction * Config.spacing * 3;
            _onB = !_onB;
        }
        scrollAnim.stop();
        flick.contentY = 0;
        pageLoader.sourceComponent = null;
        pageLoader.y = 0;
        pageLoader.opacity = 0;
        pageLoader.sourceComponent = pageComponents[id];
        if (!first)
            exitAnim.start();
    }

    function pageLoaded(slot: Loader) {
        if (slot !== pageLoader)
            return;
        enterAnim.restart();
        if (SettingsService.pendingReveal)
            revealTimer.restart();
    }

    function clearSlot(slot: Loader) {
        if (slot === pageLoader)
            return;
        slot.sourceComponent = null;
        slot.y = 0;
        slot.opacity = 1;
    }

    Component.onCompleted: showPage()

    // Rows the search result asked for, flashed once the scroll ends
    property var _flashRows: []

    // Scrolls to the row (or group) of SettingsService.pendingReveal on the
    // current page and flashes it; hidden rows fall back to their group
    function revealPending() {
        const r = SettingsService.pendingReveal;
        SettingsService.pendingReveal = null;
        if (!r || !root.pageLoader.item || r.page !== SettingsService.currentPage)
            return;
        const rows = [];
        const groups = [];
        const walk = item => {
            for (const c of item.children) {
                if (!c.visible)
                    continue;
                if (c.isSettingRow === true)
                    rows.push(c);
                else if (c._visibleRows !== undefined)
                    groups.push(c);
                walk(c);
            }
        };
        walk(root.pageLoader.item);
        const groupTitle = item => {
            for (let p = item.parent; p; p = p.parent) {
                if (p._visibleRows !== undefined)
                    return p.title;
            }
            return "";
        };
        let anchor = null;
        let flash = [];
        if (r.label !== "") {
            const matches = rows.filter(x => x.label === r.label);
            const row = matches.find(x => groupTitle(x) === r.group) ?? matches[0];
            if (row) {
                anchor = row;
                flash = [row];
            }
        }
        if (!anchor && r.group !== "") {
            const group = groups.find(x => x.title === r.group);
            if (group) {
                anchor = group;
                flash = group._visibleRows;
            }
        }
        if (!anchor)
            return;
        const y = anchor.mapToItem(root.pageLoader, 0, 0).y;
        const target = Math.max(0, Math.min(flick.contentHeight - flick.height, y - Config.spacing * 4));
        _flashRows = flash;
        if (Math.abs(target - flick.contentY) < 1) {
            flashPending();
        } else {
            scrollAnim.to = target;
            scrollAnim.restart();
        }
    }

    function flashPending() {
        _flashRows.forEach(row => row.flash());
        _flashRows = [];
    }

    Timer {
        id: revealTimer

        // Lets the page settle (layouts, lazy content) before measuring
        interval: Config.animDuration
        onTriggered: root.revealPending()
    }

    Connections {
        target: SettingsService

        function onRevealRequested() {
            revealTimer.restart();
        }

        function onCurrentPageChanged() {
            root.showPage();
        }
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
        id: lockPage
        LockPage {}
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
        id: osdPage
        OsdPage {}
    }

    Component {
        id: screenshotPage
        ScreenshotPage {}
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
        id: keyboardPage
        KeyboardPage {}
    }

    Component {
        id: keybindsPage
        KeybindsPage {}
    }

    Component {
        id: specialsPage
        SpecialsPage {}
    }

    Component {
        id: monitorsPage
        MonitorsPage {}
    }

    Component {
        id: workspacesPage
        WorkspacesPage {}
    }

    Component {
        id: idlePage
        IdlePage {}
    }

    Component {
        id: brightnessPage
        BrightnessPage {}
    }

    Component {
        id: appsPage
        AppsPage {}
    }

    Component {
        id: autostartPage
        AutostartPage {}
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
    // an optional handleEscape(): bool; then it clears the search
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.pageLoader.item?.handleEscape?.())
                return;
            if (search.text !== "") {
                search.text = "";
                return;
            }
            if (search.activeFocus) {
                search.focus = false;
                return;
            }
            SettingsService.close();
        }
    }

    // Next / previous page in sidebar order
    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: SettingsService.stepPage(1)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
        onActivated: SettingsService.stepPage(-1)
    }

    // A text field keeps "/" for itself (typed, not a shortcut)
    Shortcut {
        sequences: ["Ctrl+F", "/"]
        onActivated: {
            search.forceActiveFocus();
            search.selectAll();
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

            HoverHandler {
                id: sidebarHover
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.padding * 2
                // The nav list reaches the edge: its scrollbar sits in the margin
                anchors.rightMargin: 0
                spacing: Config.spacing

                // Title
                RowLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: Config.padding * 2
                    Layout.bottomMargin: Config.spacing
                    spacing: Config.spacing + Config.padding

                    Rectangle {
                        implicitWidth: root.boxSize
                        implicitHeight: root.boxSize
                        radius: Config.radiusLarge
                        color: Qt.alpha(Config.accentColor, 0.15)

                        LyneLogo {
                            anchors.centerIn: parent
                            height: Config.fontSizeNormal
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

                // Search: pages and the options inside them
                Rectangle {
                    Layout.fillWidth: true
                    Layout.rightMargin: Config.padding * 2
                    Layout.bottomMargin: Config.spacing
                    implicitHeight: root.boxSize + Config.padding
                    radius: Config.radiusLarge
                    color: Config.surface1Color
                    border.width: search.activeFocus ? 1 : 0
                    border.color: Qt.alpha(Config.accentColor, 0.6)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: search.forceActiveFocus()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.padding * 2
                        anchors.rightMargin: Config.padding * 2
                        spacing: Config.spacing

                        // md-magnify
                        Text {
                            text: "\u{f0349}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: search.activeFocus ? Config.accentColor : Config.subtextColor
                        }

                        TextInput {
                            id: search

                            Layout.fillWidth: true
                            clip: true
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                            selectionColor: Qt.alpha(Config.accentColor, 0.4)
                            selectByMouse: true
                            onActiveFocusChanged: {
                                if (activeFocus)
                                    SettingsService.buildIndex();
                            }
                            Keys.onUpPressed: results.move(-1)
                            Keys.onDownPressed: results.move(1)
                            Keys.onReturnPressed: results.activateCurrent()
                            Keys.onEnterPressed: results.activateCurrent()

                            Text {
                                visible: search.text === ""
                                text: "Search"
                                font: search.font
                                color: Config.subtextColor
                            }
                        }

                        Text {
                            visible: search.text === "" && !search.activeFocus
                            text: "Ctrl F"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.mutedColor
                        }

                        // md-close
                        Text {
                            visible: search.text !== ""
                            text: "\u{f0156}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: clearMouse.containsMouse ? Config.textColor : Config.subtextColor

                            MouseArea {
                                id: clearMouse

                                anchors.fill: parent
                                anchors.margins: -Config.padding
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: search.text = ""
                            }
                        }
                    }
                }

                SearchResults {
                    id: results

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: search.text !== ""
                    query: search.text
                }

                // Scrolls when the pages don't fit the window height; the
                // items cut by an edge with more to scroll fade out
                Flickable {
                    id: navFlick

                    readonly property real fadeLength: Config.spacing * 4 / Math.max(height, 1)
                    property real topFade: atYBeginning ? 0 : 1
                    property real bottomFade: atYEnd ? 0 : 1

                    Behavior on topFade {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    Behavior on bottomFade {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: search.text === ""
                    clip: true
                    contentHeight: navColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    layer.enabled: topFade > 0 || bottomFade > 0
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: navFlick.width
                            height: navFlick.height
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Qt.alpha("black", 1 - navFlick.topFade)
                                }
                                GradientStop {
                                    position: navFlick.fadeLength
                                    color: "black"
                                }
                                GradientStop {
                                    position: 1 - navFlick.fadeLength
                                    color: "black"
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.alpha("black", 1 - navFlick.bottomFade)
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: QsScrollBar {
                        autoHide: true
                        peek: sidebarHover.hovered
                    }

                    ColumnLayout {
                        id: navColumn

                        width: navFlick.width - Config.padding * 2
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
                                            enabled: !Config.themeTransitioning
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
                                                    enabled: !Config.themeTransitioning
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

            // Header: page icon, title and description, lined up with the
            // page column below
            Item {
                Layout.fillWidth: true
                Layout.topMargin: Config.padding * 2
                implicitHeight: header.implicitHeight

                RowLayout {
                    id: header

                    x: Math.round((parent.width - width) / 2)
                    width: Math.min(parent.width - root.pageGutter * 2, root.maxContentWidth)
                    spacing: Config.spacing + Config.padding

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: Config.fontSizeIconLarge * 2
                        implicitHeight: implicitWidth
                        radius: Config.radiusLarge
                        color: Qt.alpha(Config.accentColor, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: SettingsService.currentEntry.icon
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: Config.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(Config.padding / 3)

                        Text {
                            Layout.fillWidth: true
                            text: SettingsService.currentEntry.label
                            elide: Text.ElideRight
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
                }
            }

            Flickable {
                id: flick

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: root.pageLoader.implicitHeight + Config.padding * 4
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: QsScrollBar {}

                NumberAnimation {
                    id: scrollAnim

                    target: flick
                    property: "contentY"
                    duration: Config.animDurationLong
                    easing.type: Easing.OutCubic
                    onFinished: root.flashPending()
                }

                // Two slots take turns: the new page slides in from the side
                // of its place in the sidebar while the old one fades out
                Loader {
                    id: slotA

                    x: Math.round((flick.width - width) / 2)
                    width: Math.min(flick.width - root.pageGutter * 2, root.maxContentWidth)
                    enabled: root.pageLoader === slotA
                    z: enabled ? 1 : 0
                    onLoaded: root.pageLoaded(slotA)
                }

                Loader {
                    id: slotB

                    x: Math.round((flick.width - width) / 2)
                    width: Math.min(flick.width - root.pageGutter * 2, root.maxContentWidth)
                    enabled: root.pageLoader === slotB
                    z: enabled ? 1 : 0
                    onLoaded: root.pageLoaded(slotB)
                }

                ParallelAnimation {
                    id: enterAnim

                    NumberAnimation {
                        target: root.pageLoader
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                    }

                    NumberAnimation {
                        target: root.pageLoader
                        property: "y"
                        from: root._direction * Config.spacing * 3
                        to: 0
                        duration: Config.animDurationLong
                        easing.type: Easing.OutExpo
                    }
                }

                ParallelAnimation {
                    id: exitAnim

                    property Loader slot
                    property real toY

                    NumberAnimation {
                        target: exitAnim.slot
                        property: "opacity"
                        to: 0
                        duration: Config.animDurationShort
                    }

                    NumberAnimation {
                        target: exitAnim.slot
                        property: "y"
                        to: exitAnim.toY
                        duration: Config.animDurationShort
                        easing.type: Easing.InCubic
                    }

                    onFinished: root.clearSlot(slot)
                }
            }
        }
    }
}
