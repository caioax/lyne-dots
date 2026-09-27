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

    // --- Motion hooks, for buttons that animate the logo ---
    // How far the dot rises, as a fraction of the logo height
    property real dotLift: 0
    // Dot size (1 = the drawing's)
    property real dotScale: 1
    // Squash & stretch: > 0 tall and thin, < 0 wide and flat. The dot keeps
    // its bottom in place, so it squashes against the ground
    property real dotStretch: 0
    // How much of the line is drawn, from its start (0–1)
    property real lineDraw: 1
    // Dot travelling along cometPath (0 and 1 = at home); a fading trail
    // follows it
    property real travel: 0
    // Riding back (travel decreasing): the trail goes on the other side
    property bool travelReverse: false

    readonly property real dotRadius: 48.13
    readonly property point dotHome: Qt.point(343.87, 100.32)
    readonly property string linePath: "M204.81 208.97 L170.82 235.53 A89.84 89.84 0 0 1 115.51 254.57 A89.84 89.84 0 0 1 25.67 164.73 L25.67 115.51 A89.84 89.84 0 0 1 115.51 25.67 A89.84 89.84 0 0 1 186.3 60.2 L328.72 242.49 A31.44 31.44 0 0 0 353.5 254.57 L366.33 254.57"
    // The line's first segment aims at the dot: the comet leaves home along
    // it, rides the whole line and jumps from the tail back home
    readonly property string cometPath: "M343.87 100.32 L204.81 208.97 L170.82 235.53 A89.84 89.84 0 0 1 115.51 254.57 A89.84 89.84 0 0 1 25.67 164.73 L25.67 115.51 A89.84 89.84 0 0 1 115.51 25.67 A89.84 89.84 0 0 1 186.3 60.2 L328.72 242.49 A31.44 31.44 0 0 0 353.5 254.57 L366.33 254.57 Q400 180 343.87 100.32"
    readonly property bool travelling: travel > 0 && travel < 1

    implicitHeight: Config.fontSizeIcon
    implicitWidth: height * viewBox.width / viewBox.height

    PathInterpolator {
        id: cometPos
        progress: root.travel
        path: Path {
            PathSvg {
                path: root.cometPath
            }
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
            trim.end: root.lineDraw

            PathSvg {
                path: root.linePath
            }
        }

        // Comet trail: two lengths, the shorter one stronger, so it fades
        // towards its end
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.travelling ? Qt.alpha(root.dotColor, 0.3) : Qt.alpha(root.dotColor, 0)
            strokeWidth: root.dotRadius * 1.2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            trim.start: root.travelReverse ? root.travel : Math.max(0, root.travel - 0.2)
            trim.end: root.travelReverse ? Math.min(1, root.travel + 0.2) : root.travel

            PathSvg {
                path: root.cometPath
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.travelling ? Qt.alpha(root.dotColor, 0.45) : Qt.alpha(root.dotColor, 0)
            strokeWidth: root.dotRadius * 1.5
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            trim.start: root.travelReverse ? root.travel : Math.max(0, root.travel - 0.08)
            trim.end: root.travelReverse ? Math.min(1, root.travel + 0.08) : root.travel

            PathSvg {
                path: root.cometPath
            }
        }

        ShapePath {
            id: dot

            readonly property real radius: root.dotRadius * root.dotScale
            readonly property real rx: radius * (1 - root.dotStretch * 0.6)
            readonly property real ry: radius * (1 + root.dotStretch)

            fillColor: root.dotColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathAngleArc {
                centerX: root.travelling ? cometPos.x : root.dotHome.x
                centerY: root.travelling ? cometPos.y : root.dotHome.y - root.dotLift * root.viewBox.height + dot.radius - dot.ry
                radiusX: dot.rx
                radiusY: dot.ry
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
