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

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    // Pinned to the left: while the island's width animates, the items stay
    // put instead of sliding around a moving center
    clip: true

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Config.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.padding
    }
}
