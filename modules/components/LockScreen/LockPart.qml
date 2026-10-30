import QtQuick

Item {
    id: root

    required property LockTimeline line
    property int at: 0
    property int dur: 500
    property var curve: null
    property int outAt: 0
    property int outDur: 220
    property var outCurve: null

    property real dx: 0
    property real dy: 0
    property real fromScale: 1
    property real fromRotation: 0
    property real exitDx: root.dx
    property real exitDy: root.dy
    property real exitScale: root.fromScale
    property real exitRotation: root.fromRotation
    property real fade: 1

    readonly property real p: root.line.span(root.at, root.dur, root.curve, root.outAt, root.outDur, root.outCurve)
    readonly property bool _out: root.line.leaving
    readonly property real _s: (root._out ? root.exitScale : root.fromScale)

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    opacity: Math.max(0, Math.min(1, root.p * root.fade))

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root._s + (1 - root._s) * root.p
            yScale: root._s + (1 - root._s) * root.p
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            angle: (root._out ? root.exitRotation : root.fromRotation) * (1 - root.p)
        },
        Translate {
            x: (1 - root.p) * (root._out ? root.exitDx : root.dx)
            y: (1 - root.p) * (root._out ? root.exitDy : root.dy)
        }
    ]
}
