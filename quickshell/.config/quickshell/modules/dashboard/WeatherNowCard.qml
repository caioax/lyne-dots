pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Current weather and today's range, compact (the forecast lives in the
// Weather tab, which a click opens)
Card {
    id: root

    readonly property var current: WeatherService.current
    readonly property var today: WeatherService.daily[0] ?? null

    color: mouse.containsMouse ? Config.cardHoverColor : Config.cardColor

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    // Behind the content, so the refresh button keeps its own clicks
    MouseArea {
        id: mouse
        parent: root
        z: -1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: DashboardService.tab = "weather"
    }

    CardHeader {
        icon: "\u{f034e}"
        title: WeatherService.location

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

    GridLayout {
        visible: WeatherService.available
        Layout.fillWidth: true
        columns: 2
        uniformCellWidths: true
        rowSpacing: Config.padding
        columnSpacing: Config.padding

        DetailTile {
            icon: "\u{f050f}"
            label: "Feels"
            value: (root.current?.feelsLike ?? 0) + "°"
        }

        DetailTile {
            icon: "\u{f058c}"
            label: "Rain"
            value: (root.today?.rain ?? 0) + "%"
        }

        DetailTile {
            icon: "\u{f058e}"
            label: "Humidity"
            value: (root.current?.humidity ?? 0) + "%"
        }

        DetailTile {
            icon: "\u{f059d}"
            label: "Wind"
            value: (root.current?.wind ?? 0) + " km/h"
        }
    }

    Item {
        visible: WeatherService.available
        Layout.fillHeight: true
    }
}
