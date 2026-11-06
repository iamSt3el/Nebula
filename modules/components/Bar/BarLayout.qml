pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.services
import qs.modules.utils
import "BarOps.js" as BarOps
import "BarCatalog.js" as BarCatalog

Singleton {
    id: root

    Component.onCompleted: {
        EditSession.namers.item = id => {
            const e = root.entry(id)
            return e ? e.label : id
        }
        EditSession.namers.block = id => {
            const b = root.blockById(id)
            return b ? b.edge + " edge, " + root.blockLabel(id).toLowerCase() + " block" : "a block"
        }
        EditSession.searchers.parts = q => root.hiddenItems.filter(id => {
            const e = root.entry(id)
            return !!e && (e.label.toLowerCase().indexOf(q) >= 0 || (e.group ?? "").toLowerCase().indexOf(q) >= 0)
        }).length
    }

    readonly property var groups: ["Core", "Stats", "Toggles", "Launchers", "Layout"]

    function onRoleColor(name) {
        switch (name) {
        case "secondary":   return Colors.secondaryText
        case "tertiary":    return Colors.tertiaryText
        case "error":       return Colors.errorText
        case "outline":
        case "surfaceText": return Colors.surface
        }
        return Colors.primaryText
    }

    function roleColor(name) {
        switch (name) {
        case "secondary":   return Colors.secondary
        case "tertiary":    return Colors.tertiary
        case "error":       return Colors.error
        case "outline":     return Colors.outline
        case "surfaceText": return Colors.surfaceText
        }
        return Colors.primary
    }

    readonly property var catalog: BarCatalog.build({
        barHeight: Appearance.size.barHeight,
        launcherStyles: ServiceLauncher.styles
    })

    readonly property var anchorNames: ["left", "center", "right"]

    function anchorsOnly(host) {
        const ids = host && host.itemIds ? host.itemIds : []
        return ids.length > 0 && ids.every(i => {
            const b = root.baseId(i)
            return b === "popups" || b === "osd"
        })
    }

    function baseId(id) {
        const k = id.indexOf("#")
        return k < 0 ? id : id.slice(0, k)
    }

    function entry(id) {
        const base = root.baseId(id)
        return root.catalog.find(e => e.id === base) ?? null
    }

    function fileFor(id) {
        const base = root.baseId(id)
        return "BarItem" + base.charAt(0).toUpperCase() + base.slice(1) + ".qml"
    }

    function newInstanceId(base) {
        return base + "#" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
    }

    function defaultBlocks() {
        const g = SettingsConfig.general ?? {}
        const centreItems = ["clock"]
        const right = ["rec", "tray"]
        if (g.barWeather ?? true)
            right.push("weather")
        right.push("volume", "wifi", "bluetooth", "notifications", "battery")
        return [
            { id: "left",   anchor: "left",   items: ["workspaces", "windowTitle"] },
            { id: "center", anchor: "center", items: centreItems },
            { id: "right",  anchor: "right",  items: right }
        ]
    }

    function urlFor(id) {
        return Qt.resolvedUrl(root.fileFor(id))
    }

    property var _stableCache: ({})

    function _stable(key, value) {
        const text = JSON.stringify(value)
        const hit = root._stableCache[key]
        if (hit && hit.text === text)
            return hit.value
        root._stableCache[key] = { text: text, value: value }
        return value
    }

    readonly property var dockConfig: root._stable("dockConfig", (SettingsConfig.bar ?? {}).dock ?? ({}))

    function _list(v) {
        return (v !== undefined && v !== null && typeof v.length === "number")
            ? Array.prototype.slice.call(v) : undefined
    }

    readonly property bool edgeV2: BarOps.isEdgeV2(SettingsConfig.bar)
    readonly property bool gapModel: BarOps.gapModel(SettingsConfig.bar)

    property var gapDraft: null
    readonly property bool gapDragging: root.gapDraft !== null
    property real gapDragT: root.gapDragging ? 1 : 0
    Behavior on gapDragT { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property var gapCfg: {
        const bar = SettingsConfig.bar ?? {}
        const d = root.gapDraft
        if (!d)
            return bar
        const out = Object.assign({}, bar)
        if (d.gaps) {
            out.edges = Object.assign({}, bar.edges ?? {})
            out.edges[d.side] = Object.assign({}, out.edges[d.side] ?? {}, {
                gaps: Object.assign({}, BarOps.edgeGaps(bar, SettingsConfig.general, d.side), d.gaps)
            })
        }
        if (d.block && d.style) {
            out.blockStyles = Object.assign({}, bar.blockStyles ?? {})
            out.blockStyles[d.block] = Object.assign({}, out.blockStyles[d.block] ?? {}, d.style)
        }
        return out
    }

    function edgeGaps(side) {
        return BarOps.edgeGaps(root.gapCfg, SettingsConfig.general, side)
    }

    function blockGaps(blockId, side) {
        return BarOps.blockGaps(root.gapCfg, SettingsConfig.general, blockId, side)
    }

    function draftGaps(side, gaps) {
        root.gapDraft = { side: side, gaps: gaps }
    }

    function draftBlockStyle(side, blockId, style) {
        root.gapDraft = { side: side, block: blockId, style: style }
    }

    function commitGapDraft(extra) {
        const d = root.gapDraft
        if (!d) {
            if (extra)
                extra()
            return
        }
        const round = (k, v) => k === "fill" ? Math.round(v * 20) / 20 : Math.round(v)
        if (d.gaps) {
            const g = {}
            for (const k in d.gaps)
                g[k] = round(k, d.gaps[k])
            root.setEdgeGaps(d.side, g)
        }
        if (d.block && d.style)
            for (const k in d.style) {
                const v = d.style[k]
                root.setBlockStyle(d.block, k, v === null ? undefined : typeof v === "number" ? round(k, v) : v)
            }
        if (extra)
            extra()
        root.gapDraft = null
    }

    readonly property var gapPresets: ({
        pill:    { edge: 8, block: 10, end: 10, fill: 0, radius: 20 },
        stepped: { edge: 0, block: 10, end: 0,  fill: 0, radius: -1 },
        merged:  { edge: 8, block: 0,  end: 10, fill: 0, radius: 20 },
        full:    { edge: 0, block: 0,  end: 0,  fill: 1, radius: -1 }
    })

    readonly property var gapPresetInfo: [
        { value: "pill",    label: "Pill",    desc: "Each block floats on its own" },
        { value: "stepped", label: "Stepped", desc: "Blocks hang from the screen edge" },
        { value: "merged",  label: "Merged",  desc: "Blocks in a group join into one piece" },
        { value: "full",    label: "Full",    desc: "One strip from side to side" }
    ]

    readonly property var panelStyleInfo: [
        { value: "attached", label: "Attached", desc: "Grows out of the bar" },
        { value: "merged",   label: "Joined",   desc: "Joined to its block by a short neck" },
        { value: "floating", label: "Floating", desc: "Hangs free with a gap" }
    ]

    function applyGapPreset(side, name) {
        const p = root.gapPresets[name]
        if (p)
            root.setEdgeGaps(side, p)
    }

    readonly property var edgeFollowKeys: ["edgeGap", "radius", "corners", "panels", "panelGap", "gapBefore"]

    function matchEdge(blockId) {
        const all = Object.assign({}, root.blockStyles)
        const cur = Object.assign({}, all[blockId] ?? {})
        for (const k of root.edgeFollowKeys)
            delete cur[k]
        all[blockId] = cur
        root._patch({ blockStyles: all })
    }

    function blockName(blockId) {
        const blk = root.blockById(blockId)
        const names = (blk ? blk.items : []).map(i => root.entry(i)).filter(e => !!e).map(e => e.label)
        if (!names.length)
            return root.blockLabel(blockId) + " block"
        return names.length > 2 ? names.slice(0, 2).join(" · ") + " +" + (names.length - 2) : names.join(" · ")
    }

    function blockHasOwnStyle(blockId) {
        const st = root.blockStyles[blockId] ?? {}
        return root.edgeFollowKeys.some(k => st[k] !== undefined && st[k] !== null)
    }

    function setEdgeGaps(side, patch) {
        root.setEdge(side, "gaps", Object.assign({}, root.edgeGaps(side), patch))
    }

    function gapPresetOf(side) {
        const g = root.edgeGaps(side)
        for (const name in root.gapPresets) {
            const p = root.gapPresets[name]
            if (Object.keys(p).every(k => Math.abs((g[k] ?? 0) - p[k]) < 0.01))
                return name
        }
        return ""
    }

    readonly property var storedBlocks: {
        const saved = root._list(SettingsConfig.bar?.blocks)
        const clean = BarOps.sanitize((saved && saved.length) ? saved : root.defaultBlocks(), {
            migrated: root.edgeV2 || root.dockConfig.edgeModel === true,
            dockItems: root._list(root.dockConfig.items),
            musicOn: (SettingsConfig.general ?? {}).dockMusicPlayer ?? true
        }, id => root.entry(id), root.anchorNames)
        return root._stable("storedBlocks", BarOps.upgradeBlocks(clean, SettingsConfig.bar))
    }

    readonly property var allBlocks: root._stable("allBlocks", root.storedBlocks.map(b => ({
        id: b.id, anchor: b.anchor, edge: b.edge, items: b.items.filter(i => Features.barItemOn(i))
    })))

    function _withHidden(list) {
        const hidden = []
        for (const b of root.storedBlocks) {
            const prevs = []
            for (const i of b.items) {
                if (!Features.barItemOn(i))
                    hidden.push({ id: i, block: b, prevs: prevs.slice().reverse() })
                prevs.push(i)
            }
        }
        if (hidden.length === 0)
            return list
        const out = list.map(b => Object.assign({}, b, { items: root._list(b.items) ?? [] }))
        const placed = {}
        for (const b of out)
            for (const i of b.items)
                placed[i] = true
        for (const h of hidden) {
            if (placed[h.id])
                continue
            let done = false
            for (const p of h.prevs) {
                const t = out.find(b => b.items.indexOf(p) >= 0)
                if (t) {
                    t.items.splice(t.items.indexOf(p) + 1, 0, h.id)
                    done = true
                    break
                }
            }
            if (!done) {
                let t = out.find(b => b.id === h.block.id)
                if (!t) {
                    t = { id: h.block.id, anchor: h.block.anchor, edge: h.block.edge, items: [] }
                    out.push(t)
                }
                t.items.splice(0, 0, h.id)
            }
            placed[h.id] = true
        }
        return out
    }

    readonly property var sideNames: ["top", "right", "bottom", "left"]

    readonly property var edges: root._stable("edges", {
        top: BarOps.edgeCfg(SettingsConfig.bar, SettingsConfig.general, "top"),
        right: BarOps.edgeCfg(SettingsConfig.bar, SettingsConfig.general, "right"),
        bottom: BarOps.edgeCfg(SettingsConfig.bar, SettingsConfig.general, "bottom"),
        left: BarOps.edgeCfg(SettingsConfig.bar, SettingsConfig.general, "left")
    })

    function edge(side) {
        return root.edges[side] ?? root.edges.top
    }

    function blocksOn(side) {
        return root.allBlocks.filter(b => b.edge === side)
    }

    readonly property var presentEdges: root._stable("presentEdges",
        root.sideNames.filter(s => !root.edges[s].hidden && root.allBlocks.some(b => b.edge === s && b.items.length > 0)))

    function edgeShown(side) {
        return root.presentEdges.indexOf(side) >= 0
    }

    readonly property string sysEdge: BarOps.sysEdge(SettingsConfig.bar, SettingsConfig.general)

    function _v2Base() {
        if (root.edgeV2)
            return {}
        return { edgeVersion: 2, edges: BarOps.legacyEdges(SettingsConfig.bar, SettingsConfig.general) }
    }

    function setEdge(side, key, value) {
        const base = root._v2Base()
        const all = Object.assign({}, base.edges ?? SettingsConfig.bar?.edges ?? {})
        all[side] = Object.assign({}, all[side] ?? {}, { [key]: value })
        root._patch(Object.assign(base, { blocks: root.allBlocks, edges: all }))
    }

    readonly property bool dockPresent: root.allBlocks.some(b => b.items.some(i => i.split("#")[0] === "dockApps"))

    Binding {
        target: GlobalStates
        property: "dockPresent"
        value: root.dockPresent
    }

    readonly property var itemGroups: root._stable("itemGroups", SettingsConfig.bar?.groups ?? ({}))
    readonly property var placedIds: {
        const out = {}
        for (const b of root.allBlocks)
            for (const i of root._list(b.items))
                out[i] = true
        return out
    }
    readonly property var groupedIds: {
        const out = []
        const g = root.itemGroups
        for (const key in g) {
            if (!root.placedIds[key])
                continue
            for (const id of root._list(g[key]))
                out.push(id)
        }
        return out
    }
    readonly property var hiddenItems: BarOps.hidden(root.catalog, root.allBlocks, root.groupedIds)
        .filter(id => Features.barItemOn(id))

    property QtObject editor: null

    property bool settled: false

    Timer {
        interval: 1000
        running: SettingsConfig.settingsReady && !root.settled
        onTriggered: root.settled = true
    }

    Connections {
        target: ServiceLayouts
        function onApplying() { root.settled = false }
    }

    readonly property bool launcherItemHost: (ServiceLauncher.position === "item" || ServiceLauncher.position === "block")
        && root.allBlocks.some(b => b.items.indexOf("launcher") >= 0 && !root.edge(b.edge).hidden)
    readonly property bool clipboardItemHost: root.allBlocks.some(b => b.items.indexOf("clipboard") >= 0)
    readonly property bool wallpaperItemHost: root.allBlocks.some(b => b.items.indexOf("wallpaper") >= 0)

    function panelItemHost(kind) {
        return kind === "clipboard" ? root.clipboardItemHost : kind === "wallpaper" ? root.wallpaperItemHost : false
    }

    readonly property bool sysPanelOpen: (GlobalStates.clipboardOpen && !root.clipboardItemHost)
        || (GlobalStates.wallpaperOpen && !root.wallpaperItemHost)
        || ((GlobalStates.panelPreview === "wallpaper" || GlobalStates.panelPreview === "clipboard")
            && !root.panelItemHost(GlobalStates.panelPreview))
        || (GlobalStates.osdOpen && root.osdHostItem === "")
    readonly property bool needSysHost: root.sysPanelOpen
        && (root.edge(root.sysEdge).hidden || !root.allBlocks.some(b => b.edge === root.sysEdge && b.anchor === "center"))
    readonly property string sysHostId: {
        if (root.needSysHost)
            return "__sys"
        const c = root.allBlocks.find(b => b.edge === root.sysEdge && b.anchor === "center")
        return c ? c.id : ""
    }
    readonly property var sysHostBlock: ({ id: "__sys", anchor: "center", edge: root.sysEdge, items: [] })

    function moreId(side) {
        return "__more:" + side
    }

    function isMore(id) {
        return id.indexOf("__more") === 0
    }

    function blockById(id) {
        if (id === "__sys")
            return root.sysHostBlock
        if (root.isMore(id))
            return { id: id, anchor: "right", edge: id.split(":")[1] ?? "top", items: ["more"] }
        return root.allBlocks.find(b => b.id === id) ?? null
    }

    function idsFor(anchor, edge) {
        const ids = root.edge(edge).hidden ? []
            : root.allBlocks.filter(b => b.anchor === anchor && b.edge === edge).map(b => b.id)
        if (edge === root.sysEdge && anchor === "center" && root.needSysHost)
            ids.push("__sys")
        return ids
    }

    function newBlockId() {
        return "b" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
    }

    function _clone() {
        return root.allBlocks.map(b => ({ id: b.id, anchor: b.anchor, edge: b.edge, items: b.items.slice() }))
    }

    function _patch(patch) {
        if (patch.blocks && patch.blocks.length > 0)
            patch = Object.assign({}, patch, { blocks: root._withHidden(patch.blocks) })
        SettingsConfig.bar = Object.assign({}, SettingsConfig.bar ?? {}, patch)
    }

    function _statePatch(list) {
        const d = Object.assign({}, root.dockConfig, { edgeModel: true })
        delete d.items
        const patch = Object.assign(root._v2Base(), { blocks: list, dock: d })
        const groups = root._prunedGroups(list)
        if (groups)
            patch.groups = groups
        return patch
    }

    function _prunedGroups(list) {
        const placed = {}
        for (const b of list)
            for (const i of root._list(b.items))
                placed[i] = true
        const out = {}
        let dropped = false
        for (const key in root.itemGroups) {
            if (placed[key])
                out[key] = root._list(root.itemGroups[key])
            else
                dropped = true
        }
        return dropped ? out : null
    }

    function _write(list) {
        root._patch(root._statePatch(list))
    }

    function moveItem(itemId, toBlock, index) {
        const e = root.entry(itemId)
        const id = (e && e.multi && itemId.indexOf("#") < 0) ? root.newInstanceId(itemId) : itemId
        const next = BarOps.move(root.allBlocks, id, toBlock, index, i => root.entry(i))
        if (next)
            root._write(next)
    }

    function hideItem(itemId) {
        const patch = root._statePatch(BarOps.hide(root.allBlocks, itemId))
        if (itemId.indexOf("#") >= 0) {
            const m = Object.assign({}, root.margins)
            delete m[itemId]
            const op = Object.assign({}, root.itemOptions)
            delete op[itemId]
            patch.margins = m
            patch.options = op
        }
        if (root.itemStyles[itemId] !== undefined) {
            const st = Object.assign({}, root.itemStyles)
            delete st[itemId]
            patch.itemStyles = st
        }
        if (root.isGroup(itemId) && root.itemGroups[itemId] !== undefined) {
            const groups = {}
            for (const key in root.itemGroups)
                if (key !== itemId)
                    groups[key] = root._list(root.itemGroups[key])
            patch.groups = groups
        }
        root._patch(patch)
    }

    function addBlock(anchor, edge) {
        const e = root.sideNames.indexOf(edge) >= 0 ? edge : "top"
        const list = root._clone()
        const block = { id: root.newBlockId(), anchor: anchor, edge: e, items: [] }
        if (anchor === "right") {
            const k = list.findIndex(b => b.anchor === "right" && b.edge === e)
            if (k < 0) list.push(block)
            else list.splice(k, 0, block)
        } else {
            let k = -1
            list.forEach((b, i) => { if (b.anchor === anchor && b.edge === e) k = i })
            if (k < 0) list.push(block)
            else list.splice(k + 1, 0, block)
        }
        root._write(list)
        return block.id
    }

    function placeInNewBlock(itemId, anchor, index, edge) {
        const e = root.entry(itemId)
        if (!e)
            return ""
        const id = (e.multi && itemId.indexOf("#") < 0) ? root.newInstanceId(itemId) : itemId
        const side = root.sideNames.indexOf(edge) >= 0 ? edge : "top"
        const list = root._clone()
        const from = list.find(b => b.items.indexOf(id) >= 0)
        BarOps.strip(list, id)
        const emptied = from && from.items.length === 0 && list.length > 1 ? from.id : ""
        const kept = emptied !== "" ? list.filter(b => b.id !== emptied) : list
        const blk = { id: root.newBlockId(), anchor: anchor, edge: side, items: [id] }
        const same = []
        kept.forEach((b, i) => { if (b.anchor === anchor && b.edge === side) same.push(i) })
        let at = kept.length
        if (index < same.length) at = same[index]
        else if (same.length) at = same[same.length - 1] + 1
        kept.splice(at, 0, blk)
        const patch = root._statePatch(kept)
        if (emptied !== "" && root.blockStyles[emptied] !== undefined) {
            const st = Object.assign({}, root.blockStyles)
            delete st[emptied]
            patch.blockStyles = st
        }
        root._patch(patch)
        return blk.id
    }

    function removeBlock(id) {
        const b = root.blockById(id)
        if (!b || root.allBlocks.length <= 1)
            return
        const patch = root._statePatch(root._clone().filter(x => x.id !== id))
        if (root.blockStyles[id] !== undefined) {
            const st = Object.assign({}, root.blockStyles)
            delete st[id]
            patch.blockStyles = st
        }
        root._patch(patch)
    }

    function joinBlocks(fromId, toId, atEnd) {
        if (fromId === toId)
            return
        const list = root._clone()
        const src = list.find(b => b.id === fromId)
        const dst = list.find(b => b.id === toId)
        if (!src || !dst)
            return
        dst.items = atEnd ? dst.items.concat(src.items) : src.items.concat(dst.items)
        const patch = root._statePatch(list.filter(b => b.id !== fromId))
        if (root.blockStyles[fromId] !== undefined) {
            const st = Object.assign({}, root.blockStyles)
            delete st[fromId]
            patch.blockStyles = st
        }
        root._patch(patch)
    }

    function splitBlockAt(blockId, itemId) {
        const list = root._clone()
        const k = list.findIndex(b => b.id === blockId)
        if (k < 0)
            return ""
        const blk = list[k]
        const at = blk.items.indexOf(itemId)
        if (at <= 0)
            return ""
        const piece = { id: root.newBlockId(), anchor: blk.anchor, edge: blk.edge, items: blk.items.slice(at) }
        blk.items = blk.items.slice(0, at)
        list.splice(k + 1, 0, piece)
        const patch = root._statePatch(list)
        const own = root.blockStyles[blockId]
        if (own !== undefined) {
            const st = Object.assign({}, root.blockStyles)
            const copy = Object.assign({}, own)
            delete copy.gapBefore
            st[piece.id] = copy
            patch.blockStyles = st
        }
        root._patch(patch)
        return piece.id
    }

    function moveBlock(id, anchor, index, edge) {
        const list = root._clone()
        const k = list.findIndex(b => b.id === id)
        if (k < 0)
            return
        const blk = list[k]
        const e = root.sideNames.indexOf(edge) >= 0 ? edge : blk.edge
        list.splice(k, 1)
        blk.anchor = anchor
        blk.edge = e
        const same = []
        list.forEach((b, i) => { if (b.anchor === anchor && b.edge === e) same.push(i) })
        let at = list.length
        if (index < same.length) at = same[index]
        else if (same.length) at = same[same.length - 1] + 1
        list.splice(at, 0, blk)
        root._write(list)
    }

    function pruneEmpty() {
        const list = root._clone()
        const kept = BarOps.prune(list)
        if (kept.length === list.length)
            return
        root._write(kept)
    }

    readonly property var blockStyles: root._stable("blockStyles", SettingsConfig.bar?.blockStyles ?? ({}))

    function blockStyle(blockId, key, def) {
        const st = root.blockStyles[blockId]
        const v = st ? st[key] : undefined
        return v === undefined ? def : v
    }

    function setBlockStyle(blockId, key, value) {
        const all = Object.assign({}, root.blockStyles)
        all[blockId] = Object.assign({}, all[blockId] ?? {}, { [key]: value })
        if (value === undefined)
            delete all[blockId][key]
        root._patch({ blockStyles: all })
    }

    readonly property var shapes: root._stable("shapes", BarOps.blockShapes(root.gapCfg, SettingsConfig.general, root.allBlocks))

    function blockShape(blockId, edge) {
        if (root.isMore(blockId)) {
            const r = root.allBlocks.filter(b => b.anchor === "right" && b.edge === edge).pop()
            return BarOps.shapeIn(root.shapes, r ? r.id : blockId, edge)
        }
        return BarOps.shapeIn(root.shapes, blockId, edge)
    }

    function splitBlock(blockId) {
        return root.blockStyle(blockId, "split", root.blockStyle(blockId, "clear", false)) === true
    }

    function setBlockSplit(blockId, on) {
        const all = Object.assign({}, root.blockStyles)
        const cur = Object.assign({}, all[blockId] ?? {}, { split: on })
        delete cur.clear
        all[blockId] = cur
        root._patch({ blockStyles: all })
    }

    function blockOfItem(id) {
        return root.allBlocks.find(b => b.items.indexOf(id) >= 0) ?? null
    }

    function inSplit(id) {
        const b = root.blockOfItem(id)
        return !!b && root.blockShape(b.id, b.edge) === "pill" && root.splitBlock(b.id)
    }

    function plateH(id, barH) {
        const m = root.itemStyle(id, "minH", 0)
        return m > 0 ? Math.min(barH, m) : barH
    }

    function plateW(id, contentWidth, contentHeight, barH) {
        const h = root.plateH(id, barH)
        if (root.iconOnly(contentWidth, contentHeight))
            return h
        const pad = Math.max(10, root.itemStyle(id, "pad", 12))
        return Math.max(h, contentWidth + pad * 2, root.itemStyle(id, "minW", 0))
    }

    function plateShape(id, contentWidth, contentHeight) {
        const s = root.chipShape(id)
        return s !== "none" && root.iconOnly(contentWidth, contentHeight) ? s : ""
    }

    function plateHoverFill(c) {
        return Qt.tint(c, Qt.alpha(Colors.surfaceText, 0.12))
    }

    function plateRadius(id, h) {
        const r = root.itemStyle(id, "radius", -1)
        return r < 0 ? h / 2 : Math.min(r, h / 2)
    }

    function panelStyleFor(blockId, edge, shape) {
        if (shape === "pill" && root.splitBlock(blockId))
            return "floating"
        if (shape === "pill")
            return root.blockPanels(blockId, edge)
        const v = root.ownPanels(blockId) || root.edgePanels(edge)
        return v === "floating" || v === "merged" ? v : "attached"
    }

    function validPanels(v) {
        return v === "floating" || v === "attached" || v === "merged" ? v : ""
    }

    function ownPanels(blockId) {
        return root.validPanels(root.blockStyle(blockId, "panels", ""))
    }

    function edgePanels(edge) {
        return root.validPanels(root.edge(edge).panels)
    }

    function blockPanels(blockId, edge) {
        const v = root.ownPanels(blockId) || root.edgePanels(edge)
        if (v !== "")
            return v
        return root.edge(edge).sys ? "attached" : "floating"
    }

    function setEdgePanels(edge, value) {
        root.setEdge(edge, "panels", value)
    }

    function edgePanelGap(edge) {
        const v = root.edge(edge).panelGap
        return typeof v === "number" && v >= 0 ? v : root.panelGap
    }

    function setEdgePanelGap(edge, value) {
        root.setEdge(edge, "panelGap", value)
    }

    function edgeOverrides(edge, key) {
        return root.allBlocks.filter(b => b.edge === edge && root.blockStyle(b.id, key, null) !== null)
    }

    function clearEdgeOverrides(edge, key) {
        const all = Object.assign({}, root.blockStyles)
        let hit = false
        for (const b of root.allBlocks) {
            if (b.edge !== edge || !all[b.id] || all[b.id][key] === undefined)
                continue
            const st = Object.assign({}, all[b.id])
            delete st[key]
            all[b.id] = st
            hit = true
        }
        if (hit)
            root._patch({ blockStyles: all })
    }

    function edgeShapes(edge) {
        return root.shapes.edges[root.sideNames.indexOf(edge) >= 0 ? edge : "top"]
    }

    function isAnchorItem(id) {
        const e = root.entry(id)
        return !!e && e.anchor === true
    }

    function testPopup(urgent) {
        GlobalStates.barEditTest = true
        Quickshell.execDetached(["notify-send", "-a", "Nebula", "-i", "dialog-information",
                                 "-u", urgent ? "critical" : "normal",
                                 urgent ? "Urgent test popup" : "Test popup",
                                 "This is where your notifications appear."])
        editTestEnd.interval = Math.max(4000, ((SettingsConfig.notifications?.popupTimeout ?? 5) + 2) * 1000)
        editTestEnd.restart()
    }

    function testOsd(kind) {
        GlobalStates.barEditTest = true
        GlobalStates.osdKinds = [kind]
        GlobalStates.osdKind = kind
        GlobalStates.osdOpen = true
        editTestEnd.interval = 3000
        editTestEnd.restart()
        osdTestEnd.restart()
    }

    Timer {
        id: osdTestEnd
        interval: 2600
        onTriggered: GlobalStates.osdOpen = false
    }

    Timer {
        id: editTestEnd
        interval: 4000
        onTriggered: GlobalStates.barEditTest = false
    }

    function blockLabel(blockId) {
        const b = root.blockById(blockId)
        if (!b)
            return ""
        const name = b.anchor === "center" ? "Centre" : (b.anchor === "left" ? "Left" : "Right")
        const same = root.allBlocks.filter(x => x.anchor === b.anchor && x.edge === b.edge)
        if (same.length < 2)
            return name
        return name + " " + (same.findIndex(x => x.id === blockId) + 1)
    }

    readonly property var margins: root._stable("margins", SettingsConfig.bar?.margins ?? ({}))

    function marginsFor(id) {
        const m = root.margins[id]
        return (m && m.length === 2) ? m : [0, 0]
    }

    function setMargin(id, side, px) {
        const cur = root.marginsFor(id).slice()
        cur[side === "left" ? 0 : 1] = Math.max(0, Math.min(40, Math.round(px)))
        const next = Object.assign({}, root.margins)
        if (cur[0] === 0 && cur[1] === 0) delete next[id]
        else next[id] = cur
        root._patch({ margins: next })
    }

    readonly property var itemStyles: root._stable("itemStyles", SettingsConfig.bar?.itemStyles ?? ({}))

    function itemStyle(id, key, def) {
        const st = root.itemStyles[id]
        const v = st ? st[key] : undefined
        return v === undefined ? def : v
    }

    function setItemStyle(id, key, value) {
        const all = Object.assign({}, root.itemStyles)
        const cur = Object.assign({}, all[id] ?? {}, { [key]: value })
        if (value === undefined)
            delete cur[key]
        if (key === "tint" && (value ?? "none") === "none" && !root.inSplit(id)) {
            delete cur.radius
            delete cur.minW
            delete cur.minH
            delete cur.shape
        }
        if ((cur.tint ?? "none") === "none")
            delete cur.tint
        if (!cur.iconSize)
            delete cur.iconSize
        if (Object.keys(cur).length === 0)
            delete all[id]
        else
            all[id] = cur
        root._patch({ itemStyles: all })
    }

    readonly property var itemLookKeys: ["tint", "iconSize", "shape", "rotate", "radius", "pad", "gap", "minW", "minH"]

    function resetItemLook(id) {
        const all = Object.assign({}, root.itemStyles)
        const cur = Object.assign({}, all[id] ?? {})
        for (const k of root.itemLookKeys)
            delete cur[k]
        if (Object.keys(cur).length === 0)
            delete all[id]
        else
            all[id] = cur
        root._patch({ itemStyles: all })
    }

    function itemLookChanged(id) {
        const cur = root.itemStyles[id] ?? {}
        return root.itemLookKeys.some(k => cur[k] !== undefined)
    }

    function iconPx(id, def) {
        const v = root.itemStyle(id, "iconSize", 0)
        return v > 0 ? v : def
    }

    function iconOnly(contentWidth, contentHeight) {
        return contentWidth > 0 && contentHeight > 0 && contentWidth <= contentHeight + 8
    }

    function chipShape(id) {
        return root.itemStyle(id, "shape", "none")
    }

    function chipShaped(id, contentWidth, contentHeight) {
        return root.chipShape(id) !== "none" && root.iconOnly(contentWidth, contentHeight)
    }

    readonly property real chipInset: 4
    readonly property real glyphRatio: 0.64

    function iconFromBox(box) {
        return Math.max(10, Math.min(40, Math.round(box * root.glyphRatio)))
    }

    function boxFor(id, host) {
        const hosted = host && host.contentBox ? host.contentBox : 0
        if (hosted > 0)
            return hosted
        const h = root.itemStyle(id, "minH", 0)
        return h > 0 ? Math.max(12, h - root.chipInset * 2) : 0
    }

    function iconPxFor(id, box, defIcon) {
        const v = root.itemStyle(id, "iconSize", 0)
        if (v > 0)
            return v
        return box > 0 ? root.iconFromBox(box) : defIcon
    }

    function platePxFor(box, icon, defIcon, defPlate) {
        if (box > 0)
            return box
        return icon === defIcon ? defPlate : Math.round(defPlate * icon / defIcon)
    }

    function scaleFor(icon, defIcon, value, floor) {
        return icon === defIcon ? value : Math.max(floor, Math.round(value * icon / defIcon))
    }

    function tinted(id) {
        return root.itemStyle(id, "tint", "none") !== "none"
    }

    function tintOwner(id) {
        if (root.tinted(id))
            return id
        const g = root.groupOwning(id)
        return g !== "" && root.tinted(g) ? g : ""
    }

    function chipHovers(id, contentWidth, contentHeight) {
        return root.tintOwner(id) !== "" || root.inSplit(id)
    }

    function chipPad(id, shaped) {
        return root.itemStyle(id, "pad", root.isGroup(id) || shaped ? 10 : 0)
    }

    function tintHover(id) {
        const owner = root.tintOwner(id)
        return owner === "" ? "transparent"
            : Qt.alpha(root.roleColor(root.itemStyle(owner, "tint", "primary")), 0.22)
    }

    function chipGap(id, fallback) {
        const g = root.itemStyle(id, "gap", -1)
        return g >= 0 ? g : fallback
    }

    function chipSide(id, contentWidth, contentHeight, barH) {
        const auto = Math.max(contentWidth, contentHeight) + root.chipPad(id, true)
        return Math.min(barH, Math.max(auto, root.itemStyle(id, "minH", 0)))
    }

    function chipW(id, contentWidth, contentHeight, barH) {
        if (root.itemStyle(id, "tint", "none") === "none")
            return 0
        if (root.chipShaped(id, contentWidth, contentHeight))
            return root.chipSide(id, contentWidth, contentHeight, barH)
        return Math.max(contentWidth + root.chipPad(id) * 2, root.itemStyle(id, "minW", 0))
    }

    function chipH(id, contentHeight, barH, contentWidth) {
        if (root.itemStyle(id, "tint", "none") === "none")
            return 0
        if (root.chipShaped(id, contentWidth, contentHeight))
            return root.chipSide(id, contentWidth, contentHeight, barH)
        return Math.min(barH, Math.max(contentHeight + (root.isGroup(id) ? 8 : 0), root.itemStyle(id, "minH", 0)))
    }

    function chipRadius(id, h) {
        const r = root.itemStyle(id, "radius", -1)
        return r < 0 ? h / 2 : r
    }

    function chipColor(id, hovered) {
        return Qt.alpha(root.roleColor(root.itemStyle(id, "tint", "primary")), hovered ? 0.32 : 0.18)
    }

    function isGroup(id) {
        return root.baseId(id) === "group"
    }

    function groupMembers(groupId) {
        return root._list(root.itemGroups[groupId] ?? [])
    }

    function groupOwning(itemId) {
        const g = root.itemGroups
        for (const key in g)
            if (root._list(g[key]).indexOf(itemId) >= 0)
                return key
        return ""
    }

    function _groupsPatch(groups, blocks) {
        const patch = { groups: groups }
        if (blocks)
            Object.assign(patch, root._statePatch(blocks))
        root._patch(patch)
    }

    function addToGroup(groupId, itemId) {
        const e = root.entry(itemId)
        const id = (e && e.multi && itemId.indexOf("#") < 0) ? root.newInstanceId(itemId) : itemId
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key]).filter(x => x !== id)
        groups[groupId] = (groups[groupId] ?? []).concat([id])
        const list = root._clone()
        BarOps.strip(list, id)
        root._groupsPatch(groups, list)
    }

    function removeFromGroup(groupId, itemId) {
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key]).filter(x => x !== itemId)
        root._groupsPatch(groups, null)
    }

    function moveInGroup(groupId, itemId, delta) {
        const cur = root.groupMembers(groupId)
        const next = BarOps.reorder(cur, itemId, delta)
        if (next.join("\u0000") === cur.join("\u0000"))
            return
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key])
        groups[groupId] = next
        root._patch({ groups: groups })
    }

    function clearMargins(id) {
        if (!(id in root.margins))
            return
        const next = Object.assign({}, root.margins)
        delete next[id]
        root._patch({ margins: next })
    }

    readonly property var panelSpecs: ({
        "calendar":  { "label": "Calendar",  "minW": 320, "maxW": 640, "defW": 400, "minH": 300, "maxH": 560,  "defH": 400 },
        "weather":   { "label": "Weather",   "minW": 300, "maxW": 720, "defW": 340, "minH": 360, "maxH": 1600, "defH": -1 },
        "dashboard": { "label": "Dashboard", "minW": 360, "maxW": 980, "defW": 460, "minH": 400, "maxH": 1600, "defH": -1, "fitOnly": true },
        "launcher":  { "label": "Launcher", "minW": ServiceLauncher.minWidth, "maxW": ServiceLauncher.maxWidth,
                       "defW": ServiceLauncher.defaultWidth, "minH": ServiceLauncher.minHeight,
                       "maxH": ServiceLauncher.maxHeight, "defH": ServiceLauncher.defaultHeight }
    })
    readonly property var panelOpeners: ({ "clock": "calendar", "weather": "weather", "launcher": "launcher", "wallpaper": "wallpaper", "clipboard": "clipboard", "notifications": "notifications", "dashboard": "dashboard" })
    readonly property var panelSizes: root._stable("panelSizes", SettingsConfig.bar?.panelSizes ?? ({}))
    property var panelDraft: null

    function draftOf(kind) {
        if (kind === "launcher") return ServiceLauncher.draft
        return root.panelDraft && root.panelDraft.kind === kind ? root.panelDraft : null
    }

    function setDraft(kind, w, h) {
        if (kind === "launcher") ServiceLauncher.draft = { w: w, h: h }
        else root.panelDraft = { kind: kind, w: w, h: h }
    }

    function panelCustom(kind) {
        return kind === "launcher" ? ServiceLauncher.customSize : kind in root.panelSizes
    }

    function isPlaced(id) {
        return root.allBlocks.some(b => b.items.indexOf(id) >= 0)
            || (root.groupedIds ?? []).indexOf(id) >= 0
    }

    function shownItemIds() {
        const ids = []
        root.allBlocks.forEach(b => {
            if (!root.edge(b.edge).hidden)
                b.items.forEach(id => ids.push(id))
        })
        return ids
    }

    readonly property string popupHostItem: {
        const ids = root.shownItemIds()
        const placed = ids.find(id => root.baseId(id) === "popups")
        if (placed)
            return placed
        if ((SettingsConfig.general?.notifPopupStyle ?? "item") === "icon")
            return ""
        return ids.find(id => root.baseId(id) === "notifications") ?? ""
    }
    readonly property string osdHostItem: root.shownItemIds().find(i => root.baseId(i) === "osd") ?? ""
    readonly property string popupMode: (SettingsConfig.notifications?.popupLook ?? "cards") === "island" ? "island"
        : root.popupHostItem !== "" ? "item"
        : (SettingsConfig.general?.notifPopupStyle ?? "item") === "icon" ? "icon" : "corner"

    function panelHostItem(kind) {
        if (kind === "calendar") return "clock"
        if (root.blockOfItem(kind))
            return kind
        const ids = Object.keys(root.followKinds).filter(id => root.followKinds[id] === kind)
        return ids.find(id => root.blockOfItem(id)) ?? ids[0] ?? kind
    }

    function logoFor(action) {
        const ids = []
        root.allBlocks.forEach(b => b.items.forEach(id => ids.push(id)))
        const found = ids.find(id => root.baseId(id) === "logo" && (root.opt(id, "action") ?? "launcher") === action)
        return found ?? ""
    }

    readonly property var followKinds: ({
        "battery": "battery", "cpu": "cpu", "memory": "memory", "bluetooth": "bluetooth", "brightness": "brightness", "claudeCode": "claudeCode",
        "kindle": "kindle", "dashboard": "dashboard", "nextEvent": "calendar", "clock": "calendar", "notifications": "notifications",
        "volume": "sound", "phoneCall": "phoneCall",
        "phoneNotifs": "phoneNotifs", "phoneStatus": "phoneStatus", "powerMode": "powerMode", "power": "power",
        "scenes": "scenes", "soundscape": "soundscape", "weather": "weather", "wifi": "network",
        "windowTitle": "windowInfo", "wiz": "wiz"
    })

    readonly property var hoverOpeners: ({ "clock": true, "music": true, "tray": true })

    function openOn(id) {
        return root.itemStyle(id, "openOn", root.hoverOpeners[root.baseId(id)] ? "hover" : "click")
    }

    function hasOpenChoice(id) {
        return !!id && (root.followKind(id) !== "" || !!root.hoverOpeners[root.baseId(id)])
    }

    function setOpenOn(id, value) {
        root.setItemStyle(id, "openOn", value === (root.hoverOpeners[root.baseId(id)] ? "hover" : "click") ? undefined : value)
    }

    function followKind(id) {
        return id ? root.followKinds[root.baseId(id)] ?? "" : ""
    }

    function panelFor(id) {
        if (!id) return ""
        return root.panelOpeners[root.baseId(id)] ?? ""
    }

    function clampPanelW(kind, w) {
        const s = root.panelSpecs[kind]
        return Math.round(Math.max(s.minW, Math.min(s.maxW, w)))
    }

    function clampPanelH(kind, h) {
        const s = root.panelSpecs[kind]
        return h < 0 ? -1 : Math.round(Math.max(s.minH, Math.min(s.maxH, h)))
    }

    function panelW(kind) {
        if (kind === "launcher") return ServiceLauncher.panelWidth
        const s = root.panelSpecs[kind]
        if (!s) return 0
        const d = root.panelDraft
        if (d && d.kind === kind) return d.w
        const own = root.panelSizes[kind]
        const w = own && typeof own.w === "number" ? root.clampPanelW(kind, own.w) : s.defW
        if (!s.fitOnly)
            return w
        return [s.minW, s.defW, s.maxW].reduce((best, c) => Math.abs(c - w) < Math.abs(best - w) ? c : best, s.defW)
    }

    function panelH(kind) {
        if (kind === "launcher") return ServiceLauncher.panelHeight
        const s = root.panelSpecs[kind]
        if (!s) return -1
        if (s.fitOnly) return -1
        const d = root.panelDraft
        if (d && d.kind === kind) return d.h
        const own = root.panelSizes[kind]
        return own && typeof own.h === "number" ? root.clampPanelH(kind, own.h)
            : s.defH > 0 ? Math.min(s.defH, root.panelCapH) : s.defH
    }

    readonly property int panelCapH: Math.max(280, Quickshell.screens.reduce((m, sc) => Math.min(m, sc.height), 100000) - 60)

    function panelHeightIn(kind, auto, room) {
        const h = root.panelH(kind)
        return Math.max(0, Math.min(room, h < 0 ? auto : h))
    }

    function panelPresets(kind) {
        const s = root.panelSpecs[kind]
        if (!s)
            return []
        const mid = (a, b) => Math.round((a + b) / 2)
        return [
            { value: "snug", label: "Snug", w: s.minW, h: s.defH < 0 ? -1 : s.minH },
            { value: "roomy", label: "Roomy", w: s.defW, h: s.defH, reset: true },
            { value: "wide", label: "Wide", w: s.fitOnly ? s.maxW : mid(s.defW, s.maxW), h: s.defH < 0 ? -1 : mid(s.defH, s.maxH) }
        ]
    }

    function presetActive(kind, value) {
        const p = root.panelPresets(kind).find(x => x.value === value)
        return !!p && root.panelW(kind) === root.clampPanelW(kind, p.w) && root.panelH(kind) === root.clampPanelH(kind, p.h)
    }

    function applyPreset(kind, value) {
        const p = root.panelPresets(kind).find(x => x.value === value)
        if (!p)
            return
        if (p.reset) root.clearPanelSize(kind)
        else root.setPanelSize(kind, p.w, p.h)
    }

    readonly property var panelRadii: root._stable("panelRadius", SettingsConfig.bar?.panelRadius ?? ({}))

    function panelRadius(kind) {
        const v = kind ? root.panelRadii[kind] : undefined
        return v === undefined ? -1 : v
    }

    function setPanelRadius(kind, v) {
        if (!kind) return
        const next = Object.assign({}, root.panelRadii)
        if (v < 0) delete next[kind]
        else next[kind] = Math.round(v)
        root._patch({ panelRadius: next })
    }

    function setPanelSize(kind, w, h) {
        if (kind === "launcher") {
            ServiceLauncher.setSize(w, h)
            return
        }
        if (!root.panelSpecs[kind]) return
        const s = root.panelSpecs[kind]
        const next = Object.assign({}, root.panelSizes)
        const cw = root.clampPanelW(kind, w)
        const ch = root.clampPanelH(kind, h)
        if (cw === s.defW && ch === s.defH) delete next[kind]
        else next[kind] = { "w": cw, "h": ch }
        root.panelDraft = null
        root._patch({ panelSizes: next })
    }

    function clearPanelSize(kind) {
        if (kind === "launcher") {
            ServiceLauncher.clearSize()
            return
        }
        root.panelDraft = null
        if (!(kind in root.panelSizes))
            return
        const next = Object.assign({}, root.panelSizes)
        delete next[kind]
        root._patch({ panelSizes: next })
    }

    readonly property var itemOptions: root._stable("itemOptions", SettingsConfig.bar?.options ?? ({}))

    function specFor(id, key) {
        const e = root.entry(id)
        if (!e || !e.options)
            return null
        return e.options.find(o => o.key === key) ?? null
    }

    function opt(id, key) {
        const s = root.specFor(id, key)
        if (s && s.setting)
            return (SettingsConfig[s.section ?? "general"] ?? {})[s.setting] ?? s.default
        const own = root.itemOptions[id]
        const v = own ? own[key] : undefined
        return v !== undefined ? v : (s ? s.default : undefined)
    }

    function setOption(id, key, value) {
        const s = root.specFor(id, key)
        if (s && s.setting) {
            const g = {}
            g[s.setting] = value
            const sec = s.section ?? "general"
            SettingsConfig[sec] = Object.assign({}, SettingsConfig[sec], g)
            return
        }
        const next = Object.assign({}, root.itemOptions)
        const own = Object.assign({}, next[id] ?? {})
        own[key] = value
        next[id] = own
        root._patch({ options: next })
    }

    readonly property real itemGap: (SettingsConfig.bar ?? {}).itemGap ?? 6
    readonly property real blockGap: (SettingsConfig.bar ?? {}).blockGap ?? -1
    readonly property real cornerRadius: (SettingsConfig.bar ?? {}).radius ?? 18

    function setSize(key, value) {
        const o = {}
        o[key] = value
        root._patch(o)
    }

    readonly property var screenBorder: Object.assign({ on: false, size: 8, radius: 20, top: true, right: true, bottom: true, left: true },
                                                      SettingsConfig.bar?.border ?? {})

    function setBorder(patch) {
        root._patch({ border: Object.assign({}, root.screenBorder, patch) })
    }

    readonly property var barShadow: Object.assign({ on: false, size: 16, strength: 35, offset: 0, contact: 0, tint: false },
                                                   SettingsConfig.bar?.shadow ?? {})
    readonly property real shadowReach: root.barShadow.on === true ? Number(root.barShadow.size) * 1.7 : 0
    readonly property real shadowAlpha: root.barShadow.on === true ? Number(root.barShadow.strength) / 100 * 0.7 : 0
    readonly property real shadowLift: root.barShadow.on === true ? Number(root.barShadow.offset) : 0
    readonly property real shadowContact: root.barShadow.on === true ? Number(root.barShadow.contact) / 100 * 0.6 : 0
    readonly property color shadowTone: root.barShadow.tint === true
        ? Qt.rgba(Colors.primary.r * 0.32, Colors.primary.g * 0.32, Colors.primary.b * 0.32, 1)
        : Colors.shadow
    readonly property var shadowPresets: [
        { value: "soft",  label: "Soft",  size: 8,  strength: 20, offset: 0, contact: 0 },
        { value: "lift",  label: "Lifted", size: 10, strength: 30, offset: 3, contact: 50 },
        { value: "float", label: "Float", size: 20, strength: 40, offset: 8, contact: 0 },
        { value: "crisp", label: "Crisp", size: 14, strength: 15, offset: 0, contact: 80 },
        { value: "halo",  label: "Halo",  size: 9,  strength: 50, offset: 0, contact: 0 }
    ]
    readonly property string shadowPreset: {
        const s = root.barShadow
        const hit = root.shadowPresets.find(p => p.size === Number(s.size) && p.strength === Number(s.strength)
                                                 && p.offset === Number(s.offset) && p.contact === Number(s.contact))
        return hit ? hit.value : ""
    }

    function applyShadowPreset(id) {
        const p = root.shadowPresets.find(q => q.value === id)
        if (p)
            root.setShadow({ size: p.size, strength: p.strength, offset: p.offset, contact: p.contact })
    }

    function setShadow(patch) {
        root._patch({ shadow: Object.assign({}, root.barShadow, patch) })
    }

    property var gapFlash: null
    property var gapHover: null

    function hoverGap(on, key, edge, block) {
        const h = root.gapHover
        if (on)
            root.gapHover = { key: key, edge: edge ?? "", block: block ?? "" }
        else if (h && h.key === key && h.edge === (edge ?? "") && h.block === (block ?? ""))
            root.gapHover = null
    }

    function flashGap(key, edge, block) {
        root.gapFlash = { key: key, edge: edge ?? "", block: block ?? "", n: (root.gapFlash ? root.gapFlash.n : 0) + 1 }
    }

    readonly property real panelGap: Math.max(0, Number(SettingsConfig.bar?.panelGap ?? 8) || 0)

    function setPanelGap(v) {
        const all = {}
        for (const id in root.blockStyles) {
            const st = Object.assign({}, root.blockStyles[id])
            delete st.panelGap
            all[id] = st
        }
        const patch = { panelGap: v, blockStyles: all }
        const stored = SettingsConfig.bar?.edges
        if (stored && typeof stored === "object") {
            const edges = {}
            for (const side in stored) {
                const e = Object.assign({}, stored[side])
                delete e.panelGap
                edges[side] = e
            }
            patch.edges = edges
        }
        root._patch(patch)
    }

    function blockCorners(blockId) {
        const d = root.gapDraft
        const c = d && d.block === blockId && d.style && "corners" in d.style ? d.style.corners
            : root.blockStyle(blockId, "corners", null)
        const pick = k => c && c[k] !== undefined && c[k] !== null ? Math.max(0, Number(c[k]) || 0) : null
        return { tl: pick("tl"), tr: pick("tr"), br: pick("br"), bl: pick("bl") }
    }

    function setBlockCorner(blockId, key, v) {
        const cur = Object.assign({}, root.blockStyle(blockId, "corners", null) ?? {})
        if (key === "all") {
            for (const k of ["tl", "tr", "br", "bl"])
                cur[k] = v
        } else {
            cur[key] = v
        }
        const empty = ["tl", "tr", "br", "bl"].every(k => cur[k] === undefined || cur[k] === null)
        root.setBlockStyle(blockId, "corners", empty ? null : cur)
    }

    function blockPanelGap(blockId) {
        const v = root.blockStyle(blockId, "panelGap", null)
        if (v !== null && v !== undefined)
            return Math.max(0, Number(v) || 0)
        const b = root.blockById(blockId)
        return b ? root.edgePanelGap(b.edge) : root.panelGap
    }

    function reset() {
        root.panelDraft = null
        root._patch({ blocks: [], dock: {}, margins: {}, options: {}, groups: {}, panelSizes: {},
                      itemStyles: {}, blockStyles: {}, edgeVersion: 0, edges: {}, side: "top",
                      height: 40, itemGap: 6, blockGap: -1, radius: 18 })
    }

    function syncAnimated(model, ids, role, leaving) {
        for (let i = 0; i < model.count; i++) {
            const id = model.get(i)[role]
            if (ids.indexOf(id) < 0) leaving[id] = true
            else delete leaving[id]
        }
        root.syncModel(model, ids, role, leaving)
    }

    function dropLeaving(model, ids, role, leaving, id) {
        delete leaving[id]
        root.syncModel(model, ids, role, leaving)
    }

    function syncModel(model, wanted, role, leaving) {
        const ids = wanted.slice()
        if (leaving) {
            for (let i = 0; i < model.count; i++) {
                const id = model.get(i)[role]
                if (ids.indexOf(id) < 0 && leaving[id])
                    ids.splice(Math.min(i, ids.length), 0, id)
            }
        }
        for (let i = 0; i < ids.length; i++) {
            if (i < model.count && model.get(i)[role] === ids[i])
                continue
            let found = -1
            for (let j = i + 1; j < model.count; j++) {
                if (model.get(j)[role] === ids[i]) {
                    found = j
                    break
                }
            }
            if (found >= 0) {
                model.move(found, i, 1)
            } else {
                const o = { leaving: false }
                o[role] = ids[i]
                model.insert(i, o)
            }
        }
        while (model.count > ids.length)
            model.remove(model.count - 1)
        for (let i = 0; i < model.count; i++) {
            const lv = !!(leaving && leaving[model.get(i)[role]])
            if (model.get(i).leaving !== lv)
                model.setProperty(i, "leaving", lv)
        }
    }

    Connections {
        target: GlobalStates
        function onEditModeChanged() {
            if (!GlobalStates.editMode) root.pruneEmpty()
        }
    }

    IpcHandler {
        target: "bar"
        function edit(): void { GlobalStates.openEdit("edges") }
        function done(): void { GlobalStates.closeEdit() }
        function reset(): void { root.reset() }
        function open(kind: string): void { GlobalStates.openPanel(kind) }
        function close(): void { GlobalStates.openPanel("") }
        function state(): string {
            return JSON.stringify({ margins: root.margins, options: root.itemOptions, bar: SettingsConfig.bar, hidden: root.hiddenItems,
                                    blocks: root.allBlocks, edges: root.edges })
        }
    }

    GlobalShortcut {
        name: "barEdit"
        onPressed: GlobalStates.toggleEdit("edges")
    }
}
