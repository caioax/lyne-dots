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
        else
            preloaded = 0;
    }

    // Tabs built besides the open one: one per tick once the popup has
    // opened, so building them doesn't stall the opening animation
    property int preloaded: 0

    Timer {
        interval: root.preloaded === 0 ? Config.animDurationLong : Config.animDurationShort
        running: root.visible && root.preloaded < DashboardService.tabs.length
        repeat: true
        onTriggered: root.preloaded++
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

    // A one-column grid so the tabs can go below the pages: with the bar at
    // the bottom they stay next to it while the pages change height
    GridLayout {
        anchors.fill: parent
        columns: 1
        rowSpacing: Config.spacing

        QsTabBar {
            id: tabBar
            Layout.row: Config.barOnBottom ? 1 : 0
            flipped: Config.barOnBottom
            tabs: DashboardService.tabs
            currentIndex: DashboardService.tabIndex
            onSelected: index => DashboardService.tab = DashboardService.tabs[index].id
        }

        Item {
            id: pages

            readonly property real currentHeight: {
                void repeater.count; // reevaluated once the tabs exist
                return repeater.itemAt(DashboardService.tabIndex)?.implicitHeight ?? 0;
            }

            // Swipe between tabs (Settings › Dashboard): the pages follow the
            // pointer with the next tab beside them, and the release changes
            // tab past a third of the width or on a quick flick
            property bool dragging: false
            property real dragOffset: 0
            property real dragVelocity: 0

            function dragTo(dx: real) {
                const next = DashboardService.tabIndex + (dx < 0 ? 1 : -1);
                // No tab that way: the pages only give a little
                dragOffset = next < 0 || next >= repeater.count ? dx / 3 : dx;
            }

            function release() {
                const flicked = Math.abs(dragVelocity) > width * 1.5 && (dragVelocity < 0) === (dragOffset < 0);
                const target = DashboardService.tabIndex + (dragOffset < 0 ? 1 : -1);
                // Slides from where it was let go
                dragging = false;
                if ((Math.abs(dragOffset) > width / 3 || flicked) && target >= 0 && target < repeater.count)
                    DashboardService.tab = DashboardService.tabs[target].id;
                dragOffset = 0;
            }

            Layout.row: Config.barOnBottom ? 0 : 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            DragHandler {
                id: swipe

                target: null
                enabled: DashboardService.swipeTabs && repeater.count > 1
                yAxis.enabled: false
                onActiveChanged: {
                    if (active) {
                        pages.dragVelocity = 0;
                        pages.dragging = true;
                    } else {
                        pages.release();
                    }
                }
                onActiveTranslationChanged: {
                    if (active)
                        pages.dragTo(activeTranslation.x);
                }
                onCentroidChanged: {
                    if (active)
                        pages.dragVelocity = centroid.velocity.x;
                }
            }

            // Each tab places itself: a Row would skip the hidden ones
            Item {
                x: -DashboardService.tabIndex * pages.width + pages.dragOffset

                // Jumps instead while opening straight on another tab, and
                // follows the pointer while dragged
                Behavior on x {
                    enabled: root.visible && !root.isClosing && !pages.dragging

                    NumberAnimation {
                        id: slide
                        duration: Config.animDurationLong
                        easing.type: Easing.OutExpo
                    }
                }

                Repeater {
                    id: repeater
                    model: DashboardService.tabs

                    // Tabs only exist while the dashboard is shown (loaded in
                    // the hidden one on every monitor they took half the
                    // shell's idle CPU). The open one is built at once, the
                    // others after it (`preloaded`). Not asynchronously:
                    // incubated that way, the month card's MonthGrid and
                    // DayOfWeekRow came out misaligned and narrow
                    Loader {
                        required property var modelData
                        required property int index

                        // The tab a drag brings in beside the open one
                        readonly property bool neighbor: pages.dragging && Math.abs(index - DashboardService.tabIndex) === 1

                        x: index * pages.width
                        width: pages.width
                        active: root.visible && (index === DashboardService.tabIndex || index < root.preloaded || neighbor)
                        // Off-screen tabs are hidden, so their animations
                        // (Behaviors enabled by visibility) stay still
                        visible: index === DashboardService.tabIndex || slide.running || neighbor
                        sourceComponent: root.tabComponents[modelData.id] ?? null
                    }
                }
            }

            // Two fingers sideways on a touchpad change tab, one per gesture,
            // the way content scrolls. On top of the tabs, so their own wheel
            // handlers don't take it; up and down still reach them (volume,
            // month)
            Item {
                anchors.fill: parent

                property real travel: 0
                property bool switched: false

                WheelHandler {
                    enabled: swipe.enabled
                    acceptedDevices: PointerDevice.TouchPad
                    orientation: Qt.Horizontal
                    onActiveChanged: {
                        if (!active) {
                            parent.travel = 0;
                            parent.switched = false;
                        }
                    }
                    onWheel: event => {
                        const area = parent;
                        if (area.switched)
                            return;
                        area.travel += event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 8;
                        if (Math.abs(area.travel) < pages.width / 8)
                            return;
                        const target = DashboardService.tabIndex + (area.travel > 0 ? -1 : 1);
                        if (target >= 0 && target < repeater.count)
                            DashboardService.tab = DashboardService.tabs[target].id;
                        area.switched = true;
                    }
                }
            }
        }
    }

    // One per DashboardService.tabs id
    readonly property var tabComponents: ({
            overview: overviewComponent,
            media: mediaComponent,
            weather: weatherComponent,
            system: systemComponent
        })

    readonly property OverviewTab overview: {
        void repeater.count; // reevaluated once the tabs exist
        return repeater.itemAt(DashboardService.tabs.findIndex(t => t.id === "overview"))?.item ?? null;
    }

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
        }
    }

    Component {
        id: weatherComponent

        WeatherTab {
            active: root.visible && DashboardService.tab === "weather"
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
