pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    active: calendarWindow.visible
    contentItem: clockText
    onClicked: calendarWindow.visible = !calendarWindow.visible

    Text {
        id: clockText
        anchors.centerIn: parent
        text: TimeService.format("hh:mm - ddd, dd MMM")
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true
        color: root.active ? Config.accentColor : Config.textColor

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    CalendarWindow {
        id: calendarWindow
        visible: false
    }
}
