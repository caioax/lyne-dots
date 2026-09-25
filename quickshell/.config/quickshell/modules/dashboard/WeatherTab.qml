pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Weather now, the next 24 hours (every 2 hours, over a temperature curve)
// and the week, each day's range drawn against the whole week's
ColumnLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    readonly property var current: WeatherService.current
    readonly property var today: WeatherService.daily[0] ?? null
    // One every 2 hours
    readonly property var hours: WeatherService.hourly.filter((h, i) => i % 2 === 0)
    readonly property real weekMin: Math.min(...WeatherService.daily.map(d => d.min))
    readonly property real weekMax: Math.max(...WeatherService.daily.map(d => d.max))

    onActiveChanged: {
        if (active)
            WeatherService.refresh(false);
    }

    spacing: Config.spacing

    function uvColor(uv: int): color {
        if (uv >= 8)
            return Config.errorColor;
        if (uv >= 6)
            return Config.warningColor;
        return Config.successColor;
    }

    // ==================== EMPTY / ERROR ====================
    Card {
        visible: !WeatherService.available
        Layout.fillWidth: true
        Layout.preferredHeight: Config.fontSizeIconLarge * 8

        Item {
            Layout.fillHeight: true
        }

        Spinner {
            Layout.alignment: Qt.AlignHCenter
            running: WeatherService.loading
            visible: running
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

        RefreshButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !WeatherService.loading
            size: Config.fontSizeSmall * 2
            loading: WeatherService.loading
            onClicked: WeatherService.refresh(true)
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // ==================== NOW ====================
    Card {
        visible: WeatherService.available
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing * 2

            Text {
                text: root.current ? WeatherService.icon(root.current.code, root.current.isDay) : ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconLarge * 2.2
                color: Config.accentColor
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: (root.current?.temp ?? 0) + "°"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge * 1.5
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    text: root.current ? WeatherService.description(root.current.code) : ""
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.textColor
                }

                Text {
                    text: "Feels " + (root.current?.feelsLike ?? 0) + "°  ·  \u{f005d} " + (root.today?.max ?? 0) + "°  \u{f0045} " + (root.today?.min ?? 0) + "°"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Config.padding / 2

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Config.padding

                    Text {
                        text: "\u{f034e}  " + WeatherService.location
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textColor
                    }

                    RefreshButton {
                        size: Config.fontSizeSmall * 2
                        loading: WeatherService.loading
                        onClicked: WeatherService.refresh(true)
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: WeatherService.lastUpdate > 0 ? "Updated " + Qt.formatTime(new Date(WeatherService.lastUpdate), "hh:mm") : ""
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Config.padding

            StatChip {
                icon: "\u{f058e}"
                text: (root.current?.humidity ?? 0) + "%"
            }

            StatChip {
                icon: "\u{f059d}"
                text: (root.current?.wind ?? 0) + " km/h"
            }

            StatChip {
                icon: "\u{f058c}"
                text: (root.today?.rain ?? 0) + "%"
                accent: Config.accentColor
            }

            StatChip {
                icon: "\u{f0599}"
                text: "UV " + (root.current?.uv ?? 0)
                accent: root.uvColor(root.current?.uv ?? 0)
            }

            StatChip {
                icon: "\u{f059c}"
                text: WeatherService.sunrise
                accent: Config.warningColor
            }

            StatChip {
                icon: "\u{f059b}"
                text: WeatherService.sunset
                accent: Config.warningColor
            }
        }
    }

    // ==================== NEXT 24 HOURS ====================
    Card {
        visible: WeatherService.available && root.hours.length > 0
        Layout.fillWidth: true

        CardHeader {
            icon: "\u{f0150}"
            title: "Next 24 hours"
        }

        Item {
            id: hoursArea

            readonly property real columnWidth: width / Math.max(1, root.hours.length)
            readonly property real labelHeight: Config.fontSizeSmall + Config.padding
            readonly property real iconHeight: Config.fontSizeIcon + Config.padding
            // The curve lives between the icons and the rain line
            readonly property real curveTop: labelHeight + iconHeight + labelHeight
            readonly property real curveHeight: Config.fontSizeIconLarge * 1.5
            readonly property real minTemp: Math.min(...root.hours.map(h => h.temp))
            readonly property real maxTemp: Math.max(...root.hours.map(h => h.temp))

            function pointY(temp: real): real {
                const span = Math.max(1, maxTemp - minTemp);
                return curveTop + curveHeight * (1 - (temp - minTemp) / span);
            }

            Layout.fillWidth: true
            implicitHeight: curveTop + curveHeight + Config.padding + labelHeight

            Canvas {
                id: curve
                anchors.fill: parent

                onWidthChanged: requestPaint()
                Connections {
                    target: WeatherService
                    function onHourlyChanged() {
                        curve.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const pts = root.hours.map((h, i) => [hoursArea.columnWidth * (i + 0.5), hoursArea.pointY(h.temp)]);
                    if (pts.length < 2)
                        return;

                    // Soft fill under a smooth line
                    const path = () => {
                        ctx.moveTo(pts[0][0], pts[0][1]);
                        for (let i = 1; i < pts.length; i++) {
                            const mx = (pts[i - 1][0] + pts[i][0]) / 2;
                            ctx.bezierCurveTo(mx, pts[i - 1][1], mx, pts[i][1], pts[i][0], pts[i][1]);
                        }
                    };
                    const bottom = hoursArea.curveTop + hoursArea.curveHeight;
                    ctx.beginPath();
                    path();
                    ctx.lineTo(pts[pts.length - 1][0], bottom);
                    ctx.lineTo(pts[0][0], bottom);
                    ctx.closePath();
                    const grad = ctx.createLinearGradient(0, hoursArea.curveTop, 0, bottom);
                    grad.addColorStop(0, Qt.alpha(Config.accentColor, 0.25));
                    grad.addColorStop(1, Qt.alpha(Config.accentColor, 0));
                    ctx.fillStyle = grad;
                    ctx.fill();

                    ctx.beginPath();
                    path();
                    ctx.strokeStyle = Config.accentColor;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    ctx.fillStyle = Config.accentColor;
                    for (const p of pts) {
                        ctx.beginPath();
                        ctx.arc(p[0], p[1], 3, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }

            Repeater {
                model: root.hours

                Item {
                    id: hour

                    required property var modelData
                    required property int index

                    x: hoursArea.columnWidth * index
                    width: hoursArea.columnWidth
                    height: hoursArea.height

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hour.index === 0 ? "Now" : Qt.formatTime(hour.modelData.date, "hh")
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: hour.index === 0
                        color: hour.index === 0 ? Config.textColor : Config.subtextColor
                    }

                    Text {
                        y: hoursArea.labelHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: WeatherService.icon(hour.modelData.code, hour.modelData.isDay)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: Config.textColor
                    }

                    // Temperature just above its point
                    Text {
                        y: hoursArea.pointY(hour.modelData.temp) - height - Config.padding / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hour.modelData.temp + "°"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u{f058c}" + hour.modelData.rain + "%"
                        opacity: hour.modelData.rain >= 20 ? 1 : 0.35
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall - 2
                        color: hour.modelData.rain >= 20 ? Config.accentColor : Config.subtextColor
                    }
                }
            }
        }
    }

    // ==================== WEEK ====================
    Card {
        visible: WeatherService.available && WeatherService.daily.length > 0
        Layout.fillWidth: true
        spacing: Config.padding

        CardHeader {
            icon: "\u{f0a33}"
            title: WeatherService.daily.length + " days"
        }

        Repeater {
            model: WeatherService.daily

            RowLayout {
                id: day

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Config.spacing

                Text {
                    Layout.preferredWidth: Config.fontSizeNormal * 4
                    text: day.index === 0 ? "Today" : day.modelData.date.toLocaleDateString(Qt.locale(), "ddd")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: day.index === 0
                    font.capitalization: Font.Capitalize
                    color: day.index === 0 ? Config.textColor : Config.subtextColor
                }

                Text {
                    Layout.preferredWidth: Config.fontSizeIcon * 1.5
                    text: WeatherService.icon(day.modelData.code, true)
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    color: Config.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.preferredWidth: Config.fontSizeSmall * 4
                    text: "\u{f058c} " + day.modelData.rain + "%"
                    opacity: day.modelData.rain >= 20 ? 1 : 0.35
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: day.modelData.rain >= 20 ? Config.accentColor : Config.subtextColor
                }

                Text {
                    Layout.preferredWidth: Config.fontSizeSmall * 2.5
                    text: day.modelData.min + "°"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    horizontalAlignment: Text.AlignRight
                }

                // Day's range against the week's
                Item {
                    Layout.fillWidth: true
                    implicitHeight: Config.padding

                    readonly property real span: Math.max(1, root.weekMax - root.weekMin)

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.alpha(Config.surface3Color, 0.5)
                    }

                    Rectangle {
                        x: parent.width * (day.modelData.min - root.weekMin) / parent.span
                        width: Math.max(height, parent.width * (day.modelData.max - day.modelData.min) / parent.span)
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: Config.accentColor
                            }
                            GradientStop {
                                position: 1
                                color: Config.warningColor
                            }
                        }
                    }

                    // Now, on today's bar
                    Rectangle {
                        visible: day.index === 0 && root.current !== null
                        readonly property real ratio: ((root.current?.temp ?? 0) - root.weekMin) / parent.span
                        x: parent.width * Math.max(0, Math.min(1, ratio)) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.height * 2
                        height: width
                        radius: width / 2
                        color: Config.textColor
                        border.width: 2
                        border.color: Config.accentColor
                    }
                }

                Text {
                    Layout.preferredWidth: Config.fontSizeSmall * 2.5
                    text: day.modelData.max + "°"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.textColor
                }

                StatChip {
                    Layout.preferredWidth: Config.fontSizeSmall * 5
                    icon: "\u{f0599}"
                    text: String(day.modelData.uv)
                    accent: root.uvColor(day.modelData.uv)
                }
            }
        }
    }
}
