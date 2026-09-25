pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services

// The active track's cover, blurred and darkened, as a card background.
// Rounded to `radius`
Item {
    id: root

    property real radius: Config.radiusLarge

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Image {
        id: bgSource
        anchors.fill: parent
        source: MprisService.artUrl
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    FastBlur {
        anchors.fill: parent
        source: bgSource
        radius: 48
        opacity: 0.35
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.3
    }
}
