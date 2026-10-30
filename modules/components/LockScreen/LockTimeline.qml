import QtQuick

Item {
    id: root

    property bool animated: true
    property bool exiting: false
    property int inMs: 1600
    property int outMs: 1000

    property real t: root.animated ? 0 : root.inMs
    property real o: 0
    property bool leaving: false

    readonly property var standard: [0.2, 0.0, 0.0, 1.0]
    readonly property var decel: [0.05, 0.7, 0.1, 1.0]
    readonly property var accel: [0.3, 0.0, 0.8, 0.15]
    readonly property var inOut: [0.4, 0.0, 0.2, 1.0]
    readonly property var spring: [0.38, 1.21, 0.22, 1.0]

    function bez(v, c) {
        if (v <= 0)
            return 0
        if (v >= 1)
            return 1
        let u = v
        for (let i = 0; i < 8; i++) {
            const x = 3 * (1 - u) * (1 - u) * u * c[0] + 3 * (1 - u) * u * u * c[2] + u * u * u - v
            const dx = 3 * (1 - u) * (1 - u) * c[0] + 6 * (1 - u) * u * (c[2] - c[0]) + 3 * u * u * (1 - c[2])
            if (Math.abs(x) < 1e-4 || dx === 0)
                break
            u = Math.max(0, Math.min(1, u - x / dx))
        }
        return 3 * (1 - u) * (1 - u) * u * c[1] + 3 * (1 - u) * u * u * c[3] + u * u * u
    }

    function seg(a, d, c) {
        return root.bez((root.t - a) / d, c ?? root.standard)
    }

    function out(a, d, c) {
        return root.bez((root.o - a) / d, c ?? root.accel)
    }

    function span(a, d, c, oa, od, oc) {
        const v = root.seg(a, d, c)
        return root.leaving ? Math.min(v, 1 - root.out(oa ?? 0, od ?? 240, oc)) : v
    }

    NumberAnimation {
        id: inAnim
        target: root
        property: "t"
        from: 0
        to: root.inMs
        duration: root.inMs
    }

    NumberAnimation {
        id: outAnim
        target: root
        property: "o"
        from: 0
        to: root.outMs
        duration: root.outMs
    }

    Component.onCompleted: if (root.animated) inAnim.start()

    onExitingChanged: {
        if (root.exiting) {
            inAnim.stop()
            root.leaving = true
            outAnim.restart()
        } else if (root.leaving) {
            outAnim.stop()
            root.leaving = false
            root.o = 0
            if (root.animated)
                inAnim.restart()
            else
                root.t = root.inMs
        }
    }
}
