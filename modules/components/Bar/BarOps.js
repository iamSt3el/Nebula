.pragma library

function isBottom(edge) {
    return edge === "bottom" || edge === "dock"
}

function allows(entry, edge) {
    if (!entry)
        return false
    if (!entry.surfaces)
        return true
    return entry.surfaces.indexOf(isBottom(edge) ? "dock" : "bar") >= 0
}

function defaultDock(musicOn) {
    const d = ["launcher", "separator#dock", "dockApps"]
    if (musicOn)
        d.push("dockMusic")
    return d
}

function uniqueId(taken, base) {
    if (!taken[base])
        return base
    let n = 2
    while (taken[base + "-" + n])
        n++
    return base + "-" + n
}

function sanitize(blocks, legacy, entryOf, anchors) {
    const seen = {}
    const ids = {}
    const out = []
    for (const b of (blocks ?? [])) {
        if (!b || !b.id || ids[b.id])
            continue
        ids[b.id] = true
        const edge = b.edge === "bottom" ? "bottom" : "top"
        const items = []
        for (const i of (b.items ?? [])) {
            if (seen[i] || !allows(entryOf(i), edge))
                continue
            seen[i] = true
            items.push(i)
        }
        out.push({
            id: String(b.id),
            anchor: anchors.indexOf(b.anchor) >= 0 ? b.anchor : "left",
            edge: edge,
            items: items
        })
    }
    const lg = legacy ?? {}
    if (!lg.migrated && !out.some(b => b.edge === "bottom")) {
        const items = []
        for (const i of (lg.dockItems ?? defaultDock(lg.musicOn ?? true))) {
            if (seen[i] || !allows(entryOf(i), "bottom"))
                continue
            seen[i] = true
            items.push(i)
        }
        out.push({ id: uniqueId(ids, "dock"), anchor: "center", edge: "bottom", items: items })
    }
    return out
}

function clone(blocks) {
    return blocks.map(b => ({ id: b.id, anchor: b.anchor, edge: b.edge, items: b.items.slice() }))
}

function strip(list, id) {
    for (const b of list) {
        const k = b.items.indexOf(id)
        if (k >= 0)
            b.items.splice(k, 1)
    }
}

function move(blocks, id, toBlock, index, entryOf) {
    const target = blocks.find(b => b.id === toBlock)
    if (!target || !allows(entryOf(id), target.edge))
        return null
    const s = clone(blocks)
    strip(s, id)
    const list = s.find(b => b.id === toBlock).items
    list.splice(Math.max(0, Math.min(index, list.length)), 0, id)
    return s
}

function hide(blocks, id) {
    const s = clone(blocks)
    strip(s, id)
    return s
}

function hidden(catalog, blocks, grouped) {
    const used = {}
    for (const b of blocks)
        for (const i of b.items)
            used[i] = true
    if (grouped)
        for (const i of grouped)
            used[i] = true
    return catalog.filter(e => e.multi || !used[e.id]).map(e => e.id)
}

function hasBottom(blocks) {
    return blocks.some(b => b.edge === "bottom")
}

function hasDockMusic(blocks) {
    return blocks.some(b => b.items.indexOf("dockMusic") >= 0)
}

function setDockMusic(blocks, on, newId) {
    const s = clone(blocks)
    strip(s, "dockMusic")
    if (on) {
        let t = s.find(b => b.edge === "bottom" && b.anchor === "center")
        if (!t) {
            t = { id: newId, anchor: "center", edge: "bottom", items: [] }
            s.push(t)
        }
        t.items.push("dockMusic")
    }
    return s
}

function prune(blocks) {
    const needTop = !blocks.some(b => b.edge !== "bottom" && b.items.length > 0)
    const keepTop = needTop ? blocks.find(b => b.edge !== "bottom") : null
    return blocks.filter(b => b.items.length > 0 || b === keepTop)
}

function canMoveBlock(block, edge, entryOf) {
    return block.items.every(i => allows(entryOf(i), edge))
}

function movePin(pins, id, index) {
    const list = Array.prototype.slice.call(pins)
    const want = String(id).toLowerCase()
    const k = list.findIndex(p => String(p).toLowerCase() === want)
    const stored = k >= 0 ? list.splice(k, 1)[0] : id
    list.splice(Math.max(0, Math.min(index, list.length)), 0, stored)
    return list
}

function appDropIndex(rects, draggedId, localX) {
    const want = String(draggedId).toLowerCase()
    const from = rects.findIndex(r => String(r.appId).toLowerCase() === want)
    const stride = rects.length > 1 ? rects[1].x - rects[0].x : (rects.length ? rects[0].w : 0)
    let n = 0
    for (let i = 0; i < rects.length; i++) {
        const r = rects[i]
        if (i === from || !r.pinned)
            continue
        const shift = (from >= 0 && i > from) ? -stride : 0
        if (r.x + shift + r.w / 2 < localX)
            n++
    }
    return n
}

function dockStyleOf(dockCfg, general) {
    const g = general ?? {}
    const s = (dockCfg && dockCfg.style) || "match"
    if (s !== "match")
        return s
    return g.barMode ?? (g.flatBarMode === false ? "stepped" : "flat")
}

const SHAPES = ["flat", "stepped", "pill"]

function isShape(s) {
    return SHAPES.indexOf(s) >= 0
}

function edgeOf(block) {
    return isBottom(block && block.edge) ? "bottom" : "top"
}

function legacyShape(edge, barCfg, general) {
    const g = general ?? {}
    if (isBottom(edge))
        return dockStyleOf(barCfg ? barCfg.dock : null, g)
    return g.barMode ?? (g.flatBarMode === false ? "stepped" : "flat")
}

function blockShapes(barCfg, general, sanitized) {
    const blocks = sanitized || (barCfg && barCfg.blocks) || []
    const styles = (barCfg && barCfg.blockStyles) || {}
    const out = { ids: {}, edges: {} }
    for (const e of ["top", "bottom"]) {
        const list = blocks.filter(b => edgeOf(b) === e)
        const own = list.map(b => {
            const s = styles[b.id] ? styles[b.id].shape : undefined
            return isShape(s) ? s : ""
        })
        const legacy = legacyShape(e, barCfg, general)
        for (let i = 0; i < list.length; i++) {
            let s = own[i]
            for (let d = 1; !s && d < list.length; d++)
                s = own[i - d] || own[i + d] || ""
            out.ids[list[i].id] = s || legacy
        }
        out.edges[e] = list.map(b => out.ids[b.id])
        if (!out.edges[e].length)
            out.edges[e] = [legacy]
    }
    return out
}

function shapeIn(shapes, id, edge) {
    const s = shapes.ids[id]
    if (s)
        return s
    return shapes.edges[isBottom(edge) ? "bottom" : "top"][0]
}

function dockReserve(barCfg, general, hidden, hasDock) {
    const g = general ?? {}
    if (hidden || hasDock === false || g.dock === false)
        return 0
    const d = (barCfg && barCfg.dock) ?? {}
    const h = d.height ?? 60
    const shapes = blockShapes(barCfg, g).edges.bottom
    if (shapes.indexOf("flat") >= 0)
        return Math.round(h)
    if (shapes.indexOf("pill") >= 0 && !(g.dockAutoHide ?? true))
        return Math.round(h + (d.pillGap ?? g.pillMargin ?? 6) + 10)
    return 0
}

function reorder(list, id, delta) {
    const out = list.slice()
    const k = out.indexOf(id)
    if (k < 0 || delta === 0)
        return out
    let to = k + delta
    to = Math.max(0, Math.min(out.length - 1, to))
    if (to === k)
        return out
    out.splice(k, 1)
    out.splice(to, 0, id)
    return out
}

const SIDES = ["top", "bottom", "left", "right"]

function normSide(side, fallback) {
    return SIDES.indexOf(side) >= 0 ? side : fallback
}

function oppositeSide(side) {
    switch (side) {
    case "top":    return "bottom"
    case "bottom": return "top"
    case "left":   return "right"
    }
    return "left"
}

function sidesOf(barCfg) {
    const c = barCfg ?? {}
    const bar = normSide(c.side, "top")
    let dock = normSide((c.dock ?? {}).side, "bottom")
    if (dock === bar)
        dock = oppositeSide(bar)
    return { bar: bar, dock: dock }
}

function withSide(barCfg, which, side) {
    const c = barCfg ?? {}
    const cur = sidesOf(c)
    const s = normSide(side, which === "dock" ? cur.dock : cur.bar)
    let bar = which === "dock" ? cur.bar : s
    let dock = which === "dock" ? s : cur.dock
    if (bar === dock) {
        if (which === "dock")
            bar = oppositeSide(s)
        else
            dock = oppositeSide(s)
    }
    return { side: bar, dock: Object.assign({}, c.dock ?? {}, { side: dock }) }
}

function isVerticalSide(side) {
    return side === "left" || side === "right"
}

function isFarSide(side) {
    return side === "bottom" || side === "right"
}
