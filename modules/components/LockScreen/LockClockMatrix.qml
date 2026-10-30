import QtQuick
import qs.modules.utils

Item {
    id: root

    property bool awake: false

    readonly property int hour: LockSession.hour24 % 12 === 0 ? 12 : LockSession.hour24 % 12
    readonly property vector4d current: Qt.vector4d(Math.floor(root.hour / 10), root.hour % 10, parseInt(LockSession.minute.charAt(0)), parseInt(LockSession.minute.charAt(1)))

    property vector4d shownNew: Qt.vector4d(-1, -1, -1, -1)
    property vector4d shownOld: Qt.vector4d(-1, -1, -1, -1)
    property real progress: 1
    property real colonOn: 1
    property real hide: root.awake ? 1 : 0

    Behavior on hide {
        NumberAnimation {
            duration: root.awake ? 520 : 700
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.awake ? [0.3, 0.0, 0.8, 0.15, 1, 1] : [0.05, 0.7, 0.1, 1.0, 1, 1]
        }
    }

    Behavior on colonOn {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    function roll() {
        root.shownOld = root.shownNew
        root.shownNew = root.current
        wave.restart()
    }

    onCurrentChanged: root.roll()
    Component.onCompleted: root.roll()

    NumberAnimation {
        id: wave
        target: root; property: "progress"; from: 0; to: 1
        duration: 1500
    }

    Timer {
        interval: 1000
        repeat: true
        running: !root.awake
        onTriggered: root.colonOn = root.colonOn > 0.5 ? 0 : 1
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.hide < 0.999

        property size itemSize: Qt.size(width, height)
        property point grid: Qt.point(52, Math.max(21, Math.round(52 * height / Math.max(1, width))))
        property vector4d digitsNew: root.shownNew
        property vector4d digitsOld: root.shownOld
        property real progress: root.progress
        property real colon: root.colonOn
        property real hide: root.hide
        property color hourColor: Colors.surfaceText
        property color minuteColor: Colors.primary
        property color colonColor: Colors.tertiary
        property color dimColor: Qt.alpha(Colors.surfaceText, 0.14)

        fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/lockmatrix.frag.qsb")
    }
}
