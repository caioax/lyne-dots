pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Soft glow around the hovered window; the outline itself is drawn by the
// dimming shader with the window's rounding
Item {
    id: root

    required property var screenshot
    required property var monitorScreen

    Rectangle {
        readonly property int glow: Config.padding

        visible: root.screenshot.selectionWidth > 0

        x: root.screenshot.selectionX - root.screenshot.hyprBorderSize - glow
        y: root.screenshot.selectionY - root.screenshot.hyprBorderSize - glow
        width: root.screenshot.selectionWidth + (root.screenshot.hyprBorderSize + glow) * 2
        height: root.screenshot.selectionHeight + (root.screenshot.hyprBorderSize + glow) * 2

        color: Qt.alpha(Config.accentColor, 0)
        radius: root.screenshot.selectionRadius + root.screenshot.hyprBorderSize + glow
        border.width: glow
        border.color: Qt.alpha(Config.accentColor, 0.25)
    }
}
