import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Item {
    id: root

    property var surfaces: []
    property Item shape: null
    property var hidden: ({})
    property real shapeIn: 1
    property real oldShape: 0

    property var ghosts: []
    property int count: 0
    property real clock: 0
    property int phase: 0
    property int ticks: 0
    property bool lifting: false
    property bool pendingLaunch: false
    property var extras: []
    property bool takeoff: false
    property bool counted: false
    readonly property int liftMs: 700
    readonly property int chipMs: 240
    readonly property real liftPx: 10

    readonly property int flyMs: 700
    readonly property int findMs: 160
    readonly property int holdMs: M3Motion.effectsDuration("fast")
    readonly property int handMs: 140
    readonly property int tuckMs: 240
    readonly property real tuckPx: 24
    readonly property var flyEase: root.bezier([0.4, 0, 0.2, 1, 1, 1])
    readonly property var inEase: root.bezier([0.2, 0, 0, 1])
    readonly property var outEase: root.bezier([0.3, 0, 1, 1])

    function bezier(c) {
        if (c.length === 4)
            c = c.concat([1, 1])
        const segs = []
        let sx = 0, sy = 0
        for (let i = 0; i + 5 < c.length; i += 6) {
            segs.push([sx, sy, c[i], c[i + 1], c[i + 2], c[i + 3], c[i + 4], c[i + 5]])
            sx = c[i + 4]
            sy = c[i + 5]
        }
        const at = (u, a, b, cc, d) => {
            const v = 1 - u
            return v * v * v * a + 3 * v * v * u * b + 3 * v * u * u * cc + u * u * u * d
        }
        return t => {
            if (t <= 0)
                return 0
            if (t >= 1)
                return 1
            const g = segs.find(q => t <= q[6]) ?? segs[segs.length - 1]
            let lo = 0, hi = 1, u = 0.5
            for (let i = 0; i < 40; i++) {
                u = (lo + hi) / 2
                if (at(u, g[0], g[2], g[4], g[6]) < t)
                    lo = u
                else
                    hi = u
            }
            return at(u, g[1], g[3], g[5], g[7])
        }
    }

    function surfaceOf(item) {
        for (let p = item; p; p = p.parent)
            if (p.blockItems !== undefined)
                return p
        return null
    }

    function rowOf(item, surf) {
        let p = item
        while (p && p.parent !== surf)
            p = p.parent
        return p
    }

    function geom(e) {
        const surf = root.surfaceOf(e.slot)
        if (!surf || !surf.visible)
            return null
        const row = root.rowOf(e.slot, surf)
        const crop = e.slot.mapToItem(surf, 0, 0, e.slot.width, e.slot.height)
        const c = e.slot.mapToItem(root, e.slot.width / 2, e.slot.height / 2)
        const p0 = surf.mapToItem(root, 0, 0)
        const px = surf.mapToItem(root, 1, 0)
        const py = surf.mapToItem(root, 0, 1)
        const ax = px.x - p0.x, ay = px.y - p0.y
        const m = ax * (py.y - p0.y) - ay * (py.x - p0.x) < 0
        const out = { top: [0, 1], bottom: [0, -1], left: [1, 0], right: [-1, 0] }[surf.edge] ?? [0, 0]
        let ca = 0
        if (e.item) {
            const q0 = e.item.mapToItem(root, 0, 0)
            const qx = e.item.mapToItem(root, 1, 0)
            ca = Math.atan2(qx.y - q0.y, qx.x - q0.x) * 180 / Math.PI
        }
        return {
            surf: surf, crop: crop, cx: c.x, cy: c.y, w: crop.width, h: crop.height,
            ca: ca, horiz: surf.edge === "top" || surf.edge === "bottom",
            lx: out[0] * root.liftPx, ly: out[1] * root.liftPx,
            a: Math.atan2(ay, ax) * 180 / Math.PI + (m ? 180 : 0), m: m,
            o: row ? row.opacity : 1
        }
    }

    function find(id) {
        for (const s of root.surfaces) {
            if (!s || !s.visible)
                continue
            for (const b of s.blockItems ?? []) {
                if (!b || !b.parent || b.leaving || !b.flightItems)
                    continue
                const hit = b.flightItems().find(e => e.id === id)
                if (hit)
                    return hit
            }
        }
        return null
    }

    function stop() {
        frames.running = false
        failsafe.stop()
        root.pendingLaunch = false
        root.extras = []
        root.phase = 0
        root.count = 0
        root.ghosts = []
        root.hidden = ({})
        root.shapeIn = 1
        root.oldShape = 0
        root.lifting = false
        root.takeoff = false
        if (root.counted) {
            root.counted = false
            ServiceLayouts.flights = Math.max(0, ServiceLayouts.flights - 1)
        }
        frozenShape.sourceItem = null
        shapeFade.opacity = 1
    }

    function capture() {
        root.stop()
        const patch = ServiceLayouts._patch
        if (!ServiceLayouts.animate || !root.visible || (patch && (!patch.bar || ServiceLayouts.same(SettingsConfig.bar, patch.bar))))
            return
        const list = []
        for (const s of root.surfaces) {
            if (!s || !s.visible)
                continue
            for (const b of s.blockItems ?? []) {
                if (!b || !b.parent || b.leaving || !b.flightItems)
                    continue
                for (const e of b.flightItems()) {
                    const g = root.geom(e)
                    if (!g || g.o < 0.05 || g.w < 1 || g.h < 1 || e.slot.opacity < 0.05)
                        continue
                    list.push({ id: e.id, from: g, live: null, target: null, start: -1, mode: "", landed: false })
                }
            }
        }
        if (!list.length)
            return
        root.ghosts = list
        root.count = list.length
        if (root.shape) {
            frozenShape.sourceItem = root.shape
            frozenShape.scheduleUpdate()
            root.oldShape = 1
        }
        root.phase = 1
        root.ticks = 0
        root.clock = 0
        root.counted = true
        ServiceLayouts.flights++
        ServiceLayouts.hold()
        frames.running = true
        failsafe.restart()
    }

    function captured() {
        const h = {}
        for (const e of root.ghosts)
            h[e.id] = true
        root.hidden = h
        root.shapeIn = 0
        root.takeoff = true
        root.lifting = true
        root.ticks = 0
        root.phase = 2
        failsafe.restart()
    }

    function launch() {
        if (root.phase === 1 || root.phase === 2) {
            root.pendingLaunch = true
            return
        }
        if (root.phase !== 3)
            return
        root.clock = 0
        root.ticks = 0
        root.phase = 4
        failsafe.restart()
    }

    function hideNew() {
        const ids = new Set(root.ghosts.map(e => e.id))
        const h = Object.assign({}, root.hidden)
        const out = []
        for (const s of root.surfaces) {
            if (!s || !s.visible)
                continue
            for (const b of s.blockItems ?? []) {
                if (!b || !b.parent || b.leaving || !b.flightItems)
                    continue
                for (const e of b.flightItems()) {
                    if (ids.has(e.id) || h[e.id])
                        continue
                    h[e.id] = true
                    out.push(e.id)
                }
            }
        }
        root.hidden = h
        root.extras = out
    }

    function reveal(id) {
        if (!root.hidden[id])
            return
        const h = Object.assign({}, root.hidden)
        delete h[id]
        root.hidden = h
    }

    function land(e) {
        e.landed = true
        root.reveal(e.id)
    }

    function step(dt) {
        root.ticks++
        if (root.phase === 1) {
            if (root.ticks >= 2)
                root.captured()
            return
        }
        if (root.phase === 2) {
            if (root.ticks >= 2) {
                root.phase = 3
                failsafe.restart()
                ServiceLayouts.release()
                if (root.pendingLaunch) {
                    root.pendingLaunch = false
                    root.launch()
                }
            }
            return
        }
        if (root.phase !== 4 || root.ticks === 1)
            return
        if (root.lifting) {
            root.lifting = false
            root.hideNew()
            return
        }
        root.clock += Math.min(dt, 0.05) * 1000
        const t = root.clock
        root.shapeIn = root.inEase(Math.max(0, Math.min(1, (t - root.flyMs * 0.2) / (root.flyMs * 0.4))))
        let busy = root.shapeIn < 1
        if (root.extras.length && t >= root.flyMs * 0.65) {
            for (const id of root.extras)
                root.reveal(id)
            root.extras = []
        }
        busy = busy || root.extras.length > 0
        const fresh = []
        for (const e of root.ghosts) {
            if (e.landed || e.start >= 0)
                continue
            e.target = root.find(e.id)
            if (e.target) {
                const g = root.geom(e.target)
                e.dist = g ? Math.hypot(g.cx - e.from.cx, g.cy - e.from.cy) : 0
                e.dur = Math.max(420, Math.min(root.flyMs, 380 + e.dist * 0.3))
                e.mode = "fly"
                fresh.push(e)
            } else if (t >= root.findMs) {
                e.start = t
                e.mode = "fade"
            }
        }
        fresh.sort((a, b) => a.dist - b.dist)
        fresh.forEach((e, i) => e.start = t + Math.min(i * 12, 160))
        for (const e of root.ghosts) {
            if (e.landed)
                continue
            if (e.mode === "fly") {
                if (!e.target || !e.target.slot.parent)
                    e.target = root.find(e.id)
                if (e.target)
                    e.live = root.geom(e.target) ?? e.live
                const a = t - e.start - e.dur
                if (a >= 0)
                    root.reveal(e.id)
                if (a >= root.holdMs + root.handMs) {
                    root.land(e)
                    continue
                }
            } else if (e.mode === "fade" && t - e.start >= root.tuckMs) {
                root.land(e)
                continue
            }
            busy = true
        }
        if (!busy)
            root.stop()
    }

    function stateOf(i, clock) {
        const e = root.ghosts[i]
        if (!e || e.landed)
            return null
        const f = e.from
        if (root.phase < 4 || e.start < 0 || clock < e.start)
            return { cx: f.cx, cy: f.cy, w: f.w, h: f.h, a: f.a, m: f.m, o: 1, k: 0, r: 0, chip: -1, touch: -1 }
        if (e.mode === "fade") {
            const p = Math.min(1, (clock - e.start) / root.tuckMs)
            const q = root.outEase(p)
            const back = root.tuckPx / root.liftPx
            return { cx: f.cx - f.lx * back * q, cy: f.cy - f.ly * back * q, w: f.w, h: f.h, a: f.a, m: f.m,
                     o: 1 - root.inEase(p), k: 0, r: 0, chip: 1 - p, touch: -1 }
        }
        const to = e.live ?? f
        const p = Math.min(1, (clock - e.start) / (e.dur ?? root.flyMs))
        const k = root.flyEase(p)
        const a = clock - e.start - e.dur
        const out = a <= root.holdMs ? 0 : root.outEase(Math.min(1, (a - root.holdMs) / root.handMs))
        const dx = to.cx - f.cx, dy = to.cy - f.cy
        const d = Math.hypot(dx, dy)
        let mx = (f.cx + to.cx) / 2, my = (f.cy + to.cy) / 2
        if (d > 1) {
            let nx = -dy / d, ny = dx / d
            if (nx * (root.width / 2 - mx) + ny * (root.height / 2 - my) < 0) {
                nx = -nx
                ny = -ny
            }
            const bulge = Math.min(d * 0.3, 160)
            mx += nx * bulge
            my += ny * bulge
        }
        let turn = ((to.ca - f.ca) % 360 + 540) % 360 - 180
        if (Math.abs(turn) < 1 && f.w > f.h * 1.6 && to.horiz !== f.horiz)
            turn = f.horiz ? 90 : -90
        const u = 1 - k
        return {
            cx: u * u * f.cx + 2 * u * k * mx + k * k * to.cx,
            cy: u * u * f.cy + 2 * u * k * my + k * k * to.cy,
            w: f.w, h: f.h, a: f.a, m: f.m,
            o: Math.max(0, Math.min(1, 1 + (to.o - 1) * k)) * (1 - out),
            k: k,
            r: turn * k,
            chip: 1 - root.inEase(Math.max(0, Math.min(1, (p - 0.65) / 0.35))),
            touch: a < 0 ? -1 : Math.min(1, a / (root.holdMs + root.handMs))
        }
    }

    Connections {
        target: ServiceLayouts
        function onCapture() { root.capture() }
        function onApplied() { root.launch() }
    }

    Timer {
        id: failsafe
        interval: 3000
        onTriggered: {
            if (root.phase > 0 && root.phase < 3)
                ServiceLayouts.release()
            root.stop()
        }
    }

    FrameAnimation {
        id: frames
        running: false
        onTriggered: root.step(frameTime)
    }

    Item {
        id: shapeFade
        anchors.fill: parent

        OpacityAnimator {
            target: shapeFade
            from: 1
            to: 0
            duration: root.chipMs + 80
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
            running: root.takeoff
        }

        ShaderEffectSource {
            id: frozenShape
            anchors.fill: parent
            live: false
            hideSource: false
            visible: root.oldShape > 0.001 && sourceItem !== null
        }
    }

    Repeater {
        model: root.count

        delegate: Item {
            id: ghost

            required property int index
            readonly property var entry: root.ghosts[ghost.index] ?? null
            readonly property var st: root.stateOf(ghost.index, root.clock)

            visible: ghost.st !== null && ghost.st.o > 0.01
            x: ghost.st ? ghost.st.cx : 0
            y: ghost.st ? ghost.st.cy : 0
            opacity: ghost.st ? ghost.st.o : 0
            onStChanged: if (root.phase === 4 && ghost.st && ghost.st.chip >= 0 && root.clock > root.chipMs) chip.opacity = ghost.st.chip

            Item {
                id: lift

                XAnimator {
                    target: lift
                    from: 0
                    to: ghost.entry ? ghost.entry.from.lx : 0
                    duration: root.liftMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                    running: root.lifting
                }

                YAnimator {
                    target: lift
                    from: 0
                    to: ghost.entry ? ghost.entry.from.ly : 0
                    duration: root.liftMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                    running: root.lifting
                }

                Item {
                    id: spin
                    x: -lift.x * (ghost.st ? ghost.st.k : 0)
                    y: -lift.y * (ghost.st ? ghost.st.k : 0)
                    rotation: ghost.st ? ghost.st.r : 0

                    Item {
                        id: body
                        x: -body.width / 2
                        y: -body.height / 2
                        width: ghost.st ? ghost.st.w : 0
                        height: ghost.st ? ghost.st.h : 0
                        rotation: ghost.st ? ghost.st.a : 0
                        transform: Scale {
                            origin.x: body.width / 2
                            xScale: ghost.st && ghost.st.m ? -1 : 1
                        }

                        Rectangle {
                            readonly property real tp: ghost.st ? ghost.st.touch : -1
                            readonly property real grow: root.inEase(Math.max(0, tp))
                            visible: tp >= 0 && tp < 1
                            anchors.centerIn: parent
                            width: parent.width + 6 + 16 * grow
                            height: parent.height + 6 + 16 * grow
                            radius: Math.min(width, height) / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(Colors.primary, 0.55 * (1 - tp))
                        }

                        Rectangle {
                            id: chip
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: parent.height
                            radius: Math.min(width, height) / 2
                            color: Colors.surface
                            opacity: 0

                            OpacityAnimator {
                                target: chip
                                from: 0
                                to: 1
                                duration: root.chipMs
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                                running: root.takeoff
                            }
                        }

                        ShaderEffectSource {
                            anchors.fill: parent
                            live: false
                            hideSource: false
                            sourceItem: ghost.entry ? ghost.entry.from.surf : null
                            sourceRect: ghost.entry ? ghost.entry.from.crop : Qt.rect(0, 0, 0, 0)
                            smooth: true
                        }
                    }
                }
            }
        }
    }
}
