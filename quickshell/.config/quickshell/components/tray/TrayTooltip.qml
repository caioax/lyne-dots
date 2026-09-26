pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Hover tooltip of a tray item: its title, and the app's tooltip text below
// when it has one. A popup anchored under the icon (over it with the bar at
// the bottom), so it can leave the bar's window.
PopupWindow {
    id: root

    required property Item target
    required property string title
    property string description

    readonly property int gap: Math.round(Config.padding / 2)

    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: Config.barOnBottom ? -gap : 0
    anchor.rect.width: target.width
    anchor.rect.height: target.height + gap
    anchor.edges: Config.barOnBottom ? Edges.Top : Edges.Bottom
    anchor.gravity: Config.barOnBottom ? Edges.Top : Edges.Bottom

    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height

    Rectangle {
        id: card

        readonly property int maxTextWidth: Config.fontSizeNormal * 22

        width: column.width + Config.padding * 2
        height: column.height + Config.padding * 1.5
        radius: Config.radius
        color: Config.backgroundTransparentColor
        border.width: 1
        border.color: Config.surface2Color

        Column {
            id: column

            anchors.centerIn: parent
            spacing: Math.round(Config.padding / 4)

            Text {
                width: Math.min(implicitWidth, card.maxTextWidth)
                text: root.title
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }

            // Apps may send simple markup here
            Text {
                visible: text !== ""
                width: Math.min(implicitWidth, card.maxTextWidth)
                text: root.description
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }
    }
}
