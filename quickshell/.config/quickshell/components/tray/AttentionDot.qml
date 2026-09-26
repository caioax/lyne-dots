import QtQuick
import qs.config

// Pulsing errorColor dot for a tray item that needs attention, sitting on
// the top-right corner of its parent (an icon or the button hiding it)
Rectangle {
    id: root

    property bool active: false

    width: Math.round(Config.fontSizeSmall / 2)
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.top: parent.top
    color: Config.errorColor
    visible: active
    scale: active ? 1 : 0

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation on opacity {
        running: root.active
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            root.opacity = 1

        NumberAnimation {
            to: 0.35
            duration: Config.animDurationLong
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: Config.animDurationLong
            easing.type: Easing.InOutSine
        }
    }
}
