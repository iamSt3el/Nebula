import QtQuick
import QtQuick.Effects
import qs.modules.utils

Item {
    id: root

    property bool awake: false
    property real p: 0

    readonly property string time: LockSession.hour + ":" + LockSession.minute
    readonly property rect box: { fm.font; return fm.tightBoundingRect(root.time) }
    readonly property real s: root.box.width > 0 ? Math.min(root.width * 0.9625 / root.box.width, root.height * 0.944 / root.box.height) : 1
    readonly property real originX: (root.width - root.box.width * root.s) / 2 - root.box.x * root.s
    readonly property real baseY: (root.height - root.box.height * root.s) / 2 - root.box.y * root.s
    readonly property rect zeroBox: { fm.font; return fm.tightBoundingRect("0") }
    readonly property rect colonBox: { fm.font; return fm.tightBoundingRect(":") }
    readonly property real colonShift: ((root.zeroBox.y + root.zeroBox.height / 2) - (root.colonBox.y + root.colonBox.height / 2)) * root.s
    readonly property real hourW: { fm.font; return fm.advanceWidth(LockSession.hour) * root.s }
    readonly property real colonW: { fm.font; return fm.advanceWidth(":") * root.s }

    FontMetrics {
        id: fm
        font.family: "Rubik"
        font.pixelSize: 100
        font.weight: 900
    }

    component Part: Text {
        y: Math.round(root.baseY - fm.ascent * root.s)
        color: "white"
        font.family: "Rubik"
        font.pixelSize: Math.round(100 * root.s)
        font.weight: 900
        renderType: Text.NativeRendering
    }

    states: State {
        name: "awake"
        when: root.awake
        PropertyChanges { root.p: 0 }
    }

    transitions: [
        Transition {
            to: "awake"
            NumberAnimation { target: root; property: "p"; duration: 620; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1, 1] }
        },
        Transition {
            to: ""
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation { target: root; property: "p"; duration: 820; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1] }
            }
        }
    ]

    Component.onCompleted: if (!root.awake) appear.start()
    onAwakeChanged: if (root.awake) appear.stop()

    NumberAnimation {
        id: appear
        target: root; property: "p"; from: 0; to: 1
        duration: 900
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
    }

    Item {
        anchors.fill: parent
        visible: root.p > 0.001
        opacity: Math.min(1, root.p * 1.6)
        scale: 1 + 2.6 * (1 - root.p)

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: Qt.rgba(0.02, 0.01, 0.01, 0.7)
            shadowBlur: 0.45
            shadowVerticalOffset: 4
        }

        Rectangle {
            id: slab
            anchors.fill: parent
            color: Colors.primaryContainer
            visible: false
            layer.enabled: true
        }

        Item {
            id: cut
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Part {
                x: Math.round(root.originX)
                text: LockSession.hour
            }
            Part {
                x: Math.round(root.originX + root.hourW)
                y: Math.round(root.baseY - fm.ascent * root.s + root.colonShift)
                text: ":"
            }
            Part {
                x: Math.round(root.originX + root.hourW + root.colonW)
                text: LockSession.minute
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: slab
            maskEnabled: true
            maskSource: cut
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }
}
