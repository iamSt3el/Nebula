import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property bool awake: false
    property real p: 0

    readonly property string family: SettingsConfig.general.displayFont ?? "Titan One"
    readonly property int hour: LockSession.hour24 % 12 === 0 ? 12 : LockSession.hour24 % 12
    readonly property var digits: [String(Math.floor(root.hour / 10)), String(root.hour % 10), LockSession.minute.charAt(0), LockSession.minute.charAt(1)]

    readonly property real u: 100 / 30
    property real tuck: 2
    readonly property var xs: {
        fm.font
        const d = root.digits
        const sp = -3 * root.u
        const tuck = -root.tuck * root.u
        const cm = 5 * root.u
        const x = [0, 0, 0, 0, 0]
        x[1] = fm.advanceWidth(d[0]) + tuck
        x[4] = x[1] + fm.advanceWidth(d[1]) + sp + cm
        x[2] = x[4] + fm.advanceWidth(":") + cm + sp
        x[3] = x[2] + fm.advanceWidth(d[2]) + tuck
        return x
    }
    readonly property real total: { fm.font; return root.xs[3] + fm.advanceWidth(root.digits[3]) }
    readonly property real k: root.total > 0 ? root.width * 0.9375 / root.total : 1
    readonly property real px: Math.round(100 * root.k)
    readonly property real startX: (root.width - root.total * root.k) / 2
    readonly property real capH: { fm.font; return -fm.tightBoundingRect("0").y * root.k }
    readonly property real baseY: root.height / 2 + root.capH / 2
    readonly property real ascent: fm.ascent * root.k
    readonly property real descent: fm.descent * root.k
    readonly property real ring: 0.025 * root.px
    readonly property real pad: root.ring + 4
    readonly property rect zeroBox: { fm.font; return fm.tightBoundingRect("0") }
    readonly property rect colonBox: { fm.font; return fm.tightBoundingRect(":") }
    readonly property real colonShift: ((root.zeroBox.y + root.zeroBox.height / 2) - (root.colonBox.y + root.colonBox.height / 2)) * root.k

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: 100
    }

    states: State {
        name: "awake"
        when: root.awake
        PropertyChanges { root.p: 0 }
    }

    transitions: [
        Transition {
            to: "awake"
            NumberAnimation { target: root; property: "p"; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1, 1] }
        },
        Transition {
            to: ""
            SequentialAnimation {
                PauseAnimation { duration: 220 }
                NumberAnimation { target: root; property: "p"; duration: 760; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1] }
            }
        }
    ]

    Component.onCompleted: if (!root.awake) appear.start()

    SequentialAnimation {
        id: appear
        PauseAnimation { duration: 160 }
        NumberAnimation { target: root; property: "p"; from: 0; to: 1; duration: 820; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1] }
    }

    onAwakeChanged: if (root.awake) appear.stop()

    component Pair: CutGlyphs {
        id: pair

        property int first: 0
        property color tintA: Colors.surfaceText
        property color tintB: Colors.primary
        property real slide: 0

        readonly property real gap: (root.xs[pair.first + 1] - root.xs[pair.first]) * root.k
        readonly property real by: root.pad + root.ascent

        x: Math.round(root.startX + root.xs[pair.first] * root.k - root.pad)
        y: Math.round(root.baseY - root.ascent - root.pad)
        width: Math.ceil(pair.gap + fm.advanceWidth(root.digits[pair.first + 1]) * root.k + 2 * root.pad)
        height: Math.ceil(root.ascent + root.descent + 2 * root.pad)
        opacity: root.p
        transform: Translate { x: pair.slide * (1 - root.p) * root.width * 0.55 }

        family: root.family
        px: root.px
        ring: root.ring
        glyphs: [
            { ch: root.digits[pair.first], x: root.pad, y: pair.by, color: pair.tintA },
            { ch: root.digits[pair.first + 1], x: root.pad + pair.gap, y: pair.by, color: pair.tintB }
        ]
    }

    Pair { first: 0; slide: -1 }
    Pair { first: 2; slide: 1 }

    Item {
        x: Math.round(root.startX + root.xs[4] * root.k)
        y: Math.round(root.baseY - root.ascent + root.colonShift)
        width: fm.advanceWidth(":") * root.k
        height: root.ascent + root.descent
        opacity: root.p
        scale: 0.4 + 0.6 * root.p

        Text {
            text: ":"
            color: Colors.primary
            font.family: root.family
            font.pixelSize: root.px
            renderType: Text.NativeRendering
        }
    }
}
