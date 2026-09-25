pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../calendar/"
import "../quickSettings/"

// Clock, weather, the month, the player and resource usage, laid out by
// DashboardService.overviewLayout:
//   stacked: clock + weather | month, then the wide MediaWidget player and
//            the resources, full width
//   grid:    clock + weather | month | tall player, resources below (default)
GridLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    readonly property bool grid: DashboardService.overviewLayout === "grid"

    // Back to the current month, without the slide animation
    function reset() {
        monthCard.displayMonth = TimeService.date.getMonth();
        monthCard.displayYear = TimeService.date.getFullYear();
        monthCard.selectedDate = TimeService.date;
    }

    // GPU and disk usage are only sampled while someone watches
    onActiveChanged: {
        if (active) {
            WeatherService.refresh(false);
            SystemMonitorService.acquire();
        } else {
            SystemMonitorService.release();
        }
    }
    Component.onDestruction: {
        if (active)
            SystemMonitorService.release();
    }

    rowSpacing: Config.spacing
    columnSpacing: Config.spacing

    ColumnLayout {
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: root.grid ? 250 : 280
        Layout.fillHeight: true
        spacing: Config.spacing

        ClockCard {
            Layout.fillWidth: true
        }

        WeatherNowCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    MonthCard {
        id: monthCard
        Layout.row: 0
        Layout.column: 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
    }

    PlayerCard {
        Layout.row: 0
        Layout.column: 2
        Layout.preferredWidth: 220
        Layout.fillHeight: true
        visible: root.grid && MprisService.hasPlayer
    }

    MediaWidget {
        Layout.row: 1
        Layout.column: 0
        Layout.columnSpan: 2
        visible: !root.grid && MprisService.hasPlayer
        dismissible: false
        openable: true
        expressive: true
        onOpenRequested: DashboardService.tab = "media"
    }

    ResourcesCard {
        Layout.row: 2
        Layout.column: 0
        Layout.columnSpan: root.grid ? 3 : 2
    }
}
