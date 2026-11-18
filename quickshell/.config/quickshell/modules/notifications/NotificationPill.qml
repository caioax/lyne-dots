import QtQuick
import qs.config

// Count and chevron that open and close a conversation (history and popups).
// The count shows from two messages on
Rectangle {
    id: root

    property int count: 1
    property bool expanded: false

    signal clicked

    implicitWidth: row.implicitWidth + Config.padding * 3
    implicitHeight: Config.fontSizeSmall + Config.padding * 2
    radius: height / 2
    color: mouse.containsMouse ? Qt.lighter(Config.accentColor, 1.1) : Config.accentColor

    Behavior on color {
        enabled: !Config.themeTransitioning
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(Config.padding / 2)

        Text {
            visible: root.count > 1
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textReverseColor
        }

        // md-chevron_down, turning up while open
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0140}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.textReverseColor
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
