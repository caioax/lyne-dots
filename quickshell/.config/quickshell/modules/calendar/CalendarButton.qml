pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Clock, date and (unless the weather button is shown) the current weather;
// opens the dashboard on the Overview or the tab it was left on. With the
// "clock" center style it stands alone: cava faintly behind it, the track
// sliding out on hover and the media buttons (middle click plays/pauses,
// right click skips, the wheel changes the volume)
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

    readonly property int maxTrackWidth: Config.fontSizeNormal * 14
    readonly property bool media: Config.barCenterClock && MprisService.hasPlayer
    onMiddleClicked: {
        if (media)
            MprisService.playPause();
    }
    onRightClicked: {
        if (media)
            MprisService.next();
    }

    // A handler, not a MouseArea: one on top of the button's own resets the
    // pointing hand cursor
    WheelHandler {
        enabled: root.media
        onWheel: event => {
            const step = 0.05;
            MprisService.setVolume(MprisService.volume + (event.angleDelta.y > 0 ? step : -step));
        }
    }

    CavaBackdrop {
        anchors.fill: parent
        radius: root.radius
        running: root.media && root.visible && MprisService.isPlaying && CavaService.enabled && CavaService.available
    }

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

        // Track, slides out on hover (clock style only)
        Item {
            Layout.preferredWidth: root.media && root.hovered ? Math.min(track.implicitWidth, root.maxTrackWidth) : 0
            Layout.preferredHeight: track.implicitHeight
            // Drops out of the layout (and its spacing) once collapsed
            visible: Layout.preferredWidth > 0
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.maxTrackWidth)
                text: "󰝚  " + MprisService.title + (MprisService.artist && MprisService.artist !== "Unknown" ? "  ·  " + MprisService.artist : "")
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: MprisService.isPlaying ? Config.accentColor : Config.subtextColor
                elide: Text.ElideRight
            }
        }
    }
}
