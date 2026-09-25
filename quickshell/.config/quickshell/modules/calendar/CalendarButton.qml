pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Clock, date and (unless the weather button is shown) the current weather;
// opens the dashboard on the Overview or the tab it was left on
BarButton {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property color mainColor: active ? Config.accentColor : Config.textColor

    readonly property bool weatherButton: Config.barShowWeather && DashboardService.hasTab("weather")
    // Tabs lit by the other center buttons instead of the clock
    readonly property var ownedTabs: [Config.barShowMedia && MprisService.hasPlayer ? "media" : "", Config.barShowSystem ? "system" : "", weatherButton ? "weather" : ""]
    active: DashboardService.screen === screenName && !ownedTabs.includes(DashboardService.tab)
    contentItem: content
    onClicked: DashboardService.toggle("", screenName)

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Config.padding

        Text {
            text: TimeService.format("hh:mm")
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: root.mainColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }

        Text {
            text: TimeService.format("ddd, dd MMM")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        // Current weather
        RowLayout {
            visible: WeatherService.available && !root.weatherButton
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
}
