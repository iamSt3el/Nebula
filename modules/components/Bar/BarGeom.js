.pragma library

const SIDES = ["top", "bottom", "left", "right"]

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function mergeReach(k) {
    return 0.586 * Math.max(0, k)
}

function squareness(gap, k) {
    const reach = mergeReach(k) / 2
    if (reach <= 0.001)
        return gap > 0.5 ? 1 : 0
    return clamp(gap / reach, 0, 1)
}

function vertical(side) {
    return side === "left" || side === "right"
}

function holeLength(side, hole) {
    return vertical(side) ? hole.b - hole.t : hole.r - hole.l
}

function pack(list, from, dir, gapOf) {
    const out = []
    let a = from
    for (let i = 0; i < list.length; i++) {
        const b = list[i]
        if (i > 0)
            a += dir * gapOf(dir > 0 ? list[i - 1] : b, dir > 0 ? b : list[i - 1])
        const a0 = dir > 0 ? a : a - b.len
        out.push({ src: b, a0: a0, a1: a0 + b.len })
        a += dir * b.len
    }
    return dir > 0 ? out : out.reverse()
}

function layoutEdge(edge) {
    const side = edge.side
    const hole = edge.hole
    const L = holeLength(side, hole)
    const k = edge.k ?? 14
    const thick = edge.thick
    const endGap = edge.endGap ?? 0
    const gapOf = (a, b) => b.gapBefore ?? edge.blockGap ?? 0
    const secs = edge.sections || {}

    const start = pack(secs.start || [], endGap, 1, gapOf)
    const end = pack((secs.end || []).slice().reverse(), L - endGap, -1, gapOf)
    const centerLen = (secs.center || []).reduce((s, b, i) => s + b.len + (i > 0 ? gapOf(secs.center[i - 1], b) : 0), 0)
    const center = pack(secs.center || [], (L - centerLen) / 2, 1, gapOf)

    const runs = [start, center, end].filter(r => r.length)
    const flat = []
    for (const r of runs)
        for (const it of r)
            flat.push(it)

    const fill = clamp(edge.fill ?? 0, 0, 1)
    for (let i = 0; i + 1 < runs.length; i++) {
        const a = runs[i][runs[i].length - 1]
        const b = runs[i + 1][0]
        const span = b.a0 - a.a1
        if (span <= 0 || fill <= 0)
            continue
        const reach = fill * span / 2
        a.a1 += reach
        b.a0 -= reach
    }

    const placed = flat.map((it, i) => {
        const b = it.src
        const near = b.edgeGap ?? edge.edgeGap ?? 0
        const r = b.radius ?? edge.radius ?? 0
        const prev = i > 0 ? flat[i - 1] : null
        const next = i + 1 < flat.length ? flat[i + 1] : null
        const gapL = prev ? it.a0 - prev.a1 : it.a0
        const gapR = next ? next.a0 - it.a1 : L - it.a1
        return { id: b.id, a0: it.a0, a1: it.a1, near: near, far: near + thick, r: r, gapL: gapL, gapR: gapR,
                 sideL: prev ? "block" : "end", sideR: next ? "block" : "end" }
    })

    const out = []
    for (const p of placed) {
        const sNear = squareness(p.near, k)
        const sL = squareness(p.gapL, k)
        const sR = squareness(p.gapR, k)
        const corners = {
            nearL: p.r * Math.min(sNear, sL),
            nearR: p.r * Math.min(sNear, sR),
            farL: p.r * sL,
            farR: p.r * sR
        }
        out.push(Object.assign({ id: p.id, touchEdge: p.near <= 0.5, gapL: p.gapL, gapR: p.gapR },
                               toScreen(side, hole, p.a0, p.a1, p.near, p.far, corners)))
    }

    const parent = out.map((_, i) => i)
    const find = i => parent[i] === i ? i : (parent[i] = find(parent[i]))
    for (let i = 0; i + 1 < placed.length; i++)
        if (placed[i].gapR <= 0.5)
            parent[find(i)] = find(i + 1)
    const groups = {}
    out.forEach((b, i) => {
        const g = find(i)
        b.group = out[g].id
        ;(groups[b.group] = groups[b.group] || []).push(b.id)
    })

    const shapes = []
    let run = null
    placed.forEach((p, i) => {
        const flush = run && placed[i - 1].gapR <= 0.5 && Math.abs(p.near - run.near) < 0.01 && Math.abs(p.far - run.far) < 0.01
        if (flush) {
            run.a1 = p.a1
            run.last = i
        } else {
            if (run)
                shapes.push(run)
            run = { a0: p.a0, a1: p.a1, near: p.near, far: p.far, first: i, last: i }
        }
    })
    if (run)
        shapes.push(run)
    const shapeRects = shapes.map(sh => {
        const f = out[sh.first]
        const l = out[sh.last]
        const cf = cornersOf(side, f)
        const cl = cornersOf(side, l)
        return toScreen(side, hole, sh.a0, sh.a1, sh.near, sh.far,
                        { nearL: cf.nearL, farL: cf.farL, nearR: cl.nearR, farR: cl.farR })
    })
    return { side: side, blocks: out, groups: Object.values(groups), shapes: shapeRects }
}

function cornersOf(side, b) {
    if (side === "bottom")
        return { nearL: b.rbl, nearR: b.rbr, farL: b.rtl, farR: b.rtr }
    if (side === "top")
        return { nearL: b.rtl, nearR: b.rtr, farL: b.rbl, farR: b.rbr }
    if (side === "left")
        return { nearL: b.rtl, nearR: b.rbl, farL: b.rtr, farR: b.rbr }
    return { nearL: b.rtr, nearR: b.rbr, farL: b.rtl, farR: b.rbl }
}

function toScreen(side, hole, a0, a1, near, far, c) {
    if (side === "bottom")
        return { x: hole.l + a0, y: hole.b - far, w: a1 - a0, h: far - near,
                 rtl: c.farL, rtr: c.farR, rbl: c.nearL, rbr: c.nearR }
    if (side === "top")
        return { x: hole.l + a0, y: hole.t + near, w: a1 - a0, h: far - near,
                 rtl: c.nearL, rtr: c.nearR, rbl: c.farL, rbr: c.farR }
    if (side === "left")
        return { x: hole.l + near, y: hole.t + a0, w: far - near, h: a1 - a0,
                 rtl: c.nearL, rbl: c.nearR, rtr: c.farL, rbr: c.farR }
    return { x: hole.r - far, y: hole.t + a0, w: far - near, h: a1 - a0,
             rtr: c.nearL, rbr: c.nearR, rtl: c.farL, rbl: c.farR }
}

function blobsOf(layouts) {
    const out = []
    for (const l of layouts)
        for (const b of l.shapes)
            out.push({ x: b.x, y: b.y, w: b.w, h: b.h, rtl: b.rtl, rtr: b.rtr, rbl: b.rbl, rbr: b.rbr })
    return out
}

function styleOf(layout) {
    const bs = layout.blocks
    if (!bs.length)
        return ""
    const touching = bs.filter(b => b.touchEdge).length
    if (touching === bs.length && layout.groups.length === 1 && bs[0].gapL <= 0.5 && bs[bs.length - 1].gapR <= 0.5)
        return "full"
    if (touching === bs.length)
        return "stepped"
    if (touching === 0)
        return layout.groups.length < bs.length ? "merged" : "pill"
    return "mixed"
}

function squareAll(rects, hole, k) {
    const covers = (lo, hi, v) => lo <= v + 0.5 && v - 0.5 <= hi
    const gapAt = (a, i, cx, cy, horiz, dir) => {
        let g = horiz ? (dir > 0 ? hole.b - (a.y + a.h) : a.y - hole.t) : (dir > 0 ? hole.r - (a.x + a.w) : a.x - hole.l)
        for (let j = 0; j < rects.length; j++) {
            if (j === i)
                continue
            const b = rects[j]
            if (b.solo)
                continue
            if (horiz) {
                if (!covers(b.x, b.x + b.w, cx))
                    continue
                const d = dir > 0 ? b.y - (a.y + a.h) : a.y - (b.y + b.h)
                const past = dir > 0 ? b.y + b.h > a.y + a.h + 0.5 : b.y < a.y - 0.5
                if (past && d > -0.5 * a.h)
                    g = Math.min(g, Math.max(0, d) + (b.clear ?? 0) * mergeReach(b.k ?? k))
            } else {
                if (!covers(b.y, b.y + b.h, cy))
                    continue
                const d = dir > 0 ? b.x - (a.x + a.w) : a.x - (b.x + b.w)
                const past = dir > 0 ? b.x + b.w > a.x + a.w + 0.5 : b.x < a.x - 0.5
                if (past && d > -0.5 * a.w)
                    g = Math.min(g, Math.max(0, d) + (b.clear ?? 0) * mergeReach(b.k ?? k))
            }
        }
        return g
    }
    return rects.map((a, i) => {
        if (a.solo)
            return Object.assign({}, a)
        const r = a.r ?? 0
        const base = { tl: a.rtl ?? r, tr: a.rtr ?? r, bl: a.rbl ?? r, br: a.rbr ?? r }
        const L = a.x, R = a.x + a.w, T = a.y, B = a.y + a.h
        const top = (cx) => gapAt(a, i, cx, T, true, -1)
        const bot = (cx) => gapAt(a, i, cx, B, true, 1)
        const lef = (cy) => gapAt(a, i, L, cy, false, -1)
        const rig = (cy) => gapAt(a, i, R, cy, false, 1)
        const sq = g => squareness(g, a.k ?? k)
        return Object.assign({}, a, {
            rtl: base.tl * Math.min(sq(top(L)), sq(lef(T))),
            rtr: base.tr * Math.min(sq(top(R)), sq(rig(T))),
            rbl: base.bl * Math.min(sq(bot(L)), sq(lef(B))),
            rbr: base.br * Math.min(sq(bot(R)), sq(rig(B)))
        })
    })
}

function mergeFlush(rects) {
    const out = rects.map(r => Object.assign({}, r))
    const near = (a, b) => Math.abs(a - b) <= 0.5
    let merged = true
    while (merged) {
        merged = false
        for (let i = 0; i < out.length && !merged; i++) {
            for (let j = i + 1; j < out.length && !merged; j++) {
                const a = out[i]
                const b = out[j]
                if (a.solo || b.solo || (a.gooKey && b.gooKey && a.gooKey !== b.gooKey))
                    continue
                if ((a.k ?? 0) !== (b.k ?? 0) || !near(a.clear ?? 0, b.clear ?? 0) || !near(a.tint ?? 0, b.tint ?? 0)
                        || (a.tintRgb ?? 0) !== (b.tintRgb ?? 0))
                    continue
                const rowA = near(a.y, b.y) && near(a.h, b.h)
                const colA = near(a.x, b.x) && near(a.w, b.w)
                let joined = null
                if (rowA && a.x + a.w >= b.x - 0.5 && b.x + b.w >= a.x - 0.5) {
                    const l = a.x <= b.x ? a : b
                    const r = a.x + a.w >= b.x + b.w ? a : b
                    const x = Math.min(a.x, b.x)
                    joined = Object.assign({}, a, { gooKey: a.gooKey ?? b.gooKey, gooK: a.gooK ?? b.gooK, x: x, w: Math.max(a.x + a.w, b.x + b.w) - x,
                                                   rtl: l.rtl, rbl: l.rbl, rtr: r.rtr, rbr: r.rbr })
                } else if (colA && a.y + a.h >= b.y - 0.5 && b.y + b.h >= a.y - 0.5) {
                    const t = a.y <= b.y ? a : b
                    const d = a.y + a.h >= b.y + b.h ? a : b
                    const y = Math.min(a.y, b.y)
                    joined = Object.assign({}, a, { gooKey: a.gooKey ?? b.gooKey, gooK: a.gooK ?? b.gooK, y: y, h: Math.max(a.y + a.h, b.y + b.h) - y,
                                                   rtl: t.rtl, rtr: t.rtr, rbl: d.rbl, rbr: d.rbr })
                }
                if (joined) {
                    out[i] = joined
                    out.splice(j, 1)
                    merged = true
                }
            }
        }
    }
    return out
}

function snapFaces(rects) {
    const out = rects.map(r => Object.assign({}, r))
    const touching = (a, b) => Math.max(a.x - (b.x + b.w), b.x - (a.x + a.w), a.y - (b.y + b.h), b.y - (a.y + a.h)) <= 1
    const snap = (u, v) => Math.abs(u - v) > 0 && Math.abs(u - v) < 1 ? Math.round((u + v) / 2) : null
    for (let i = 0; i < out.length; i++) {
        for (let j = i + 1; j < out.length; j++) {
            const a = out[i]
            const b = out[j]
            if (a.solo || b.solo || !touching(a, b))
                continue
            for (const [pos, len] of [["x", "w"], ["y", "h"]]) {
                const lo = snap(a[pos], b[pos])
                if (lo !== null)
                    for (const r of [a, b]) {
                        r[len] += r[pos] - lo
                        r[pos] = lo
                    }
                const hi = snap(a[pos] + a[len], b[pos] + b[len])
                if (hi !== null)
                    for (const r of [a, b])
                        r[len] = hi - r[pos]
            }
        }
    }
    return out
}

function gooCode(r, keys) {
    if (!r.gooKey)
        return 0
    let id = keys.indexOf(r.gooKey)
    if (id < 0)
        id = keys.push(r.gooKey) - 1
    const v = (id + 1) * 64 + clamp(r.gooK ?? 0, 0, 63)
    return r.solo ? -v : v
}
