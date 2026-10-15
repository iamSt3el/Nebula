.pragma library

const SIDES = ["top", "bottom", "left", "right"]

function isBottom(edge) {
    return edge === "bottom" || edge === "dock"
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
        const edge = normSide(b.edge, "top")
        const items = []
        for (const i of (b.items ?? [])) {
            if (seen[i] || !entryOf(i))
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
            if (seen[i] || !entryOf(i))
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
    if (!target || !entryOf(id))
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

function prune(blocks) {
    const kept = blocks.filter(b => b.items.length > 0)
    return kept.length ? kept : blocks.slice(0, 1)
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
    return normSide(block && block.edge, "top")
}

function isEdgeV2(barCfg) {
    return !!barCfg && barCfg.edgeVersion === 2
}

function upgradeBlocks(blocks, barCfg) {
    if (isEdgeV2(barCfg))
        return blocks
    const s = sidesOf(barCfg)
    return blocks.map(b => Object.assign({}, b, { edge: isBottom(b.edge) ? s.dock : s.bar }))
}

function edgeDefaults(barCfg, general) {
    const c = barCfg ?? {}
    const g = general ?? {}
    return {
        height: Math.max(32, Math.min(56, c.height ?? 40)),
        iconSize: 0,
        itemGap: c.itemGap ?? 6,
        blockGap: c.blockGap ?? -1,
        radius: c.radius ?? 18,
        pillGap: g.pillMargin ?? 6,
        pillStart: g.pillLeftMargin ?? 6,
        pillEnd: g.pillRightMargin ?? 6,
        lineUp: false,
        autoHide: false,
        gameHide: false,
        hidden: false,
        sys: false,
        shape: g.barMode ?? (g.flatBarMode === false ? "stepped" : "flat")
    }
}

function legacyEdges(barCfg, general) {
    const c = barCfg ?? {}
    const g = general ?? {}
    const d = c.dock ?? {}
    const s = sidesOf(c)
    const out = {}
    out[s.bar] = {}
    out[s.dock] = {
        height: d.height ?? 60,
        iconSize: d.iconSize ?? 32,
        itemGap: d.itemGap ?? 2,
        blockGap: d.blockGap ?? -1,
        radius: d.radius ?? 18,
        pillGap: d.pillGap ?? g.pillMargin ?? 6,
        autoHide: g.dockAutoHide ?? true,
        gameHide: true,
        hidden: g.dock === false,
        sys: true,
        shape: dockStyleOf(d, g)
    }
    return out
}

function storedEdges(barCfg, general) {
    return isEdgeV2(barCfg) ? (barCfg.edges ?? {}) : legacyEdges(barCfg, general)
}

function edgeCfg(barCfg, general, side) {
    return Object.assign(edgeDefaults(barCfg, general), storedEdges(barCfg, general)[side] ?? {})
}

function sysEdge(barCfg, general) {
    const all = storedEdges(barCfg, general)
    for (const side of SIDES)
        if (all[side] && all[side].sys)
            return side
    return "bottom"
}

function blockShapes(barCfg, general, sanitized) {
    const blocks = sanitized || upgradeBlocks((barCfg && barCfg.blocks) || [], barCfg)
    const styles = (barCfg && barCfg.blockStyles) || {}
    const out = { ids: {}, edges: {} }
    for (const e of SIDES) {
        const list = blocks.filter(b => edgeOf(b) === e)
        const own = list.map(b => {
            const s = styles[b.id] ? styles[b.id].shape : undefined
            return isShape(s) ? s : ""
        })
        const legacy = edgeCfg(barCfg, general, e).shape
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
    return shapes.edges[normSide(edge, "top")][0]
}

function edgePresent(barCfg, side) {
    const blocks = upgradeBlocks((barCfg && barCfg.blocks) || [], barCfg)
    return blocks.some(b => edgeOf(b) === side && (b.items ?? []).length > 0)
}

function edgeReserve(barCfg, general, side, gameHidden) {
    if (!edgePresent(barCfg, side))
        return 0
    const cfg = edgeCfg(barCfg, general, side)
    if (cfg.hidden || (gameHidden && cfg.gameHide))
        return 0
    const shapes = blockShapes(barCfg, general).edges[side]
    const flat = shapes.indexOf("flat") >= 0
    if (cfg.autoHide)
        return 0
    if (shapes.indexOf("pill") >= 0)
        return Math.round(cfg.height + cfg.pillGap + 10)
    if (flat)
        return Math.round(cfg.height)
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

function isVerticalSide(side) {
    return side === "left" || side === "right"
}

function isFarSide(side) {
    return side === "bottom" || side === "right"
}
