import QtQuick
import QtQuick.Layouts
import qs.config

// Thin vertical separator between items of a BarIsland
Rectangle {
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 1
    implicitHeight: Config.barButtonHeight - Config.padding * 2
    color: Config.surface2Color
}
