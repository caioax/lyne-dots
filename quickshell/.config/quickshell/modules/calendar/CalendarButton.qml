pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Clock, date and current weather; opens the calendar
BarButton {
    id: root

    readonly property color mainColor: active ? Config.accentColor : Config.textColor

    active: calendarWindow.visible
    contentItem: content
    onClicked: calendarWindow.visible = !calendarWindow.visible

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
            visible: WeatherService.available
            spacing: Math.round(Config.padding / 2)

            BarDivider {
                Layout.rightMargin: Config.padding / 2
            }

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

    CalendarWindow {
        id: calendarWindow
        anchorItem: root
        visible: false
    }
}
