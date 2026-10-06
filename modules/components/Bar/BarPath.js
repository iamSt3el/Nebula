.pragma library

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function smooth(t) {
    const c = clamp(t, 0, 1)
    return c * c * (3 - 2 * c)
}

function sdfEmpty() {
    return { pills: [], segs: [], flares: [] }
}

function sdfShape(bs, o, out) {
    const rMax = o.rMax
    const T = o.top
    const B = o.top + o.bridge
    const L = o.left
    const R = o.right
    const n = bs.length
    const e = clamp(o.endR, -rMax, Math.max(0, (B - T) / 2))
    const ec = Math.max(0, e)
    if (!n) {
        out.pills.push({ l: L, r: R, bot: B, top: T, rtl: ec, rtr: ec, rbl: ec, rbr: ec })
        return out
    }

    const capL = o.capL === true
    const capR = o.capR === true
    const eCap = Math.min(rMax, Math.max(0, (B - T) / 2))
    const eL = capL ? eCap : e
    const eR = capR ? eCap : e
    const edgeFlare = clamp(-o.endR / rMax, 0, 1)
    const flareL = capL ? 0 : edgeFlare
    const flareR = capR ? 0 : edgeFlare
    const touchL = capL ? -Infinity : L
    const touchR = capR ? Infinity : R
    const bot = i => Math.max(B, bs[i].bot)

    const gaps = []
    const lines = []
    const reach = []
    for (let k = 0; k <= n; k++) {
        const leftX = k === 0 ? L : bs[k - 1].x + bs[k - 1].w
        const rightX = k === n ? R : bs[k].x
        const g = Math.max(0, rightX - leftX)
        const inner = k > 0 && k < n
        const m = inner ? smooth((o.needGap - g) / 24) : 0
        gaps.push(g)
        lines.push(inner ? B + (Math.min(bot(k - 1), bot(k)) - B) * m : B)
        reach.push(g / 2 + m * rMax)
    }

    const endFactor = (ex, gap, h) => {
        const g = clamp(gap / (2 * rMax), 0, 1)
        return ex >= 0 ? Math.max(g, clamp(1 - h / rMax, 0, 1)) : g
    }
    const es = eL * endFactor(eL, gaps[0], bot(0) - B)
    const ee = eR * endFactor(eR, gaps[n], bot(n - 1) - B)
    const esA = Math.abs(es)
    const eeA = Math.abs(ee)

    if (B - T > 0.5)
        out.pills.push({ l: L, r: R, bot: B, top: T,
                         rtl: capL ? 0 : ec, rtr: capR ? 0 : ec,
                         rbl: Math.max(0, es), rbr: Math.max(0, ee) })
    if (es < -0.01)
        out.flares.push({ x: L, y: B, r: esA, mode: 1 })
    if (ee < -0.01)
        out.flares.push({ x: R, y: B, r: eeA, mode: 3 })
    if (capL) {
        const r = Math.min(rMax, Math.max(0, bot(0) - T) / 2, Math.max(0, ((o.roomL ?? Infinity) - 2) / 2))
        if (r > 0.01)
            out.flares.push({ x: L, y: T, r: r, mode: 3 })
    }
    if (capR) {
        const r = Math.min(rMax, Math.max(0, bot(n - 1) - T) / 2, Math.max(0, ((o.roomR ?? Infinity) - 2) / 2))
        if (r > 0.01)
            out.flares.push({ x: R, y: T, r: r, mode: 1 })
    }

    const share = []
    for (let k = 0; k <= n; k++) {
        const prevW = k > 0 ? bs[k - 1].w : Infinity
        const nextW = k < n ? bs[k].w : Infinity
        share.push(Math.min(prevW, nextW) / 2)
    }

    const lefts = []
    const entry = []
    for (let i = 0; i < n; i++) {
        lefts.push(i === 0 ? Math.max(bs[i].x, L + esA) : bs[i].x)
        entry.push(Math.min(rMax, Math.max(0, bot(i) - lines[i]) / 2, reach[i], share[i]))
    }

    const sideTouch = px => Math.max(clamp(1 - (px - touchL) / rMax, 0, 1),
                                     clamp(1 - (touchR - px) / rMax, 0, 1))

    const factor = (edgeTouch, b, px, melt, ef) => {
        const fE = ef * edgeTouch
        const fB = o.bottomFlare * clamp(1 - (o.screenH - b) / rMax, 0, 1)
            * (melt ? 1 : sideTouch(px))
        return { s: 1 - 2 * Math.max(fE, fB), vertical: fE >= fB }
    }

    let curX = L + esA
    for (let i = 0; i < n; i++) {
        const b = bs[i]
        const y = bot(i)
        const x = lefts[i]
        const limit = i === n - 1 ? R - eeA : lefts[i + 1] - entry[i + 1]
        const X = Math.max(x, Math.min(b.x + b.w, limit))
        const w = Math.max(0, X - x)
        const lineL = lines[i]
        const lineR = lines[i + 1]
        const hL = Math.max(0, y - lineL)
        const hR = Math.max(0, y - lineR)
        const raL = Math.max(0, Math.min(entry[i], x - curX))
        const raR = Math.min(rMax, hR / 2, reach[i + 1], share[i + 1])
        const melt = b.melt === true

        let rl = 0
        let rr = 0
        const cl = factor(i === 0 ? clamp(1 - gaps[0] / rMax, 0, 1) : 0, y, x, melt, flareL)
        if (cl.s >= 0) {
            rl = Math.min(rMax, hL - raL, w / 2) * cl.s
        } else {
            const r = cl.vertical ? Math.min(rMax * -cl.s, w)
                                  : Math.min(rMax, hL - raL) * -cl.s
            if (r > 0.01)
                out.flares.push({ x: x, y: y, r: r, mode: cl.vertical ? 1 : 2 })
        }
        const cr = factor(i === n - 1 ? clamp(1 - gaps[n] / rMax, 0, 1) : 0, y, X, melt, flareR)
        if (cr.s >= 0) {
            rr = Math.min(rMax, hR - raR, w / 2) * cr.s
        } else {
            const r = cr.vertical ? Math.min(rMax * -cr.s, w)
                                  : Math.min(rMax, hR - raR) * -cr.s
            if (r > 0.01)
                out.flares.push({ x: X, y: y, r: r, mode: cr.vertical ? 3 : 4 })
        }

        out.segs.push({ id: b.id, x: x, w: w, bot: y, top: T, rl: Math.max(0, rl), rr: Math.max(0, rr),
                        lineL: lineL, raL: raL > 0.01 ? raL : 0,
                        lineR: lineR, raR: raR > 0.01 ? raR : 0,
                        gap: i < n - 1 ? Math.max(0, lefts[i + 1] - X) : -1 })
        curX = X + raR
    }

    out.flares.sort((a, b) => b.r - a.r)
    return out
}

function sdfData(bs, o) {
    return sdfShape(bs, o, sdfEmpty())
}

function sdfIslands(groups, o, into) {
    const out = into || sdfEmpty()
    const T = o.top
    const B = o.top + o.bridge
    const e = clamp(o.endR, 0, (B - T) / 2)
    for (const g of groups) {
        if (!g || !g.length)
            continue
        let L = Infinity
        let R = -Infinity
        for (const s of g) {
            L = Math.min(L, s.x)
            R = Math.max(R, s.x + s.w)
        }
        if (R - L < 0.5)
            continue
        if (g.length === 1 && g[0].bot > B + 0.01) {
            const seg = g[0]
            const bot = Math.max(B, seg.bot)
            const t = clamp((bot - B) / o.rMax, 0, 1)
            const half = (R - L) / 2
            const rTop = Math.min(e, half)
            const rBot = Math.max(0, Math.min(e + (o.rMax - e) * t, half, (bot - T) - rTop))
            out.pills.push({ l: L, r: R, bot: bot, top: T, rtl: rTop, rtr: rTop, rbl: rBot, rbr: rBot })
            continue
        }
        sdfShape(g, Object.assign({}, o, { left: L, right: R }), out)
    }
    return out
}

function sdfTabs(ts, segs, o) {
    const out = []
    const rMax = o.rMax
    for (let t of ts) {
        if (t.floating) {
            const h = t.fbot - t.ftop
            if (t.gw < 0.5 || h < 0.5)
                continue
            const r = Math.min(rMax, t.gw / 2, h / 2)
            out.push({
                x: t.gx, w: t.gw, bot: t.fbot, top: t.ftop,
                rtl: r, rtr: r, rbl: r, rbr: r,
                lineL: -1, rfL: 0, lineR: -1, rfR: 0,
                flL: 0, mL: 0, flR: 0, mR: 0,
                conL: 0, onL: 0, conR: 0, onR: 0,
                goo: 1, k: t.k,
                hostL: t.bx, hostR: t.bx + t.bw, hostT: t.top, hostB: t.top + o.barH
            })
            continue
        }
        const pill = t.pill === true
        const T = t.top
        const B = pill ? T + o.barH : T + t.bridge
        const strip = !pill && t.bridge > 0.5
        const e = pill ? o.barH / 2 : 0
        const edgeFlare = pill ? 0 : clamp(-t.endR / rMax, 0, 1)
        const melt = pill ? 0 : o.bottomFlare * 1
        if (t.w < 0.5 || t.bot <= B + 0.01)
            continue
        const blockCorner = pill ? e : Math.min(rMax, Math.max(0, t.bb - B) / 2)
        const pull = rMax + blockCorner
        const dl = t.x - t.bx
        const dr = t.bx + t.bw - (t.x + t.w)
        const x0 = dl > 0.5 && dl < pull ? t.bx : t.x
        const x1 = dr > 0.5 && dr < pull ? t.bx + t.bw : t.x + t.w
        t = Object.assign({}, t, { x: x0, w: x1 - x0 })
        const half = t.w / 2
        const X = t.x + t.w
        const sideOf = (edge, blockEdge, inward) => {
            const d = (edge - blockEdge) * inward
            if (d > 0.5)
                return { line: t.bb, room: d }
            const onStrip = !(edge < t.stripL - 0.5 || edge > t.stripR + 0.5)
            if (d < -0.5 && strip && onStrip)
                return { line: B, room: Infinity }
            if (d < -0.5 && strip)
                return { line: T, room: Infinity }
            return { line: -1, room: 0 }
        }
        const near = (edge, dir) => {
            let best = null
            for (const s of segs) {
                if (Math.abs(s.x - t.bx) < 0.5 && Math.abs(s.w - t.bw) < 0.5)
                    continue
                const reach = dir < 0 ? s.x + s.w : s.x
                const g = (edge - reach) * -dir
                const covers = dir < 0 ? s.x < edge : s.x + s.w > edge
                if (!covers || g > rMax)
                    continue
                if (!best || g < best.g)
                    best = { g: g, s: s, reach: reach }
            }
            if (!best)
                return null
            const m = best.g <= 0 ? 1 : smooth((rMax - best.g) / rMax)
            const room = dir < 0 ? edge - best.s.x : best.s.x + best.s.w - edge
            return { m: m, line: B + (best.s.bot - B) * m, room: room,
                     con: dir < 0 ? Math.min(best.reach, edge) - rMax : Math.max(best.reach, edge) + rMax }
        }
        const nl = near(t.x, -1)
        const nr = near(X, 1)
        const sl = nl && nl.m > 0.001 ? { line: nl.line, room: nl.room } : sideOf(t.x, t.bx, 1)
        const sr = nr && nr.m > 0.001 ? { line: nr.line, room: nr.room } : sideOf(X, t.bx + t.bw, -1)
        const mL = nl ? nl.m : 0
        const mR = nr ? nr.m : 0
        const fillet = s => s.line < 0 ? 0 : Math.max(0, Math.min(rMax, (t.bot - s.line) / 2, s.room))
        const corner = s => {
            if (pill && s.line < 0)
                return Math.min(e + (rMax - e) * clamp((t.bot - B) / rMax, 0, 1), half)
            const from = s.line < 0 ? B : s.line
            return Math.min(rMax, half, Math.max(0, t.bot - from) / 2)
        }
        const fB = melt * clamp(1 - (o.screenH - t.bot) / rMax, 0, 1)
        const flare = (edgeTouch, r0, vMode, hMode) => {
            const fE = edgeFlare * edgeTouch
            const s = 1 - 2 * Math.max(fE, fB)
            if (s >= 0)
                return { corner: r0 * s, r: 0, mode: 0 }
            const vertical = fE >= fB
            const r = vertical ? Math.min(rMax * -s, t.w) : Math.min(rMax, t.bot - T) * -s
            return { corner: 0, r: r > 0.01 ? r : 0, mode: vertical ? vMode : hMode }
        }
        const fl = flare(clamp(1 - (t.x - t.left) / rMax, 0, 1), corner(sl), 1, 2)
        const fr = flare(clamp(1 - (t.right - X) / rMax, 0, 1), corner(sr), 3, 4)
        const top = pill ? Math.min(e, half) : 0
        out.push({
            x: t.x, w: t.w, bot: t.bot, top: T,
            rtl: top * (1 - mL), rtr: top * (1 - mR), rbl: fl.corner, rbr: fr.corner,
            lineL: sl.line, rfL: fillet(sl), lineR: sr.line, rfR: fillet(sr),
            flL: fl.r, mL: fl.mode, flR: fr.r, mR: fr.mode,
            conL: mL > 0.001 ? nl.con : 0, onL: mL > 0.001 ? 1 : 0,
            conR: mR > 0.001 ? nr.con : 0, onR: mR > 0.001 ? 1 : 0
        })
    }
    return out
}
