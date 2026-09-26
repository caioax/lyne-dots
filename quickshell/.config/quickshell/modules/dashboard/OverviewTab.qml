pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../calendar/"

// Clock, weather, the month, the player and resource usage in three columns:
// clock + weather | month | player, with the resources below the first two.
// The player runs down to the bottom (room for the GIF); without one the
// resources take the full width
GridLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

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
        Layout.preferredWidth: 250
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
        Layout.rowSpan: 2
        Layout.fillHeight: true
        visible: MprisService.hasPlayer
    }

    ResourcesCard {
        Layout.row: 1
        Layout.column: 0
        Layout.columnSpan: MprisService.hasPlayer ? 2 : 3
    }
}
