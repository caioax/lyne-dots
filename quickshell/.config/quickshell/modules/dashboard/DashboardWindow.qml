pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Tabbed dashboard under the bar clock. One per bar; shows itself while
// DashboardService is open on its screen. Tabs slide sideways and the panel
// follows the height of the current one
QsPopupWindow {
    id: root

    readonly property bool wanted: DashboardService.screen !== "" && DashboardService.screen === (screen?.name ?? "")

    popupWidth: DashboardService.panelWidth
    popupMaxHeight: screen ? screen.height - Config.barReservedHeight - Config.spacing * 2 : 900
    anchorSide: "left"
    moduleName: "Dashboard"
    contentImplicitHeight: tabBar.implicitHeight + Config.spacing + pages.currentHeight
    keyTargets: [keyHandler]
    visible: false

    onWantedChanged: {
        if (!wanted)
            closeWindow();
    }

    // Closed from the popup itself (Escape, a click outside)
    onClosing: {
        if (wanted)
            DashboardService.close();
    }

    onVisibleChanged: {
        if (visible)
            root.overview?.reset();
    }

    Connections {
        target: DashboardService

        function onShown() {
            if (root.wanted)
                root.reopen();
        }
    }

    // Ctrl+Tab / Ctrl+Shift+Tab and Ctrl+PgDown / Ctrl+PgUp switch tabs,
    // Alt+1… jumps to one
    Item {
        id: keyHandler

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)) {
                DashboardService.cycleTab(1);
            } else if (ctrl && (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)) {
                DashboardService.cycleTab(-1);
            } else if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const tab = DashboardService.tabs[event.key - Qt.Key_1];
                if (!tab)
                    return;
                DashboardService.tab = tab.id;
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Config.spacing

        QsTabBar {
            id: tabBar
            tabs: DashboardService.tabs
            currentIndex: DashboardService.tabIndex
            onSelected: index => DashboardService.tab = DashboardService.tabs[index].id
        }

        Item {
            id: pages

            readonly property real currentHeight: repeater.count, repeater.itemAt(DashboardService.tabIndex)?.implicitHeight ?? 0

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Row {
                x: -DashboardService.tabIndex * pages.width

                // Jumps instead while opening straight on another tab
                Behavior on x {
                    enabled: root.visible && !root.isClosing

                    NumberAnimation {
                        duration: Config.animDurationLong
                        easing.type: Easing.OutExpo
                    }
                }

                Repeater {
                    id: repeater
                    model: DashboardService.tabs

                    Loader {
                        required property var modelData

                        width: pages.width
                        sourceComponent: root.tabComponents[modelData.id] ?? null
                    }
                }
            }
        }
    }

    // One per DashboardService.tabs id
    readonly property var tabComponents: ({
            overview: overviewComponent,
            media: mediaComponent,
            system: systemComponent
        })

    readonly property OverviewTab overview: repeater.count, repeater.itemAt(DashboardService.tabs.findIndex(t => t.id === "overview"))?.item ?? null

    Component {
        id: overviewComponent

        OverviewTab {
            active: root.visible && DashboardService.tab === "overview"
        }
    }

    Component {
        id: mediaComponent

        MediaTab {
            active: root.visible && DashboardService.tab === "media"
            onCloseRequested: root.closeWindow()
        }
    }

    Component {
        id: systemComponent

        SystemTab {
            active: root.visible && DashboardService.tab === "system"
            onCloseRequested: root.closeWindow()
        }
    }
}
