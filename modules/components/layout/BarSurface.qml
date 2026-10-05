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
    readonly property bool isDock: surface.edge === "bottom"
    readonly property string side: BarLayout.sideOf(surface.edge)
    readonly property bool vertical: BarOps.isVerticalSide(surface.side)
    readonly property bool far: BarOps.isFarSide(surface.side)
    readonly property real barH: surface.isDock ? BarLayout.dockHeight : Appearance.size.barHeight
    readonly property real borderStart: ServiceGaps.borderFor(surface.vertical ? "top" : "left") * (1 - surface.startPill)
    readonly property real borderEnd: ServiceGaps.borderFor(surface.vertical ? "bottom" : "right") * (1 - surface.endPill)
    readonly property real borderFar: ServiceGaps.borderFor(BarOps.oppositeSide(surface.side))
    readonly property real borderNear: surface.isDock ? ServiceGaps.borderFor(surface.side) : 0
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
        return surface.toScreen(sectionsRow.x + b.parent.x + b.x, sectionsRow.y + b.parent.y + b.y, b.width, b.height)
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
    readonly property Item dashCard: pillDashPanel
    readonly property Item weatherCard: pillWeatherPanel

    property real disX: surface.isDock ? BarLayout.dockRadius : BarLayout.cornerRadius
    property real disY: surface.isDock ? BarLayout.dockRadius : BarLayout.cornerRadius
    property real radX: surface.isDock ? BarLayout.dockRadius : BarLayout.cornerRadius
    property real radY: surface.isDock ? BarLayout.dockRadius : BarLayout.cornerRadius
    property real lineDis: surface.isDock ? 0 : 4
    readonly property var shapeList: BarLayout.edgeShapes(surface.edge)
    readonly property bool anyPill: surface.shapeList.indexOf("pill") >= 0
    readonly property bool allPill: surface.shapeList.every(v => v === "pill")
    readonly property bool anyFlat: surface.shapeList.indexOf("flat") >= 0
    property real pillMargin: surface.isDock ? BarLayout.dockPillGap : (SettingsConfig.general.pillMargin ?? 6)
    property real pillLeftMargin:  SettingsConfig.general.pillLeftMargin  ?? 6
    property real pillRightMargin: SettingsConfig.general.pillRightMargin ?? 6

    readonly property real blockGapSetting: surface.isDock ? BarLayout.dockBlockGap : BarLayout.blockGap
    readonly property real wideGap: 2 * surface.disX + 28
    readonly property real groupGap: surface.blockGapSetting >= 0 ? surface.blockGapSetting
        : surface.shapeList.every(v => v === "stepped") ? surface.wideGap : 14

    readonly property real baseGap: surface.vertical ? 6 : 14
    readonly property real minGap: 4

    function naturalGap(a, b) {
        if (surface.blockGapSetting >= 0)
            return surface.blockGapSetting
        a = a ?? b
        b = b ?? a
        if (!a)
            return surface.groupGap
        const stepped = (1 - Math.max(a.pillT, b.pillT)) * (1 - Math.min(a.flatT, b.flatT))
        const capRoom = (surface.vertical ? 1 : 2) * surface.disX
        return surface.baseGap + (surface.wideGap - surface.baseGap) * stepped + capRoom * Math.abs(a.pillT - b.pillT)
    }

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

    function recompute() {
        surface.runs = surface.calcRuns()
        surface.pathBlocks = surface.calcPathBlocks()
        surface.tabShapes = surface.calcTabShapes()
        surface.sdfField = surface.calcField()
        surface.applyFit()
        surface.applyFold()
    }

    readonly property var surfSig: [sectionsRow.x, sectionsRow.y, sectionsRow.width, sectionsRow.height,
        leftGroup.x, centerGroup.x, rightGroup.x, surface.edgeInset, surface.reveal, surface.slide, surface.barH,
        surface.disX, surface.lineDis, surface.allPill, surface.width, surface.height, surface.borderFar,
        surface.pillMargin, surface.blockItems, surface.visibleBlocks, GlobalStates.barEditMode, surface.editPage,
        SettingsConfig.settingsReady, surface.flareAnim, surface.isDock]
    onSurfSigChanged: surface.markGeom()

    function applyFit() {
        if (surface.dragging)
            return
        const f = surface.calcFit()
        if (Math.abs(surface.fitT - f) > 0.0005)
            surface.fitT = f
    }

    function toggleEditPage() {
        surface.editPage = surface.editPage === 0 ? 1 : 0
    }

    Connections {
        target: GlobalStates
        function onBarEditModeChanged() { surface.editPage = 0 }
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

    function groupLayout(rep) {
        surface.blockItems
        const xs = []
        let x = 0
        let before = 0
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k)
            const pc = o ? Math.min(1, o.pc) : 0
            x += surface.gapBetween(k > 0 ? rep.itemAt(k - 1) : null, o) * Math.min(pc, before)
            xs.push(x)
            x += o ? o.width : 0
            before = Math.max(before, pc)
        }
        return { xs: xs, total: x }
    }

    function offsetOf(rep, idx) {
        surface.blockItems
        let x = 0
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
        let n = 0
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
                    cur.roomR = surface.blockX(b) - surface.blockX(l) - l.width
                }
                cur = null
                out.push({ pill: true, blocks: [b] })
                prevPill = b
                continue
            }
            if (!cur) {
                cur = { pill: false, blocks: [], capL: prevPill !== null, capR: false, roomR: Infinity,
                        roomL: prevPill ? surface.blockX(b) - surface.blockX(prevPill) - prevPill.width : Infinity }
                out.push(cur)
            }
            cur.blocks.push(b)
        }
        for (const r of out) {
            if (r.pill)
                continue
            let flat = 1
            for (const b of r.blocks)
                flat = Math.min(flat, b.flatT)
            r.flat = flat
            r.bridge = surface.lineDis + (surface.barH - surface.lineDis) * flat
            r.endR = surface.lineDis > 0 ? -surface.disX : -surface.disX * Math.min(1, r.bridge / surface.disX)
            const f = r.blocks[0]
            const l = r.blocks[r.blocks.length - 1]
            r.L = r.capL ? surface.blockX(f) : sectionsRow.x
            r.R = r.capR ? surface.blockX(l) + l.width : sectionsRow.x + sectionsRow.width
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

    function blockTop(b) {
        if (!b.isPill)
            return surface.edgeInset
        const lift = surface.isDock && !surface.allPill ? surface.slide : 0
        return surface.edgeInset + b.drop - lift
    }

    function blockBridge(b, r) {
        const top = surface.blockTop(b)
        return b.isPill || !r ? top + surface.barH : top + r.bridge
    }

    function blockP(b) {
        return Math.min(1, b.pc) * (surface.isDock && !b.isPill ? surface.reveal : 1)
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
                const top = surface.blockTop(b)
                const bridge = surface.blockBridge(b, r)
                const bx = surface.blockX(b)
                const p = surface.blockP(b)
                const bot = bridge + (top + surface.barH - bridge) * p
                ends.push({ b: b, bx: bx, bot: bot, bridge: bridge, isl: isl })
                const dd = !b.tabOpen && (b.dropSource || b.dropReleasing) ? (b.dropDepth ?? 0) : 0
                if (dd > 0.5) {
                    const dx = Math.max(bx, bx + b.dropX)
                    const dX = Math.min(bx + b.width, bx + b.dropX + b.dropW)
                    if (dx > bx + 0.01)
                        out.push({ x: bx, w: dx - bx, bot: bot, isl: isl, run: ri, top: top })
                    out.push({ x: dx, w: Math.max(0, dX - dx), bot: bot + dd * p, isl: isl, run: ri, top: top, melt: true })
                    if (bx + b.width > dX + 0.01)
                        out.push({ x: dX, w: bx + b.width - dX, bot: bot, isl: isl, run: ri, top: top })
                } else {
                    out.push({ x: bx, w: b.width, bot: bot, isl: isl, run: ri, top: top })
                }
                isl++
            }
            if (r.pill || r.flat >= 0.999)
                continue
            for (let k = 1; k < ends.length; k++) {
                const a = ends[k - 1]
                const c = ends[k]
                const t = Math.min(a.b.flatT, c.b.flatT)
                const aR = a.bx + a.b.width
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
            const lR = last.bx + last.b.width
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
                x: bx + b.tabX,
                w: b.tabW,
                bot: bridge + (top + b.tabPathH - bridge) * p,
                bx: bx,
                bw: b.width,
                bb: bridge + (top + surface.barH - bridge) * p,
                pill: b.isPill,
                top: top,
                bridge: bridge - top,
                endR: open ? r.endR : 0,
                left: open && !r.capL ? sectionsRow.x : -1e9,
                right: open && !r.capR ? sectionsRow.x + sectionsRow.width : 1e9,
                stripL: open ? r.L : 0,
                stripR: open ? r.R : 0,
                floating: b.floating,
                gx: bx + b.gooShape.x,
                gw: b.gooShape.w,
                ftop: top + b.gooShape.y,
                fbot: top + b.gooShape.y + b.gooShape.h,
                k: b.gooShape.k
            })
        }
        return BarPath.sdfTabs(out, surface.pathBlocks, Object.assign({}, surface.sdfOpts, { barH: surface.barH }))
    }

    readonly property var tabRects: {
        const out = []
        for (const b of surface.openTabs) {
            if (b.tabW <= 0.5 || b.floating)
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

    property string floatKind: ""
    property real floatCenter: 0
    property string floatBlock: ""
    property string floatItem: ""

    HyprlandFocusGrab {
        windows: [QsWindow.window]
        active: surface.isPrimary && surface.anyPill && surface.floatKind === "weather"
        onCleared: if (surface.floatKind === "weather") surface.floatKind = ""
    }

    function openFloating(kind, centerX, blockId, itemId) {
        if (surface.floatKind === kind && surface.floatBlock === blockId) {
            surface.floatKind = ""
            return
        }
        surface.floatCenter = centerX
        surface.floatBlock = blockId
        surface.floatItem = itemId
        surface.floatKind = kind
    }

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

    readonly property int maxBlocks: 14
    readonly property real moreLen: {
        surface.blockItems
        for (const rep of [leftRep, rightRep]) {
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (o && o.blockId === "__more" && o.fixedWidth > 0)
                    return o.fixedWidth
            }
        }
        return surface.barH + 20
    }
    property var fold: ({ ids: [], right: true })
    function calcFold() {
        if (surface.isDock || !SettingsConfig.settingsReady)
            return { ids: [], right: true }
        surface.blockItems
        const pick = rep => {
            const a = []
            for (let k = 0; k < rep.count; k++) {
                const o = rep.itemAt(k)
                if (o && o.blockId !== "__more" && o.wantedBase && !o.leaving)
                    a.push(o)
            }
            return a
        }
        const allL = pick(leftRep)
        const C = pick(centerRep)
        const allR = pick(rightRep)
        let L = allL.slice()
        let R = allR.slice()
        const len = g => g.reduce((s, o) => s + o.fixedWidth, 0) + surface.minGap * Math.max(0, g.length - 1)
        let folded = []
        const fits = () => {
            const parts = [L, C, R].filter(g => g.length)
            const extra = folded.length ? surface.moreLen + surface.minGap : 0
            const count = L.length + C.length + R.length + (folded.length ? 1 : 0)
            return count <= surface.maxBlocks
                && parts.reduce((s, g) => s + len(g), 0) + surface.minGap * Math.max(0, parts.length - 1) + extra
                    <= sectionsRow.width - 8
        }
        while (!fits()) {
            if (R.length) {
                folded.push(R.shift())
            } else if (L.length > 1) {
                folded.push(L.pop())
            } else {
                break
            }
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
        if (GlobalStates.barEditMode && surface.editPage === 1 && folded.length && right)
            return { ids: R.map(o => o.blockId), right: true }
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
        const more = surface.foldIds.length ? ["__more"] : []
        const inRight = surface.fold.right
        BarLayout.syncAnimated(leftModel,   BarLayout.idsFor("left", surface.edge).concat(inRight ? [] : more), "blockId", surface.leftLeaving)
        BarLayout.syncAnimated(centerModel, BarLayout.idsFor("center", surface.edge), "blockId", surface.centerLeaving)
        BarLayout.syncAnimated(rightModel,  (inRight ? more : []).concat(BarLayout.idsFor("right", surface.edge)),  "blockId", surface.rightLeaving)
    }

    Connections {
        target: BarLayout
        function onAllBlocksChanged() { surface.syncGroups() }
        function onNeedSysHostChanged() { surface.syncGroups() }
        function onDockOnChanged() { surface.syncGroups() }
    }

    readonly property bool autoHide: surface.isDock && (SettingsConfig.general.dockAutoHide ?? true)
        && !surface.anyFlat
    readonly property bool dockActive: !surface.autoHide || revealHover.hovered || GlobalStates.barEditMode
        || (surface.isDock && GlobalStates.dockPeek)
        || BarLayout.sysPanelOpen || surface.visibleBlocks.some(b => b.hovering || b.tabOpen)
    property bool dockHidden: false
    property real reveal: surface.dockHidden ? 0 : 1
    Behavior on reveal {
        SpatialAnim { speed: "default" }
    }
    readonly property real slide: (1 - surface.reveal) * (surface.barH + surface.edgeInset + surface.maxDrop + 6)
    property Translate rowSlide: Translate { y: surface.far ? surface.slide : -surface.slide }

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
        bridge: surface.lineDis,
        endR: -surface.disX,
        rMax: surface.disX,
        needGap: 2 * surface.disX + 24,
        screenH: surface.height - surface.borderFar,
        screenW: surface.width,
        bottomFlare: surface.flareAnim
    })

    property var sdfField: ({ pills: [], segs: [], flares: [], tabs: [] })
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
                const e = Math.min(h / 2 * r.blocks[0].pillT, h / 2)
                if (!surface.allPill && g[0].bot <= T + h + 0.01)
                    f.pills.push({ l: g[0].x, r: g[0].x + g[0].w, bot: T + h, top: T, rtl: e, rtr: e, rbl: e, rbr: e })
                else
                    BarPath.sdfIslands([g], Object.assign({}, surface.sdfOpts,
                        { top: T, bridge: h, endR: h / 2 * r.blocks[0].pillT, bottomFlare: 0 }), f)
            } else {
                BarPath.sdfShape(g, Object.assign({}, surface.sdfOpts,
                    { left: r.L, right: r.R, bridge: r.bridge, endR: r.endR, capL: r.capL, capR: r.capR,
                      roomL: r.roomL, roomR: r.roomR }), f)
            }
        }
        f.flares.sort((a, b) => b.r - a.r)
        f.tabs = surface.tabShapes
        return f
    }

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
    readonly property real sdfTop: surface.edgeInset + (surface.allPill ? surface.maxDrop : 0)
    readonly property real sdfBot: surface.minBridge < Infinity ? surface.edgeInset + surface.minBridge
        : surface.sdfTop + surface.barH
    readonly property real sdfRMax: surface.disX
    readonly property real sdfFlip: surface.height + (surface.allPill ? surface.slide : 0)
    readonly property vector4d sdfMap: Qt.vector4d(surface.vertical ? 1 : 0, surface.far ? 1 : 0,
        surface.far ? surface.sdfFlip : surface.isDock && surface.allPill ? surface.slide : 0, 0)

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

    Item {
        id: sectionsRow
        transform: surface.isDock ? [surface.rowSlide] : []
        opacity: surface.isDock ? surface.reveal : 1
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin:   !surface.far ? surface.borderNear : 0
        anchors.bottomMargin: surface.far ? surface.borderNear : 0
        anchors.leftMargin:  surface.borderStart + surface.pillLeftMargin * surface.startPill
        anchors.rightMargin: surface.borderEnd + surface.pillRightMargin * surface.endPill

        Behavior on anchors.topMargin   { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }
        Behavior on anchors.bottomMargin { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }

        ListModel { id: leftModel }
        ListModel { id: centerModel }
        ListModel { id: rightModel }

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
                delegate: BarBlock {
                    id: leftBlock
                    edge: surface.edge
                    frame: surface
                    x: leftGroup.lay.xs[leftBlock.index] ?? 0
                    editor: surface.editor
                    absX: sectionsRow.x + leftGroup.x + leftBlock.x
                    coverTabs: surface.tabRects
                    spanL: sectionsRow.x
                    spanR: sectionsRow.x + sectionsRow.width
                    maxWidth: leftBlock.index === leftModel.count - 1 ? Math.max(surface.minW(leftBlock), surface.leftLimit - surface.offsetOf(leftRep, leftBlock.index)) : -1
                    floatOpenerId: surface.floatKind !== "" && surface.floatBlock === leftBlock.blockId ? surface.floatItem : ""
                    onFloatRequested: (kind, cx, id) => surface.openFloating(kind, cx, leftBlock.blockId, id)
                    onFloatCloseRequested: surface.floatKind = ""
                    onGone: surface.blockGone(leftModel, "left", surface.leftLeaving, leftBlock.blockId)
                }
                onItemAdded: Qt.callLater(surface.collectBlocks)
                onItemRemoved: Qt.callLater(surface.collectBlocks)
            }
        }

        Item {
            id: centerGroup
            x: {
                const ideal = (sectionsRow.width - centerGroup.width) / 2
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
                delegate: BarBlock {
                    id: centerBlock
                    edge: surface.edge
                    frame: surface
                    x: centerGroup.lay.xs[centerBlock.index] ?? 0
                    editor: surface.editor
                    absX: sectionsRow.x + centerGroup.x + centerBlock.x
                    coverTabs: surface.tabRects
                    spanL: sectionsRow.x
                    spanR: sectionsRow.x + sectionsRow.width
                    maxWidth: centerBlock.index === centerModel.count - 1 ? Math.max(surface.minW(centerBlock), surface.centerLimit - surface.offsetOf(centerRep, centerBlock.index)) : -1
                    floatOpenerId: surface.floatKind !== "" && surface.floatBlock === centerBlock.blockId ? surface.floatItem : ""
                    onFloatRequested: (kind, cx, id) => surface.openFloating(kind, cx, centerBlock.blockId, id)
                    onFloatCloseRequested: surface.floatKind = ""
                    onGone: surface.blockGone(centerModel, "center", surface.centerLeaving, centerBlock.blockId)
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
                delegate: BarBlock {
                    id: rightBlock
                    edge: surface.edge
                    frame: surface
                    x: rightGroup.lay.xs[rightBlock.index] ?? 0
                    editor: surface.editor
                    absX: sectionsRow.x + rightGroup.x + rightBlock.x
                    coverTabs: surface.tabRects
                    spanL: sectionsRow.x
                    spanR: sectionsRow.x + sectionsRow.width
                    floatOpenerId: surface.floatKind !== "" && surface.floatBlock === rightBlock.blockId ? surface.floatItem : ""
                    onFloatRequested: (kind, cx, id) => surface.openFloating(kind, cx, rightBlock.blockId, id)
                    onFloatCloseRequested: surface.floatKind = ""
                    onGone: surface.blockGone(rightModel, "right", surface.rightLeaving, rightBlock.blockId)
                }
                onItemAdded: Qt.callLater(surface.collectBlocks)
                onItemRemoved: Qt.callLater(surface.collectBlocks)
            }
        }
    }

    Item {
        id: revealZone
        visible: surface.isDock
        x: surface.span.x
        y: surface.far ? surface.height - 8 : 0
        width: surface.span.w
        height: 8
        HoverHandler { id: revealHover }
    }

    Rectangle {
        id: pillDashPanel
        visible: surface.isPrimary && surface.anyPill && surface.floatKind === "dashboard"

        x:      Math.max(surface.pillLeftMargin, Math.min(parent.width - width - surface.pillRightMargin, surface.floatCenter - width / 2))
        y:      surface.far ? ServiceGaps.topFinal + 8 : surface.pillMargin + surface.barH + 8
        width:  BarLayout.floatPanelW("dashboard")

        readonly property real fullHeight: surface.far
            ? parent.height - y - surface.pillMargin - surface.barH - 8
            : parent.height - y - surface.pillMargin - 8

        height: BarLayout.panelHeightIn("dashboard",
            (pillDashLoader.item && pillDashLoader.item.anyFills === false)
                ? Math.min(pillDashPanel.fullHeight, pillDashLoader.item.implicitHeight)
                : pillDashPanel.fullHeight,
            pillDashPanel.fullHeight)
        radius: 20
        color:  Colors.surface
        clip:   true

        readonly property real slideFrom: surface.floatCenter < parent.width / 2 ? -340 : 340

        opacity: 0
        property real _slideX: slideFrom
        transform: Translate { x: pillDashPanel._slideX }

        NumberAnimation on opacity { from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad; running: pillDashPanel.visible }
        NumberAnimation on _slideX { from: pillDashPanel.slideFrom; to: 0; duration: 300; easing.type: Easing.OutCubic; running: pillDashPanel.visible }

        Loader {
            id: pillDashLoader
            anchors.fill: parent
            active:  pillDashPanel.visible
            visible: false
            Timer {
                interval: 250
                running:  pillDashPanel.visible
                onTriggered: pillDashLoader.visible = true
            }
            sourceComponent: Dashboard {
                onToggleDashboard: surface.floatKind = ""
            }
        }
    }

    Rectangle {
        id: pillWeatherPanel
        visible: surface.isPrimary && surface.anyPill && surface.floatKind === "weather"

        x:      Math.max(surface.pillLeftMargin, Math.min(parent.width - width - surface.pillRightMargin, surface.floatCenter - width / 2))
        y:      surface.far ? parent.height - surface.pillMargin - surface.barH - 8 - height
                                   : surface.pillMargin + surface.barH + 8
        width:  BarLayout.floatPanelW("weather")
        height: BarLayout.panelHeightIn("weather", pillWeatherLoader.item ? pillWeatherLoader.item.implicitHeight : 0,
                                        parent.height - surface.pillMargin * 2 - surface.barH - 16)
        radius: 20
        color:  Colors.surface
        clip:   true

        readonly property real slideFrom: surface.floatCenter < parent.width / 2
            ? -(pillWeatherPanel.width + 20) : pillWeatherPanel.width + 20

        opacity: 0
        property real _slideX: slideFrom
        transform: Translate { x: pillWeatherPanel._slideX }

        NumberAnimation on opacity { from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad;   running: pillWeatherPanel.visible }
        NumberAnimation on _slideX { from: pillWeatherPanel.slideFrom; to: 0; duration: 300; easing.type: Easing.OutCubic; running: pillWeatherPanel.visible }

        Loader {
            id: pillWeatherLoader
            anchors.fill: parent
            active:  pillWeatherPanel.visible
            visible: false
            Timer {
                interval: 250
                running:  pillWeatherPanel.visible
                onTriggered: pillWeatherLoader.visible = true
            }
            sourceComponent: WeatherPanel {
                onClosed: surface.floatKind = ""
            }
        }
    }
}
