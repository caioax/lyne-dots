pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.config

// The lyne-dots logo, drawn as native vector paths so it stays sharp at any
// size and follows the theme. Same geometry as .data/assets/logo/lyne-dots-tight.svg.
// Size it by height: the width follows the drawing's aspect ratio.
// For a single-color logo, set lineColor and dotColor to the same color
Item {
    id: root

    // The brand pair (#5F8DCB line, #5598F6 dot) is one blue in two tones: the
    // dot saturated, the line a softer shade of the same hue. Deriving the line
    // from the dot keeps that relation on every theme
    property color dotColor: Config.accentColor
    property color lineColor: Qt.hsla(Math.max(0, dotColor.hslHue), dotColor.hslSaturation * 0.57, dotColor.hslLightness * 0.9, dotColor.a)

    // Size of the drawing in SVG units (the tight viewBox)
    readonly property size viewBox: Qt.size(392, 280.24)

    implicitHeight: Config.fontSizeIcon
    implicitWidth: height * viewBox.width / viewBox.height

    Behavior on dotColor {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    Behavior on lineColor {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    Shape {
        width: root.viewBox.width
        height: root.viewBox.height
        // Fits the drawing into the item, keeping the aspect ratio, centered
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lineColor
            strokeWidth: 51.34
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M204.81 208.97 L170.82 235.53 A89.84 89.84 0 0 1 115.51 254.57 A89.84 89.84 0 0 1 25.67 164.73 L25.67 115.51 A89.84 89.84 0 0 1 115.51 25.67 A89.84 89.84 0 0 1 186.3 60.2 L328.72 242.49 A31.44 31.44 0 0 0 353.5 254.57 L366.33 254.57"
            }
        }

        ShapePath {
            fillColor: root.dotColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathAngleArc {
                centerX: 343.87
                centerY: 100.32
                radiusX: 48.13
                radiusY: 48.13
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
