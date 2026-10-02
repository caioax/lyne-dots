pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// Keycaps of a navigation keys preset: H J K L, the arrow keys in their
// usual inverted T, or both, one above the other
Rectangle {
    id: root

    // Preset: "vim", "arrows" or "both"
    property string value

    readonly property real capSize: Config.fontSizeIconSmall + Config.padding
    readonly property real gap: Math.round(Config.padding / 2)
    // Room of the selected tile's check in the top-right corner (as in
    // OsdStylePreview)
    readonly property int checkClearance: Config.padding * 2 + Config.fontSizeLarge + Math.round(Config.padding / 2)

    radius: Config.radius
    color: Config.surface2Color

    Column {
        id: keys

        // Centered keycaps would run under the check (selected tile only):
        // center them in the room left of it, shrunk to fit
        readonly property bool clearsCheck: root.value !== KeybindsService.preset || (root.width - implicitWidth) / 2 >= root.checkClearance
        readonly property real roomWidth: clearsCheck ? root.width - Config.padding * 2 : root.width - root.checkClearance - Config.padding

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: clearsCheck ? 0 : (Config.padding - root.checkClearance) / 2
        spacing: root.gap * 2
        scale: Math.min(1, roomWidth / implicitWidth, (root.height - Config.padding * 2) / implicitHeight)

        Row {
            visible: root.value !== "arrows"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.gap

            Repeater {
                model: ["H", "J", "K", "L"]

                Cap {}
            }
        }

        Column {
            visible: root.value !== "vim"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.gap

            Cap {
                anchors.horizontalCenter: parent.horizontalCenter
                modelData: "↑"
            }

            Row {
                spacing: root.gap

                Repeater {
                    model: ["←", "↓", "→"]

                    Cap {}
                }
            }
        }
    }

    component Cap: Rectangle {
        required property string modelData

        width: root.capSize
        height: root.capSize
        radius: Config.radiusSmall
        color: Config.surface3Color

        Text {
            anchors.centerIn: parent
            text: parent.modelData
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }
    }
}
