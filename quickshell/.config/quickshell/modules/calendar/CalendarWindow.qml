pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

QsPopupWindow {
    id: root

    popupWidth: 640
    popupMaxHeight: 700
    anchorSide: "left"
    moduleName: "Calendar"
    contentImplicitHeight: content.implicitHeight

    onVisibleChanged: {
        if (!visible)
            return;
        // Always open on the current month, without the slide animation
        monthCard.displayMonth = TimeService.date.getMonth();
        monthCard.displayYear = TimeService.date.getFullYear();
        monthCard.selectedDate = TimeService.date;
        WeatherService.refresh(false);
    }

    RowLayout {
        id: content
        anchors.fill: parent
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
}
