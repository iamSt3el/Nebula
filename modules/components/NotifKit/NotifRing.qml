import QtQuick
import QtQuick.Shapes
import qs.modules.utils

Shape {
    id: ring

    property real remaining: 1
    property color ink: Colors.surfaceText
    property color accent: Colors.primary
    property real stroke: 2.5
    readonly property real r: Math.max(1, Math.min(ring.width, ring.height) / 2 - ring.stroke / 2 - 0.5)

    implicitWidth: 24
    implicitHeight: 24
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: Qt.alpha(ring.ink, 0.14)
        strokeWidth: ring.stroke
        fillColor: "transparent"
        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
    }

    ShapePath {
        strokeColor: ring.accent
        strokeWidth: ring.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: 360 * ring.remaining }
    }
}
