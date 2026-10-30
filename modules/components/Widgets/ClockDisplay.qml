import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(5))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false
    resizable: true
    minSpan: Qt.size(2, 3)
    maxSpan: Qt.size(7, 9)

    readonly property string family: SettingsConfig.general.displayFont ?? "Titan One"

    ClockParts { id: t }

    optionsComponent: Component {
        ClockOptions {}
    }

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: 100
    }

    readonly property var liveDigits: (t.hourPad + t.minute).split("")
    property var digits: root.liveDigits
    property real spread: 0
    property real loose: 0
    property bool solid: true
    readonly property rect zero: { fm.font; return fm.tightBoundingRect("0") }
    readonly property var boxes: { fm.font; return root.digits.map(c => fm.tightBoundingRect(c)) }
    readonly property real tuck: 5
    readonly property real colTuck: 12
    readonly property real rowGap: -root.tuck
    readonly property real capH: root.zero.height
    readonly property real cell: {
        fm.font
        let m = 0
        for (const d of "0123456789")
            m = Math.max(m, fm.tightBoundingRect(d).width)
        return m
    }
    readonly property real inkW: 2 * root.cell - root.colTuck
    readonly property real inkH: 2 * root.capH + root.rowGap

    readonly property real dateH: t.showDate ? Math.round(Math.max(14, root.height * 0.055)) : 0
    readonly property real margin: Math.round(Math.min(root.width, root.height) * 0.04)
    readonly property real k: Math.max(0.05, Math.min((root.width - 2 * root.margin) / root.inkW,
                                                        (root.height - 2 * root.margin - (t.showDate ? root.dateH * 2.2 : 0)) / root.inkH))
    readonly property int px: Math.round(100 * root.k)
    readonly property real blockW: root.inkW * root.k
    readonly property real blockH: root.inkH * root.k + (t.showDate ? root.dateH * 2.2 : 0)
    readonly property real originX: (root.width - root.blockW) / 2
    readonly property real originY: (root.height - root.blockH) / 2
    readonly property real ring: Math.max(2, 0.04 * root.px)

    function glyphX(i) {
        const w = root.boxes[i].width
        const ink = (i % 2 === 0 ? 0 : root.cell - root.colTuck) + (root.cell - w) / 2
        return root.originX + (ink - root.boxes[i].x) * root.k
    }

    function baseOf(i) {
        return root.originY + root.capH * root.k + (i < 2 ? 0 : (root.capH + root.rowGap) * root.k)
    }

    function glyph(i) {
        return {
            ch: root.digits[i],
            x: root.glyphX(i),
            y: root.baseOf(i),
            color: i === 0 || i === 3 ? t.ink : t.accent
        }
    }

    function rowRect(i) {
        const a = root.boxes[i]
        const b = root.boxes[i + 1]
        const left = root.glyphX(i) + a.x * root.k
        const right = root.glyphX(i + 1) + (b.x + b.width) * root.k
        return Qt.rect(left, root.baseOf(i) + root.zero.y * root.k, right - left, root.zero.height * root.k)
    }

    readonly property var handoffParts: {
        const parts = [
            { role: "hours", rect: root.rowRect(0), face: hoursFace },
            { role: "minutes", rect: root.rowRect(2), face: minutesFace }
        ]
        if (t.showDate)
            parts.push({ role: "date", rect: Qt.rect(dateLine.x, dateLine.y, dateLine.width, dateLine.height), face: dateFace })
        return parts
    }

    component RowCut: CutText {
        property var indices: []
        visible: root.solid
        width: Math.ceil(root.width)
        height: Math.ceil(root.height)
        family: root.family
        px: root.px
        ring: root.ring
        round: 0
        glyphs: indices.map(i => root.glyph(i))
    }

    component Loose: Item {
        id: looseLayer
        property var indices: []
        width: Math.ceil(root.width)
        height: Math.ceil(root.height)
        visible: root.loose > 0.001
        opacity: root.loose
        layer.enabled: root.loose > 0.001 && root.loose < 0.999

        Repeater {
            model: looseLayer.indices

            Text {
                required property int modelData
                x: Math.round(root.glyphX(modelData) + (modelData % 2 ? 1 : -1) * 0.07 * root.px * root.spread)
                y: Math.round(root.baseOf(modelData) + (modelData < 2 ? -1 : 1) * 0.04 * root.px * root.spread - baselineOffset)
                text: root.digits[modelData] ?? ""
                color: modelData === 0 || modelData === 3 ? t.ink : t.accent
                font.family: root.family
                font.pixelSize: root.px
                font.hintingPreference: Font.PreferNoHinting
                font.kerning: false
                renderType: Text.NativeRendering
            }
        }
    }

    readonly property var curveSpring: [0.34, 1.3, 0.64, 1, 1, 1]
    readonly property var curveOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveStd: [0.2, 0, 0, 1, 1, 1]

    onLiveDigitsChanged: {
        if (root.preview || GlobalStates.sessionLocked || !root.visible) {
            root.digits = root.liveDigits
            return
        }
        enterAnim.stop()
        pulse.restart()
    }

    function settle() {
        enterAnim.stop()
        pulse.stop()
        root.spread = 0
        root.solid = true
        root.digits = root.liveDigits
    }

    Connections {
        target: GlobalStates
        enabled: !root.preview
        function onSessionLockedChanged() {
            root.settle()
            if (GlobalStates.sessionLocked) {
                cutIn.stop()
                cutOut.restart()
            } else {
                cutOut.stop()
                cutIn.restart()
            }
        }
    }

    QtObject {
        Component.onCompleted: {
            root.digits = root.liveDigits
            if (!root.preview && !GlobalStates.sessionLocked)
                enterAnim.start()
        }
    }

    SequentialAnimation {
        id: enterAnim
        PropertyAction { target: root; property: "solid"; value: false }
        PropertyAction { target: root; property: "loose"; value: 1 }
        PropertyAction { target: root; property: "spread"; value: 1 }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: root; property: "spread"; to: 0; duration: 620; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveSpring }
        PropertyAction { target: root; property: "solid"; value: true }
        NumberAnimation { target: root; property: "loose"; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveStd }
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
        id: cutOut
        target: root
        property: "loose"
        to: 1
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curveStd
    }

    SequentialAnimation {
        id: cutIn
        PauseAnimation { duration: 160 }
        NumberAnimation { target: root; property: "loose"; to: 0; duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveStd }
    }

    component DateLine: Text {
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.originY + root.inkH * root.k + root.dateH * 0.7)
        text: (t.weekday + "  " + t.day + " " + t.month).toUpperCase()
        color: t.ink
        font.family: "Rubik"
        font.pixelSize: root.dateH
        font.weight: 600
        font.letterSpacing: root.dateH * 0.18
        renderType: Text.NativeRendering
    }

    component Face: ClockLift {
        width: root.width
        height: root.height
    }

    Component {
        id: hoursFace
        Face {
            RowCut { indices: [0, 1] }
            Loose { indices: [0, 1] }
        }
    }

    Component {
        id: minutesFace
        Face {
            RowCut { indices: [2, 3] }
            Loose { indices: [2, 3] }
        }
    }

    Component {
        id: dateFace
        Face { DateLine {} }
    }

    MotionEnter {
        anchors.fill: parent
        dy: 30
        fromScale: 0.96
        animated: !root.preview

        ClockLift {
            anchors.fill: parent

            RowCut {
                indices: [0, 1, 2, 3]
            }

            Loose {
                indices: [0, 1, 2, 3]
            }

            DateLine {
                id: dateLine
                visible: t.showDate
            }
        }
    }
}
