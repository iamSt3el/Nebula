import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings

WidgetHost {
    id: root
    configKey: "sysCreature"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(2))
    resizable: true
    minSpan: Qt.size(2, 2)
    maxSpan: Qt.size(4, 4)
    backdrop: false
    outlined: false
    defaultPos: Qt.point(540, 300)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    readonly property real cpu: Math.max(0, Math.min(1, root.si.cpuUsage))
    readonly property real ram: Math.max(0, Math.min(1, root.si.memUsage))
    readonly property real net: Math.max(0, Math.min(1, Math.log10(1 + (root.si.netDownloadBps + (root.si.netUploadBps ?? 0)) / 1024) / 4.3))
    readonly property real temp: root.si.cpuTemp > 0 ? root.si.cpuTemp : 45

    readonly property int nPts: 48
    readonly property string glyphFamily: Qt.fontFamilies().indexOf("Rubik") >= 0 ? "Rubik" : "sans-serif"
    property var off: []
    property var vel: []
    property var parts: []
    property real t0: 0
    property real bx: 0
    property real by: 0
    property real bvx: 0
    property real bvy: 0
    property real sq: 0
    property real sqv: 0

    property string emoteName: ""
    property real emoteUntil: 0
    property string mood: "content"

    property real px: -9999
    property real py: -9999
    property bool pin: false
    property real lastMove: Date.now()
    property real lastPx: 0
    property real lastPy: 0
    property real ptrAng: 0
    property real angAcc: 0
    property bool down: false
    property bool grab: false
    property real gx: 0
    property real gy: 0
    property real dwell: 0
    property real lastCpu: 0

    readonly property var moodLabel: ({
        content: "Content", curious: "Curious", giggle: "Giggling", love: "In love", dizzy: "Dizzy",
        sleepy: "Sleepy", surprised: "Surprised", grumpy: "Too hot", excited: "Excited", stretch: "Stretchy"
    })

    Component.onCompleted: {
        root.si.retain()
        const o = [], v = []
        for (let i = 0; i < root.nPts; i++) { o.push(0); v.push(0) }
        root.off = o
        root.vel = v
        root.lastCpu = root.cpu
    }
    Component.onDestruction: root.si.release()

    function rad() { return Math.min(width, height) * 0.2 * (0.8 + root.ram * 0.6) }
    function homeX() { return width / 2 }
    function homeY() { return height * 0.55 }
    function dist() { return Math.hypot(root.px - root.bx, root.py - root.by) }

    function emote(n, sec) {
        root.emoteName = n
        root.emoteUntil = Date.now() + sec * 1000
        if (n === "love") for (let i = 0; i < 6; i++) root.spawn("heart")
        if (n === "dizzy") for (let i = 0; i < 5; i++) root.spawn("star")
        if (n === "surprised") root.spawn("bang")
        if (n === "excited") { for (let i = 0; i < 8; i++) root.spawn("spark"); root.bvy -= root.rad() * 2.4 }
        if (n === "grumpy") root.spawn("steam")
    }

    function currentMood() {
        const t = Date.now()
        if (root.grab) return "stretch"
        if (t < root.emoteUntil) return root.emoteName
        if (root.temp > 78) return "grumpy"
        if (t - root.lastMove > 20000 && !root.down) return "sleepy"
        if (root.pin && root.dist() < root.rad() * 2.4) return "curious"
        return "content"
    }

    function poke(a, s) {
        const v = root.vel
        for (let i = 0; i < root.nPts; i++) {
            const d = Math.atan2(Math.sin(i / root.nPts * 6.283 - a), Math.cos(i / root.nPts * 6.283 - a))
            v[i] -= s * 0.22 * Math.exp(-d * d * 5)
        }
        root.sqv += s * 0.9
    }

    function spawn(kind) {
        const r = root.rad()
        const p = root.parts
        if (p.length > 40) return
        p.push({ kind: kind, x: root.bx + (Math.random() - 0.5) * r, y: root.by - r * 0.9,
                 vx: (Math.random() - 0.5) * 60, vy: -60 - Math.random() * 60, life: 0,
                 max: 1.6 + Math.random() * 0.8, rot: Math.random() * 6, s: 0.7 + Math.random() * 0.6 })
    }

    function pointerAt(x, y) {
        const t = Date.now()
        if (root.pin) {
            const a = Math.atan2(y - root.by, x - root.bx)
            let da = a - root.ptrAng
            da = Math.atan2(Math.sin(da), Math.cos(da))
            root.angAcc = root.angAcc * 0.96 + da
            root.ptrAng = a
            if (Math.abs(root.angAcc) > 14 && Math.hypot(x - root.bx, y - root.by) < root.rad() * 3.5) {
                root.emote("dizzy", 3)
                root.angAcc = 0
            }
        }
        const wasAsleep = root.mood === "sleepy"
        root.px = x
        root.py = y
        root.lastPx = x
        root.lastPy = y
        root.pin = true
        root.lastMove = t
        if (wasAsleep) root.emote("surprised", 1)
    }

    Connections {
        target: GlobalStates
        enabled: !root.preview
        function onDesktopCursorXChanged() { root.fromDesktop() }
        function onDesktopCursorYChanged() { root.fromDesktop() }
        function onDesktopCursorActiveChanged() { if (!GlobalStates.desktopCursorActive && !root.down) root.pin = false }
    }

    function fromDesktop() {
        if (!GlobalStates.desktopCursorActive || root.down) return
        const p = root.mapFromItem(null, GlobalStates.desktopCursorX, GlobalStates.desktopCursorY)
        root.pointerAt(p.x, p.y)
    }

    onCpuChanged: {
        if (root.preview) return
        if (root.cpu - root.lastCpu > 0.25) root.emote("surprised", 1.6)
        root.lastCpu = root.cpu
    }
    onNetChanged: if (!root.preview && root.net > 0.8 && Date.now() > root.emoteUntil) root.emote("excited", 1.8)

    MouseArea {
        anchors.fill: parent
        enabled: !root.preview && !root.lifted
        hoverEnabled: true
        preventStealing: true
        onPositionChanged: mouse => {
            if (root.down && !root.grab && Math.hypot(mouse.x - root.gx, mouse.y - root.gy) > 10)
                root.grab = true
            root.pointerAt(mouse.x, mouse.y)
        }
        onPressed: mouse => {
            root.lastMove = Date.now()
            if (Math.hypot(mouse.x - root.bx, mouse.y - root.by) < root.rad() * 1.15) {
                root.down = true
                root.grab = false
                root.gx = mouse.x
                root.gy = mouse.y
            } else {
                mouse.accepted = false
            }
        }
        onReleased: mouse => {
            if (root.down) {
                if (root.grab) {
                    root.emote("giggle", 1.2)
                    root.sqv -= 6
                } else {
                    root.poke(Math.atan2(mouse.y - root.by, mouse.x - root.bx), 10)
                    root.emote("giggle", 1.4)
                    root.spawn("spark")
                }
            }
            root.down = false
            root.grab = false
        }
        onDoubleClicked: root.emote("love", 3)
        onExited: if (!root.down) root.pin = false
    }

    Timer {
        id: tick
        interval: root.mood === "sleepy" ? 160 : (root.pin || root.down || (Date.now() < root.emoteUntil && root.mood !== "grumpy")) ? 33 : root.mood === "grumpy" || root.parts.length > 0 ? 60 : 100
        repeat: true
        running: root.visible && root.width > 0
        onTriggered: root.step(Math.min(0.17, interval / 1000))
    }

    function step(dt) {
        if (root.bx === 0 && root.by === 0) { root.bx = root.homeX(); root.by = root.homeY() }
        root.t0 += dt
        const r = root.rad()
        const m = root.currentMood()
        if (m !== root.mood) root.mood = m
        if (root.pin && !root.down && m === "content" && root.dist() < r) {
            root.dwell += dt
            if (root.dwell > 1.6) { root.emote("love", 2.6); root.dwell = 0 }
        } else if (m !== "love") {
            root.dwell = 0
        }

        const hx = root.homeX(), hy = root.homeY()
        let tx = hx, ty = hy
        if (root.grab) { tx = hx + (root.px - hx) * 0.55; ty = hy + (root.py - hy) * 0.55 }
        else if (m === "curious") { tx = hx + (root.px - hx) * 0.08; ty = hy + (root.py - hy) * 0.05 }
        const k = root.grab ? 60 : 40, c = root.grab ? 9 : 6.5
        const sub = 3, h = dt / sub
        const off = root.off, vel = root.vel, n = root.nPts
        const ks = 70, cs = 7, cpl = 18
        const ga = root.grab ? Math.atan2(root.py - root.by, root.px - root.bx) : 0
        const pull = root.grab ? Math.min(0.9, Math.hypot(root.px - root.bx, root.py - root.by) / r) * 0.55 : 0
        for (let st = 0; st < sub; st++) {
            root.bvx += ((tx - root.bx) * k - root.bvx * c) * h
            root.bvy += ((ty - root.by) * k - root.bvy * c) * h
            if (root.net > 0.6 && Math.random() < h * root.net * 1.5) root.bvy -= r * 0.35
            root.bx += root.bvx * h
            root.by += root.bvy * h
            root.sqv += (-root.sq * 120 - root.sqv * 9) * h
            root.sq += root.sqv * h
            for (let i = 0; i < n; i++) {
                const l = off[(i - 1 + n) % n], rr = off[(i + 1) % n]
                let tgt = 0
                if (root.grab) {
                    const d = Math.atan2(Math.sin(i / n * 6.283 - ga), Math.cos(i / n * 6.283 - ga))
                    tgt = pull * Math.exp(-d * d * 2.5) - pull * 0.18
                }
                vel[i] += (-(off[i] - tgt) * ks - vel[i] * cs + (l + rr - 2 * off[i]) * cpl) * h
            }
            for (let i = 0; i < n; i++) {
                off[i] += vel[i] * h
                if (off[i] > 0.7) { off[i] = 0.7; vel[i] = 0 }
                if (off[i] < -0.45) { off[i] = -0.45; vel[i] = 0 }
            }
        }

        if (m === "sleepy" && Math.random() < dt * 0.6) root.spawn("z")
        if (m === "grumpy" && Math.random() < dt * 0.9) root.spawn(Math.random() < 0.5 ? "sweat" : "steam")
        if (m === "love" && Math.random() < dt * 2) root.spawn("heart")
        if (m === "dizzy" && Math.random() < dt * 2.5) root.spawn("star")

        const p = root.parts
        for (let i = p.length - 1; i >= 0; i--) {
            const q = p[i]
            q.life += dt
            if (q.life > q.max) { p.splice(i, 1); continue }
            q.x += q.vx * dt
            q.y += q.vy * dt
            q.vy += (q.kind === "sweat" ? 220 : -8) * dt
            q.rot += dt * 2
        }
        body.requestPaint()
    }

    function rgb(hex) {
        const s = String(hex).replace("#", "")
        const o = s.length === 8 ? 2 : 0
        return [parseInt(s.substr(o, 2), 16), parseInt(s.substr(o + 2, 2), 16), parseInt(s.substr(o + 4, 2), 16)]
    }
    function mix(a, b, t) { return [0, 1, 2].map(i => Math.round(a[i] + (b[i] - a[i]) * t)) }
    function css(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + (a === undefined ? 1 : a) + ")" }

    Canvas {
        id: body
        anchors.fill: parent

        function heart(g, x, y, s, c) {
            g.fillStyle = c
            g.beginPath()
            g.moveTo(x, y + s * 0.35)
            g.bezierCurveTo(x - s * 0.9, y - s * 0.2, x - s * 0.35, y - s * 0.8, x, y - s * 0.3)
            g.bezierCurveTo(x + s * 0.35, y - s * 0.8, x + s * 0.9, y - s * 0.2, x, y + s * 0.35)
            g.fill()
        }

        function ellipse(g, x, y, rx, ry) {
            g.ellipse(x - rx, y - ry, rx * 2, ry * 2)
        }

        onPaint: {
            const g = getContext("2d")
            const W = width, H = height
            g.reset()
            if (root.bx === 0 && root.by === 0) { root.bx = W / 2; root.by = H * 0.55 }
            const m = root.mood, t0 = root.t0
            const r0 = root.rad()
            const P = root.rgb(Colors.primary), T = root.rgb(Colors.tertiary), E = [255, 138, 122]
            const INK = "#1b140c"
            const heat = Math.max(0, Math.min(1, (root.temp - 55) / 35))
            let col = heat > 0 ? root.mix(P, E, heat) : root.mix(T, P, Math.min(1, root.temp / 55))
            if (m === "love") col = root.mix(col, [255, 150, 170], 0.25)
            const breath = m === "sleepy" ? 1 + 0.05 * Math.sin(t0 * 1.4) : 1 + 0.03 * Math.sin(t0 * 2.2)
            const sqf = root.sq * 0.04, sx = (1 + sqf) * breath, sy = (1 - sqf) / breath
            const cx = root.bx, cy = root.by
            const r = r0

            const glow = g.createRadialGradient(cx, cy, r * 0.3, cx, cy, Math.min(W, H) * 0.49)
            glow.addColorStop(0, root.css(col, 0.2))
            glow.addColorStop(1, root.css(col, 0))
            g.fillStyle = glow
            g.fillRect(0, 0, W, H)

            g.fillStyle = "rgba(0,0,0,0.3)"
            g.beginPath()
            ellipse(g, cx, H * 0.55 + r0 * 1.05, Math.max(4, r0 * 0.8 * (1 - (H * 0.55 - cy) / (r0 * 6))), r0 * 0.12)
            g.fill()

            const wa = 0.03 + root.cpu * 0.07, ws = 1.3 + root.cpu * 5
            const n = root.nPts, off = root.off
            g.beginPath()
            for (let i = 0; i <= n; i++) {
                const a = i / n * 6.283
                const rr = r * (1 + off[i % n] + wa * (Math.sin(a * 3 + t0 * ws) * 0.6 + Math.sin(a * 5 - t0 * ws * 1.4) * 0.3))
                const x = cx + rr * Math.cos(a) * sx, y = cy + rr * Math.sin(a) * sy * 0.95
                if (i === 0) g.moveTo(x, y)
                else g.lineTo(x, y)
            }
            g.closePath()
            const f = g.createRadialGradient(cx - r * 0.35, cy - r * 0.45, r * 0.1, cx, cy, r * 1.25)
            f.addColorStop(0, root.css(root.mix(col, [255, 255, 255], 0.38)))
            f.addColorStop(0.6, root.css(col))
            f.addColorStop(1, root.css(root.mix(col, [22, 19, 15], 0.45)))
            g.fillStyle = f
            g.fill()

            g.fillStyle = "rgba(255,255,255,0.35)"
            g.save()
            g.translate(cx - r * 0.38, cy - r * 0.5)
            g.rotate(-0.6)
            g.beginPath()
            ellipse(g, 0, 0, r * 0.16, r * 0.08)
            g.fill()
            g.restore()

            const lx = root.pin ? Math.max(-1, Math.min(1, (root.px - cx) / (r * 3))) : Math.sin(t0 * 0.4) * 0.3
            const ly = root.pin ? Math.max(-1, Math.min(1, (root.py - cy) / (r * 3))) : 0
            const ex = r * 0.3 * sx, ey = cy - r * 0.1, ew = r * 0.13, eh = r * 0.19
            const blink = Math.sin(t0 * 0.9) > 0.992 || m === "sleepy"
            g.fillStyle = INK
            g.strokeStyle = INK
            g.lineCap = "round"
            g.lineWidth = Math.max(2.5, r * 0.045)
            for (const s of [-1, 1]) {
                const x = cx + s * ex + lx * r * 0.07, y = ey + ly * r * 0.05
                if (m === "giggle" || m === "excited") {
                    g.beginPath(); g.arc(x, y + eh * 0.3, ew * 0.9, 1.15 * Math.PI, 1.85 * Math.PI, false); g.stroke()
                } else if (m === "love") {
                    heart(g, x, y, ew * 1.6, "#d9486a")
                } else if (m === "dizzy") {
                    g.beginPath()
                    for (let k = 0; k < 40; k++) {
                        const a = k * 0.45 + t0 * 6 * s, rr = k / 40 * ew * 1.2
                        if (k === 0) g.moveTo(x, y)
                        else g.lineTo(x + rr * Math.cos(a), y + rr * Math.sin(a))
                    }
                    g.stroke()
                } else if (blink) {
                    g.beginPath(); g.moveTo(x - ew * 0.9, y + eh * 0.2); g.quadraticCurveTo(x, y + eh * 0.6, x + ew * 0.9, y + eh * 0.2); g.stroke()
                } else {
                    const big = (m === "surprised" || m === "curious") ? 1.25 : 1
                    g.fillStyle = INK
                    g.beginPath(); ellipse(g, x, y, ew * big, eh * big); g.fill()
                    g.fillStyle = "#ffffff"
                    g.beginPath(); g.arc(x + lx * ew * 0.35 - ew * 0.28, y + ly * eh * 0.3 - eh * 0.35, ew * 0.32 * big, 0, 6.283, false); g.fill()
                    g.fillStyle = INK
                }
                if (m === "grumpy") {
                    g.beginPath(); g.moveTo(x + ew * 1.3 * s, y - eh * 1.6); g.lineTo(x - ew * 1.2 * s, y - eh * 1.15); g.stroke()
                }
            }
            if (m === "love" || m === "giggle" || (m === "curious" && root.dist() < r * 1.3)) {
                g.fillStyle = "rgba(230,110,110,0.35)"
                for (const s of [-1, 1]) { g.beginPath(); ellipse(g, cx + s * r * 0.52 * sx, cy + r * 0.12, r * 0.13, r * 0.07); g.fill() }
            }

            const my = cy + r * 0.2, mw = r * 0.16
            g.fillStyle = INK
            g.beginPath()
            if (m === "giggle" || m === "excited") {
                g.moveTo(cx - mw * 1.2, my - 2); g.quadraticCurveTo(cx, my + mw * 1.6, cx + mw * 1.2, my - 2); g.closePath(); g.fill()
            } else if (m === "surprised") {
                ellipse(g, cx, my + mw * 0.3, mw * 0.45, mw * 0.6); g.fill()
            } else if (m === "sleepy") {
                ellipse(g, cx, my + mw * 0.2, mw * 0.25 + mw * 0.1 * Math.sin(t0 * 1.4), mw * 0.2 + mw * 0.12 * Math.sin(t0 * 1.4)); g.fill()
            } else if (m === "grumpy") {
                g.arc(cx, my + mw * 1.2, mw, 1.15 * Math.PI, 1.85 * Math.PI, false); g.stroke()
            } else if (m === "dizzy") {
                for (let k = 0; k <= 20; k++) {
                    const x = cx - mw * 1.2 + k / 20 * mw * 2.4, y = my + mw * 0.3 + Math.sin(k * 0.9 + t0 * 8) * mw * 0.18
                    if (k === 0) g.moveTo(x, y)
                    else g.lineTo(x, y)
                }
                g.stroke()
            } else if (m === "love") {
                g.arc(cx, my, mw * 0.9, 0.1 * Math.PI, 0.9 * Math.PI, false); g.stroke()
            } else if (m === "curious") {
                g.arc(cx, my + mw * 0.2, mw * 0.35, 0, 6.283, false); g.stroke()
            } else {
                g.arc(cx, my - mw * 0.2, mw, 0.18 * Math.PI, 0.82 * Math.PI, false); g.stroke()
            }

            const motes = Math.round(root.net * 12)
            for (let i = 0; i < motes; i++) {
                const a = t0 * (0.6 + root.net * 1.6) + i / motes * 6.283, rr = Math.min(r * 1.55, Math.min(W, H) * 0.44)
                g.fillStyle = root.css(col, 0.8)
                g.beginPath(); g.arc(cx + rr * Math.cos(a), cy + rr * Math.sin(a) * 0.4, 2.5 + (i % 3), 0, 6.283, false); g.fill()
            }

            for (const q of root.parts) {
                const a = Math.max(0, 1 - q.life / q.max)
                g.save()
                g.globalAlpha = a
                g.translate(q.x, q.y)
                if (q.kind === "heart") {
                    heart(g, 0, 0, 14 * q.s, "#e8637f")
                } else if (q.kind === "z") {
                    g.fillStyle = "#d3c4b5"; g.font = "bold " + Math.round(16 * q.s) + "px " + root.glyphFamily; g.fillText("z", 0, 0)
                } else if (q.kind === "star") {
                    g.rotate(q.rot); g.fillStyle = "#f5d27a"; g.beginPath()
                    for (let k = 0; k < 10; k++) {
                        const rr = k % 2 ? 4 * q.s : 10 * q.s, an = k / 10 * 6.283
                        if (k === 0) g.moveTo(rr, 0)
                        else g.lineTo(rr * Math.cos(an), rr * Math.sin(an))
                    }
                    g.closePath(); g.fill()
                } else if (q.kind === "spark") {
                    g.fillStyle = root.css(col); g.beginPath(); g.arc(0, 0, 3 * q.s, 0, 6.283, false); g.fill()
                } else if (q.kind === "sweat") {
                    g.fillStyle = "#8fc3ff"; g.beginPath(); g.moveTo(0, -8 * q.s)
                    g.quadraticCurveTo(6 * q.s, 2 * q.s, 0, 5 * q.s); g.quadraticCurveTo(-6 * q.s, 2 * q.s, 0, -8 * q.s); g.fill()
                } else if (q.kind === "steam") {
                    g.strokeStyle = "rgba(234,225,217,0.6)"; g.lineWidth = 3; g.beginPath(); g.moveTo(0, 0)
                    g.bezierCurveTo(8, -8, -8, -16, 0, -24); g.stroke()
                } else if (q.kind === "bang") {
                    g.fillStyle = "#ffb4ab"; g.font = "bold 34px " + root.glyphFamily; g.fillText("!", 0, 0)
                }
                g.restore()
            }
        }
    }
}
