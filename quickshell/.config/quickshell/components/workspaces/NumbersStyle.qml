import QtQuick
import qs.config

// Numbers: occupied workspaces show their number, empty ones a faint dot,
// and the active number sits on the accent pill.
WorkspaceStrip {
    id: root

    itemWidth: Math.round(Config.fontSizeSmall * 1.5)
    activeWidth: itemWidth + Config.padding * 2
    itemSpacing: Math.round(Config.padding / 3)

    slotContent: Component {
        Text {
            required property Item slot

            anchors.centerIn: parent
            text: slot.isEmpty && !slot.isActive ? "·" : slot.index + 1
            font {
                family: Config.font
                pixelSize: Config.fontSizeSmall
                bold: slot.isActive
            }
            color: slot.isActive ? Config.textReverseColor : slot.isEmpty ? Config.mutedColor : Config.textColor

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
