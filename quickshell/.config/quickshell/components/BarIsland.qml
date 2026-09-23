pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Floating group of bar items, styled like the popups (translucent + border)
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + Config.padding * 2
    implicitHeight: Config.barIslandHeight
    radius: height / 2
    color: Config.backgroundTransparentColor
    border.width: 1
    border.color: Config.surface1Color

    // No width animation here: the items (tray drawer, CPU details, window
    // title) already animate their own size, and a second, lagging animation
    // on the island made the items at the far edge wobble

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Config.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.padding
    }
}
