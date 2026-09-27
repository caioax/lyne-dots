import QtQuick
import QtQuick.Controls
import qs.config

// Hover hint inside a shell window, drawn like the tray tooltip. Put it in
// the target: `QsToolTip { text: "Lock"; shown: mouse.containsMouse }`
ToolTip {
    id: root

    property bool shown: false

    visible: shown && text !== ""
    delay: Config.animDurationLong
    padding: Config.padding
    topPadding: Math.round(Config.padding * 0.75)
    bottomPadding: topPadding
    // Above the target, kept inside the window by the popup margins
    y: -implicitHeight - Math.round(Config.padding / 2)
    margins: Config.spacing

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Config.animDurationShort
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Config.animDurationShort
        }
    }

    background: Rectangle {
        radius: Config.radius
        color: Config.backgroundTransparentColor
        border.width: 1
        border.color: Config.surface2Color
    }

    contentItem: Text {
        text: root.text
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: Config.textColor
    }
}
