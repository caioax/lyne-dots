pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Rectangle {
    id: root

    property bool active: false
    property Item contentItem: null
    readonly property bool hovered: mouseArea.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked

    implicitWidth: (contentItem?.implicitWidth ?? 0) + (Config.padding * 2)
    implicitHeight: Config.barButtonHeight
    radius: height / 2

    color: (active || hovered) ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

    Behavior on color {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
    }
}
