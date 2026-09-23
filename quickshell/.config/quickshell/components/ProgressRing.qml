pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.config

// Circular (or partial arc) progress indicator.
// value is 0-100. Angles in degrees, 0 = 3 o'clock, clockwise.
Item {
    id: root

    property real value: 0
    property real startAngle: -90
    property real sweepAngle: 360
    property real strokeWidth: 6
    property color color: Config.accentColor
    property color trackColor: Config.surface2Color

    property real animatedValue: Math.max(0, Math.min(100, value))
    Behavior on animatedValue {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    readonly property real _radius: (Math.min(width, height) - strokeWidth) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._radius
                radiusY: root._radius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.animatedValue > 0 ? root.color : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._radius
                radiusY: root._radius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle * root.animatedValue / 100
            }
        }
    }
}
