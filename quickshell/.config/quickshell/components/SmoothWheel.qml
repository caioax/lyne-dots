import QtQuick
import qs.config

// Mouse wheel scrolling for a Flickable: each notch glides `step` pixels
// (Qt's own wheel moves 15 px per notch on Wayland), and notches in a row add
// up to where the glide is heading. Touchpads keep Qt's own scrolling
WheelHandler {
    id: root

    required property Flickable flickable
    property real step: Config.spacing * 15

    // Lets the owner stop its own scroll animation first
    signal wheelStarted

    function _clamp(y) {
        return Math.max(0, Math.min(flickable.contentHeight - flickable.height, y));
    }

    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        // Touchpads scroll in phases (begin, update, end) and stay with the
        // Flickable, which follows the finger and keeps the inertia
        if (event.phase !== Qt.NoScrollPhase || flickable.contentHeight <= flickable.height) {
            event.accepted = false;
            return;
        }
        root.wheelStarted();
        const from = glide.running ? glide.to : flickable.contentY;
        glide.to = _clamp(from - event.angleDelta.y / 120 * step);
        glide.restart();
    }

    property NumberAnimation _glide: NumberAnimation {
        id: glide

        target: root.flickable
        property: "contentY"
        duration: Config.animDuration
        easing.type: Easing.OutCubic
    }
}
