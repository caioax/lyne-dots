pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../calendar/"

// Clock, weather and the month (the old calendar popup, for now)
RowLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    // Back to the current month, without the slide animation
    function reset() {
        monthCard.displayMonth = TimeService.date.getMonth();
        monthCard.displayYear = TimeService.date.getFullYear();
        monthCard.selectedDate = TimeService.date;
    }

    onActiveChanged: {
        if (active)
            WeatherService.refresh(false);
    }

    spacing: Config.spacing

    ColumnLayout {
        Layout.preferredWidth: 280
        Layout.fillHeight: true
        spacing: Config.spacing

        ClockCard {
            Layout.fillWidth: true
        }

        WeatherCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    MonthCard {
        id: monthCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
    }
}
