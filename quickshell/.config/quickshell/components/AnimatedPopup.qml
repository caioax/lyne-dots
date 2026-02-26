pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Centralized entry/exit animation wrapper for overlay popups (launchers, pickers, panels).
//
// Usage:
//   AnimatedPopup {
//       anchors.centerIn: parent
//       width: ...; height: ...
//       shown: MyService.visible
//       // override defaults if needed:
//       easingType: Easing.OutBack
//       easingOvershoot: 1.1
//
//       Rectangle { anchors.fill: parent; ... }
//   }
//
// The caller controls sizing. Children are placed inside the animated Item.
// Pair with a keepAlive Loader in shell.qml so exit animations complete before
// the component is destroyed (see shell.qml comments).
Item {
    id: root

    // Drive this to animate in (true) or out (false)
    property bool shown: false

    // --- Configurable per-use (defaults come from Config) ---
    property real fromScale: Config.animPopupFromScale
    property int enterDuration: Config.animDurationLong
    property int exitDuration: Config.animDuration
    property int easingType: Config.animPopupEasing
    property real easingOvershoot: 0.0

    // -------------------------------------------------------------------------
    // Internal: _ready starts false so the component is created at fromScale/0.
    // On the next event-loop tick _ready becomes true, which triggers the
    // Behavior and plays the entry animation — even though `shown` was already
    // true at construction time (Behaviors only fire on property *changes*).
    // -------------------------------------------------------------------------
    property bool _ready: false
    Component.onCompleted: Qt.callLater(() => { _ready = true; })

    // -------------------------------------------------------------------------
    // Animation
    // -------------------------------------------------------------------------
    scale: (shown && _ready) ? 1.0 : fromScale
    opacity: (shown && _ready) ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? root.enterDuration : root.exitDuration
            easing.type: root.easingType
            easing.overshoot: root.easingOvershoot
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }
}
