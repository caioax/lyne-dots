pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Current weather; opens the dashboard on its Weather tab
BarButton {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    visible: WeatherService.available
    active: DashboardService.screen === screenName && DashboardService.tab === "weather"
    contentItem: content
    onClicked: DashboardService.toggle("weather", screenName)

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(Config.padding / 2)

        Text {
            text: WeatherService.available ? WeatherService.icon(WeatherService.current.code, WeatherService.current.isDay) : ""
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.warningColor
        }

        Text {
            text: WeatherService.available ? WeatherService.current.temp + "°" : ""
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }
    }
}
