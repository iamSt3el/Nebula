import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.settings

Item {
    id: root

    property string hours: "00"
    property string minutes: "00"
    property int px: 300
    property color ink: Colors.surfaceText
    property color accent: Colors.primary
    property string family: SettingsConfig.general.displayFont ?? "Titan One"
    property bool animated: false
    property bool handoff: false
    property real reveal: 1
    property bool exiting: false
    property int enterDelay: 0

    readonly property real tuck: 5
    readonly property real colTuck: 12
    readonly property real k: root.px / 100
    readonly property real pad: Math.ceil(0.06 * root.px)

    property real spread: 0
    property real loose: 0
    property bool solid: true
    property bool cutStarted: false
    readonly property var curveSpring: [0.34, 1.3, 0.64, 1, 1, 1]
    readonly property var curveOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveStd: [0.2, 0, 0, 1, 1, 1]

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: 100
    }

    readonly property var liveDigits: (root.hours + root.minutes).split("")
    property var digits: root.liveDigits
    readonly property rect zero: { fm.font; return fm.tightBoundingRect("0") }
    readonly property real capH: root.zero.height
    readonly property var boxes: { fm.font; return root.digits.map(c => fm.tightBoundingRect(c)) }
    readonly property real cell: {
        fm.font
        let m = 0
        for (const d of "0123456789")
            m = Math.max(m, fm.tightBoundingRect(d).width)
        return m
    }
    readonly property real inkW: (2 * root.cell - root.colTuck) * root.k
    readonly property real inkH: (2 * root.capH - root.tuck) * root.k

    implicitWidth: Math.ceil(root.inkW + 2 * root.pad)
    implicitHeight: Math.ceil(root.inkH + 2 * root.pad)

    function glyphX(i) {
        const b = root.boxes[i]
        const ink = (i % 2 === 0 ? 0 : root.cell - root.colTuck) + (root.cell - b.width) / 2
        return root.pad + (ink - b.x) * root.k
    }

    function baseOf(i) {
        return root.pad + root.capH * root.k + (i < 2 ? 0 : (root.capH - root.tuck) * root.k)
    }

    function rowRect(i) {
        const a = root.boxes[i]
        const b = root.boxes[i + 1]
        if (!a || !b)
            return Qt.rect(0, 0, 0, 0)
        const left = root.glyphX(i) + a.x * root.k
        const right = root.glyphX(i + 1) + (b.x + b.width) * root.k
        return Qt.rect(left, root.baseOf(i) + root.zero.y * root.k, right - left, root.zero.height * root.k)
    }

    function startCut() {
        if (root.cutStarted)
            return
        root.cutStarted = true
        root.solid = true
        root.spread = 0
        cutIn.restart()
    }

    onLiveDigitsChanged: {
        if (!root.animated || root.exiting || !root.visible) {
            root.digits = root.liveDigits
            return
        }
        enterAnim.stop()
        pulse.restart()
    }

    onRevealChanged: if (root.animated && root.handoff && root.reveal > 0.6) root.startCut()

    onExitingChanged: {
        if (!root.exiting || !root.animated)
            return
        enterAnim.stop()
        pulse.stop()
        cutIn.stop()
        root.spread = 0
        root.solid = true
        root.digits = root.liveDigits
        cutOut.restart()
    }

    Component.onCompleted: {
        root.digits = root.liveDigits
        if (!root.animated)
            return
        if (root.handoff) {
            root.loose = 1
            if (root.reveal > 0.6)
                root.startCut()
            return
        }
        root.cutStarted = true
        enterAnim.start()
    }

    SequentialAnimation {
        id: enterAnim
        PropertyAction { target: root; property: "solid"; value: false }
        PropertyAction { target: root; property: "loose"; value: 1 }
        PropertyAction { target: root; property: "spread"; value: 1 }
        PauseAnimation { duration: root.enterDelay }
        NumberAnimation { target: root; property: "spread"; to: 0; duration: 680; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveSpring }
        PropertyAction { target: root; property: "solid"; value: true }
        NumberAnimation { target: root; property: "loose"; to: 0; duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveStd }
    }

    SequentialAnimation {
        id: pulse
        NumberAnimation { target: root; property: "loose"; to: 1; duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveStd }
        PropertyAction { target: root; property: "solid"; value: false }
        NumberAnimation { target: root; property: "spread"; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveOut }
        ScriptAction { script: root.digits = root.liveDigits }
        NumberAnimation { target: root; property: "spread"; to: 0; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveSpring }
        PropertyAction { target: root; property: "solid"; value: true }
        NumberAnimation { target: root; property: "loose"; to: 0; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveStd }
    }

    NumberAnimation {
        id: cutIn
        target: root
        property: "loose"
        to: 0
        duration: 460
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curveStd
    }

    NumberAnimation {
        id: cutOut
        target: root
        property: "loose"
        to: 1
        duration: 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curveStd
    }

    CutText {
        visible: root.solid
        width: root.implicitWidth
        height: root.implicitHeight
        family: root.family
        px: root.px
        ring: Math.max(2, 0.04 * root.px)
        round: 0
        glyphs: root.boxes.length === 4 ? [0, 1, 2, 3].map(i => ({
            ch: root.digits[i],
            x: root.glyphX(i),
            y: root.baseOf(i),
            color: i === 0 || i === 3 ? root.ink : root.accent
        })) : []
    }

    Item {
        id: looseLayer
        width: root.implicitWidth
        height: root.implicitHeight
        visible: root.loose > 0.001
        opacity: root.loose
        layer.enabled: root.loose > 0.001 && root.loose < 0.999

        Repeater {
            model: root.boxes.length === 4 ? 4 : 0

            Text {
                required property int index
                x: Math.round(root.glyphX(index) + (index % 2 ? 1 : -1) * 0.07 * root.px * root.spread)
                y: Math.round(root.baseOf(index) + (index < 2 ? -1 : 1) * 0.04 * root.px * root.spread - baselineOffset)
                text: root.digits[index] ?? ""
                color: index === 0 || index === 3 ? root.ink : root.accent
                font.family: root.family
                font.pixelSize: root.px
                font.hintingPreference: Font.PreferNoHinting
                font.kerning: false
                renderType: Text.NativeRendering
            }
        }
    }
}
