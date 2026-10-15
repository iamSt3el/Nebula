import QtQuick
import QtQuick.Shapes
import qs.modules.utils

Item {
    id: root

    property real strength: 1
    readonly property int bars: root.strength >= 0.75 ? 3 : root.strength >= 0.5 ? 2 : root.strength >= 0.25 ? 1 : 0
    property color color: Colors.surfaceText
    property real size: 22
    readonly property real u: root.size / 24
    readonly property color dim: Qt.alpha(root.color, 0.28)

    implicitWidth: root.size
    implicitHeight: Math.round(root.size * 20 / 24)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            PathAngleArc {
                centerX: 12 * root.u
                centerY: 17.6 * root.u
                radiusX: 1.9 * root.u
                radiusY: 1.9 * root.u
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bars >= 1 ? root.color : root.dim
            strokeWidth: 2.6 * root.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 12 * root.u
                centerY: 19 * root.u
                radiusX: 7 * root.u
                radiusY: 7 * root.u
                startAngle: -135
                sweepAngle: 90
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bars >= 2 ? root.color : root.dim
            strokeWidth: 2.6 * root.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 12 * root.u
                centerY: 19 * root.u
                radiusX: 11 * root.u
                radiusY: 11 * root.u
                startAngle: -135
                sweepAngle: 90
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bars >= 3 ? root.color : root.dim
            strokeWidth: 2.6 * root.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 12 * root.u
                centerY: 19 * root.u
                radiusX: 15 * root.u
                radiusY: 15 * root.u
                startAngle: -135
                sweepAngle: 90
            }
        }
    }
}
