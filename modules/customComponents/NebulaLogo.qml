import QtQuick
import QtQuick.Shapes
import qs.modules.utils

Item {
    id: root

    property color color: Colors.surfaceText
    property bool tonal: false
    property color outerColor: root.tonal ? Colors.primaryContainerText : root.color
    property color middleColor: root.tonal ? Colors.primary : root.color
    property color innerColor: root.tonal ? Colors.secondary : root.color
    property color coreColor: root.tonal ? Colors.tertiary : root.color
    property real progress: 1
    readonly property bool playing: ignite.running
    readonly property real small: root.clamp((48 - Math.min(root.width, root.height)) / 32)

    implicitWidth: 48
    implicitHeight: 48

    function play() {
        ignite.restart()
    }

    NumberAnimation {
        id: ignite
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 1800
    }

    readonly property var arms: [
        { r: 40, a0: -110, w0: 3, w1: 10 },
        { r: 27.5, a0: 10, w0: 3, w1: 9 },
        { r: 15, a0: 130, w0: 2.6, w1: 7.5 }
    ]

    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    function seg(p, a, b) { return root.clamp((p - a) / (b - a)) }
    function lerp(a, b, t) { return a + (b - a) * t }

    function bezier(x1, y1, x2, y2, x) {
        if (x <= 0) return 0
        if (x >= 1) return 1
        const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
        const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        let t = x
        for (let i = 0; i < 10; i++) {
            const d = (3 * ax * t + 2 * bx) * t + cx
            if (Math.abs(d) < 1e-7) break
            t -= (((ax * t + bx) * t + cx) * t - x) / d
        }
        t = root.clamp(t)
        return ((ay * t + by) * t + cy) * t
    }
    function decel(x) { return root.bezier(0.05, 0.7, 0.1, 1, x) }
    function soft(x) { return root.bezier(0.4, 0, 0.2, 1, x) }
    function std(x) { return root.bezier(0.2, 0, 0, 1, x) }

    function armState(i) {
        const p = root.progress
        const a = 0.12 + 0.08 * (2 - i)
        const e = root.decel(root.seg(p, a, a + 0.5))
        return {
            k: e,
            rot: -42 * (1 - e),
            ws: root.lerp(0.55, 1, root.decel(root.seg(p, a, a + 0.3))),
            op: root.soft(root.seg(p, a, a + 0.07))
        }
    }

    function armPath(i) {
        const base = root.arms[i]
        const arm = { r: base.r, a0: base.a0, w0: root.lerp(base.w0, 5.5, root.small), w1: base.w1 * (1 + 0.1 * root.small) }
        const st = root.armState(i)
        const k = st.k
        if (k < 0.002) return ""
        const n = 96
        const start = arm.a0 + st.rot
        const A = [], B = []
        for (let j = 0; j <= n; j++) {
            const u = j / n
            const rad = (start + 255 * k * u) * Math.PI / 180
            const w = root.lerp(arm.w0, arm.w1, k * u) * st.ws / 2
            const c = Math.cos(rad), s = Math.sin(rad)
            A.push((50 + (arm.r - w) * c).toFixed(2) + " " + (50 + (arm.r - w) * s).toFixed(2))
            B.push((50 + (arm.r + w) * c).toFixed(2) + " " + (50 + (arm.r + w) * s).toFixed(2))
        }
        const w0 = (arm.w0 * st.ws / 2).toFixed(2)
        const w1 = (root.lerp(arm.w0, arm.w1, k) * st.ws / 2).toFixed(2)
        let d = "M" + A[0]
        for (let j = 1; j <= n; j++) d += "L" + A[j]
        d += "A" + w1 + " " + w1 + " 0 0 0 " + B[n]
        for (let j = n - 1; j >= 0; j--) d += "L" + B[j]
        d += "A" + w0 + " " + w0 + " 0 0 0 " + A[0] + "Z"
        return d
    }

    readonly property real coreT: root.decel(root.seg(root.progress, 0, 0.3))
    readonly property real coreR: 6.4 * (1 + 0.2 * root.small) * root.lerp(0.2, 1, root.coreT)
    readonly property real coreOpacity: root.soft(root.seg(root.progress, 0, 0.14))
    readonly property real glowT: root.seg(root.progress, 0.06, 0.5)
    readonly property real glowR: root.lerp(6, 22, root.decel(root.glowT))
    readonly property real glowOpacity: root.glowT > 0 && root.glowT < 1 ? 0.28 * (1 - root.std(root.glowT)) : 0

    Item {
        width: 100
        height: 100
        scale: Math.min(root.width, root.height) / 100
        transformOrigin: Item.TopLeft
        x: (root.width - Math.min(root.width, root.height)) / 2
        y: (root.height - Math.min(root.width, root.height)) / 2

        Shape {
            anchors.fill: parent
            visible: root.glowOpacity > 0
            opacity: root.glowOpacity
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.middleColor
                PathAngleArc { centerX: 50; centerY: 50; radiusX: root.glowR; radiusY: root.glowR; startAngle: 0; sweepAngle: 360 }
            }
        }

        Item {
            anchors.fill: parent
            rotation: -28 * (1 - root.decel(root.progress))
            scale: root.lerp(0.94, 1, root.decel(root.seg(root.progress, 0, 0.85)))

            Repeater {
                model: 3

                Shape {
                    id: arm
                    required property int index
                    readonly property color tone: [root.outerColor, root.middleColor, root.innerColor][arm.index]
                    anchors.fill: parent
                    opacity: root.armState(arm.index).op
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: arm.tone
                        PathSvg { path: root.armPath(arm.index) }
                    }
                }
            }

            Shape {
                anchors.fill: parent
                opacity: root.coreOpacity
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.coreColor
                    PathAngleArc { centerX: 50; centerY: 50; radiusX: root.coreR; radiusY: root.coreR; startAngle: 0; sweepAngle: 360 }
                }
            }
        }
    }
}
