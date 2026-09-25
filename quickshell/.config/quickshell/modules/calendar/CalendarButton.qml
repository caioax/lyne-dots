pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Clock and date; opens the dashboard (on the Overview or the tab it was
// left on). Media, weather and CPU have their own buttons for their tabs
BarButton {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property color mainColor: active ? Config.accentColor : Config.textColor

    // Lit unless one of the other center buttons owns the current tab
    readonly property var ownedTabs: ["media", "weather", "system"]
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
    }
}
