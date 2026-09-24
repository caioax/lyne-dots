pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Group of bar items. In the "islands" bar style it floats on its own, styled
// like the popups (translucent + border); in the other styles the bar draws
// the background and the group is just a row
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    readonly property bool framed: Config.barIslands
    readonly property int sidePadding: framed ? Config.padding : 0

    implicitWidth: row.implicitWidth + sidePadding * 2
    implicitHeight: Config.barIslandHeight
    radius: height / 2
    color: framed ? Config.backgroundTransparentColor : "transparent"
    border.width: framed ? 1 : 0
    border.color: Config.surface1Color

    // No width animation here: the items (tray drawer, CPU details, window
    // title) already animate their own size, and a second, lagging animation
    // on the island made the items at the far edge wobble

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: root.sidePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.padding
    }
}
