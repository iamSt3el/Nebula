import QtQuick
import Nebula

Item {
    id: root

    property color color: "#6750A4"
    property real size: 48
    property bool running: true

    readonly property var shapes: ["softBurst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]
    readonly property bool _live: root.running && root.visible

    property int _index: 0
    property real _morph: 0
    property real _turn: 90
    property real _spin: 0

    width: root.size
    height: root.size

    SequentialAnimation {
        loops: Animation.Infinite
        running: root._live

        NumberAnimation {
            target: root
            property: "_morph"
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
        PauseAnimation { duration: 150 }
        ScriptAction {
            script: {
                root._index = (root._index + 1) % root.shapes.length
                root._morph = 0
                root._turn = (root._turn + 90) % 360
            }
        }
    }

    NumberAnimation on _spin {
        from: 0
        to: 360
        duration: 4666
        loops: Animation.Infinite
        running: root._live
    }

    ShapePainter {
        anchors.centerIn: parent
        width: Math.round(root.size * 38 / 48)
        height: width
        fromShape: root.shapes[root._index]
        toShape: root.shapes[(root._index + 1) % root.shapes.length]
        progress: Math.min(1, root._morph)
        color: root.color
        rotation: root._morph * 90 + root._turn + root._spin
        antialiasing: true
    }
}
