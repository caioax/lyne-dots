import QtQuick
import qs.config

// Mask for a Flickable whose content cut by an edge with more to scroll
// fades out. Place it next to the Flickable (it stays hidden, so layouts skip
// it) and give the Flickable:
//   layer.enabled: mask.active
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; ... }
Rectangle {
    id: root

    required property Flickable flickable
    readonly property real fadeLength: Config.spacing * 4 / Math.max(height, 1)
    property real topFade: flickable.atYBeginning ? 0 : 1
    property real bottomFade: flickable.atYEnd ? 0 : 1
    readonly property bool active: topFade > 0 || bottomFade > 0

    Behavior on topFade {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    Behavior on bottomFade {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    width: flickable.width
    height: flickable.height
    visible: false
    layer.enabled: true
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha("black", 1 - root.topFade)
        }
        GradientStop {
            position: root.fadeLength
            color: "black"
        }
        GradientStop {
            position: 1 - root.fadeLength
            color: "black"
        }
        GradientStop {
            position: 1
            color: Qt.alpha("black", 1 - root.bottomFade)
        }
    }
}
