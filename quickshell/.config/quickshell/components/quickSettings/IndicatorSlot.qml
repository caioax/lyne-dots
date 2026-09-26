pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Holds one indicator in a style's row and grows it in or out when it
// appears or goes away. The row itself has no spacing: each slot but the
// first shown one carries the gap before it, so the gaps animate too.
Item {
    id: root

    required property QsIndicatorsModel model
    required property string indicatorId
    // Gap before the item when another shown indicator precedes it
    property int gap: Config.spacing

    default property alias content: holder.data

    readonly property bool shown: model.indicators[indicatorId]?.shown ?? false
    property int lead: model.shownIds.indexOf(indicatorId) > 0 ? gap : 0

    implicitWidth: shown ? holder.childrenRect.width + lead : 0
    implicitHeight: holder.childrenRect.height
    Layout.alignment: Qt.AlignVCenter
    visible: shown || widthAnim.running
    // Only while resizing: the bell's badge sits outside the glyph
    clip: widthAnim.running

    Behavior on implicitWidth {
        NumberAnimation {
            id: widthAnim
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on lead {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: holder

        x: root.lead
        y: Math.round((root.height - childrenRect.height) / 2)
        width: childrenRect.width
        height: childrenRect.height
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.6

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
            }
        }
    }
}
