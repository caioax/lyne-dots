pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.config

// History graph. Newest sample sits on the right edge, older samples scroll left.
// Pass values2 to draw a second series on the same scale.
Item {
    id: root

    property var values: []
    property var values2: []
    property int capacity: 60
    // Fixed ceiling (e.g. 100 for percentages); 0 = auto-scale to the data
    property real maxValue: 100
    property real minAutoMax: 1
    property color color: Config.accentColor
    property color color2: Config.successColor
    property real lineWidth: 1.5

    readonly property real _max: {
        if (maxValue > 0)
            return maxValue;
        let m = minAutoMax;
        for (const v of values)
            m = Math.max(m, v);
        for (const v of values2)
            m = Math.max(m, v);
        return m * 1.15; // headroom so peaks don't touch the top
    }

    // Smooth auto-scale changes instead of jumping
    property real _scale: _max
    Behavior on _scale {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutCubic
        }
    }

    function _points(series) {
        const pts = [];
        const n = series.length;
        if (n < 2 || width <= 0)
            return pts;
        const step = width / (capacity - 1);
        const x0 = width - (n - 1) * step;
        const h = height - lineWidth;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, series[i] / _scale));
            pts.push(Qt.point(x0 + i * step, lineWidth / 2 + h * (1 - v)));
        }
        return pts;
    }

    function _area(pts) {
        if (pts.length < 2)
            return [];
        return pts.concat([Qt.point(pts[pts.length - 1].x, height), Qt.point(pts[0].x, height)]);
    }

    // Faint horizontal guides (e.g. 3 = lines at 25/50/75%)
    property int gridLines: 0

    readonly property var _line1: _points(values)
    readonly property var _line2: _points(values2)

    Repeater {
        model: root.gridLines

        Rectangle {
            required property int index
            y: Math.round(root.height * (index + 1) / (root.gridLines + 1))
            width: root.width
            height: 1
            color: Qt.alpha(Config.surface2Color, 0.35)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Series 2 is drawn first so series 1 stays on top
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.alpha(root.color2, 0.25)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(root.color2, 0)
                }
            }
            PathPolyline {
                path: root._area(root._line2)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color2
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: root._line2
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.alpha(root.color, 0.3)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(root.color, 0)
                }
            }
            PathPolyline {
                path: root._area(root._line1)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: root._line1
            }
        }
    }
}
