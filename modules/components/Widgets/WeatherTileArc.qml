import QtQuick
import QtQuick.Shapes
import qs.modules.utils

Shape {
    id: root

    property real radius: 10
    property real startAngle: 0
    property real sweep: 360
    property real progress: 0
    property real lineWidth: 4
    property real gapAngle: 16
    property color activeColor: Colors.primary
    property color trackColor: Colors.surfaceContainerHighest

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real frac: Math.max(0, Math.min(1, root.progress))
    readonly property real activeSweep: root.sweep * root.frac
    readonly property real trackStart: root.frac > 0.005 ? root.activeSweep + root.gapAngle : 0
    readonly property real trackSweep: Math.max(0, root.sweep - root.trackStart - (root.sweep >= 360 && root.frac > 0.005 ? root.gapAngle : 0))

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.trackSweep > 0.5 ? root.trackColor : "transparent"
        strokeWidth: root.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: root.cx
            centerY: root.cy
            radiusX: root.radius
            radiusY: root.radius
            startAngle: root.startAngle - 90 + root.trackStart
            sweepAngle: root.trackSweep
        }
    }

    ShapePath {
        strokeColor: root.frac > 0.005 ? root.activeColor : "transparent"
        strokeWidth: root.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: root.cx
            centerY: root.cy
            radiusX: root.radius
            radiusY: root.radius
            startAngle: root.startAngle - 90
            sweepAngle: Math.max(0.01, root.activeSweep)
        }
    }
}
