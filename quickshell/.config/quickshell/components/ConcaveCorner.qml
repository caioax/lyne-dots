import QtQuick
import QtQuick.Shapes

// Square filled everywhere except a quarter circle: placed under a docked bar
// it makes the bar flow into the screen edge. By default it fills the top-left
// corner; `mirrored` flips it for the right side. Hide it with size 0, not
// `visible`: a Shape created hidden isn't drawn when shown later
Shape {
    id: root

    property real size
    property color color
    property bool mirrored: false

    // Explicit: Shape would size itself to the path's bounding box
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
        origin.x: root.width / 2
        xScale: root.mirrored ? -1 : 1
    }

    ShapePath {
        fillColor: root.color
        strokeWidth: -1

        startX: 0
        startY: 0

        PathLine {
            x: root.size
            y: 0
        }

        PathArc {
            x: 0
            y: root.size
            radiusX: root.size
            radiusY: root.size
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: 0
            y: 0
        }
    }
}
