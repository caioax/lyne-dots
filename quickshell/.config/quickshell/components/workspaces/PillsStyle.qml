import QtQuick
import qs.config

// Pills: the active slot is a wide accent pill, occupied pills are solid and
// empty ones faint.
WorkspaceStrip {
    id: root

    readonly property int pillHeight: itemWidth

    // The accent pill slides over the others
    contentOverIndicator: false

    slotContent: Component {
        Rectangle {
            required property Item slot

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.pillHeight
            radius: Config.radius
            color: !slot.isEmpty ? Config.surface3Color : Qt.alpha(Config.surface2Color, 0.65)

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
