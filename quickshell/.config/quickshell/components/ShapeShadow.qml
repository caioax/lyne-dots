import QtQuick
import QtQuick.Effects
import qs.config

// Shadow of any shape (Config.shadow*): the children, drawn opaque in
// `shapeColor`, are its silhouette, blurred and shifted down. For panels that
// aren't one rounded rectangle, like the attached ones flowing into the bar
// through their fillets; PanelShadow is cheaper for the rest. Declare it
// before the panel so it draws under it. The children are placed in the
// item's own coordinates and may reach `reach` past its edges
Item {
    id: root

    default property alias shape: canvas.data
    // How far the silhouette may go past the item's edges
    property real reach: Config.shadowPad + Config.radiusLarge * 2
    readonly property color shapeColor: Qt.alpha(Config.shadowColor, 1)

    visible: Config.shadowEnabled

    Item {
        id: silhouette

        x: -root.reach
        y: -root.reach + Config.shadowOffset
        width: root.width + root.reach * 2
        height: root.height + root.reach * 2
        opacity: Config.shadowColor.a
        layer.enabled: root.visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Math.round(Config.shadowBlur)
        }

        Item {
            id: canvas

            x: root.reach
            y: root.reach
            width: root.width
            height: root.height
        }
    }
}
