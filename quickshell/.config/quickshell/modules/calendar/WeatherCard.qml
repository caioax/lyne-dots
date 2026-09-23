pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    readonly property var current: WeatherService.current

    CardHeader {
        icon: root.current ? WeatherService.icon(root.current.code, root.current.isDay) : "󰖐"
        title: "Weather"
        subtitle: WeatherService.location

        RefreshButton {
            size: Config.fontSizeSmall * 2
            loading: WeatherService.loading
            onClicked: WeatherService.refresh(true)
        }
    }

    // ==================== EMPTY / ERROR ====================
    ColumnLayout {
        visible: !WeatherService.available
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.padding

        Item {
            Layout.fillHeight: true
        }

        Spinner {
            Layout.alignment: Qt.AlignHCenter
            running: WeatherService.loading
            color: Config.subtextColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: !WeatherService.loading
            text: "󰖪  " + (WeatherService.error || "Weather unavailable")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // ==================== CURRENT ====================
    RowLayout {
        visible: WeatherService.available
        Layout.fillWidth: true
        spacing: Config.spacing

        Text {
            text: root.current ? WeatherService.icon(root.current.code, root.current.isDay) : ""
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge + Config.fontSizeIconSmall
            color: Config.accentColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: (root.current?.temp ?? 0) + "°"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconLarge
                font.bold: true
                color: Config.textColor
            }

            Text {
                Layout.fillWidth: true
                text: root.current ? WeatherService.description(root.current.code) : ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            spacing: 2

            Detail {
                icon: "󰔏"
                text: "Feels " + (root.current?.feelsLike ?? 0) + "°"
            }

            Detail {
                icon: "󰖎"
                text: (root.current?.humidity ?? 0) + "%"
            }

            Detail {
                icon: "󰖝"
                text: (root.current?.wind ?? 0) + " km/h"
            }
        }
    }

    RowLayout {
        visible: WeatherService.available
        spacing: Config.padding

        StatChip {
            icon: "󰖜"
            text: WeatherService.sunrise
            accent: Config.warningColor
        }

        StatChip {
            icon: "󰖛"
            text: WeatherService.sunset
            accent: Config.warningColor
        }
    }

    // ==================== FORECAST ====================
    RowLayout {
        visible: WeatherService.available
        Layout.fillWidth: true
        uniformCellSizes: true
        spacing: Config.padding / 2

        Repeater {
            model: WeatherService.daily

            Rectangle {
                id: day
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: dayColumn.implicitHeight + Config.padding * 2
                radius: Config.radius
                color: index === 0 ? Qt.alpha(Config.accentColor, 0.12) : Config.surface1Color

                ColumnLayout {
                    id: dayColumn
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.index === 0 ? "Today" : day.modelData.date.toLocaleDateString(Qt.locale(), "ddd")
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: day.index === 0
                        color: day.index === 0 ? Config.accentColor : Config.subtextColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: WeatherService.icon(day.modelData.code, true)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.textColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.modelData.max + "°"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.modelData.min + "°"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }

                    // Chance of rain, only when it's worth mentioning
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        opacity: day.modelData.rain >= 20 ? 1 : 0
                        text: "󰖌 " + day.modelData.rain + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.accentColor
                    }
                }
            }
        }
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text

        Layout.alignment: Qt.AlignRight
        spacing: Config.padding / 2

        Text {
            text: detail.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Text {
            text: detail.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.textColor
        }
    }
}
