import QtQuick
import QtQuick.Effects
import qs.config

// Soft shadow of a shell panel (Config.shadow*). A child of the panel: z -1
// draws it under the panel, scaled and faded with it. The window leaves
// Config.shadowPad around the panel. Flush sides (attached panels) push the
// shadow past that edge, where the panel's clip hides it
RectangularShadow {
    id: root

    // Sides flush against the bar or a screen edge: "top", "bottom", ...
    property var flush: []

    readonly property real _past: Config.shadowPad + radius

    anchors.fill: parent
    anchors.topMargin: flush.includes("top") ? -_past : 0
    anchors.bottomMargin: flush.includes("bottom") ? -_past : 0
    anchors.leftMargin: flush.includes("left") ? -_past : 0
    anchors.rightMargin: flush.includes("right") ? -_past : 0
    z: -1
    visible: Config.shadowEnabled
    blur: Config.shadowBlur
    offset.y: Config.shadowOffset
    color: Config.shadowColor
}
