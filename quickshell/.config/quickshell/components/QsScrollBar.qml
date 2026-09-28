import QtQuick
import QtQuick.Controls
import qs.config

// Themed vertical scrollbar: a thin visible handle at rest that gets
// stronger on hover and while dragging. With `autoHide` it only shows while
// scrolling, while `peek` is set (e.g. the pointer is over the list) and a
// moment after
ScrollBar {
    id: root

    property bool autoHide: false
    property bool peek: false
    readonly property bool _wanted: !autoHide || active || peek || hovered || pressed
    property bool _shown: !autoHide

    on_WantedChanged: {
        if (_wanted) {
            hideTimer.stop();
            _shown = true;
        } else {
            hideTimer.restart();
        }
    }

    policy: ScrollBar.AsNeeded
    padding: Math.round(Config.padding / 3)

    background: Item {}

    // The style fades the handle out when idle through these
    states: []
    transitions: []

    contentItem: Rectangle {
        implicitWidth: Math.round(Config.padding * 2 / 3)
        implicitHeight: implicitWidth
        radius: width / 2
        color: root.pressed ? Config.surface3Color : root.hovered ? Config.surface2Color : Qt.alpha(Config.surface2Color, 0.7)
        visible: root.size < 1
        opacity: root._shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Behavior on color {
            enabled: !Config.themeTransitioning
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    Timer {
        id: hideTimer

        interval: Config.animDurationLong * 2
        onTriggered: root._shown = false
    }
}
