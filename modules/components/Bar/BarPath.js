.pragma library

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function smooth(t) {
    const c = clamp(t, 0, 1)
    return c * c * (3 - 2 * c)
}

function sdfEmpty() {
    return { pills: [], segs: [], flares: [], tabs: [] }
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
    const flushL = o.flushL === true
    const flushR = o.flushR === true
    const eL = capL ? eCap : flushL ? 0 : e
    const eR = capR ? eCap : flushR ? 0 : e
    const edgeFlare = clamp(-o.endR / rMax, 0, 1)
    const flareL = capL || flushL ? 0 : o.screenL === true ? 1 : edgeFlare
    const flareR = capR || flushR ? 0 : o.screenR === true ? 1 : edgeFlare
    const touchL = capL ? -Infinity : L
    const touchR = capR ? Infinity : R
    const bot = i => Math.max(B, bs[i].bot)
    const capY = Math.max(T, o.capTop ?? T)

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
        const r = Math.min(rMax, Math.max(0, bot(0) - capY) / 2, Math.max(0, ((o.roomL ?? Infinity) - 2) / 2, o.capRL ?? 0))
        if (r > 0.01)
            out.flares.push({ x: L, y: capY, r: r, mode: 3 })
    }
    if (capR) {
        const r = Math.min(rMax, Math.max(0, bot(n - 1) - capY) / 2, Math.max(0, ((o.roomR ?? Infinity) - 2) / 2, o.capRR ?? 0))
        if (r > 0.01)
            out.flares.push({ x: R, y: capY, r: r, mode: 1 })
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

    const factor = (edgeTouch, b, px, ef) => {
        const fE = ef * edgeTouch
        const fB = o.bottomFlare * clamp(1 - (o.screenH - b) / rMax, 0, 1)
            * sideTouch(px)
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
        const vL = Math.max(hL, b.vh ?? 0)
        const vR = Math.max(hR, b.vh ?? 0)
        const risen = r => b.vh ? Math.min(r, Math.max(0, Math.min(hL, hR) - Math.min(rMax, w / 2))) : r
        const raL = risen(Math.max(0, Math.min(entry[i], x - curX)))
        const raR = risen(Math.min(rMax, hR / 2, reach[i + 1], share[i + 1]))

        let rl = 0
        let rr = 0
        const cl = factor(i === 0 ? clamp(1 - gaps[0] / rMax, 0, 1) : 0, y, x, flareL)
        if (cl.s >= 0) {
            rl = Math.min(rMax, vL - raL, w / 2) * cl.s
        } else {
            const r = cl.vertical ? Math.min(rMax * -cl.s, w)
                                  : Math.min(rMax, hL - raL) * -cl.s
            if (r > 0.01)
                out.flares.push({ x: x, y: y, r: r, mode: cl.vertical ? 1 : 2 })
        }
        const cr = factor(i === n - 1 ? clamp(1 - gaps[n] / rMax, 0, 1) : 0, y, X, flareR)
        if (cr.s >= 0) {
            rr = Math.min(rMax, vR - raR, w / 2) * cr.s
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
        const cs = g.length === 1 ? o.corners : null
        if (cs && g[0].bot <= B + 0.01) {
            const k = v => Math.max(0, Math.min(v, (R - L) / 2, (B - T) / 2))
            out.pills.push({ l: L, r: R, bot: B, top: T, rtl: k(cs.nl), rtr: k(cs.nr), rbl: k(cs.fl), rbr: k(cs.fr) })
            continue
        }
        if (g.length === 1 && g[0].bot > B + 0.01) {
            const seg = g[0]
            const bot = Math.max(B, seg.bot)
            const t = clamp((bot - B) / o.rMax, 0, 1)
            const half = (R - L) / 2
            const rTop = Math.min(e, half)
            const rBot = Math.max(0, Math.min(e + (o.rMax - e) * t, half, (bot - T) - rTop))
            const tl = cs ? Math.min(cs.nl, half) : rTop
            const tr = cs ? Math.min(cs.nr, half) : rTop
            out.pills.push({ l: L, r: R, bot: bot, top: T, rtl: tl, rtr: tr, rbl: rBot, rbr: rBot })
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
        const rC = t.rad ?? rMax
        if (t.floating) {
            const h = t.fbot - t.ftop
            if (t.gw < 0.5 || h < 0.5)
                continue
            const r = Math.min(rC, t.gw / 2, h / 2)
            out.push({
                id: t.id,
                x: t.gx, w: t.gw, bot: t.fbot, top: t.ftop,
                rtl: r, rtr: r, rbl: r, rbr: r,
                lineL: -1, rfL: 0, lineR: -1, rfR: 0,
                flL: 0, mL: 0, flR: 0, mR: 0,
                conL: 0, onL: 0, conR: 0, onR: 0,
                goo: 1, k: t.k,
                hostL: t.hx, hostR: t.hx + t.hw, hostT: t.top + t.hy, hostB: t.top + t.hy + t.hh,
                hostRad: t.hr
            })
            continue
        }
        if (t.merged) {
            const pillTab = t.pill === true
            const nb = t.top + o.barH
            const gap = t.gap ?? 0
            const bt = nb + gap
            const e = t.pr ?? o.barH / 2
            const et = pillTab ? e : 0
            const eb = pillTab ? e : Math.min(rMax, e)
            const hb = t.bot - bt
            if (t.w < 0.5 || hb <= 0.01)
                continue
            const bl = t.bodyL ?? t.bx
            const br = t.bodyR ?? t.bx + t.bw
            let x0 = t.x
            let x1 = t.x + t.w
            if (Math.abs(x0 - bl) < 4)
                x0 = bl
            if (Math.abs(x1 - br) < 4)
                x1 = br
            const side = (ext) => {
                if (ext > 0.5) {
                    const rf = Math.max(0, Math.min(rMax, bt - t.top - et, ext / 2, hb / 2))
                    return { line: bt, rf: -rf, top: Math.max(0, Math.min(rC, ext - rf, hb / 2)) }
                }
                if (ext < -0.5)
                    return { line: nb, rf: Math.max(0, Math.min(rMax, -ext - eb, (t.bot - nb) / 2)), top: 0 }
                return { line: -1, rf: 0, top: 0 }
            }
            const sl = side(bl - x0)
            const sr = side(x1 - br)
            const bc = Math.min(rC, (x1 - x0) / 2, hb / 2)
            out.push({
                id: t.id,
                x: x0, w: x1 - x0, bot: t.bot, top: t.top,
                rtl: sl.top, rtr: sr.top, rbl: bc, rbr: bc,
                lineL: sl.line, rfL: sl.rf, lineR: sr.line, rfR: sr.rf,
                flL: 0, mL: 0, flR: 0, mR: 0,
                conL: gap, onL: 0, conR: 0, onR: 0,
                merged: 1, mL0: bl, mR0: br, nb: nb, e: pillTab ? e : -eb
            })
            continue
        }
        const pill = t.pill === true
        const T = t.top
        const B = pill ? T + o.barH : T + t.bridge
        const capY = Math.max(T, o.capTop ?? T)
        const e = pill ? (t.pr ?? o.barH / 2) : 0
        const edgeFlare = pill ? 0 : clamp(-t.endR / rMax, 0, 1)
        const melt = pill ? 0 : o.bottomFlare * 1
        if (t.w < 0.5 || t.bot <= B + 0.01)
            continue
        const blockCorner = pill ? e : Math.min(rMax, Math.max(0, t.bb - B) / 2)
        const pull = rMax + blockCorner
        const dl = t.x - t.bx
        const dr = t.bx + t.bw - (t.x + t.w)
        const x0 = dl > 0.5 && dl < pull && t.bx >= (t.limL ?? -Infinity) - 0.5 ? t.bx : t.x
        const x1 = dr > 0.5 && dr < pull && t.bx + t.bw <= (t.limR ?? Infinity) + 0.5 ? t.bx + t.bw : t.x + t.w
        t = Object.assign({}, t, { x: x0, w: x1 - x0 })
        const half = t.w / 2
        const X = t.x + t.w
        const sideOf = (edge, blockEdge, inward) => {
            const d = (edge - blockEdge) * inward
            if (d > 0.5)
                return { line: t.bb, room: d }
            const onStrip = !(edge < t.stripL - 0.5 || edge > t.stripR + 0.5)
            if (d < -0.5 && !pill)
                return { line: onStrip ? B : capY, room: Infinity }
            return { line: -1, room: 0 }
        }
        const near = (edge, dir) => {
            let best = null
            for (const s of segs) {
                if (Math.abs(s.x - t.bx) < 0.5 && Math.abs(s.w - t.bw) < 0.5)
                    continue
                if (t.run !== undefined && s.run !== undefined && s.run !== t.run)
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
        const sink = s => !pill && s.line >= 0 && s.line - T < 0.5 && (o.sink ?? 0) > 0 && fillet(s) > 0.5 ? o.sink : 0
        const kL = mL > 0.001 ? 0 : sink(sl)
        const kR = mR > 0.001 ? 0 : sink(sr)
        const corner = s => {
            if (pill && s.line < 0)
                return Math.min(e + (rC - e) * clamp((t.bot - B) / rMax, 0, 1), half)
            const from = s.line < 0 ? B : s.line
            return Math.min(rC, half, Math.max(0, t.bot - from) / 2)
        }
        const farHit = !pill && o.farMerge === true && t.bot >= o.screenH - 0.5
        const fB = farHit ? 0 : melt * clamp(1 - (o.screenH - t.bot) / rMax, 0, 1)
        const flare = (edgeTouch, r0, vMode, hMode, border) => {
            const fE = (border ? 1 : edgeFlare) * edgeTouch
            const s = 1 - 2 * Math.max(fE, fB)
            if (s >= 0)
                return { corner: r0 * s, r: 0, mode: 0 }
            const vertical = fE >= fB
            const r = vertical ? Math.min(rMax * -s, t.w) : Math.min(rMax, t.bot - T) * -s
            return { corner: 0, r: r > 0.01 ? r : 0, mode: vertical ? vMode : hMode }
        }
        const stripHitL = !pill && o.sideStripL === true && t.x - t.left < 0.5
        const stripHitR = !pill && o.sideStripR === true && t.right - X < 0.5
        const none = { corner: 0, r: 0, mode: 0 }
        const fl = stripHitL ? none : flare(clamp(1 - (t.x - t.left) / rMax, 0, 1), farHit ? 0 : corner(sl), 1, 2, !pill && t.screenL === true)
        const fr = stripHitR ? none : flare(clamp(1 - (t.right - X) / rMax, 0, 1), farHit ? 0 : corner(sr), 3, 4, !pill && t.screenR === true)
        const top = pill ? Math.min(e, half) : 0
        const gx = t.x - (stripHitL ? 2 : 0)
        const gw = t.w + (stripHitL ? 2 : 0) + (stripHitR ? 2 : 0)
        out.push({
            id: t.id,
            x: gx, w: gw, bot: farHit ? t.bot + 2 : t.bot, top: T,
            rtl: top * (1 - mL), rtr: top * (1 - mR), rbl: fl.corner, rbr: fr.corner,
            lineL: sl.line, rfL: fillet(sl), lineR: sr.line, rfR: fillet(sr), sinkL: kL, sinkR: kR,
            flL: fl.r, mL: fl.mode, flR: fr.r, mR: fr.mode,
            conL: mL > 0.001 ? nl.con : 0, onL: mL > 0.001 ? 1 : 0,
            conR: mR > 0.001 ? nr.con : 0, onR: mR > 0.001 ? 1 : 0
        })
    }
    return out
}

function planPush(items, gaps, o) {
    const plan = { push: {}, shift: {}, hide: {} }
    const n = items.length
    for (let k = 0; k < n; k++) {
        const a = items[k]
        if (!a.panel || a.panel.w < 0.5)
            continue
        const live = a.panel.live
        let l = a.panel.l
        const w = a.panel.w
        const movable = b => !b.open && (b.pill || a.pill || b.run !== a.run)
        const left = []
        for (let i = k - 1; i >= 0 && movable(items[i]); i--)
            left.push(i)
        const right = []
        for (let i = k + 1; i < n && movable(items[i]); i++)
            right.push(i)
        const clearL = o.pairClear && k > 0 ? gaps[k - 1] : o.clear
        const clearR = o.pairClear && k < n - 1 ? gaps[k] : o.clear
        const gapL = (j, tight) => tight ? o.minGap : gaps[left[j + 1]]
        const gapR = (j, tight) => tight ? o.minGap : gaps[right[j]]
        const packL = (edge, tight) => {
            const xs = []
            let cur = edge - clearL
            for (let j = 0; j < left.length; j++) {
                const b = items[left[j]]
                const nx = Math.min(b.x, cur - b.w)
                xs.push(nx)
                cur = nx - (j + 1 < left.length ? gapL(j, tight) : 0)
            }
            return xs
        }
        const packR = (edge, tight) => {
            const xs = []
            let cur = edge + clearR
            for (let j = 0; j < right.length; j++) {
                const b = items[right[j]]
                const nx = Math.max(b.x, cur)
                xs.push(nx)
                cur = nx + b.w + (j + 1 < right.length ? gapR(j, tight) : 0)
            }
            return xs
        }
        const lastL = left.length ? items[left[left.length - 1]] : null
        const lastR = right.length ? items[right[right.length - 1]] : null
        const floorL = lastL ? Math.min(o.spanStart, lastL.x) : o.spanStart
        const ceilR = lastR ? Math.max(o.spanEnd, lastR.x + lastR.w) : o.spanEnd
        const defL = xs => xs.length ? floorL - xs[xs.length - 1] : 0
        const defR = xs => xs.length ? xs[xs.length - 1] + lastR.w - ceilR : 0
        if (live) {
            let s = 0
            const dl = defL(packL(l, false))
            const dr = defR(packR(l + w, false))
            if (dl > 0.5 && dr <= 0.5) {
                s = dl
                const back = defR(packR(l + w + s, false))
                if (back > 0.5)
                    s = Math.max(0, s - back)
            } else if (dr > 0.5 && dl <= 0.5) {
                s = -dr
                const back = defL(packL(l + s, false))
                if (back > 0.5)
                    s = Math.min(0, s + back)
            }
            const minO = Math.min(24, a.w / 2)
            const lo = Math.max(o.spanStart - l, a.absX + minO - (l + w))
            const hi = Math.min(o.spanEnd - (l + w), a.absX + a.w - minO - l)
            s = lo <= hi ? Math.max(lo, Math.min(hi, s)) : 0
            if (Math.abs(s) > 0.5)
                plan.shift[a.id] = s
            l += s
        }
        let r = l + w
        if (live) {
            const dL = l - a.absX
            if (dL > 0.5 && dL < a.reach && a.absX >= o.spanStart - 0.5)
                l = a.absX
            const dR = a.absX + a.w - r
            if (dR > 0.5 && dR < a.reach && a.absX + a.w <= o.spanEnd + 0.5)
                r = a.absX + a.w
        }
        for (const side of [-1, 1]) {
            const chain = side < 0 ? left : right
            if (!chain.length)
                continue
            const pack = side < 0 ? packL : packR
            const def = side < 0 ? defL : defR
            const edge = side < 0 ? l : r
            let xs = pack(edge, false)
            if (def(xs) > 0.5)
                xs = pack(edge, true)
            if (def(xs) > 0.5) {
                let cur = side < 0 ? floorL : ceilR
                for (let j = chain.length - 1; j >= 0; j--) {
                    const b = items[chain[j]]
                    if (side < 0) {
                        xs[j] = Math.max(cur, xs[j])
                        cur = xs[j] + b.w + o.minGap
                        if (xs[j] + b.w > l - o.minGap)
                            plan.hide[b.id] = true
                    } else {
                        xs[j] = Math.min(cur - b.w, xs[j])
                        cur = xs[j] - o.minGap
                        if (xs[j] < r + o.minGap)
                            plan.hide[b.id] = true
                    }
                }
            }
            for (let j = 0; j < chain.length; j++) {
                const b = items[chain[j]]
                const d = xs[j] - b.x
                if (Math.abs(d) <= 0.5 || plan.hide[b.id])
                    continue
                const prev = plan.push[b.id] ?? 0
                plan.push[b.id] = side < 0 ? Math.min(prev, d) : Math.max(prev, d)
            }
        }
    }
    return plan
}
