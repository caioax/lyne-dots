pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Pills with the battery, the weather and how many notifications arrived
// (the count only: their content stays hidden while locked). `vertical`
// stacks them
GridLayout {
    id: root

    property bool vertical: false
    // Off where the weather has its own spot (the cards template)
    property bool showWeather: true

    readonly property var weather: WeatherService.current

    columns: vertical ? 1 : 3
    rowSpacing: Config.spacing
    columnSpacing: Config.spacing

    Pill {
        visible: BatteryService.hasBattery
        icon: BatteryService.isCharging ? "\u{f0084}" : "\u{f0079}"
        text: BatteryService.percentage + "%" + (BatteryService.isCharging ? " · charging" : "")
        accent: BatteryService.percentage <= 20 && !BatteryService.isCharging ? Config.errorColor : Config.textColor
    }

    Pill {
        visible: root.showWeather && root.weather !== null
        icon: root.weather ? WeatherService.icon(root.weather.code, root.weather.isDay) : ""
        text: root.weather ? root.weather.temp + "° " + WeatherService.description(root.weather.code) : ""
    }

    Pill {
        visible: NotificationService.count > 0
        icon: "\u{f0178}"
        text: NotificationService.count + (NotificationService.count === 1 ? " notification" : " notifications")
        accent: Config.accentColor
    }

    component Pill: Rectangle {
        id: pill

        property string icon
        property string text
        property color accent: Config.textColor

        implicitWidth: row.implicitWidth + Config.padding * 4
        implicitHeight: Config.fontSizeNormal * 2.4
        radius: height / 2
        color: Config.cardColor

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: Config.spacing

            Text {
                text: pill.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: pill.accent
            }

            Text {
                text: pill.text
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.textColor
            }
        }
    }
}
