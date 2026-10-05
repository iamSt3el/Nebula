import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import "lavaPhysics.js" as Lava

WidgetHost {
    id: root
    configKey: "lavaLamp"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(3))
    resizable: true
    minSpan: Qt.size(2, 2)
    maxSpan: Qt.size(3, 4)
    defaultPos: Qt.point(1575, 165)
    backdrop: false

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    property real load: Math.max(0, Math.min(1, root.si.cpuUsage))
    property real heat: root.load
    property real phase: Math.random()
    property double _last: 0
    property var sim: null

    readonly property bool listening: !root.preview && root.visible && ServiceMusic.isPlaying
    property bool _cava: false
    property var spectrum: root._cava ? ServiceCava.cavaData : []
    property real level: 0
    property real shimmer: 0
    property real _bassAvg: 0
    property real _lastBass: 0
    property real _cooldown: 0

    onListeningChanged: root.hold(root.listening)

    readonly property real unit: Math.max(1, Math.min(root.width, root.height * 0.7))
    readonly property real halfW: root.width / 2 / root.unit
    readonly property real depth: root.height / root.unit
    readonly property real ceiling: 12 / root.unit

    Component.onCompleted: {
        root.si.retain()
        root.hold(root.listening)
    }
    Component.onDestruction: {
        root.si.release()
        if (root._cava)
            ServiceCava.release()
    }

    function hold(on) {
        if (on === root._cava)
            return
        root._cava = on
        if (on)
            ServiceCava.retain()
        else
            ServiceCava.release()
    }

    function mean(d, from, to) {
        let sum = 0
        for (let i = from; i < to; i++)
            sum += d[i]
        return to > from ? sum / (to - from) : 0
    }

    function listen(dt) {
        const d = root.spectrum
        const n = d ? d.length : 0
        if (n < 8) {
            root.level *= Math.exp(-dt * 2)
            root.shimmer *= Math.exp(-dt * 4)
            return
        }
        const bass = root.mean(d, 0, Math.max(2, Math.round(n / 6)))
        const treble = root.mean(d, Math.round(n * 2 / 3), n)
        root.level += (root.mean(d, 0, n) - root.level) * Math.min(1, dt * 3)
        root.shimmer += (Math.min(1, treble * 1.5) - root.shimmer) * Math.min(1, dt * 6)
        root._bassAvg += (bass - root._bassAvg) * Math.min(1, dt * 1.2)
        root._cooldown -= dt
        if (root.sim && root._cooldown <= 0 && bass > root._lastBass
                && bass > root._bassAvg * 1.3 + 0.06) {
            Lava.kick(root.sim, Math.max(0.3, Math.min(1, (bass - root._bassAvg) * 2.5)), root.halfW, root.depth)
            root._cooldown = 0.2
        }
        root._lastBass = bass
    }

    function advance(dt) {
        if (!root.sim) {
            root.sim = Lava.create(root.halfW, root.depth)
            Lava.step(root.sim, 40, root.heat, root.halfW, root.depth, root.ceiling)
        }
        Lava.step(root.sim, dt, root.heat, root.halfW, root.depth, root.ceiling)
        const b = root.sim.blobs
        for (let i = 0; i < b.length; i++)
            lamp["b" + i] = Qt.vector4d(b[i].x, b[i].y, b[i].r, Lava.wobble(b[i]))
        lamp.tempA = Qt.vector4d(b[0].t, b[1].t, b[2].t, b[3].t)
        lamp.tempB = Qt.vector4d(b[4].t, b[5].t, b[6].t, b[7].t)
        lamp.poolY = Lava.poolSurface(root.sim, root.depth)
        lamp.music = Qt.vector4d(root.sim.rippleA, root.sim.rippleT, root.sim.rippleX, root.shimmer)
    }

    Timer {
        interval: 33
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.width > 0
        onRunningChanged: root._last = 0
        onTriggered: {
            const now = Date.now()
            const dt = root._last > 0 ? Math.min(0.1, (now - root._last) / 1000) : 0
            root._last = now
            root.listen(dt)
            const target = Math.min(1, root.load + root.level * 0.25)
            root.heat += (target - root.heat) * Math.min(1, dt * 0.4)
            root.phase = (root.phase + dt / 90) % 1
            root.advance(dt)
        }
    }

    ShaderEffect {
        id: lamp
        anchors.fill: parent
        readonly property vector2d itemSize: Qt.vector2d(width, height)
        readonly property real unit: root.unit
        property real poolY: root.depth - 0.15
        readonly property real phase: root.phase
        readonly property real heat: root.heat
        readonly property real cornerRadius: WidgetSizes.radius
        property vector4d b0: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b1: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b2: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b3: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b4: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b5: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b6: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d b7: Qt.vector4d(0, 99, 0.1, 0)
        property vector4d tempA: Qt.vector4d(0, 0, 0, 0)
        property vector4d tempB: Qt.vector4d(0, 0, 0, 0)
        property vector4d music: Qt.vector4d(0, 9, 0, 0)
        readonly property color waxHot: Colors.tertiary
        readonly property color waxCool: Colors.primary
        fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/lava.frag.qsb")
    }
}
