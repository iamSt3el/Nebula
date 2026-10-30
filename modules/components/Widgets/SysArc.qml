import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.customComponents

Shape {
    id: arc

    property real value: 0
    property real cx: width / 2
    property real cy: height / 2
    property real radius: Math.min(width, height) / 2 - thickness
    property real from: -Math.PI / 2
    property real span: Math.PI * 2
    property real gap: 0.16
    property real thickness: 8
    property real trackThickness: thickness
    property real wave: 0
    property real waves: 20
    property color color: Colors.primary
    property color trackColor: Colors.surfaceContainerHighest

    property real shown: Math.max(0, Math.min(1, arc.value))
    Behavior on shown { SpatialAnim {} }

    readonly property bool closed: arc.span >= Math.PI * 2 - 0.01
    readonly property real end: arc.from + arc.span * arc.shown
    readonly property bool hasValue: arc.shown > 0.004

    function points(r0, a, b, amp) {
        if (b <= a)
            return [Qt.point(arc.cx + r0 * Math.cos(a), arc.cy + r0 * Math.sin(a))]
        const n = Math.max(8, Math.ceil((b - a) * r0 / 2))
        const out = []
        for (let i = 0; i <= n; i++) {
            const t = a + (b - a) * i / n
            const r = r0 + amp * Math.sin((t - arc.from) * arc.waves)
            out.push(Qt.point(arc.cx + r * Math.cos(t), arc.cy + r * Math.sin(t)))
        }
        return out
    }

    readonly property real trackFrom: arc.hasValue ? arc.end + arc.gap : arc.from
    readonly property real trackTo: arc.from + arc.span - (arc.closed && arc.hasValue ? arc.gap : 0)

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: arc.trackTo > arc.trackFrom ? arc.trackColor : "transparent"
        strokeWidth: arc.trackThickness
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: arc.points(arc.radius, arc.trackFrom, arc.trackTo, 0) }
    }

    ShapePath {
        strokeColor: arc.hasValue ? arc.color : "transparent"
        strokeWidth: arc.thickness
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: arc.points(arc.radius, arc.from, arc.end, arc.wave) }
    }
}
