pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Current weather and today's range, compact (the forecast lives in the
// Weather tab)
Card {
    id: root

    readonly property var current: WeatherService.current
    readonly property var today: WeatherService.daily[0] ?? null

    CardHeader {
        icon: "\u{f0595}"
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
            text: "\u{f05aa}  " + (WeatherService.error || "Weather unavailable")
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // ==================== NOW ====================
    Item {
        visible: WeatherService.available
        Layout.fillHeight: true
    }

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
            Layout.alignment: Qt.AlignTop
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignRight
                text: "\u{f005d} " + (root.today?.max ?? 0) + "°"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: "\u{f0045} " + (root.today?.min ?? 0) + "°"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }
    }

    Flow {
        visible: WeatherService.available
        Layout.fillWidth: true
        spacing: Config.padding

        StatChip {
            icon: "\u{f050f}"
            text: "Feels " + (root.current?.feelsLike ?? 0) + "°"
        }

        StatChip {
            visible: (root.today?.rain ?? 0) > 0
            icon: "\u{f058c}"
            text: (root.today?.rain ?? 0) + "%"
            accent: Config.accentColor
        }

        StatChip {
            icon: "\u{f058e}"
            text: (root.current?.humidity ?? 0) + "%"
        }

        StatChip {
            icon: "\u{f059d}"
            text: (root.current?.wind ?? 0) + " km/h"
        }
    }

    Item {
        visible: WeatherService.available
        Layout.fillHeight: true
    }
}
