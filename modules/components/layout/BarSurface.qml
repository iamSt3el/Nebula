import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.components.Bar
import qs.modules.settings
import qs.modules.components.AppLauncher
import qs.modules.components.ToolsWidget
import qs.modules.components.Setting
import qs.modules.components.Clipboard
import qs.modules.components.Notification
import qs.modules.components.Osd
import qs.modules.components.Widgets
import qs.modules.services
import qs.modules.customComponents
import "../Bar/BarPath.js" as BarPath
import "../Bar/BarOps.js" as BarOps

Item {
    id: surface
    x: 0
    y: 0
    width: surface.vertical ? parent.height : parent.width
    height: surface.vertical ? parent.width : parent.height
    transform: surface.vertical ? [surface.transpose] : []

    property bool isPrimary: true
    property QtObject editor: null
    property string edge: "top"
    readonly property string side: surface.edge
    readonly property var cfg: BarLayout.edge(surface.edge)
    readonly property bool present: BarLayout.edgeShown(surface.edge)
    readonly property bool vertical: BarOps.isVerticalSide(surface.side)
    readonly property bool far: BarOps.isFarSide(surface.side)
    readonly property real barH: surface.cfg.height
    property real crossStart: 0
    property real crossEnd: 0
    property real sideStart: 0
    property real sideEnd: 0
    property Item cornerPillStart: null
    property Item cornerPillEnd: null
    property real stripStart: 0
    property real stripEnd: 0
    readonly property real spanStart: Math.max(sectionsRow.x, surface.sideStart)
    readonly property real spanEnd: Math.max(surface.spanStart, Math.min(sectionsRow.x + sectionsRow.width, surface.width - surface.sideEnd))
    readonly property real panelGap: 16
    readonly property var pushPlan: {
        if (surface.dragging || GlobalStates.barEditMode)
            return surface.keepJson("pushPlan", { push: {}, shift: {}, hide: {} })
        const pos = b => b.baseX ?? b.absX
        const all = surface.visibleBlocks.slice().sort((p, q) => pos(p) - pos(q))
        const items = []
        const gaps = []
        let prev = null
        for (const b of all) {
            const attached = b.tabOpen && !b.floating && !b.merged
            const live = attached && b.shownKind !== ""
            const it = {
                id: b.blockId, x: pos(b), w: b.width, open: b.tabOpen, pill: b.isPill, run: surface.runOf(b),
                absX: b.absX, reach: b.snapReach,
                panel: !live ? null : { live: true, l: b.absX + b.tabPreX, w: b.tabNaturalW }
            }
            const body = surface.fused[b.blockId]?.key ?? b.blockId
            const last = items[items.length - 1]
            if (last && last.body === body) {
                const r = Math.max(last.x + last.w, it.x + it.w)
                last.x = Math.min(last.x, it.x)
                last.w = r - last.x
                last.absX = Math.min(last.absX, it.absX)
                last.open = last.open || it.open
                if (it.panel) {
                    last.id = it.id
                    last.panel = it.panel
                    last.reach = it.reach
                }
                last.members.push(it.id)
            } else {
                if (prev)
                    gaps.push(surface.naturalGap(prev, b))
                it.body = body
                it.members = [it.id]
                items.push(it)
            }
            prev = b
        }
        const plan = BarPath.planPush(items, gaps, { spanStart: surface.spanStart, spanEnd: surface.spanEnd,
                                                    clear: surface.disX + 6, pairClear: surface.blockGapSetting >= 0,
                                                    minGap: surface.minGap })
        for (const it of items) {
            if (it.members.length < 2)
                continue
            for (const m of it.members) {
                if (plan.push[it.id] !== undefined)
                    plan.push[m] = plan.push[it.id]
                if (plan.hide[it.id] !== undefined)
                    plan.hide[m] = plan.hide[it.id]
            }
        }
        return surface.keepJson("pushPlan", plan)
    }
    readonly property var pushMotion: {
        let src = null
        for (const b of surface.visibleBlocks) {
            if (!b || b.floating || b.merged || !b.panelMotion)
                continue
            if (!src || (b.tabOpen && !src.tabOpen))
                src = b
        }
        return src ? { duration: src.spanDuration, curve: src.spanCurve }
            : { duration: M3Motion.spatialDuration("default"), curve: M3Motion.spatialCurve("default") }
    }

    function reachBase(atEnd, depth) {
        if (depth <= 0)
            return 0
        let reach = 0
        for (const b of surface.visibleBlocks) {
            if (!b.tabOpen)
                continue
            const live = b.shownKind !== "" && !b.closing
            const x0 = b.absX + (live ? b.tabBaseX : b.tabX)
            const x1 = x0 + (live ? b.tabNaturalW : b.tabW)
            if (x1 - x0 < 0.5)
                continue
            const d = surface.blockTop(b) + (live ? surface.barH + b.acrossOf(b.shownKind) : b.tabH) + (b.floating ? b.floatGap : 0)
            const hit = atEnd ? x1 > surface.width - depth - surface.panelGap : x0 < depth + surface.panelGap
            if (hit)
                reach = Math.max(reach, d)
        }
        return reach > 0 ? reach + surface.panelGap : 0
    }
    function fitsWith(start, end) {
        const lo = Math.max(sectionsRow.x, start)
        const hi = Math.min(sectionsRow.x + sectionsRow.width, surface.width - end)
        for (const b of surface.visibleBlocks) {
            if (b.shownKind !== "" && !b.closing && b.alongOf(b.shownKind) > hi - lo + 0.5)
                return false
        }
        return true
    }
    function openRects(side) {
        const out = []
        for (const b of surface.visibleBlocks) {
            if (b.shownKind === "" || b.closing || b.tabTargetW < 1)
                continue
            const a0 = b.absX + b.tabTargetX
            out.push({ id: b.blockId, side: side, a0: a0, a1: a0 + b.tabTargetW,
                       depth: surface.blockTop(b) + surface.barH + b.acrossOf(b.shownKind) + (b.floating ? b.floatGap : 0) })
        }
        return out
    }
    function blockRects(side, atEnd) {
        if (surface.autoHide || !surface.present || surface.stripInset > 0)
            return []
        const gap = atEnd ? surface.cornerGapEnd : surface.cornerGapStart
        const out = []
        for (const b of surface.visibleBlocks) {
            if (b.width < 1)
                continue
            out.push({ id: "block:" + b.blockId, side: side, a0: b.absX, a1: b.absX + b.width,
                       depth: surface.blockTop(b) + surface.barH, gap: gap > 0 ? gap : undefined, block: true })
        }
        return out
    }
    function restX(b) {
        return b.baseX ?? surface.blockX(b)
    }
    property var crossPanels: []
    function crossFor(b) {
        if (!surface.crossPanels.length)
            return []
        const near = surface.blockTop(b) + surface.barH
        const far = near + b.acrossOf(b.shownKind) + (b.floating ? b.floatGap : 0)
        const y0 = surface.far ? surface.height - far : near
        const y1 = surface.far ? surface.height - near : far
        const out = []
        for (const p of surface.crossPanels) {
            if (Math.min(p.a1, y1) - Math.max(p.a0, y0) <= 0)
                continue
            out.push({ id: "cross:" + p.id, l: p.side === "left" ? -1e6 : surface.width - p.depth,
                       r: p.side === "left" ? p.depth : surface.width + 1e6, il: false, ir: false, transient: false,
                       gap: p.block && b.floating ? b.floatGap : p.gap })
        }
        return out
    }
    readonly property real panelDepth: {
        let d = 0
        for (const b of surface.visibleBlocks) {
            if (b.shownKind !== "" && !b.closing)
                d = Math.max(d, surface.blockTop(b) + surface.barH + b.acrossOf(b.shownKind) + (b.floating ? b.floatGap : 0))
        }
        return d
    }
    readonly property real thickness: surface.present ? surface.borderNear + surface.maxDrop + surface.barH : 0
    readonly property real borderStart: Math.max(ServiceGaps.borderFor(surface.vertical ? "top" : "left") * (1 - surface.startPill), surface.crossStart)
    readonly property real borderEnd: Math.max(ServiceGaps.borderFor(surface.vertical ? "bottom" : "right") * (1 - surface.endPill), surface.crossEnd)
    readonly property bool screenStart: surface.crossStart <= ServiceGaps.borderFor(surface.vertical ? "top" : "left")
    readonly property bool screenEnd: surface.crossEnd <= ServiceGaps.borderFor(surface.vertical ? "bottom" : "right")
    readonly property real cornerStart: ServiceGaps.borderOn
        ? Math.max(ServiceGaps.borderFor(surface.vertical ? "top" : "left"), surface.crossStart)
          + surface.curveClear(ServiceGaps.borderRadius, surface.orderedBlocks.length ? surface.orderedBlocks[0].pillRadius : surface.barH / 2)
        : 0
    readonly property real cornerEnd: ServiceGaps.borderOn
        ? Math.max(ServiceGaps.borderFor(surface.vertical ? "bottom" : "right"), surface.crossEnd)
          + surface.curveClear(ServiceGaps.borderRadius, surface.orderedBlocks.length ? surface.orderedBlocks[surface.orderedBlocks.length - 1].pillRadius : surface.barH / 2)
        : 0

    readonly property var _clearMemo: ({ size: 0, values: {} })
    function _remember(key, value) {
        const memo = surface._clearMemo
        if (++memo.size > 600) {
            memo.values = {}
            memo.size = 1
        }
        memo.values[key] = value
        return value
    }

    function curveClear(r, rp, h, gap) {
        h = h ?? surface.barH
        gap = gap ?? surface.pillMargin
        const key = r + "|" + rp + "|" + h + "|" + gap
        const memo = surface._clearMemo.values[key]
        return memo !== undefined ? memo : surface._remember(key, surface._clearRaw(r, rp, h, gap))
    }

    function flareFit(room, rp, gap) {
        room = Math.max(0, Math.round(room * 4) / 4)
        gap = Math.max(0, Math.round(gap * 4) / 4)
        const key = "f|" + room + "|" + rp + "|" + gap + "|" + surface.disX + "|" + surface.barH
        const memo = surface._clearMemo.values[key]
        if (memo !== undefined)
            return memo
        const margin = Math.min(Math.max(2, gap), room)
        const fits = r => surface._clearRaw(r, rp, surface.barH, gap, margin) <= room + 0.01
        let lo = 0
        let hi = surface.disX
        if (fits(hi))
            lo = hi
        else
            for (let i = 0; i < 12; i++) {
                const mid = (lo + hi) / 2
                if (fits(mid)) lo = mid
                else hi = mid
            }
        return surface._remember(key, lo)
    }

    function _clearRaw(r, rp, h, gap, margin) {
        const exact = margin !== undefined
        const m = exact ? margin : Math.max(2, gap)
        const cy = gap + h / 2
        const away = g => {
            let d = g
            const cx = g + 2 * h
            for (let i = 0; i <= 16; i++) {
                const a = Math.PI * (1 + i / 32)
                const qx = Math.abs(r + r * Math.cos(a) - cx) - (2 * h - rp)
                const qy = Math.abs(r + r * Math.sin(a) - cy) - (h / 2 - rp)
                d = Math.min(d, Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - rp)
            }
            return d
        }
        let lo = m
        let hi = r + m + 1
        if (away(lo) < m) {
            for (let i = 0; i < 14; i++) {
                const mid = (lo + hi) / 2
                if (away(mid) >= m) hi = mid
                else lo = mid
            }
            lo = hi
        }
        return exact ? lo : Math.ceil(lo)
    }
    readonly property real borderFar: ServiceGaps.borderFor(BarOps.oppositeSide(surface.side))
    property real farBand: 0
    property real farReserve: 0
    readonly property real panelFar: Math.max(surface.borderFar, surface.farBand)
    readonly property real borderNear: ServiceGaps.borderFor(surface.side)
    readonly property real edgeInset: surface.far
        ? surface.height - sectionsRow.y - sectionsRow.height : sectionsRow.y
    property Matrix4x4 transpose: Matrix4x4 { matrix: Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

    function toScreen(x, y, w, h) {
        return surface.vertical ? Qt.rect(y, x, h, w) : Qt.rect(x, y, w, h)
    }

    function toFrame(x, y) {
        return surface.vertical ? Qt.point(y, x) : Qt.point(x, y)
    }

    function blockRect(b) {
        const lu = b.lineUp ?? 0
        return surface.toScreen(sectionsRow.x + b.parent.x + b.x, sectionsRow.y + b.parent.y + b.y - (surface.far ? lu : 0),
                                b.width, b.height + lu)
    }

    function hiddenRect(b) {
        const x = sectionsRow.x + b.parent.x + b.x
        return surface.toScreen(x, surface.far ? surface.height - 8 : 0, b.width, 8)
    }

    function tabRect(b) {
        const x = sectionsRow.x + b.parent.x + b.x + b.tabX
        const y = sectionsRow.y + b.parent.y + b.y + (surface.far ? b.barH - b.tabH - b.floatGap : 0)
        return surface.toScreen(x, y, b.tabW, b.tabH + b.floatGap)
    }

    function tabGoalRect(b) {
        const h = b.barH + b.liveAcross
        const x = sectionsRow.x + b.parent.x + b.x + b.tabTargetX
        const y = sectionsRow.y + b.parent.y + b.y + (surface.far ? b.barH - h - b.floatGap : 0)
        return surface.toScreen(x, y, b.tabTargetW, h + b.floatGap)
    }

    readonly property rect bandRect: surface.toScreen(0, surface.far ? surface.height - surface.edgeInset - surface.maxDrop - surface.barH : 0,
                                                      surface.width, surface.edgeInset + surface.maxDrop + surface.barH)

    function inBand(fx, fy, slack) {
        if (surface.far)
            return fy >= sectionsRow.y + sectionsRow.height - surface.maxDrop - surface.barH - slack
        return fy <= sectionsRow.y + surface.maxDrop + surface.barH + slack
    }
    readonly property Item rowItem: sectionsRow
    readonly property Item leftRepeater: leftRep
    readonly property Item centerRepeater: centerRep
    readonly property Item rightRepeater: rightRep
    readonly property Item leftGroupItem: leftGroup
    readonly property Item centerGroupItem: centerGroup
    readonly property Item rightGroupItem: rightGroup

    readonly property real disX: surface.cfg.radius
    readonly property var shapeList: BarLayout.edgeShapes(surface.edge)
    readonly property bool anyPill: surface.shapeList.indexOf("pill") >= 0
    readonly property bool allPill: surface.shapeList.every(v => v === "pill")
    readonly property real pillMargin: surface.cfg.pillGap
    readonly property real lineUpDepth: surface.cfg.lineUp === true && surface.anyPill && !surface.allPill ? surface.pillMargin : 0
    readonly property real pillStartGap: surface.cfg.pillStart
    readonly property real pillEndGap: surface.cfg.pillEnd

    readonly property real blockGapSetting: surface.cfg.blockGap
    readonly property real wideGap: 2 * surface.disX + 28
    readonly property real groupGap: surface.blockGapSetting >= 0 ? surface.blockGapSetting
        : surface.shapeList.every(v => v === "stepped") ? surface.wideGap : 14

    readonly property real baseGap: surface.vertical ? 6 : 14
    readonly property real minGap: 4

    readonly property var gaps: BarLayout.gapModel ? BarLayout.edgeGaps(surface.edge) : null
    property real fillShown: surface.gaps ? Math.max(0, Math.min(1, surface.gaps.fill)) : 0
    Behavior on fillShown { enabled: BarLayout.settled && surface.gaps !== null && !BarLayout.gapDragging; SpatialAnim { speed: "default" } }
    property real radiusShown: surface.gaps && surface.gaps.radius >= 0 ? surface.gaps.radius : surface.disX
    Behavior on radiusShown { enabled: BarLayout.settled && surface.gaps !== null && !BarLayout.gapDragging; SpatialAnim { speed: "default" } }

    function naturalGap(a, b) {
        if (surface.gaps)
            return a && b && a.anchorSide === b.anchorSide && (b.gapBefore ?? -1) >= 0 ? b.gapBefore : surface.gaps.block
        a = a ?? b
        b = b ?? a
        if (!a)
            return surface.groupGap
        const mix = Math.abs(a.pillT - b.pillT)
        if (surface.blockGapSetting >= 0)
            return surface.blockGapSetting + mix * surface.curveClear(surface.disX, (a.pillT > b.pillT ? a : b).pillRadius ?? surface.barH / 2)
        const capRoom = (surface.vertical ? 1 : 2) * surface.disX * mix
        const stepped = (1 - Math.max(a.pillT, b.pillT)) * (1 - Math.min(a.flatT, b.flatT))
        return surface.baseGap + (surface.wideGap - surface.baseGap) * stepped + capRoom
    }

    function cornerGap(pill, own) {
        if (!surface.vertical || !pill || !own)
            return 0
        return surface.naturalGap(own, pill) * (1 - own.pillT)
    }
    readonly property real cornerGapStart: surface.cornerGap(surface.cornerPillStart, surface.orderedBlocks[0] ?? null)
    readonly property real cornerGapEnd: surface.cornerGap(surface.cornerPillEnd, surface.orderedBlocks[surface.orderedBlocks.length - 1] ?? null)

    function gapBetween(a, b) {
        const g = surface.naturalGap(a, b)
        return g <= surface.minGap ? g : surface.minGap + (g - surface.minGap) * surface.fitT
    }

    property real fitT: 1
    readonly property bool dragging: !!surface.editor && surface.editor.mode !== ""
    property int editPage: 0
    onDraggingChanged: surface.markGeom()

    function markGeom() {
        Qt.callLater(surface.recompute)
    }

    function markTabs() {
        Qt.callLater(surface.recomputeTabs)
    }

    function recomputeTabs() {
        surface.tabShapes = surface.calcTabShapes()
        const split = surface.splitTabs(surface.tabShapes)
        const lift = surface.sdfField.lift ? Object.assign({}, surface.sdfField.lift, { tabs: split.lift }) : surface.sdfField.lift
        surface.sdfField = Object.assign({}, surface.sdfField, { tabs: split.main, lift: lift })
    }

    function liftIds() {
        const ids = {}
        for (const b of surface.visibleBlocks)
            if (!b.isPill)
                ids[b.blockId] = true
        return ids
    }

    function splitTabs(tabs) {
        const ids = surface.revealSplit ? surface.liftIds() : {}
        const rigid = {}
        for (const b of surface.visibleBlocks) {
            if (b.drawer) {
                ids[b.blockId] = true
                rigid[b.blockId] = b.panelCorner
            }
        }
        if (!tabs.some(t => ids[t.id]))
            return { main: tabs, lift: [] }
        const base = line => line >= 0 && line <= surface.sdfBot + 0.5
        const full = t => {
            const r = rigid[t.id]
            return { top: Math.max(t.top, surface.sdfBot), rtl: r, rtr: r,
                     rbl: t.rbl > 0.01 ? r : t.rbl, rbr: t.rbr > 0.01 ? r : t.rbr }
        }
        return {
            main: tabs.filter(t => !ids[t.id]),
            lift: tabs.filter(t => ids[t.id]).map(t => Object.assign({}, t,
                base(t.lineL) ? { lineL: -1, rfL: 0, sinkL: 0 } : {},
                base(t.lineR) ? { lineR: -1, rfR: 0, sinkR: 0 } : {},
                rigid[t.id] !== undefined ? full(t) : {}))
        }
    }

    property var compactIds: ({})
    property var fullLen: ({})

    function compactNeed(groups, compact, extra) {
        const len = g => {
            let t = 0
            for (let i = 0; i < g.length; i++) {
                const o = g[i]
                t += (compact[o.blockId] ? o.naturalWidth : (surface.fullLen[o.blockId] ?? o.naturalWidth))
                    + (i > 0 ? surface.naturalGap(g[i - 1], o) : 0)
            }
            return t
        }
        const room = sectionsRow.width - 8 - extra
        const parts = groups.filter(g => g.length)
        let total = 0
        for (let i = 0; i < parts.length; i++)
            total += len(parts[i]) + (i > 0 ? surface.naturalGap(parts[i - 1][parts[i - 1].length - 1], parts[i][0]) : 0)
        return { left: total - room, right: total - room }
    }

    function applyCompact() {
        if (!surface.vertical || surface.dragging) {
            if (!surface.vertical && Object.keys(surface.compactIds).length)
                surface.compactIds = {}
            return false
        }
        const compact = surface.compactIds
        const lens = Object.assign({}, surface.fullLen)
        const groups = []
        for (const rep of [leftRep, centerRep, rightRep]) {
            const g = []
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (!o || !o.wantedBase || o.leaving || BarLayout.isMore(o.blockId))
                    continue
                if (!compact[o.blockId])
                    lens[o.blockId] = o.naturalWidth
                g.push(o)
            }
            groups.push(g)
        }
        surface.fullLen = lens
        const set = ids => {
            surface.compactIds = ids
            surface.markGeom()
            return true
        }
        const now = surface.compactNeed(groups, compact, 0)
        if (now.left > 0.5 || now.right > 0.5) {
            const L = groups[0].filter(o => !compact[o.blockId])
            const R = groups[2].filter(o => !compact[o.blockId])
            const C = groups[1].filter(o => !compact[o.blockId])
            const pickR = now.right > 0.5 && R.length && (now.right >= now.left || !L.length)
            const next = pickR ? R[0] : now.left > 0.5 && L.length ? L[L.length - 1] : R[0] ?? L[L.length - 1] ?? C[0]
            if (!next)
                return false
            return set(Object.assign({}, compact, { [next.blockId]: true }))
        }
        for (const id of Object.keys(compact).reverse()) {
            const trial = Object.assign({}, compact)
            delete trial[id]
            const t = surface.compactNeed(groups, trial, 24)
            if (t.left <= 0 && t.right <= 0)
                return set(trial)
        }
        return false
    }

    function recompute() {
        if (surface.applyCompact())
            return
        surface.runs = surface.calcRuns()
        surface.pathBlocks = surface.calcPathBlocks()
        surface.tabShapes = surface.calcTabShapes()
        surface.sdfField = surface.calcField()
        surface.applyFit()
        surface.applyFold()
        surface.geometryUpdated()
    }

    signal geometryUpdated()

    readonly property var surfSig: [sectionsRow.x, sectionsRow.y, sectionsRow.width, sectionsRow.height,
        leftGroup.x, centerGroup.x, rightGroup.x, surface.edgeInset, surface.reveal, surface.slide, surface.bumpDepth, surface.barH,
        surface.disX, surface.allPill, surface.width, surface.height, surface.panelFar,
        surface.pillMargin, surface.blockItems, surface.visibleBlocks, GlobalStates.barEditMode, surface.editPage,
        SettingsConfig.settingsReady, surface.flareAnim, surface.cfg, surface.crossStart, surface.crossEnd,
        surface.stripInset, surface.stripStart, surface.stripEnd, surface.revealSplit, surface.pushPlan,
        surface.screenStart, surface.screenEnd, surface.cornerPillStart, surface.cornerPillEnd]
    onSurfSigChanged: surface.markGeom()

    function applyFit() {
        if (surface.dragging)
            return
        const f = surface.calcFit()
        if (Math.abs(surface.fitT - f) > 0.0005)
            surface.fitT = f
    }

    property var pageFold: null

    function toggleEditPage() {
        if (surface.editPage === 0 && surface.foldIds.length) {
            surface.pageFold = { ids: surface.foldIds.slice(), right: surface.fold.right }
            surface.editPage = 1
        } else {
            surface.editPage = 0
            surface.pageFold = null
        }
    }

    Connections {
        target: GlobalStates
        function onBarEditModeChanged() {
            surface.editPage = 0
            surface.pageFold = null
        }
    }
    function calcFit() {
        surface.blockItems
        let blocks = 0
        let gaps = 0
        let n = 0
        const ends = []
        for (const rep of [leftRep, centerRep, rightRep]) {
            let before = 0
            let first = null
            let last = null
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (!o)
                    continue
                const pc = Math.min(1, o.pc)
                if (before > 0 && pc > 0) {
                    gaps += surface.naturalGap(rep.itemAt(k - 1), o) * Math.min(pc, before)
                    n += Math.min(pc, before)
                }
                blocks += o.fixedWidth * pc
                before = Math.max(before, pc)
                if (pc > 0.001) {
                    first = first ?? o
                    last = o
                }
            }
            ends.push({ first: first, last: last })
        }
        const filled = ends.filter(e => e.first)
        for (let i = 1; i < filled.length; i++) {
            gaps += surface.naturalGap(filled[i - 1].last, filled[i].first)
            n += 1
        }
        const avail = sectionsRow.width
        const floor = surface.minGap * n
        if (blocks + gaps <= avail || gaps <= floor)
            return 1
        return Math.max(0, Math.min(1, (avail - blocks - floor) / (gaps - floor)))
    }

    function minW(b) {
        return b && b.isPill ? surface.barH : surface.barH * 2
    }

    readonly property var orderedBlocks: surface.blockItems.filter(b => b && b.visible)
    readonly property real startPill: surface.orderedBlocks.length ? surface.orderedBlocks[0].pillT
        : (surface.allPill ? 1 : 0)
    readonly property real endPill: surface.orderedBlocks.length ? surface.orderedBlocks[surface.orderedBlocks.length - 1].pillT
        : (surface.allPill ? 1 : 0)
    readonly property real maxDrop: {
        let d = 0
        for (const b of surface.orderedBlocks)
            d = Math.max(d, b.drop)
        return d
    }
    readonly property real flareAnim: 1

    function lastOf(rep) {
        surface.blockItems
        return rep.count > 0 ? rep.itemAt(rep.count - 1) : null
    }
    function firstOf(rep) {
        surface.blockItems
        return rep.count > 0 ? rep.itemAt(0) : null
    }
    readonly property real gapLC: surface.gapBetween(surface.lastOf(leftRep), surface.firstOf(centerRep))
    readonly property real gapCR: surface.gapBetween(surface.lastOf(centerRep), surface.firstOf(rightRep))
    readonly property real gapLCn: surface.naturalGap(surface.lastOf(leftRep), surface.firstOf(centerRep))
    readonly property real gapCRn: surface.naturalGap(surface.lastOf(centerRep), surface.firstOf(rightRep))

    property var leftLeaving: ({})
    property var centerLeaving: ({})
    property var rightLeaving: ({})

    function groupPad(rep) {
        if (!surface.gaps || rep.count === 0)
            return { lead: 0, trail: 0 }
        const first = rep.itemAt(0)
        const last = rep.itemAt(rep.count - 1)
        const lead = first && first.anchorSide === "left" ? (first.offset ?? 0) * Math.min(1, first.pc) : 0
        const trail = last && last.anchorSide === "right" ? (last.offset ?? 0) * Math.min(1, last.pc) : 0
        return { lead: lead, trail: trail }
    }

    function groupLayout(rep) {
        surface.blockItems
        const pad = surface.groupPad(rep)
        const xs = []
        let x = pad.lead
        let before = 0
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k)
            const pc = o ? Math.min(1, o.pc) : 0
            x += surface.gapBetween(k > 0 ? rep.itemAt(k - 1) : null, o) * Math.min(pc, before)
            xs.push(x)
            x += o ? o.width : 0
            before = Math.max(before, pc)
        }
        return { xs: xs, total: x + pad.trail }
    }

    function pivotIndex(widths) {
        const mid = (widths.length - 1) / 2
        let best = 0
        for (let i = 1; i < widths.length; i++) {
            const d = widths[i] - widths[best]
            if (d > 0.5 || (Math.abs(d) <= 0.5 && Math.abs(i - mid) < Math.abs(best - mid)))
                best = i
        }
        return best
    }

    function offsetOf(rep, idx) {
        surface.blockItems
        let x = surface.groupPad(rep).lead
        let before = 0
        for (let k = 0; k < idx && k < rep.count; k++) {
            const o = rep.itemAt(k)
            const pc = o ? Math.min(1, o.pc) : 0
            x += surface.gapBetween(k > 0 ? rep.itemAt(k - 1) : null, o) * Math.min(pc, before)
            x += o ? o.width : 0
            before = Math.max(before, pc)
        }
        const o = rep.itemAt(idx)
        const pc = o ? Math.min(1, o.pc) : 0
        return x + (idx > 0 ? surface.gapBetween(rep.itemAt(idx - 1), o) * Math.min(pc, before) : 0)
    }

    function groupNatural(rep) {
        surface.blockItems
        const pad = surface.groupPad(rep)
        let n = pad.lead + pad.trail
        let before = 0
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k)
            if (!o)
                continue
            const pc = Math.min(1, o.pc)
            n += surface.naturalGap(k > 0 ? rep.itemAt(k - 1) : null, o) * Math.min(pc, before)
            n += o.naturalWidth * pc
            before = Math.max(before, pc)
        }
        return n
    }

    function blockGone(model, side, leaving, id) {
        Qt.callLater(() => BarLayout.dropLeaving(model, BarLayout.idsFor(side, surface.edge), "blockId", leaving, id))
    }

    property var blockItems: []

    property var _kept: ({})

    function keepList(key, list) {
        const prev = surface._kept[key]
        if (prev && prev.length === list.length && prev.every((v, i) => v === list[i]))
            return prev
        surface._kept[key] = list
        return list
    }

    function keepJson(key, value) {
        const text = JSON.stringify(value)
        const prev = surface._kept[key]
        if (prev && prev.text === text)
            return prev.value
        surface._kept[key] = { text: text, value: value }
        return value
    }

    readonly property var visibleBlocks: surface.keepList("visible", surface.blockItems
        .filter(b => b && b.parent && b.visible)
        .sort((a, b) => (a.parent.x + a.x) - (b.parent.x + b.x)))

    function blockX(b) {
        return sectionsRow.x + b.parent.x + b.x
    }

    function crowds(b) {
        const w = b.tabNaturalW
        if (!(w > 0.5))
            return false
        const x0 = surface.blockX(b)
        const x1 = x0 + b.width
        let lo = surface.spanStart
        let hi = surface.spanEnd
        const own = surface.fused[b.blockId]?.key ?? b.blockId
        for (const o of surface.visibleBlocks) {
            if (o === b || o.leaving || o.width <= 0 || (surface.fused[o.blockId]?.key ?? o.blockId) === own)
                continue
            const a = surface.blockX(o)
            const e = a + o.width
            if (e <= x0 + 0.5)
                lo = Math.max(lo, e)
            else if (a >= x1 - 0.5)
                hi = Math.min(hi, a)
        }
        return w > hi - lo - 2 * surface.minGap
    }

    readonly property var fused: {
        const pos = b => b.baseX ?? b.absX
        const map = {}
        let cur = null
        let prev = null
        for (const b of surface.visibleBlocks) {
            const ri = b.isPill ? -1 : surface.runOf(b)
            const r = ri >= 0 ? surface.runs[ri] : null
            let join = false
            if (prev && cur) {
                const gap = pos(b) - (pos(prev) + prev.width)
                if (b.isPill && prev.isPill)
                    join = gap <= 1 && Math.abs(surface.blockTop(b) - surface.blockTop(prev)) <= 1
                else if (!b.isPill && !prev.isPill && ri === cur.run)
                    join = cur.flat || gap <= 1
            }
            if (!join)
                cur = { key: b.blockId, run: ri, flat: !!r && r.flat >= 0.999, ids: [] }
            cur.ids.push(b.blockId)
            map[b.blockId] = cur
            prev = b
        }
        return surface.keepJson("fused", map)
    }

    function fusedSpan(b) {
        const body = surface.fused[b.blockId]
        const x = surface.blockX(b)
        if (!body || body.ids.length < 2 && !body.flat)
            return { L: x, R: x + b.width, n: 1 }
        const r = body.flat ? surface.runs[body.run] : null
        if (r)
            return { L: r.L, R: r.R, n: body.ids.length }
        let L = x
        let R = x + b.width
        for (const o of surface.visibleBlocks) {
            if (body.ids.indexOf(o.blockId) < 0)
                continue
            L = Math.min(L, surface.blockX(o))
            R = Math.max(R, surface.blockX(o) + o.width)
        }
        return { L: L, R: R, n: body.ids.length }
    }

    function fusedCovers(b, x, w) {
        const s = surface.fusedSpan(b)
        if (s.n < 2 && !(surface.fused[b.blockId]?.flat ?? false))
            return false
        const l = surface.blockX(b) + x
        return l >= s.L - 1 && l + w <= s.R + 1
    }

    property var runs: []
    function calcRuns() {
        const out = []
        let cur = null
        let prevPill = null
        for (const b of surface.visibleBlocks) {
            if (b.isPill) {
                if (cur) {
                    const l = cur.blocks[cur.blocks.length - 1]
                    cur.capR = true
                    cur.pillR = b
                    cur.roomR = surface.blockX(b) - surface.blockX(l) - l.width
                }
                cur = null
                out.push({ pill: true, blocks: [b] })
                prevPill = b
                continue
            }
            if (!cur) {
                cur = { pill: false, blocks: [], capL: prevPill !== null, capR: false, roomR: Infinity, pillL: prevPill,
                        roomL: prevPill ? surface.blockX(b) - surface.blockX(prevPill) - prevPill.width : Infinity }
                out.push(cur)
            }
            cur.blocks.push(b)
        }
        const firstRun = out[0]
        const lastRun = out[out.length - 1]
        if (surface.vertical && surface.cornerPillStart && firstRun && !firstRun.pill && !firstRun.capL) {
            firstRun.capL = true
            firstRun.crossL = true
            firstRun.pillL = surface.cornerPillStart
            firstRun.roomL = surface.blockX(firstRun.blocks[0]) - surface.crossStart
        }
        if (surface.vertical && surface.cornerPillEnd && lastRun && !lastRun.pill && !lastRun.capR) {
            const l = lastRun.blocks[lastRun.blocks.length - 1]
            lastRun.capR = true
            lastRun.crossR = true
            lastRun.pillR = surface.cornerPillEnd
            lastRun.roomR = surface.width - surface.crossEnd - surface.blockX(l) - l.width
        }
        for (const r of out) {
            if (r.pill)
                continue
            let flat = 1
            for (const b of r.blocks)
                flat = Math.min(flat, b.flatT)
            r.flat = flat
            r.bridge = surface.barH * flat * (surface.bumpMode ? Math.max(0, Math.min(1, surface.bumpDepth)) : 1)
            r.endR = -surface.disX * Math.min(1, r.bridge / surface.disX)
            const f = r.blocks[0]
            const l = r.blocks[r.blocks.length - 1]
            r.L = r.capL ? surface.blockX(f) : sectionsRow.x
            r.R = r.capR ? surface.blockX(l) + l.width : sectionsRow.x + sectionsRow.width
            r.screenL = !r.capL && surface.screenStart
            r.screenR = !r.capR && surface.screenEnd
            if (!surface.vertical) {
                r.flushL = !r.capL && surface.stripStart > 0
                r.flushR = !r.capR && surface.stripEnd > 0
            } else if (surface.stripInset > 0) {
                if (!r.capL) {
                    r.L = 0
                    r.flushL = true
                }
                if (!r.capR) {
                    r.R = surface.width
                    r.flushR = true
                }
            }
        }
        return out
    }

    function runOf(b) {
        for (let i = 0; i < surface.runs.length; i++) {
            if (surface.runs[i].blocks.indexOf(b) >= 0)
                return i
        }
        return -1
    }

    function capFlare(pill, room) {
        if (!pill || !(room < Infinity))
            return undefined
        const capY = Math.max(surface.edgeInset, surface.sdfOpts.capTop)
        return surface.flareFit(room, pill.pillRadius, surface.blockTop(pill) - capY) * pill.pillT
    }

    function blockTop(b) {
        if (!b.isPill)
            return surface.edgeInset
        const lift = !surface.allPill ? surface.slide : 0
        return surface.edgeInset + b.drop - lift
    }

    function blockBridge(b, r) {
        const top = surface.blockTop(b)
        return b.isPill || !r ? top + surface.barH : top + r.bridge
    }

    function blockP(b) {
        return Math.min(1, b.pc) * (!b.isPill ? surface.bumpDepth : 1)
    }

    function tabPullFor(b) {
        if (b.floating)
            return 0
        const r = surface.runs[surface.runOf(b)]
        if (b.isPill || !r)
            return surface.disX + surface.barH / 2
        return surface.disX + Math.min(surface.disX, Math.max(0, surface.barH - r.bridge) / 2)
    }

    property var pathBlocks: []
    function calcPathBlocks() {
        const out = []
        const runs = surface.runs
        let isl = 0
        for (let ri = 0; ri < runs.length; ri++) {
            const r = runs[ri]
            const ends = []
            for (const b of r.blocks) {
                if (b.tuckedAway)
                    continue
                const top = surface.blockTop(b)
                const bridge = surface.blockBridge(b, r)
                const bw = b.width
                const bx = surface.blockX(b) + (b.width - bw) / 2
                const p = surface.blockP(b)
                const bot = bridge + (top + surface.barH + (b.lineUp ?? 0) - bridge) * p
                ends.push({ b: b, bx: bx, bw: bw, bot: bot, bridge: bridge, isl: isl })
                out.push({ x: bx, w: bw, bot: bot, isl: isl, run: ri, top: top, id: b.blockId,
                           vh: surface.bumpMode && !b.isPill ? top + surface.barH + (b.lineUp ?? 0) - bridge : 0 })
                isl++
            }
            if (r.pill || r.flat >= 0.999 || !ends.length)
                continue
            for (let k = 1; k < ends.length; k++) {
                const a = ends[k - 1]
                const c = ends[k]
                const t = Math.min(a.b.flatT, c.b.flatT)
                const aR = a.bx + a.bw
                if (t <= 0.001 || c.bx - aR <= 0.5)
                    continue
                const bot = a.bridge + (Math.min(a.bot, c.bot) - a.bridge) * t
                if (bot > a.bridge + 0.01)
                    out.push({ x: aR, w: c.bx - aR, bot: bot, isl: a.isl, run: ri, top: surface.edgeInset })
            }
            const first = ends[0]
            const last = ends[ends.length - 1]
            if (!r.capL && first.b.flatT > 0.001 && first.bx - r.L > 0.5) {
                const bot = first.bridge + (first.bot - first.bridge) * first.b.flatT
                if (bot > first.bridge + 0.01)
                    out.push({ x: r.L, w: first.bx - r.L, bot: bot, isl: first.isl, run: ri, top: surface.edgeInset })
            }
            const lR = last.bx + last.bw
            if (!r.capR && last.b.flatT > 0.001 && r.R - lR > 0.5) {
                const bot = last.bridge + (last.bot - last.bridge) * last.b.flatT
                if (bot > last.bridge + 0.01)
                    out.push({ x: lR, w: r.R - lR, bot: bot, isl: last.isl, run: ri, top: surface.edgeInset })
            }
        }
        out.sort((p, q) => p.x - q.x)
        for (let i = 1; i < out.length; i++) {
            let a = out[i - 1]
            for (let j = i - 2; j >= 0; j--) {
                if (out[j].x + out[j].w > a.x + a.w)
                    a = out[j]
            }
            const b = out[i]
            const aR = a.x + a.w
            if (b.x >= aR - 0.01)
                continue
            if (b.bot >= a.bot) {
                a.w = Math.max(0, b.x - a.x)
                a.trimmed = true
            } else {
                const bR = b.x + b.w
                b.x = Math.min(aR, bR)
                b.w = Math.max(0, bR - b.x)
                b.trimmed = true
            }
        }
        return out.filter(sg => !sg.trimmed || sg.w > 0.01)
    }

    readonly property var openTabs: surface.keepList("open", surface.visibleBlocks.filter(b => b.tabOpen))

    property var tabShapes: []
    function calcTabShapes() {
        const out = []
        for (const b of surface.openTabs) {
            const r = surface.runs[surface.runOf(b)]
            const top = surface.blockTop(b)
            const bridge = surface.blockBridge(b, r)
            const bx = surface.blockX(b)
            const p = surface.blockP(b)
            const open = !b.isPill && r
            out.push({
                id: b.blockId,
                x: bx + b.tabX,
                w: b.tabW,
                bot: bridge + (top + b.tabPathH - bridge) * p,
                bx: bx,
                bw: b.width,
                bb: bridge + (top + surface.barH + (b.lineUp ?? 0) - bridge) * p,
                pill: b.isPill,
                top: top,
                bridge: bridge - top,
                endR: open ? r.endR : 0,
                screenL: open && r.screenL === true,
                screenR: open && r.screenR === true,
                left: open && !r.capL ? sectionsRow.x : -1e9,
                right: open && !r.capR ? sectionsRow.x + sectionsRow.width : 1e9,
                stripL: open ? r.L : 0,
                stripR: open ? r.R : 0,
                pr: b.isPill ? b.pillRadius : undefined,
                rad: b.panelCorner,
                limL: surface.spanStart,
                limR: surface.spanEnd,
                run: surface.runOf(b),
                floating: b.floating,
                merged: b.merged,
                gap: b.merged ? b.floatGap : 0,
                bodyL: b.merged ? surface.fusedSpan(b).L : bx,
                bodyR: b.merged ? surface.fusedSpan(b).R : bx + b.width,
                gx: bx + b.gooShape.x,
                gw: b.gooShape.w,
                ftop: top + b.gooShape.y,
                fbot: top + b.gooShape.y + b.gooShape.h,
                k: b.gooShape.k,
                hx: bx + b.gooHost.x,
                hw: b.gooHost.w,
                hy: b.gooHost.y,
                hh: b.gooHost.h,
                hr: b.gooHost.r
            })
        }
        return BarPath.sdfTabs(out, surface.pathBlocks, Object.assign({}, surface.sdfOpts, { barH: surface.barH }))
    }

    function blobShapes() {
        const out = []
        if (!surface.visible || !surface.present)
            return out
        const z = surface.sdfMap.z
        const push = (x, top, w, bot, rad, b) => {
            if (w < 0.5 || bot - top < 0.5)
                return null
            const y = surface.far ? z - bot : top - z
            const s = surface.toScreen(x, y, w, bot - top)
            const o = typeof rad === "object" ? { x: s.x, y: s.y, w: s.width, h: s.height, rtl: rad.tl, rtr: rad.tr, rbl: rad.bl, rbr: rad.br }
                                              : { x: s.x, y: s.y, w: s.width, h: s.height, r: rad }
            o.k = surface.disX
            if (b && b.isPill && (b.pillClear > 0.001 || b.pillTintT > 0.001)) {
                o.clear = b.pillClear
                o.tint = 0.22 * b.pillTintT
                o.tintRgb = b.pillTintRgb
            }
            out.push(o)
            return o
        }
        if (!surface.gaps) {
            for (const r of surface.runs) {
                if (r.pill || r.bridge < 0.5)
                    continue
                const T = surface.edgeInset
                push(r.L, T - surface.disX, r.R - r.L, T + r.bridge, 0)
            }
        }
        const half = surface.barH / 2
        const steppedR = surface.gaps ? Math.min(surface.radiusShown, half) : surface.disX
        const items = []
        for (const b of surface.visibleBlocks) {
            if (b.tuckedAway)
                continue
            const r = surface.runs[surface.runOf(b)]
            const top = surface.blockTop(b)
            const bridge = surface.blockBridge(b, r)
            const bot = b.isPill ? top + surface.barH
                : bridge + (top + surface.barH + (b.lineUp ?? 0) - bridge) * surface.blockP(b)
            const pr = Math.min(b.pillRadius, half)
            const sc = b.screenCorners
            items.push({ b: b, x: surface.blockX(b), w: b.width, top: b.isPill ? top : top - surface.disX, bot: bot,
                         rad: !b.isPill ? steppedR
                              : sc && sc.custom ? { tl: Math.min(sc.tl, half), tr: Math.min(sc.tr, half), bl: Math.min(sc.bl, half), br: Math.min(sc.br, half) }
                              : pr })
        }
        const fill = surface.gaps ? Math.max(0, Math.min(1, surface.fillShown)) : 0
        if (fill > 0) {
            items.sort((p, q) => p.x - q.x)
            for (let i = 0; i + 1 < items.length; i++) {
                const a = items[i]
                const c = items[i + 1]
                if (a.b.anchorSide === c.b.anchorSide)
                    continue
                const span = c.x - (a.x + a.w)
                if (span <= 0)
                    continue
                const reach = fill * span / 2
                a.w += reach
                c.x -= reach
                c.w += reach
            }
        }
        for (const it of items)
            it.o = push(it.x, it.top, it.w, it.bot, it.rad, it.b)
        for (const t of surface.tabShapes) {
            const rad = Math.max(t.rtl ?? 0, t.rtr ?? 0, t.rbl ?? 0, t.rbr ?? 0, 8)
            const top = t.merged ? (t.nb ?? t.top) + (t.conL ?? 0) : t.top
            const tab = push(t.x, top, t.w, t.bot, rad)
            if (tab && t.goo) {
                const key = surface.edge + ":" + t.id
                Object.assign(tab, { gooKey: key, gooK: t.k, solo: true })
                const host = items.find(it => it.b.blockId === t.id)
                if (t.k > 0.01 && host && host.b.split && t.hostR - t.hostL > 0.5) {
                    const plate = push(t.hostL, t.hostT, t.hostR - t.hostL, t.hostB, t.hostRad)
                    if (plate)
                        Object.assign(plate, { gooKey: key, gooK: t.k, solo: true })
                } else if (host && host.o) {
                    Object.assign(host.o, { gooKey: key, gooK: t.k })
                }
            }
            if (t.merged && (t.conL ?? 0) > 0.5) {
                const l = Math.max(t.mL0, t.x)
                const r = Math.min(t.mR0, t.x + t.w)
                const at = out.length
                push(l, t.nb - 0.5, r - l, top + 0.5, 0)
                if (out.length > at)
                    out[at].k = Math.min(surface.disX, t.conL / 2)
            }
        }
        return out
    }

    readonly property var tabRects: {
        const out = []
        for (const b of surface.openTabs) {
            if (b.tabW <= 0.5 || b.floating || b.merged)
                continue
            out.push({ id: b.blockId, l: b.absX + b.tabX, r: b.absX + b.tabX + b.tabW })
        }
        return surface.keepJson("tabRects", out)
    }


    readonly property real centerNatural: surface.groupNatural(centerRep)
    readonly property real leftLimit: surface.centerNatural > 0
        ? Math.max(0, (sectionsRow.width - surface.centerNatural) / 2 - 12)
        : rightGroup.x - 12
    readonly property real leftReserve: leftGroup.width > 0 ? leftGroup.width + surface.gapLC : 0
    readonly property real centerLimit: Math.max(surface.minW(surface.lastOf(centerRep)),
        rightGroup.x - surface.gapCRn - (leftGroup.width > 0 ? leftGroup.width + surface.gapLCn : 0))

    function collectBlocks() {
        const out = []
        for (const rep of [leftRep, centerRep, rightRep]) {
            for (let i = 0; i < rep.count; i++) {
                const it = rep.itemAt(i)
                if (it) out.push(it)
            }
        }
        surface.blockItems = out
    }

    readonly property int maxBlocks: 20
    readonly property real moreLen: {
        surface.blockItems
        for (const rep of [leftRep, rightRep]) {
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (o && BarLayout.isMore(o.blockId) && o.fixedWidth > 0)
                    return o.fixedWidth
            }
        }
        return surface.barH + 20
    }
    property var fold: ({ ids: [], right: true })
    function calcFold() {
        if (!SettingsConfig.settingsReady)
            return { ids: [], right: true }
        surface.blockItems
        const pick = rep => {
            const a = []
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (o && !BarLayout.isMore(o.blockId) && o.wantedBase && !o.leaving)
                    a.push(o)
            }
            return a
        }
        const allL = pick(leftRep)
        const C = pick(centerRep)
        const allR = pick(rightRep)
        const pf = surface.pageFold
        if (GlobalStates.barEditMode && surface.editPage === 1 && pf)
            return { ids: (pf.right ? allR : allL).filter(o => pf.ids.indexOf(o.blockId) < 0).map(o => o.blockId), right: pf.right }
        let L = allL.slice()
        let R = allR.slice()
        let folded = []
        const moreRight = () => folded.every(o => o.anchorSide === "right")
        const len = g => {
            let s = 0
            for (let i = 0; i < g.length; i++) {
                const shrinks = g === L && i === g.length - 1 && (!folded.length || moreRight())
                s += (shrinks ? g[i].fixedWidth : g[i].naturalWidth) + (i > 0 ? surface.naturalGap(g[i - 1], g[i]) : 0)
            }
            return s
        }
        const side = (g, inner, mine) => {
            if (!g.length && !mine)
                return 0
            const more = mine ? surface.moreLen + (g.length ? surface.groupGap : 0) : 0
            return len(g) + more + (inner ? surface.naturalGap(g.length ? g[inner === "first" ? 0 : g.length - 1] : null, C[0] ?? null) : 0)
        }
        const room = sectionsRow.width - 8
        const pivotC = () => {
            if (!C.length)
                return 0
            const xs = []
            let x = 0
            for (let i = 0; i < C.length; i++) {
                if (i > 0)
                    x += surface.naturalGap(C[i - 1], C[i])
                xs.push(x)
                x += C[i].naturalWidth
            }
            const m = surface.pivotIndex(C.map(o => o.naturalWidth))
            return xs[m] + C[m].naturalWidth / 2
        }
        const halfL = () => room / 2 - pivotC()
        const halfR = () => room / 2 - (len(C) - pivotC())
        const fits = () => {
            const count = L.length + C.length + R.length + (folded.length ? 1 : 0)
            if (count > surface.maxBlocks)
                return false
            const mR = folded.length > 0 && moreRight()
            const mL = folded.length > 0 && !mR
            const l = side(L, C.length ? "last" : "", mL)
            const r = side(R, C.length ? "first" : "", mR)
            if (C.length && surface.vertical)
                return l + len(C) + r <= room
            if (C.length)
                return l <= halfL() && r <= halfR()
            return l + r + (l > 0 && r > 0 ? surface.groupGap : 0) <= room
        }
        while (!fits()) {
            const mR = folded.length > 0 && moreRight()
            const overL = L.length > 1 ? side(L, C.length ? "last" : "", !mR && folded.length > 0) - halfL() : -Infinity
            const overR = R.length ? side(R, C.length ? "first" : "", mR) - halfR() : -Infinity
            if (overR === -Infinity && overL === -Infinity)
                break
            if (C.length ? overR >= overL : R.length)
                folded.push(R.shift())
            else
                folded.push(L.pop())
        }
        for (let i = folded.length - 1; i >= 0; i--) {
            const keep = folded.filter((o, j) => j !== i)
            const prevL = L
            const prevR = R
            const prevF = folded
            folded = keep
            L = allL.filter(o => keep.indexOf(o) < 0)
            R = allR.filter(o => keep.indexOf(o) < 0)
            if (!fits()) {
                folded = prevF
                L = prevL
                R = prevR
            }
        }
        const right = folded.every(o => o.anchorSide === "right")
        return { ids: folded.map(o => o.blockId), right: right }
    }
    readonly property var foldIds: surface.fold.ids
    property string foldKey: ""

    function applyFold() {
        if (surface.dragging)
            return
        const f = surface.calcFold()
        const key = f.ids.join(",") + "|" + f.right
        if (key === surface.foldKey)
            return
        surface.foldKey = key
        surface.fold = f
        surface.syncGroups()
    }

    function syncGroups() {
        const more = surface.foldIds.length ? [BarLayout.moreId(surface.edge)] : []
        const inRight = surface.fold.right
        BarLayout.syncAnimated(leftModel,   BarLayout.idsFor("left", surface.edge).concat(inRight ? [] : more), "blockId", surface.leftLeaving)
        BarLayout.syncAnimated(centerModel, BarLayout.idsFor("center", surface.edge), "blockId", surface.centerLeaving)
        BarLayout.syncAnimated(rightModel,  (inRight ? more : []).concat(BarLayout.idsFor("right", surface.edge)),  "blockId", surface.rightLeaving)
    }

    Connections {
        target: BarLayout
        function onAllBlocksChanged() { surface.syncGroups() }
        function onNeedSysHostChanged() { surface.syncGroups() }
        function onEdgesChanged() { surface.syncGroups() }
    }

    readonly property bool autoHide: surface.cfg.autoHide
    readonly property bool dockActive: !surface.autoHide || revealHover.hovered || GlobalStates.barEditMode
        || (surface.autoHide && GlobalStates.dockPeek)
        || BarLayout.sysPanelOpen || surface.visibleBlocks.some(b => b.hovering || b.tabOpen)
    property bool dockHidden: false
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property var emphasizedCurve: [0.05, 0.0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1.0, 1, 1]
    property bool revealOpening: true
    property real revealGoal: 1
    onDockHiddenChanged: {
        surface.revealOpening = !surface.dockHidden
        surface.revealGoal = surface.dockHidden ? 0 : 1
    }
    property real reveal: surface.revealGoal
    Behavior on reveal {
        NumberAnimation {
            duration: surface.revealOpening ? 500 : 400
            easing.type: Easing.BezierSpline
            easing.bezierCurve: surface.revealOpening ? surface.spatialCurve : surface.emphasizedCurve
        }
    }
    readonly property real slide: (1 - surface.reveal) * (surface.barH + surface.edgeInset + surface.maxDrop + 6)
    readonly property bool bumpMode: surface.autoHide && !surface.allPill
    property Translate rowSlide: Translate { y: surface.bumpMode ? 0 : surface.far ? surface.slide : -surface.slide }

    property real bumpDepth: surface.revealGoal
    Behavior on bumpDepth {
        NumberAnimation {
            id: bumpAnim
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: surface.spatialCurve
        }
    }
    onDockActiveChanged: {
        if (surface.dockActive) {
            hideTimer.stop()
            surface.dockHidden = false
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: surface.dockHidden = !surface.dockActive
    }

    readonly property var sdfOpts: ({
        left: sectionsRow.x,
        right: sectionsRow.x + sectionsRow.width,
        top: surface.edgeInset,
        bridge: 0,
        endR: -surface.disX,
        rMax: surface.disX,
        needGap: 2 * surface.disX + 24,
        screenH: surface.height - surface.panelFar,
        screenW: surface.width,
        bottomFlare: surface.flareAnim,
        farMerge: surface.farBand > surface.borderFar + 0.5,
        capTop: ServiceGaps.borderFor(surface.side) > 0 ? surface.sdfBot : surface.edgeInset,
        sink: ServiceGaps.borderFor(surface.side) <= 0 ? BarLayout.shadowReach + BarLayout.shadowLift : 0,
        sideStripL: surface.stripStart > 0.5,
        sideStripR: surface.stripEnd > 0.5
    })

    property var panelBodies: ({})
    property int panelSeq: 0

    function setBody(id, l, r, il, ir, transient) {
        const cur = surface.panelBodies[id]
        if (cur && cur.transient === transient && Math.abs(cur.l - l) < 0.5 && Math.abs(cur.r - r) < 0.5
                && cur.il === il && cur.ir === ir)
            return
        const n = Object.assign({}, surface.panelBodies)
        let seq = cur && cur.transient === transient ? cur.seq : 0
        if (seq === 0) {
            surface.panelSeq++
            seq = (transient ? 1000000 : 0) + surface.panelSeq
        }
        n[id] = { id: id, l: l, r: r, il: il, ir: ir, transient: transient, seq: seq }
        surface.panelBodies = n
    }

    function clearBody(id) {
        if (!(id in surface.panelBodies))
            return
        const n = Object.assign({}, surface.panelBodies)
        delete n[id]
        surface.panelBodies = n
    }

    function obstaclesFor(id, bodies, transient) {
        const me = bodies[id]
        const mine = me ? me.seq : transient ? Infinity : 999999
        const out = []
        for (const k in bodies) {
            if (k !== id && bodies[k].seq < mine)
                out.push(bodies[k])
        }
        return out
    }

    property var sdfField: ({ pills: [], segs: [], flares: [], tabs: [] })
    function cornerOf(blockId, field) {
        return field.corners ? field.corners[blockId] ?? null : null
    }
    function calcField() {
        const h = surface.barH
        const f = BarPath.sdfEmpty()
        const groups = []
        for (const seg of surface.pathBlocks) {
            if (!groups[seg.run])
                groups[seg.run] = []
            groups[seg.run].push(seg)
        }
        for (let ri = 0; ri < surface.runs.length; ri++) {
            const r = surface.runs[ri]
            let g = groups[ri]
            if (!g || !g.length)
                continue
            if (r.pill) {
                if (!surface.allPill && g.length > 1) {
                    let l = Infinity
                    let R = -Infinity
                    let bot = 0
                    for (const sg of g) {
                        l = Math.min(l, sg.x)
                        R = Math.max(R, sg.x + sg.w)
                        bot = Math.max(bot, sg.bot)
                    }
                    g = [{ x: l, w: R - l, bot: bot, top: g[0].top, run: ri }]
                }
                const T = g[0].top
                const pb = r.blocks[0]
                const e = Math.min(pb.pillRadius, h / 2) * pb.pillT
                const fc = g.length === 1 ? pb.frameCorners : null
                const cs = fc ? { nl: Math.min(fc.nl, h / 2) * pb.pillT, nr: Math.min(fc.nr, h / 2) * pb.pillT,
                                  fl: Math.min(fc.fl, h / 2) * pb.pillT, fr: Math.min(fc.fr, h / 2) * pb.pillT } : null
                const from = f.pills.length
                if (!surface.allPill && g[0].bot <= T + h + 0.01)
                    f.pills.push(cs ? { l: g[0].x, r: g[0].x + g[0].w, bot: T + h, top: T, rtl: cs.nl, rtr: cs.nr, rbl: cs.fl, rbr: cs.fr }
                                    : { l: g[0].x, r: g[0].x + g[0].w, bot: T + h, top: T, rtl: e, rtr: e, rbl: e, rbr: e })
                else
                    BarPath.sdfIslands([g], Object.assign({}, surface.sdfOpts,
                        { top: T, bridge: h, endR: Math.min(pb.pillRadius, h / 2) * pb.pillT, bottomFlare: 0, corners: cs }), f)
                if (pb.pillClear > 0.001 || pb.pillTintT > 0.001) {
                    for (let k = from; k < f.pills.length; k++)
                        Object.assign(f.pills[k], { clear: pb.pillClear, tint: 0.22 * pb.pillTintT, tintRgb: pb.pillTintRgb })
                }
            } else {
                BarPath.sdfShape(g, Object.assign({}, surface.sdfOpts,
                    { left: r.L, right: r.R, bridge: r.bridge, endR: r.endR, capL: r.capL, capR: r.capR,
                      roomL: r.roomL, roomR: r.roomR, capRL: r.crossL ? surface.disX : surface.capFlare(r.pillL, r.roomL),
                      capRR: r.crossR ? surface.disX : surface.capFlare(r.pillR, r.roomR), flushL: r.flushL === true, flushR: r.flushR === true,
                      screenL: r.screenL === true, screenR: r.screenR === true }), f)
            }
        }
        f.flares.sort((a, b) => b.r - a.r)
        const split = surface.splitTabs(surface.tabShapes)
        f.tabs = split.main
        const lift = BarPath.sdfEmpty()
        lift.tabs = split.lift
        if (surface.revealSplit) {
            const ids = surface.liftIds()
            f.segs = f.segs.filter(sg => {
                if (!ids[sg.id])
                    return true
                lift.segs.push(Object.assign({}, sg, { lineL: -1, raL: 0, lineR: -1, raR: 0 }))
                return false
            })
            f.flares = f.flares.filter(fl => !lift.segs.some(sg => fl.x > sg.x - 0.5 && fl.x < sg.x + sg.w + 0.5))
            if (lift.segs.length) {
                let l = Infinity
                let r = -Infinity
                for (const sg of lift.segs) {
                    l = Math.min(l, sg.x)
                    r = Math.max(r, sg.x + sg.w)
                }
                const T = surface.edgeInset
                f.pills.push({ l: l - 3 * surface.disX, r: r + 3 * surface.disX, top: T - 50, bot: T,
                               rtl: 0, rtr: 0, rbl: 0, rbr: 0 })
            }
        }
        lift.k = lift.segs.length ? Math.min(surface.sdfRMax, surface.barH / 2) : surface.sdfRMax
        f.lift = lift
        const corners = {}
        for (const list of [f.segs, lift.segs]) {
            const own = {}
            for (const sg of list) {
                if (corners[sg.id] && !own[sg.id])
                    continue
                own[sg.id] = true
                if (corners[sg.id])
                    corners[sg.id].r = sg.rr
                else
                    corners[sg.id] = { l: sg.rl, r: sg.rr }
            }
        }
        f.corners = corners
        return f
    }

    readonly property bool detachedField: {
        if (!surface.allPill)
            return false
        const f = surface.sdfField
        let l = Infinity
        let r = -Infinity
        for (const p of f.pills) {
            l = Math.min(l, p.l)
            r = Math.max(r, p.r)
        }
        for (const t of f.tabs ?? []) {
            l = Math.min(l, t.x)
            r = Math.max(r, t.x + t.w)
        }
        if (l === Infinity)
            return true
        const touchStart = surface.crossStart > 0.5 && l - surface.crossStart <= 0.5
        const touchEnd = surface.crossEnd > 0.5 && surface.width - surface.crossEnd - r <= 0.5
        return !touchStart && !touchEnd
    }

    readonly property bool revealSplit: surface.bumpMode
        && (bumpAnim.running || (surface.bumpDepth > 0.001 && surface.bumpDepth < 0.999))

    readonly property real minBridge: {
        let m = Infinity
        for (const r of surface.runs) {
            if (!r.pill)
                m = Math.min(m, r.bridge)
        }
        return m
    }
    readonly property real maxBridge: {
        let m = 0
        for (const r of surface.runs) {
            if (!r.pill)
                m = Math.max(m, r.bridge)
        }
        return m
    }
    readonly property real stripInset: ServiceGaps.borderFor(surface.side) <= 0 && surface.present && surface.visible
        && surface.runs.length > 0 && surface.runs.every(r => !r.pill) && surface.minBridge > 0.5
        ? surface.edgeInset + surface.minBridge : 0
    readonly property real sdfTop: surface.edgeInset + (surface.allPill ? surface.maxDrop : 0)
    readonly property real sdfBot: surface.minBridge < Infinity ? surface.edgeInset + surface.minBridge
        : surface.sdfTop + surface.barH
    readonly property real sdfRMax: surface.disX
    readonly property real stripBand: !surface.present ? 0
        : Math.max(surface.borderNear, !surface.allPill && surface.minBridge < Infinity ? surface.sdfBot : 0)
    readonly property real panelBand: surface.autoHide ? surface.stripBand : surface.thickness
    readonly property real occupied: !surface.visible || !surface.present ? 0
        : surface.autoHide ? surface.stripBand
        : surface.thickness
    readonly property real sdfFlip: surface.height + (surface.allPill ? surface.slide : 0)
    readonly property vector4d sdfMap: Qt.vector4d(surface.vertical ? 1 : 0, surface.far ? 1 : 0,
        surface.far ? surface.sdfFlip : surface.allPill ? surface.slide : 0, 0)

    readonly property real sdfCut: {
        let b = surface.edgeInset + surface.maxDrop + surface.maxBridge + surface.disX + surface.barH
        for (const s of surface.pathBlocks)
            b = Math.max(b, s.bot)
        for (const t of surface.tabShapes)
            b = Math.max(b, t.bot + Math.max(t.flL, t.flR))
        return b + surface.disX * 2 + 2
    }

    readonly property rect sdfArea: {
        const pad = surface.disX * 2 + 4
        let l = Infinity
        let r = -Infinity
        for (const s of surface.pathBlocks) {
            l = Math.min(l, s.x)
            r = Math.max(r, s.x + s.w)
        }
        for (const f of surface.sdfField.flares) {
            l = Math.min(l, f.x - f.r)
            r = Math.max(r, f.x + f.r)
        }
        for (const t of surface.tabShapes) {
            l = Math.min(l, t.x - Math.max(t.rfL, t.flL))
            r = Math.max(r, t.x + t.w + Math.max(t.rfR, t.flR))
        }
        for (const run of surface.runs) {
            if (!run.pill && run.bridge > 0.5) {
                l = Math.min(l, run.L)
                r = Math.max(r, run.R)
            }
        }
        if (!(l < r))
            return Qt.rect(0, 0, 0, 0)
        l = Math.max(0, l - pad)
        r = Math.min(surface.width, r + pad)
        const cut = surface.sdfCut + 2
        const y0 = Math.max(0, surface.far ? surface.sdfFlip - cut : -surface.sdfMap.z)
        const y1 = Math.min(surface.height, surface.far ? surface.sdfFlip : cut - surface.sdfMap.z)
        return y1 > y0 ? surface.toScreen(l, y0, r - l, y1 - y0) : Qt.rect(0, 0, 0, 0)
    }

    readonly property var span: {
        let l = Infinity
        let r = -Infinity
        for (const b of surface.visibleBlocks) {
            const bx = sectionsRow.x + b.parent.x + b.x
            l = Math.min(l, bx)
            r = Math.max(r, bx + b.width)
        }
        return l < r ? { x: l, w: r - l } : { x: 0, w: 0 }
    }

    Component.onCompleted: {
        surface.markGeom()
        surface.syncGroups()
        if (!surface.dockActive)
            hideTimer.restart()
    }

    component GroupBlock: BarBlock {
        id: gb
        required property Item groupItem
        required property var groupModel
        required property Repeater groupRep
        required property string groupName
        required property var groupLeaving
        property real groupLimit: 0
        property bool limited: false
        edge: surface.edge
        frame: surface
        readonly property real baseX: sectionsRow.x + gb.groupItem.x + (gb.groupItem.lay.xs[gb.index] ?? 0)
        property real pushX: surface.pushPlan.push[gb.blockId] ?? 0
        Behavior on pushX {
            NumberAnimation {
                duration: surface.pushMotion.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: surface.pushMotion.curve
            }
        }
        x: (gb.groupItem.lay.xs[gb.index] ?? 0) + gb.pushX
        editor: surface.editor
        absX: sectionsRow.x + gb.groupItem.x + gb.x
        coverTabs: surface.tabRects
        spanL: surface.spanStart
        spanF: sectionsRow.x
        spanR: surface.spanEnd
        maxWidth: gb.limited && gb.index === gb.groupModel.count - 1
            ? Math.max(surface.minW(gb), gb.groupLimit - surface.offsetOf(gb.groupRep, gb.index)) : -1
        onGone: surface.blockGone(gb.groupModel, gb.groupName, gb.groupLeaving, gb.blockId)
    }

    Item {
        id: sectionsRow
        transform: [surface.rowSlide]
        opacity: surface.bumpMode ? 1 : surface.reveal
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin:   !surface.far ? surface.borderNear : 0
        anchors.bottomMargin: surface.far ? surface.borderNear : 0
        anchors.leftMargin: surface.gaps ? Math.max(surface.borderStart, surface.stripStart) + surface.gaps.end
                            : Math.max(surface.borderStart, surface.stripStart, (surface.cornerPillStart ? 0 : surface.cornerStart) * surface.startPill)
                              + surface.pillStartGap * surface.startPill + surface.cornerGapStart
        anchors.rightMargin: surface.gaps ? Math.max(surface.borderEnd, surface.stripEnd) + surface.gaps.end
                             : Math.max(surface.borderEnd, surface.stripEnd, (surface.cornerPillEnd ? 0 : surface.cornerEnd) * surface.endPill)
                               + surface.pillEndGap * surface.endPill + surface.cornerGapEnd

        Behavior on anchors.topMargin   { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }
        Behavior on anchors.bottomMargin { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }

        ListModel { id: leftModel; onRowsMoved: Qt.callLater(surface.collectBlocks) }
        ListModel { id: centerModel; onRowsMoved: Qt.callLater(surface.collectBlocks) }
        ListModel { id: rightModel; onRowsMoved: Qt.callLater(surface.collectBlocks) }

        Item {
            id: leftGroup
            anchors.left: parent.left
            readonly property var lay: surface.groupLayout(leftRep)
            width: leftGroup.lay.total
            height: surface.barH
            y: surface.far ? sectionsRow.height - height : 0

            Repeater {
                id: leftRep
                model: leftModel
                delegate: GroupBlock {
                    groupItem: leftGroup
                    groupModel: leftModel
                    groupRep: leftRep
                    groupName: "left"
                    groupLeaving: surface.leftLeaving
                    groupLimit: surface.leftLimit
                    limited: true
                }
                onItemAdded: Qt.callLater(surface.collectBlocks)
                onItemRemoved: Qt.callLater(surface.collectBlocks)
            }
        }

        Item {
            id: centerGroup
            readonly property real pivot: {
                const idx = []
                for (let k = 0; k < centerRep.count; k++) {
                    const o = centerRep.itemAt(k)
                    if (o && !o.leaving)
                        idx.push(k)
                }
                const xs = centerGroup.lay.xs
                const at = k => centerRep.itemAt(k)
                if (!idx.length)
                    return centerGroup.width / 2
                const k = idx[surface.pivotIndex(idx.map(i => at(i).naturalWidth))]
                return (xs[k] ?? 0) + at(k).width / 2
            }
            x: {
                const ideal = sectionsRow.width / 2 - centerGroup.pivot
                const limit = rightGroup.x - centerGroup.width - surface.gapCR
                return Math.round(Math.max(surface.leftReserve, Math.min(ideal, limit)))
            }
            readonly property var lay: surface.groupLayout(centerRep)
            width: centerGroup.lay.total
            height: surface.barH
            y: surface.far ? sectionsRow.height - height : 0

            Repeater {
                id: centerRep
                model: centerModel
                delegate: GroupBlock {
                    groupItem: centerGroup
                    groupModel: centerModel
                    groupRep: centerRep
                    groupName: "center"
                    groupLeaving: surface.centerLeaving
                    groupLimit: surface.centerLimit
                    limited: true
                }
                onItemAdded: Qt.callLater(surface.collectBlocks)
                onItemRemoved: Qt.callLater(surface.collectBlocks)
            }
        }

        Item {
            id: rightGroup
            anchors.right: parent.right
            readonly property var lay: surface.groupLayout(rightRep)
            width: Math.round(rightGroup.lay.total)
            height: surface.barH
            y: surface.far ? sectionsRow.height - height : 0

            Repeater {
                id: rightRep
                model: rightModel
                delegate: GroupBlock {
                    groupItem: rightGroup
                    groupModel: rightModel
                    groupRep: rightRep
                    groupName: "right"
                    groupLeaving: surface.rightLeaving
                }
                onItemAdded: Qt.callLater(surface.collectBlocks)
                onItemRemoved: Qt.callLater(surface.collectBlocks)
            }
        }
    }

    Item {
        id: revealZone
        visible: surface.autoHide
        x: surface.span.x
        y: surface.far ? surface.height - 8 : 0
        width: surface.span.w
        height: 8
        HoverHandler { id: revealHover }
    }
}
