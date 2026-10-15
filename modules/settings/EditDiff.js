.pragma library

function words(key) {
    return String(key).replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_#].*$/, "").toLowerCase()
}

function cap(s) {
    return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b)
}

function list(v) {
    return v && typeof v.length === "number" ? Array.prototype.slice.call(v) : []
}

function keysOf(a, b) {
    const out = Object.keys(a || {})
    for (const k of Object.keys(b || {}))
        if (out.indexOf(k) < 0) out.push(k)
    return out
}

const edgeWords = {
    height: "thickness", iconSize: "icon size", itemGap: "item gap", blockGap: "block gap",
    radius: "corners", pillGap: "pill gap", pillStart: "start gap", pillEnd: "end gap", shape: "shape"
}

function edgeValue(key, v) {
    if (key === "hidden") return v ? "hidden" : "shown"
    if (key === "autoHide") return v ? "auto-hide on" : "auto-hide off"
    if (key === "gameHide") return v ? "hides in games" : "stays in games"
    if (key === "lineUp") return v ? "tabs lined up with pills" : "tabs at natural depth"
    if (key === "sys") return v ? "hosts system panels" : "no system panels"
    if (key === "iconSize" && v === 0) return "icon size auto"
    if (typeof v === "number") return (edgeWords[key] || words(key)) + " " + v + " px"
    return (edgeWords[key] || words(key)) + " " + v
}

function where(blocks) {
    const out = {}
    for (const b of blocks) {
        const items = list(b.items)
        for (let i = 0; i < items.length; i++)
            out[items[i]] = { block: b.id, index: i }
    }
    return out
}

function barChanges(a, b, name, out, hint) {
    const ab = list(a.blocks), bb = list(b.blocks)
    if ((ab.length === 0) !== (bb.length === 0) || a.edgeVersion !== b.edgeVersion) {
        out.push("Edited the bar")
        return
    }
    if (!same(ab, bb)) {
        const wa = where(ab), wb = where(bb)
        const before = out.length
        for (const id of Object.keys(wb)) {
            if (!wa[id]) out.push("Added " + name("item", id))
            else if (wa[id].block !== wb[id].block) out.push("Moved " + name("item", id) + " to " + name("block", wb[id].block))
        }
        for (const id of Object.keys(wa))
            if (!wb[id]) out.push("Removed " + name("item", id))
        if (out.length === before) {
            for (const blk of bb) {
                const old = ab.find(x => x.id === blk.id)
                const xa = old ? list(old.items) : [], xb = list(blk.items)
                if (same(xa, xb) || xa.length !== xb.length)
                    continue
                const movers = xb.filter(id => same(xa.filter(x => x !== id), xb.filter(x => x !== id)))
                const mover = movers.indexOf(hint) >= 0 ? hint : movers[0]
                out.push("Moved " + name("item", mover || xb.find((id, i) => xa[i] !== id)))
                break
            }
        }
        if (out.length === before) {
            if (bb.length > ab.length) out.push("Added a block")
            else if (bb.length < ab.length) out.push("Removed a block")
            else out.push("Moved a block")
        }
    }
    const ea = a.edges || {}, eb = b.edges || {}
    for (const side of keysOf(ea, eb)) {
        const sa = ea[side] || {}, sb = eb[side] || {}
        for (const k of keysOf(sa, sb))
            if (!same(sa[k], sb[k])) out.push(cap(side) + " edge: " + edgeValue(k, sb[k]))
    }
    const oa = a.options || {}, ob = b.options || {}
    for (const id of keysOf(oa, ob)) {
        const xa = oa[id] || {}, xb = ob[id] || {}
        for (const k of keysOf(xa, xb))
            if (!same(xa[k], xb[k]))
                out.push(name("item", id) + ": " + words(k) + (typeof xb[k] === "string" ? " " + words(xb[k]) : ""))
    }
    const ia = a.itemStyles || {}, ib = b.itemStyles || {}
    for (const id of keysOf(ia, ib))
        if (!same(ia[id], ib[id])) out.push(name("item", id) + ": look")
    const ma = a.margins || {}, mb = b.margins || {}
    for (const id of keysOf(ma, mb))
        if (!same(ma[id], mb[id])) out.push(name("item", id) + ": spacing")
    const ba = a.blockStyles || {}, bs = b.blockStyles || {}
    for (const id of keysOf(ba, bs)) {
        const xa = ba[id] || {}, xb = bs[id] || {}
        for (const k of keysOf(xa, xb))
            if (!same(xa[k], xb[k]))
                out.push(cap(name("block", id)) + ": " + words(k) + (typeof xb[k] === "string" ? " " + words(xb[k]) : ""))
    }
    const skip = ["blocks", "edges", "options", "itemStyles", "margins", "blockStyles", "edgeVersion"]
    for (const k of keysOf(a, b))
        if (skip.indexOf(k) < 0 && !same(a[k], b[k])) out.push("Bar: " + words(k))
}

function widgetChanges(a, b, name, out) {
    const touched = {}
    for (const k of keysOf(a, b)) {
        if (same(a[k], b[k]))
            continue
        if (/^show[A-Z]/.test(k) && k !== "showWidgets") {
            out.push((b[k] ? "Added " : "Removed ") + name("widgetShow", k))
            continue
        }
        const m = /^(.*?)(X|Y|W|H|Locked)$/.exec(k)
        if (m && m[1] !== "") {
            const what = m[2] === "X" || m[2] === "Y" ? "Moved " : m[2] === "Locked" ? (b[k] ? "Locked " : "Unlocked ") : "Resized "
            const label = what + name("widget", m[1])
            if (!touched[label]) {
                touched[label] = true
                out.push(label)
            }
            continue
        }
        if (k === "cardSurface" || k === "cardOpacity" || k === "glassStrength") {
            if (!touched.look) {
                touched.look = true
                out.push("Widget look")
            }
            continue
        }
        out.push("Widgets: " + words(k))
    }
}

function dashChanges(a, b, name, out) {
    const ia = list(a.items), ib = list(b.items)
    if (!same(ia, ib)) {
        const before = out.length
        const byA = {}, byB = {}
        for (const t of ia) byA[t.id] = t
        for (const t of ib) byB[t.id] = t
        for (const id of Object.keys(byB))
            if (!byA[id]) out.push("Added " + name("tile", id) + " to the dashboard")
        for (const id of Object.keys(byA))
            if (!byB[id]) out.push("Removed " + name("tile", id) + " from the dashboard")
        if (out.length === before)
            for (const id of Object.keys(byB)) {
                const x = byA[id], y = byB[id]
                if (x.w !== y.w || x.h !== y.h) { out.push("Resized " + name("tile", id)); break }
                if (x.x !== y.x || x.y !== y.y) { out.push("Moved " + name("tile", id)); break }
            }
        if (out.length === before) out.push("Rearranged the dashboard")
    }
    const oa = a.options || {}, ob = b.options || {}
    for (const id of keysOf(oa, ob))
        if (!same(oa[id], ob[id])) out.push(name("tile", id) + ": options")
    for (const k of keysOf(a, b))
        if (k !== "items" && k !== "options" && !same(a[k], b[k])) out.push("Dashboard: " + words(k))
}

function generalChanges(a, b, out) {
    for (const k of keysOf(a, b)) {
        if (same(a[k], b[k]))
            continue
        if (k === "pinnedApps") out.push("Pinned apps")
        else out.push(cap(words(k)))
    }
}

function describe(a, b, name, hint) {
    const out = []
    barChanges(a.bar || {}, b.bar || {}, name, out, hint)
    widgetChanges(a.widgets || {}, b.widgets || {}, name, out)
    dashChanges(a.dashboard || {}, b.dashboard || {}, name, out)
    generalChanges(a.general || {}, b.general || {}, out)
    if (out.length === 0)
        return "Changed a setting"
    return out.length === 1 ? out[0] : out[0] + " and " + (out.length - 1) + " more"
}
