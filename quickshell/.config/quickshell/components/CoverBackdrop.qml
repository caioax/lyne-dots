pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.services

// The active track's cover, blurred and darkened, as a card background.
// Rounded to `radius`
ClippingRectangle {
    id: root

    radius: Config.radiusLarge
    color: "transparent"

    Image {
        id: bgSource
        anchors.fill: parent
        source: MprisService.artUrl
        fillMode: Image.PreserveAspectCrop
        // Blurred anyway: no need to decode a 1280×720 cover at full size
        sourceSize: Qt.size(128, 128)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bgSource
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 0.75
        opacity: 0.35
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.3
    }
}
