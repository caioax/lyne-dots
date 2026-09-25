pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

Button {
    id: root

    // --- Properties ---
    property string iconText: ""        // The icon (text)
    property string tooltipText: "Back" // Tooltip text on hover
    property int size: 40                // Button size

    // --- Fine Tuning (Offsets) ---
    // Use if the font icon is not visually centered
    property real iconOffsetX: -2
    property real iconOffsetY: 0

    // --- Layout ---
    implicitWidth: size
    implicitHeight: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size

    // --- Background ---
    background: Rectangle {
        radius: root.height / 2 // Ensures a perfect circle

        // Color changes on hover
        color: root.hovered ? Config.surface2Color : Qt.alpha(Config.surface2Color, 0)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    // --- Content (Icon) ---
    Text {
        // Center relative to the wrapper
        anchors.centerIn: parent

        // Apply manual offsets
        anchors.horizontalCenterOffset: root.iconOffsetX
        anchors.verticalCenterOffset: root.iconOffsetY

        text: root.iconText

        color: Config.textColor
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
    }

    // --- Tooltip ---
    ToolTip.visible: root.hovered && root.tooltipText !== ""
    ToolTip.text: root.tooltipText
    ToolTip.delay: 500
}
