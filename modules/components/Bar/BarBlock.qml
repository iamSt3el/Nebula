import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.Osd
import qs.modules.components.AppLauncher
import qs.modules.components.CustomContextMenu
import "BarOps.js" as BarOps

Item {
    id: barBlock

    required property string blockId
    required property int index
    required property bool leaving
    property QtObject editor: null
    property real maxWidth: -1
    property real absX: 0
    property var coverTabs: []

    function coveredAt(x0, w) {
        if (GlobalStates.barEditMode || !barBlock.isPill)
            return false
        const l = barBlock.absX + x0
        const r = l + w
        for (const t of barBlock.coverTabs) {
            if (t.id === barBlock.blockId)
                continue
            if (t.r > l + 1 && t.l < r - 1)
                return true
        }
        return false
    }
    property real spanL: 0
    property real spanR: 0
    property real spanF: 0
    property string edge: "top"
    property Item frame: null
    readonly property var edgeCfg: BarLayout.edge(barBlock.edge)
    readonly property bool far: barBlock.frame ? barBlock.frame.far : BarOps.isFarSide(barBlock.edge)
    readonly property bool vertical: barBlock.frame ? barBlock.frame.vertical : false
    readonly property bool sideCrowded: barBlock.vertical && !!barBlock.frame && !!barBlock.frame.compactIds && barBlock.frame.compactIds[barBlock.blockId] === true
    property var fullW: ({})

    function noteFull(id, w) {
        if (w <= 0 || Math.abs((barBlock.fullW[id] ?? -1) - w) < 0.5)
            return
        const n = Object.assign({}, barBlock.fullW)
        n[id] = w
        barBlock.fullW = n
    }

    function compactFor(id) {
        return barBlock.sideCrowded && (barBlock.fullW[id] ?? Infinity) > barBlock.barH - 4
    }
    readonly property real frameW: barBlock.frame ? barBlock.frame.width : layout.width
    readonly property real frameH: barBlock.frame ? barBlock.frame.height : layout.height
    readonly property real iconSize: barBlock.edgeCfg.iconSize
    readonly property real appIconSize: barBlock.iconSize > 0 ? barBlock.iconSize : Math.max(16, barBlock.barH - 16)

    function flipAbout(w, h) {
        return Qt.matrix4x4(0, 1, 0, (w - h) / 2, 1, 0, 0, (h - w) / 2, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    function mirrorAbout(w, h) {
        return barBlock.frame && barBlock.frame.side === "right"
            ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, h, 0, 0, 1, 0, 0, 0, 0, 1)
            : Qt.matrix4x4(-1, 0, 0, w, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    signal gone()

    property var lastInfo: null
    readonly property var liveInfo: BarLayout.blockById(barBlock.blockId)
    onLiveInfoChanged: if (barBlock.liveInfo) barBlock.lastInfo = barBlock.liveInfo
    readonly property var info: barBlock.liveInfo ?? barBlock.lastInfo
    readonly property var itemIds: barBlock.info ? barBlock.info.items : []
    readonly property string anchorSide: barBlock.info ? barBlock.info.anchor : "left"

    readonly property bool editMode: GlobalStates.barEditMode && layout.isPrimary
    readonly property bool editing: barBlock.editMode && !barBlock.leaving
    readonly property bool blockSelected: !!barBlock.editor && barBlock.editor.selectedBlock === barBlock.blockId
    readonly property bool otherBlockSelected: barBlock.editing && !!barBlock.editor && barBlock.editor.selectedBlock !== ""
        && !barBlock.blockSelected
    // this block's slice of the edit-mode sweep, from its own place on the screen
    readonly property real revealT: GlobalStates.barRevealAt(barBlock.absX + barBlock.width / 2,
                                                             barBlock.frameW)
    readonly property bool handlesIn: barBlock.revealT > 0.55
    readonly property string shape: BarLayout.blockShape(barBlock.blockId, barBlock.edge)
    readonly property bool isPill: barBlock.shape === "pill"
    readonly property string tintRole: BarLayout.blockStyle(barBlock.blockId, "tint", "none")
    readonly property bool tintShown: barBlock.tintRole !== "none" && !barBlock.isPill && barBlock.itemIds.length > 0
    readonly property bool split: barBlock.isPill && BarLayout.splitBlock(barBlock.blockId)
    property real clearT: barBlock.split ? 1 : 0
    Behavior on clearT { EffectsAnim { speed: "default" } }
    readonly property color plateFill: barBlock.tintRole === "none" ? Colors.surface
        : Qt.tint(Colors.surface, Qt.alpha(BarLayout.roleColor(barBlock.tintRole), 0.22))
    property real pillTintT: barBlock.isPill && barBlock.tintRole !== "none" && !barBlock.split ? 1 : 0
    Behavior on pillTintT { EffectsAnim { speed: "default" } }
    property color pillTintColor: BarLayout.roleColor(barBlock.tintRole === "none" ? "primary" : barBlock.tintRole)
    Behavior on pillTintColor { EffectsColorAnim {} }
    readonly property real pillOpacity: Math.max(0, Math.min(100, BarLayout.blockStyle(barBlock.blockId, "opacity", 100))) / 100
    property real fadeK: barBlock.isPill && !barBlock.split ? 1 - barBlock.pillOpacity : 0
    Behavior on fadeK { EffectsAnim { speed: "default" } }
    readonly property real pillClear: Math.max(barBlock.clearT, barBlock.fadeK)
    readonly property real pillTintRgb: Math.round(barBlock.pillTintColor.r * 255) * 65536
        + Math.round(barBlock.pillTintColor.g * 255) * 256 + Math.round(barBlock.pillTintColor.b * 255)
    property real pillT: barBlock.isPill ? 1 : 0
    property real flatT: barBlock.shape === "flat" ? 1 : 0
    Behavior on pillT { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }
    Behavior on flatT { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }
    readonly property var gaps: BarLayout.gapModel ? BarLayout.blockGaps(barBlock.blockId, barBlock.edge) : null
    readonly property real gapBefore: barBlock.gaps ? barBlock.gaps.gapBefore : -1
    readonly property real offset: barBlock.gaps ? barBlock.gaps.offset : 0
    property real drop: barBlock.gaps ? Math.max(0, barBlock.gaps.edge)
        : (barBlock.frame ? barBlock.frame.pillMargin : 0) * barBlock.pillT
    Behavior on drop { enabled: BarLayout.settled && barBlock.gaps !== null && !BarLayout.gapDragging; SpatialAnim { speed: "default" } }
    property real pillRadius: {
        const r = barBlock.gaps ? barBlock.gaps.radius : BarLayout.blockStyle(barBlock.blockId, "radius", -1)
        return r < 0 ? barBlock.barH / 2 : Math.min(r, barBlock.barH / 2)
    }
    Behavior on pillRadius { enabled: BarLayout.settled && barBlock.gaps !== null && !BarLayout.gapDragging; SpatialAnim { speed: "default" } }
    readonly property var screenCorners: {
        const c = BarLayout.blockCorners(barBlock.blockId)
        const f = k => c[k] === null ? barBlock.pillRadius : Math.min(c[k], barBlock.barH / 2)
        return { tl: f("tl"), tr: f("tr"), br: f("br"), bl: f("bl"),
                 custom: c.tl !== null || c.tr !== null || c.br !== null || c.bl !== null }
    }
    readonly property var frameCorners: {
        const c = barBlock.screenCorners
        if (!c.custom)
            return null
        switch (barBlock.edge) {
        case "bottom": return { nl: c.bl, nr: c.br, fl: c.tl, fr: c.tr }
        case "left":   return { nl: c.tl, nr: c.bl, fl: c.tr, fr: c.br }
        case "right":  return { nl: c.tr, nr: c.br, fl: c.tl, fr: c.bl }
        }
        return { nl: c.tl, nr: c.tr, fl: c.bl, fr: c.br }
    }
    readonly property var geomSig: [barBlock.x, barBlock.y, barBlock.width, barBlock.visible, barBlock.pc, barBlock.pillRadius, barBlock.frameCorners,
        barBlock.pillT, barBlock.flatT, barBlock.drop, barBlock.tabOpen, barBlock.fixedWidth,
        barBlock.wantedBase, barBlock.leaving, barBlock.shape, barBlock.floating, barBlock.merged, barBlock.anchorSide,
        barBlock.clearT, barBlock.fadeK, barBlock.pillTintT, barBlock.pillTintRgb, barBlock.lineUp, barBlock.panelCorner]
    onGeomSigChanged: if (barBlock.frame && barBlock.frame.markGeom) barBlock.frame.markGeom()
    readonly property var tabSig: [barBlock.tabX, barBlock.tabW, barBlock.tabH, barBlock.goo,
        barBlock.gooX, barBlock.gooW, barBlock.gooH, barBlock.srcX, barBlock.srcW, barBlock.gooHost]
    onTabSigChanged: {
        if (!barBlock.frame)
            return
        if (barBlock.gliding && barBlock.frame.recomputeTabs)
            barBlock.frame.recomputeTabs()
        else if (barBlock.frame.markTabs)
            barBlock.frame.markTabs()
    }
    readonly property string panelStyle: BarLayout.panelStyleFor(barBlock.blockId, barBlock.edge, barBlock.shape)
    readonly property real contentNearL: barBlock.floating ? barBlock.panelCorner
        : barBlock.merged && barBlock.tabX < -0.5 ? barBlock.panelCorner : 0
    readonly property real contentNearR: barBlock.floating ? barBlock.panelCorner
        : barBlock.merged && barBlock.tabX + barBlock.tabW > barBlock.width + 0.5 ? barBlock.panelCorner : 0
    function contentCorner(corner, farR) {
        const top = corner[0] === "t"
        const left = corner[1] === "l"
        if (!barBlock.vertical)
            return (barBlock.far ? !top : top) ? (left ? barBlock.contentNearL : barBlock.contentNearR) : barBlock.contentFar(farR)
        return (barBlock.far ? !left : left) ? (top ? barBlock.contentNearL : barBlock.contentNearR) : barBlock.contentFar(farR)
    }
    function contentFar(attachedR) {
        if (barBlock.merged || barBlock.floating)
            return barBlock.panelCorner
        if (barBlock.isPill)
            return attachedR
        return barBlock.acrossOf(barBlock.lastKind) >= barBlock.panelRoom - 1 ? 0 : barBlock.panelCorner
    }
    readonly property bool floating: barBlock.panelStyle === "floating"
    readonly property bool fusedAttach: barBlock.panelStyle === "attached" && barBlock.isPill && !!barBlock.frame
        && !!barBlock.frame.fused && (barBlock.frame.fused[barBlock.blockId]?.ids.length ?? 1) > 1
    readonly property bool merged: barBlock.panelStyle === "merged" || barBlock.crowded || barBlock.fusedAttach
    property bool crowded: false
    function updateCrowded() {
        if (barBlock.shownKind !== "") {
            if (!barBlock.crowded)
                barBlock.crowded = barBlock.panelStyle === "attached" && !!barBlock.frame && !!barBlock.frame.crowds
                    && barBlock.frame.crowds(barBlock)
        } else if (!barBlock.tabOpen) {
            barBlock.crowded = false
        }
    }
    onTabOpenChanged: barBlock.updateCrowded()
    onTabNaturalWChanged: barBlock.updateCrowded()
    readonly property real panelGapSetting: BarLayout.blockPanelGap(barBlock.blockId)
    readonly property bool fusedHost: barBlock.merged && !!barBlock.frame && !!barBlock.frame.fusedCovers
        && barBlock.frame.fusedCovers(barBlock, barBlock.tabTargetX, barBlock.tabNaturalW)
    readonly property real floatGap: barBlock.floating ? barBlock.panelGapSetting
        : barBlock.fusedHost ? 0
        : barBlock.merged ? Math.max(barBlock.panelGapSetting, barBlock.crowded || barBlock.fusedAttach ? 8 : 0) * Math.max(0, Math.min(1, (barBlock.tabH - barBlock.barH) / 24)) : 0
    readonly property bool sharedMotion: (SettingsConfig.general.panelMorph ?? "default") === "shared"
    readonly property bool morphFloat: barBlock.sharedMotion && barBlock.floating && !barBlock.quickMotion && !barBlock.vertical
    function bezAt(x1, y1, x2, y2, x) {
        if (x <= 0)
            return 0
        if (x >= 1)
            return 1
        let lo = 0, hi = 1, t = x
        for (let i = 0; i < 18; i++) {
            const bx = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            if (bx < x)
                lo = t
            else
                hi = t
            t = (lo + hi) / 2
        }
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
    }
    function emph(x) {
        return barBlock.bezAt(0.2, 0, 0, 1, x)
    }
    property real goo: { barBlock.snapKick; return barBlock.floating && barBlock.shownKind !== "" ? 1 : 0 }
    Behavior on goo {
        enabled: barBlock.floating && !barBlock.gooSnap
        NumberAnimation {
            id: gooAnim
            duration: barBlock.morphFloat ? (barBlock.shownKind !== "" ? 500 : 420)
                : barBlock.quickMotion ? (barBlock.shownKind !== "" ? 380 : 260)
                : barBlock.shownKind !== "" ? 520 : 400
            easing.type: barBlock.morphFloat ? Easing.Linear
                : barBlock.quickMotion && barBlock.shownKind === "" ? Easing.OutCubic : Easing.InOutCubic
        }
    }
    property real gooX: 0
    property real gooW: 0
    property real gooH: 0
    function trackGoo() {
        if (barBlock.shownKind === "")
            return
        barBlock.gooX = barBlock.tabX
        barBlock.gooW = barBlock.tabW
        barBlock.gooH = Math.max(0, barBlock.tabH - barBlock.barH)
    }
    property int openSeq: 0
    property real heroT: 0
    property var heroPairs: []
    property string heroOwner: ""
    property string heroKind: ""
    readonly property bool heroFlying: heroAnim.running
    onHeroFlyingChanged: if (!barBlock.heroFlying) barBlock.heroPairs = []

    NumberAnimation {
        id: heroAnim
        target: barBlock
        property: "heroT"
        easing.type: Easing.Linear
    }

    function heroUnder(item, anc) {
        for (let p = item; p; p = p.parent) {
            if (p === anc)
                return true
        }
        return false
    }

    function heroFly(opening) {
        const to = opening ? 1 : 0
        heroAnim.stop()
        if (!barBlock.sharedMotion || barBlock.quickMotion || barBlock.panelSwap || barBlock.vertical) {
            barBlock.heroT = to
            barBlock.heroPairs = []
            return
        }
        const pairs = []
        const slot = [slotA, slotB].find(s => s.kind === barBlock.heroKind && s.item)
        if (slot) {
            const tags = GlobalStates.heroTags
            for (const s of tags) {
                if (s.target || !s.item || !s.owner || s.owner.host !== barBlock || s.owner.itemId !== barBlock.heroOwner)
                    continue
                const d = tags.find(t => t.target && t.key === s.key && t.item && t.item.visible && barBlock.heroUnder(t.item, slot))
                if (d && s.item.width > 0 && d.item.width > 0)
                    pairs.push({ src: s.item, dst: d.item, clip: d.clip ?? null, clipR: d.clipRadius ?? 0 })
            }
        }
        if (pairs.length === 0) {
            barBlock.heroT = to
            barBlock.heroPairs = []
            return
        }
        barBlock.heroPairs = pairs
        heroAnim.from = barBlock.heroT
        heroAnim.to = to
        heroAnim.duration = Math.max(1, (opening ? 500 : 420) * Math.abs(to - barBlock.heroT))
        heroAnim.start()
    }

    onShownKindChanged: {
        if (barBlock.shownKind !== "") {
            barBlock.heroOwner = barBlock.openerId
            barBlock.heroKind = barBlock.shownKind
        }
        if (barBlock.shownKind !== "" && !barBlock.panelSwap) {
            barBlock.heroT = 0
            Qt.callLater(() => barBlock.heroFly(true))
        } else if (barBlock.shownKind === "" && barBlock.heroKind !== "") {
            barBlock.heroFly(false)
        }
        if (barBlock.shownKind !== "") {
            barBlock.heldX = barBlock.tabTargetX
            barBlock.heldW = barBlock.tabTargetW
        }
        barBlock.updateCrowded()
        if (barBlock.shownKind !== "" && layout.nextPanelSeq)
            barBlock.openSeq = layout.nextPanelSeq()
        barBlock.trackGoo()
        barBlock.queueSync()
    }
    onTabXChanged: barBlock.trackGoo()
    onTabWChanged: barBlock.trackGoo()
    onTabHChanged: barBlock.trackGoo()
    property real plateX: 0
    property real plateW: 0
    property real plateH: 0
    property real plateR: 0
    function plateFrom(item) {
        barBlock.plateW = 0
        if (!item || !barBlock.split)
            return
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || s.leaving || s.loaderItem !== item)
                continue
            const h = BarLayout.plateH(s.itemId, barBlock.barH)
            const shaped = (item.plateShape ?? "") !== ""
                || BarLayout.plateShape(s.itemId, s.contentWidth, s.contentHeight) !== ""
            const ih = shaped ? h * 0.78 : h - 2
            const w = shaped ? ih : BarLayout.plateW(s.itemId, s.contentWidth, s.contentHeight, barBlock.barH) - 2
            const c = s.mapToItem(barBlock, s.margin[0] + s.innerWidth / 2, 0).x
            barBlock.plateX = c - w / 2
            barBlock.plateH = ih
            barBlock.plateR = shaped ? ih / 2 : Math.max(0, BarLayout.plateRadius(s.itemId, h) - 1)
            barBlock.plateW = w
            return
        }
    }
    readonly property var gooHost: barBlock.split && barBlock.plateW > 0
        ? { x: barBlock.plateX, w: barBlock.plateW, y: (barBlock.barH - barBlock.plateH) / 2,
            h: barBlock.plateH, r: barBlock.plateR }
        : { x: 0, w: barBlock.width, y: 0, h: barBlock.barH, r: barBlock.pillRadius }
    readonly property real contentT: !barBlock.floating ? 1
        : barBlock.morphFloat ? barBlock.bezAt(0, 0, 0.6, 1, Math.max(0, Math.min(1, (barBlock.goo * 500 - 60) / 200)))
        : barBlock.quickMotion ? Math.max(0, Math.min(1, (barBlock.goo - 0.55) / 0.35))
        : Math.max(0, Math.min(1, (barBlock.goo - 0.75) / 0.25))
    readonly property var gooShape: {
        const g = barBlock.goo
        if (barBlock.morphFloat) {
            const p = barBlock.emph(g)
            const x0 = barBlock.srcX, w0 = Math.max(2, barBlock.srcW)
            const fx = barBlock.gooX, fw = barBlock.gooW, fy = barBlock.barH + barBlock.floatGap, fh = barBlock.gooH
            return {
                x: x0 + (fx - x0) * p,
                y: fy * p,
                w: w0 + (fw - w0) * p,
                h: barBlock.barH + (fh - barBlock.barH) * p,
                k: 18 * (1 - p)
            }
        }
        const s1 = Math.min(1, g / 0.45)
        const s2 = Math.max(0, (g - 0.45) / 0.55)
        const fw = barBlock.gooW
        const fh = barBlock.gooH
        const fx = barBlock.gooX
        const fy = barBlock.barH + barBlock.floatGap
        const host = barBlock.split && barBlock.plateW > 0
        const cx = barBlock.srcX + barBlock.srcW / 2
        const w0 = host ? Math.max(2, barBlock.plateW - 32) : Math.min(Math.max(barBlock.srcW, 24), 44)
        const h0 = host ? Math.max(2, barBlock.plateH - 32) : Math.max(8, barBlock.barH - 12)
        const x0 = host ? barBlock.plateX + (barBlock.plateW - w0) / 2 : cx - w0 / 2
        const y0 = (barBlock.barH - h0) / 2
        const mw = fw * 0.8
        const mh = fh * 0.76
        const mx = fx + (fw - mw) / 2
        const my = barBlock.barH + barBlock.floatGap * 0.5
        const early = g < 0.45
        return {
            x: early ? x0 + (mx - x0) * s1 : mx + (fx - mx) * s2,
            y: early ? y0 + (my - y0) * s1 : my + (fy - my) * s2,
            w: early ? w0 + (mw - w0) * s1 : mw + (fw - mw) * s2,
            h: early ? h0 + (mh - h0) * s1 : mh + (fh - mh) * s2,
            k: 16 * (1 - s2)
        }
    }
    readonly property bool bumpHiding: !!barBlock.frame && barBlock.frame.bumpMode === true
    readonly property real hideT: !barBlock.bumpHiding ? 1
        : Math.max(0, Math.min(1, barBlock.isPill ? barBlock.frame.reveal : barBlock.frame.bumpDepth))
    readonly property real hideLift: !barBlock.bumpHiding ? 0 : barBlock.isPill ? barBlock.frame.slide
        : (1 - barBlock.frame.bumpDepth) * (barBlock.barH + barBlock.frame.edgeInset)
    y: barBlock.far ? -barBlock.drop + barBlock.hideLift : barBlock.drop - barBlock.hideLift
    readonly property real barH: barBlock.edgeCfg.height
    property real lineUp: barBlock.frame && barBlock.frame.lineUpDepth ? barBlock.frame.lineUpDepth * barBlock.stepT : 0
    Behavior on lineUp { enabled: BarLayout.settled; SpatialAnim { speed: "default" } }
    readonly property real basePad: barBlock.anchorSide === "center" ? 15 : 10
    property var edgeL: null
    property var edgeR: null
    readonly property real stepT: (1 - barBlock.pillT) * (1 - barBlock.flatT)
    readonly property real roundT: barBlock.pillT + barBlock.stepT
    readonly property var corners: barBlock.frame && barBlock.frame.cornerOf
        ? barBlock.frame.cornerOf(barBlock.blockId, barBlock.frame.sdfField) : null
    readonly property real pad: barBlock.endPad(barBlock.edgeL, barBlock.corners ? barBlock.corners.l : 0)
    readonly property real padR: barBlock.endPad(barBlock.edgeR, barBlock.corners ? barBlock.corners.r : 0)

    function endPad(edge, corner) {
        if (barBlock.split)
            return 0
        if (!edge)
            return barBlock.basePad
        const fit = side => Math.max(0, Math.min(barBlock.basePad, side - edge.off)) - barBlock.basePad
        const stepW = corner > 0.5 ? barBlock.stepT : 0
        return barBlock.basePad + fit(edge.gap) * barBlock.pillT
            + fit(Math.max(edge.gap, corner - edge.r)) * stepW
    }

    function edgeShape(slot, fromRight) {
        const top = slot.loaderItem
        if (!top)
            return null
        let found = null
        let nearest = Infinity
        const walk = (it, depth) => {
            if (!it || !it.visible || depth > 12)
                return
            if (it.radius !== undefined && it.color !== undefined
                    && it.height >= barBlock.barH * 0.45 && it.width >= it.height * 0.6) {
                const p = it.mapToItem(slot, 0, 0)
                const off = fromRight ? slot.width - (p.x + it.width) : p.x
                if (off < nearest && off < barBlock.basePad) {
                    nearest = off
                    found = { gap: (barBlock.barH - it.height) / 2, off: off,
                              r: Math.min(it.radius, it.width / 2, it.height / 2) }
                }
            }
            for (const c of it.children)
                walk(c, depth + 1)
        }
        walk(top, 0)
        return found
    }

    function measureEdges() {
        if (typeof barBlock.edgeShape !== "function")
            return
        let first = null
        let last = null
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || s.leaving || !s.itemShown)
                continue
            if (!first)
                first = s
            last = s
        }
        barBlock.edgeL = first ? barBlock.edgeShape(first, false) : null
        barBlock.edgeR = last ? barBlock.edgeShape(last, true) : null
    }

    onSlotLayoutChanged: Qt.callLater(barBlock.measureEdges)
    onBarHChanged: Qt.callLater(barBlock.measureEdges)
    onShownCountChanged: Qt.callLater(barBlock.measureEdges)

    readonly property real gap: barBlock.split ? Math.max(6, barBlock.edgeCfg.itemGap) : barBlock.edgeCfg.itemGap

    property string clickedKind: ""
    property string hoverKind: ""
    property string lastKind: ""
    property string shownKind: ""
    property int curSlot: 0
    readonly property Item curSlotItem: barBlock.curSlot === 0 ? slotA : slotB
    property string openerId: ""
    property string pendingKind: ""
    property Item pendingItem: null
    property bool pendingClicked: false
    property bool tabSnap: false
    property var itemLeaving: ({})
    property real srcX: 0
    property real srcW: 0

    readonly property bool hovering: blockHover.hovered || tabHover.hovered
    readonly property bool sysHost: barBlock.edge === BarLayout.sysEdge && layout.isPrimary && barBlock.blockId === BarLayout.sysHostId
    function hostsSys(k) {
        return BarLayout.panelItemHost(k) ? layout.isPrimary && !barBlock.leaving && barBlock.hasItem(k) : barBlock.sysHost
    }
    readonly property string sysKind: GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") !== "center"
            && barBlock.hostsSys("clipboard") ? "clipboard"
        : GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") !== "center"
            && barBlock.hostsSys("wallpaper") ? "wallpaper"
        : barBlock.sysHost && GlobalStates.osdOpen && BarLayout.osdHostItem === "" ? "osd" : ""
    function isSys(k) {
        return k === "clipboard" || k === "wallpaper" || k === "osd"
    }
    readonly property bool launchHost: layout.isPrimary && !barBlock.leaving
        && ServiceLauncher.position !== "center" && barBlock.hasItem("launcher")
    function previewOpener(k) {
        return BarLayout.panelHostItem(k)
    }
    readonly property bool previewHost: layout.isPrimary && !barBlock.leaving && GlobalStates.panelPreview !== ""
        && (GlobalStates.panelPreview === "wallpaper" || GlobalStates.panelPreview === "clipboard" ? barBlock.hostsSys(GlobalStates.panelPreview)
            : barBlock.hasItem(barBlock.previewOpener(GlobalStates.panelPreview)))
    readonly property string panelKind: barBlock.launchHost && GlobalStates.launcherPreview ? "launcher"
        : barBlock.previewHost ? GlobalStates.panelPreview
        : barBlock.leaving ? ""
        : barBlock.editMode ? (!GlobalStates.barEditTest ? ""
            : barBlock.osdWant || barBlock.sysKind === "osd" ? "osd"
            : barBlock.popupWant ? "notifPopup" : "")
        : barBlock.sysKind !== "" ? barBlock.sysKind
        : barBlock.launchHost && GlobalStates.appLauncherOpen ? "launcher"
        : barBlock.clickedKind !== "" ? barBlock.clickedKind
        : barBlock.hovering && barBlock.hoverKind !== "" ? barBlock.hoverKind
        : barBlock.osdWant && !barBlock.popupWant && barBlock.tuckHost === "" ? "osd"
        : barBlock.popupWant && barBlock.tuckHost === "" ? "notifPopup" : ""

    readonly property bool osdHost: layout.isPrimary && BarLayout.osdHostItem !== ""
        && barBlock.hasItem(BarLayout.osdHostItem)
    readonly property bool osdWant: barBlock.osdHost && GlobalStates.osdOpen

    readonly property bool popupHost: layout.isPrimary && BarLayout.popupMode === "item"
        && barBlock.hasItem(BarLayout.popupHostItem)
    readonly property bool popupWant: barBlock.popupHost && ServiceNotification.popups.length > 0
        && !GlobalStates.notificationCenterOpen

    readonly property real openHeight: barBlock.frameH - (barBlock.isPill ? (barBlock.frame ? barBlock.frame.pillMargin : ServiceGaps.pillMargin) * 2 : 0)
    readonly property real panelRoom: barBlock.openHeight - barBlock.barH - (barBlock.floating || barBlock.merged ? barBlock.panelGapSetting : 0) - (barBlock.frame ? Math.max(barBlock.frame.panelFar, barBlock.frame.farReserve) + barBlock.frame.borderNear : 0)
    readonly property real heightRoom: barBlock.vertical ? barBlock.spanR - barBlock.spanL : barBlock.panelRoom
    readonly property real widthRoom: barBlock.vertical ? barBlock.panelRoom : barBlock.frameW - 32

    function alongOf(k) {
        return barBlock.vertical ? barBlock.contentHeight(k) : barBlock.kindWidth(k)
    }

    function acrossOf(k) {
        return barBlock.vertical ? barBlock.kindWidth(k) : barBlock.contentHeight(k)
    }

    function hasItem(id) {
        return barBlock.itemIds.indexOf(id) >= 0
    }

    function slotIdOf(item) {
        if (!item)
            return ""
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && s.loaderItem === item)
                return s.itemId
        }
        return ""
    }

    function ownerIdOf(item) {
        for (let it = item; it && it !== barBlock; it = it.parent) {
            const id = barBlock.slotIdOf(it)
            if (id !== "")
                return id
        }
        return ""
    }

    function itemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemId === id)
                return s.loaderItem
        }
        return null
    }

    function flightItems() {
        const out = []
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemShown && s.loaderItem)
                out.push({ id: s.itemId, item: s.loaderItem, slot: s })
        }
        return out
    }

    function sourceFrom(item) {
        barBlock.plateFrom(item)
        if (item) {
            const r = item.mapToItem(barBlock, 0, 0, item.width, item.height)
            barBlock.srcX = r.x
            barBlock.srcW = r.width
            return
        }
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemId === "workspaces") {
                barBlock.srcX = barBlock.pad + s.x
                barBlock.srcW = s.width
                return
            }
        }
        barBlock.srcX = 0
        barBlock.srcW = barBlock.width
    }

    function checkSettled() {
        if (tabXAnim.running || tabWAnim.running || tabHAnim.running)
            return
        if (barBlock.closing && barBlock.revealMode !== "") {
            barBlock.tabSnap = true
            barBlock.revealMode = ""
            barBlock.tabSnap = false
        }
        if (!barBlock.closing) {
            barBlock.startFollow()
            return
        }
        if (barBlock.tabH > barBlock.barH + 0.5)
            return
        barBlock.lastKind = ""
        barBlock.openerId = ""
        if (barBlock.pendingKind === "")
            return
        const k = barBlock.pendingKind
        const it = barBlock.pendingItem
        const c = barBlock.pendingClicked
        barBlock.pendingKind = ""
        barBlock.pendingItem = null
        Qt.callLater(() => barBlock.beginOpen(k, it, c))
    }

    function flushSource(kind) {
        const w = barBlock.alongOf(kind)
        const cx = barBlock.srcX + barBlock.srcW / 2
        const tx = barBlock.alignX(w, cx)
        const pinned = Math.abs(tx - (cx - w / 2)) > 0.5
        let l = barBlock.srcX
        let r = barBlock.srcX + barBlock.srcW
        if (pinned && Math.abs(tx) <= 0.5)
            l = Math.min(l, 0)
        if (pinned && Math.abs(tx + w - barBlock.width) <= 0.5)
            r = Math.max(r, barBlock.width)
        barBlock.srcX = l
        barBlock.srcW = r - l
    }

    function snapSource(item, kind) {
        barBlock.tabSnap = true
        barBlock.sourceFrom(item)
        barBlock.flushSource(kind)
        barBlock.tabSnap = false
    }

    function shownItemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemId === id)
                return s.itemShown ? s.loaderItem : null
        }
        return null
    }

    function anchorSource(id, kind) {
        const it = barBlock.shownItemFor(id)
        if (it) {
            barBlock.sourceFrom(it)
            barBlock.flushSource(kind)
            return
        }
        barBlock.plateFrom(null)
        const w = barBlock.alongOf(kind)
        barBlock.srcX = barBlock.alignX(w, barBlock.width / 2)
        barBlock.srcW = w
    }

    function resyncSource() {
        const k = barBlock.panelKind
        const snap = barBlock.tabH <= barBlock.barH + 0.5
        if (k === "osd" && barBlock.osdHost) {
            barBlock.tabSnap = snap
            barBlock.anchorSource(BarLayout.osdHostItem, k)
            barBlock.tabSnap = false
            return
        }
        if (k === "launcher") {
            if (ServiceLauncher.position === "block") {
                barBlock.tabSnap = snap
                barBlock.plateFrom(null)
                barBlock.srcX = 0
                barBlock.srcW = barBlock.width
                barBlock.flushSource("launcher")
                barBlock.tabSnap = false
                return
            }
            const it = barBlock.itemFor("launcher")
            if (snap) {
                barBlock.snapSource(it, "launcher")
            } else {
                barBlock.sourceFrom(it)
                barBlock.flushSource("launcher")
            }
            return
        }
        const item = BarLayout.panelItemHost(k) && barBlock.hasItem(k) ? barBlock.itemFor(k) : null
        if (snap) {
            barBlock.snapSource(item, k)
        } else {
            barBlock.sourceFrom(item)
            barBlock.flushSource(k)
        }
    }

    readonly property bool dockRevealing: !!barBlock.frame && (barBlock.frame.reveal ?? 1) < 0.999
    readonly property bool launcherOnBlock: barBlock.panelKind === "launcher" && ServiceLauncher.position === "block"
    onWidthChanged: if ((barBlock.isSys(barBlock.panelKind) || barBlock.launcherOnBlock) && !barBlock.dockRevealing) barBlock.resyncSource()
    onDockRevealingChanged: if (!barBlock.dockRevealing && (barBlock.isSys(barBlock.panelKind) || barBlock.launcherOnBlock)) barBlock.resyncSource()

    function beginOpen(kind, item, clicked) {
        if (barBlock.editMode)
            return
        if (barBlock.tabOpen) {
            barBlock.sourceFrom(item)
            barBlock.flushSource(kind)
            barBlock.openerId = barBlock.slotIdOf(item)
            if (clicked) {
                barBlock.clickedKind = kind
            } else {
                barBlock.clickedKind = ""
                barBlock.hoverKind = kind
            }
            return
        }
        barBlock.snapSource(item, kind)
        barBlock.openerId = barBlock.slotIdOf(item)
        if (clicked)
            barBlock.clickedKind = kind
        else
            barBlock.hoverKind = kind
    }

    function hoverOpen(kind, item) {
        if (barBlock.editMode || barBlock.clickedKind !== "")
            return
        if (barBlock.panelKind !== "" && barBlock.panelKind !== kind && !barBlock.isTransient(barBlock.panelKind))
            return
        if (kind !== "dockPreview") {
            const owner = barBlock.ownerIdOf(item ?? null)
            if (owner !== "" && !BarLayout.isGroup(owner) && BarLayout.openOn(owner) !== "hover")
                return
        }
        if (barBlock.panelKind === kind) {
            barBlock.hoverKind = kind
            return
        }
        barBlock.beginOpen(kind, item ?? null, false)
    }

    Connections {
        target: GlobalStates
        function onPanelRequested(kind) {
            if (kind === "") {
                if (barBlock.clickedKind !== "")
                    barBlock.closePanel()
                return
            }
            const id = BarLayout.panelHostItem(kind)
            if (!layout.isPrimary || !barBlock.hasItem(id) || barBlock.clickedKind === kind)
                return
            const it = barBlock.itemFor(id)
            if (it)
                barBlock.openPanel(kind, it)
        }
    }

    function openPanel(kind, item) {
        if (barBlock.editMode)
            return
        if (barBlock.clickedKind === kind) {
            barBlock.closePanel()
            return
        }
        barBlock.beginOpen(kind, item ?? null, true)
    }

    function closePanel() {
        barBlock.pendingKind = ""
        barBlock.clickedKind = ""
        barBlock.hoverKind = ""
    }

    readonly property int trayCount: ServiceSystemTray.items ? ServiceSystemTray.items.values.length : 0
    property int trayOffset: 0
    readonly property int trayHidden: Math.max(0, barBlock.trayCount - barBlock.trayOffset)
    readonly property int trayCols: Math.max(1, Math.min(6, barBlock.trayHidden))
    readonly property int trayRows: Math.max(1, Math.ceil(barBlock.trayHidden / 6))
    property var trayMenuItem: null
    readonly property bool trayMenuAlive: barBlock.trayMenuItem !== null && ServiceSystemTray.items
        && ServiceSystemTray.items.values.indexOf(barBlock.trayMenuItem) >= 0

    onTrayMenuAliveChanged: if (!barBlock.trayMenuAlive && barBlock.panelKind === "trayMenu") barBlock.closePanel()
    onTrayHiddenChanged: if (barBlock.trayHidden === 0 && barBlock.panelKind === "tray") barBlock.closePanel()

    function openTrayOverflow(source, limit, clicked) {
        if (barBlock.panelKind !== "tray")
            barBlock.trayOffset = Math.max(0, limit)
        if (clicked)
            barBlock.openPanel("tray", source)
        else
            barBlock.hoverOpen("tray", source)
    }

    function openTrayMenu(trayItem, source) {
        if (barBlock.editMode || !trayItem)
            return
        if (barBlock.panelKind === "trayMenu" && barBlock.trayMenuItem === trayItem) {
            barBlock.closePanel()
            return
        }
        barBlock.trayMenuItem = trayItem
        if (!source && barBlock.panelKind === "tray") {
            barBlock.clickedKind = "trayMenu"
            return
        }
        barBlock.beginOpen("trayMenu", source, true)
    }

    readonly property bool panelHeld: {
        const it = barBlock.itemOf(barBlock.panelKind)
        return !!it && ((it.holdOpen ?? false) || (it.passwordPrompt ?? false))
    }

    readonly property var outsideCloseKinds: ["sound", "network", "bluetooth", "brightness", "powerMode", "power", "windowInfo",
        "battery", "phoneStatus", "phoneNotifs", "phoneCall", "soundscape", "scenes", "notifications", "weather", "claudeCode",
        "kindle", "dashboard", "calendar", "more", "musicPoster", "musicDial",
        "musicSources", "musicBeads", "musicDevelop", "musicShape", "cpu", "memory", "wiz"]

    HyprlandFocusGrab {
        windows: [QsWindow.window]
        active: !GlobalStates.capturing && (barBlock.panelKind === "trayMenu" || barBlock.panelKind === "dockMenu"
            || (barBlock.outsideCloseKinds.indexOf(barBlock.panelKind) >= 0
                && barBlock.clickedKind === barBlock.panelKind
                && !barBlock.panelHeld)
            || (barBlock.panelKind === "tray" && barBlock.clickedKind === "tray")
            || ((barBlock.panelKind === "clipboard" || barBlock.panelKind === "wallpaper")
                && barBlock.sysKind === barBlock.panelKind
                && !barBlock.panelHeld && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen))
        onCleared: {
            if (barBlock.panelHeld || GlobalStates.capturing)
                return
            if (barBlock.sysKind === "clipboard" && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen) {
                GlobalStates.clipboardOpen = false
                return
            }
            if (barBlock.sysKind === "wallpaper" && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen) {
                GlobalStates.wallpaperOpen = false
                return
            }
            if (["trayMenu", "dockMenu", "tray"].indexOf(barBlock.panelKind) >= 0 || barBlock.outsideCloseKinds.indexOf(barBlock.panelKind) >= 0)
                barBlock.closePanel()
        }
    }

    function kindWidth(k) {
        switch (k) {
        case "weather":   return BarLayout.panelW("weather")
        case "calendar":  return BarLayout.panelW("calendar")
        case "musicPoster": return 480
        case "musicDial": return 380
        case "musicSources": return 440
        case "musicBeads": return 540
        case "musicDevelop": return 460
        case "musicShape": return 440
        case "tray":      return 28 + barBlock.trayCols * 36 + (barBlock.trayCols - 1) * 6
        case "trayMenu":  return 260
        case "sound":     return 360
        case "soundscape": return 360
        case "scenes":    return 360
        case "network":   return 380
        case "bluetooth": return 380
        case "brightness": return 340
        case "powerMode": return 320
        case "battery":   return 400
        case "claudeCode": return 400
        case "cpu":       return 380
        case "memory":    return 380
        case "wiz":       return 380
        case "kindle":    return 400
        case "dashboard": return barBlock.itemOf("dashboard")?.inPage ? Math.min(barBlock.itemOf("dashboard").pageW, barBlock.widthRoom)
                                 : Math.min(BarLayout.panelW("dashboard"), barBlock.widthRoom)
        case "phoneStatus": return 400
        case "phoneNotifs": return 420
        case "phoneCall": return 400
        case "power":     return 360
        case "windowInfo": return 360
        case "notifPopup": return 380
        case "more":      return barBlock.itemOf("more") ? barBlock.itemOf("more").implicitWidth : 240
        case "notifications": return 400
        case "dockPreview": return barBlock.dockPreviewWidth
        case "dockMenu":  return 210
        case "clipboard": return Appearance.size.wallpaperPanelWidth
        case "wallpaper": return Math.min(ServiceWallpaper.panelWidth, barBlock.widthRoom)
        case "osd": {
            const n = Math.max(1, GlobalStates.osdKinds.length)
            return barBlock.vertical ? 16 + n * 44 + (n - 1) * 8 : 16 + n * (n > 1 ? 220 : 284) + (n - 1) * 8
        }
        case "launcher":  return BarLayout.panelW("launcher")
        }
        return 0
    }

    function contentHeight(k) {
        switch (k) {
        case "weather":   return BarLayout.panelHeightIn("weather",
                                                         barBlock.itemOf("weather") ? barBlock.itemOf("weather").implicitHeight : Appearance.size.weatherPanelHeight,
                                                         barBlock.heightCap("weather"))
        case "calendar":  return BarLayout.panelHeightIn("calendar", Appearance.size.calanderHeight, barBlock.heightRoom)
        case "musicPoster": return 300
        case "musicDial": return 410
        case "musicSources": return 340
        case "musicBeads": return 190
        case "musicDevelop": return 230
        case "musicShape": return 240
        case "tray":      return 28 + barBlock.trayRows * 36 + (barBlock.trayRows - 1) * 6
        case "trayMenu":  return barBlock.itemOf("trayMenu") ? barBlock.itemOf("trayMenu").implicitHeight : 160
        case "sound":     return barBlock.itemOf("sound") ? barBlock.itemOf("sound").implicitHeight : 420
        case "soundscape": return barBlock.itemOf("soundscape") ? barBlock.itemOf("soundscape").implicitHeight : 560
        case "scenes":    return barBlock.itemOf("scenes") ? barBlock.itemOf("scenes").implicitHeight : 420
        case "network":   return 600
        case "bluetooth": return 600
        case "brightness": return barBlock.itemOf("brightness") ? barBlock.itemOf("brightness").implicitHeight : 150
        case "powerMode": return barBlock.itemOf("powerMode") ? barBlock.itemOf("powerMode").implicitHeight + 28 : 316
        case "power":     return barBlock.itemOf("power") ? barBlock.itemOf("power").implicitHeight : 460
        case "windowInfo": return barBlock.itemOf("windowInfo") ? barBlock.itemOf("windowInfo").implicitHeight : 300
        case "notifPopup": return barBlock.itemOf("notifPopup") ? barBlock.itemOf("notifPopup").implicitHeight : 120
        case "more":      return barBlock.itemOf("more") ? barBlock.itemOf("more").implicitHeight : 120
        case "notifications": return barBlock.measured("notifications", 120)
        case "battery":   return barBlock.itemOf("battery") ? barBlock.itemOf("battery").implicitHeight : 520
        case "claudeCode": return barBlock.itemOf("claudeCode") ? barBlock.itemOf("claudeCode").implicitHeight : 480
        case "cpu":       return barBlock.itemOf("cpu") ? barBlock.itemOf("cpu").implicitHeight : 600
        case "memory":    return barBlock.itemOf("memory") ? barBlock.itemOf("memory").implicitHeight : 600
        case "wiz":       return barBlock.itemOf("wiz") ? barBlock.itemOf("wiz").implicitHeight : 640
        case "kindle":    return barBlock.itemOf("kindle") ? barBlock.itemOf("kindle").implicitHeight : 560
        case "dashboard": return barBlock.itemOf("dashboard")?.inPage ? Math.min(barBlock.itemOf("dashboard").pageH, barBlock.heightCap("dashboard"))
                                 : BarLayout.panelHeightIn("dashboard",
                                                           barBlock.itemOf("dashboard") ? barBlock.itemOf("dashboard").implicitHeight
                                                               : GlobalStates.dashboardHeight > 0 ? GlobalStates.dashboardHeight : 600,
                                                           barBlock.heightCap("dashboard"))
        case "phoneStatus": return barBlock.itemOf("phoneStatus") ? barBlock.itemOf("phoneStatus").implicitHeight : 260
        case "phoneNotifs": return barBlock.itemOf("phoneNotifs") ? barBlock.itemOf("phoneNotifs").implicitHeight : 300
        case "phoneCall": return barBlock.itemOf("phoneCall") ? barBlock.itemOf("phoneCall").implicitHeight : 300
        case "dockPreview": return barBlock.itemOf("dockPreview") ? barBlock.itemOf("dockPreview").implicitHeight : 90
        case "dockMenu":  return barBlock.itemOf("dockMenu") ? barBlock.itemOf("dockMenu").implicitHeight : 150
        case "clipboard": return Appearance.size.wallpaperPanelHeight
        case "wallpaper": return ServiceWallpaper.panelHeight
        case "osd":       return barBlock.vertical ? 280 : 64
        case "launcher":  return Math.max(320, Math.min(BarLayout.panelH("launcher"), barBlock.heightRoom))
        }
        return 0
    }

    readonly property bool closing: barBlock.panelKind === ""
    property bool motionClosing: true
    readonly property string animKind: barBlock.motionClosing ? barBlock.lastKind : barBlock.panelKind
    readonly property bool panelMotion: barBlock.animKind !== ""
    readonly property bool quickMotion: barBlock.panelMotion && barBlock.isTransient(barBlock.animKind)
    readonly property bool caeStyle: !barBlock.merged && !barBlock.floating && !barBlock.drawer
    readonly property bool caeMotion: barBlock.caeStyle && barBlock.panelMotion && !barBlock.quickMotion
    readonly property var caeCurve: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property int sizeDuration: barBlock.gliding ? M3Motion.spatialDuration("move")
        : barBlock.caeMotion ? 500
        : barBlock.drawer && barBlock.panelMotion ? M3Motion.spatialDuration("default")
        : barBlock.quickMotion ? (barBlock.motionClosing ? 240 : 380)
        : barBlock.panelMotion && !barBlock.motionClosing
        ? M3Motion.panel.openDuration : M3Motion.spatialDuration("fast")
    readonly property var sizeCurve: barBlock.gliding ? M3Motion.spatialCurve("move")
        : !barBlock.panelMotion ? M3Motion.spatialCurve("fast")
        : barBlock.caeMotion ? barBlock.caeCurve
        : barBlock.drawer ? M3Motion.spatialCurve("default")
        : barBlock.quickMotion ? (barBlock.motionClosing ? [0.3, 0.0, 1.0, 1.0, 1, 1] : [0.05, 0.7, 0.1, 1.0, 1, 1])
        : barBlock.motionClosing ? M3Motion.panel.closeCurve
        : M3Motion.panel.openCurve

    readonly property int spanDuration: barBlock.panelMotion && barBlock.motionClosing && !barBlock.quickMotion && !barBlock.drawer
        && !barBlock.caeMotion ? M3Motion.panel.closeDuration : barBlock.sizeDuration
    readonly property var spanCurve: barBlock.sizeCurve
    readonly property int dropDuration: barBlock.spanDuration
    readonly property var dropCurve: barBlock.sizeCurve

    readonly property real panelCorner: {
        const own = BarLayout.panelRadius(barBlock.shownKind !== "" ? barBlock.shownKind : barBlock.lastKind)
        return own >= 0 ? own : barBlock.frame ? barBlock.frame.disX : 0
    }
    readonly property real snapReach: barBlock.frame && barBlock.frame.tabPullFor
        ? barBlock.frame.tabPullFor(barBlock) : barBlock.panelCorner
    function snapInL(x) {
        return x > 0.5 && x < barBlock.snapReach && barBlock.absX >= barBlock.spanL - 0.5
    }
    function snapInR(r) {
        const g = barBlock.width - r
        return g > 0.5 && g < barBlock.snapReach && barBlock.absX + barBlock.width <= barBlock.spanR + 0.5
    }
    readonly property real tabNaturalW: barBlock.alongOf(barBlock.shownKind)
    function mergedSnap(x, w) {
        if (!barBlock.merged)
            return x
        const reach = barBlock.snapReach
        const sl = barBlock.spanL - barBlock.absX
        const sr = barBlock.spanR - barBlock.absX - w
        let s = x
        if (x < -0.5 && x > -reach)
            s = 0
        else if (x + w > barBlock.width + 0.5 && x + w < barBlock.width + reach)
            s = barBlock.width - w
        return s >= sl - 0.5 && s <= sr + 0.5 ? s : x
    }

    function isTransient(k) {
        return k === "osd" || k === "notifPopup"
    }

    readonly property var bodyMap: barBlock.frame && barBlock.frame.panelBodies ? barBlock.frame.panelBodies : ({})
    readonly property bool avoids: !barBlock.editMode && !!barBlock.frame && !!barBlock.frame.obstaclesFor
    readonly property var obstacles: barBlock.avoids
        ? barBlock.frame.obstaclesFor(barBlock.blockId, barBlock.bodyMap, barBlock.isTransient(barBlock.shownKind)) : []
    readonly property var transientObstacles: barBlock.avoids
        ? barBlock.frame.obstaclesFor(barBlock.blockId, barBlock.bodyMap, true) : []
    readonly property real panelGap: 16

    function avoidX(x, w, obs, loose) {
        if (!obs.length)
            return { x: x, ok: true, host: "" }
        const corner = barBlock.floating ? 0 : barBlock.panelCorner
        const sl = barBlock.spanL - barBlock.absX + barBlock.sideInset
        const sr = barBlock.spanR - barBlock.absX - w - barBlock.sideInset
        const minOverlap = loose ? -Infinity : Math.min(24, barBlock.width / 2)
        const fits = cx => {
            if (cx < sl - 0.5 || cx > sr + 0.5)
                return false
            const L = barBlock.snapInL(cx) ? 0 : cx
            const R = barBlock.snapInR(cx + w) ? barBlock.width : cx + w
            if (Math.min(R, barBlock.width) - Math.max(L, 0) < minOverlap)
                return false
            for (const o of obs) {
                const lo = o.l - barBlock.absX
                const ro = o.r - barBlock.absX
                if ((lo + ro) / 2 >= (L + R) / 2) {
                    const need = o.gap ?? barBlock.panelGap + (R < barBlock.width - 0.5 ? corner : 0) + (o.il ? corner : 0)
                    if (lo - R < need)
                        return false
                } else {
                    const need = o.gap ?? barBlock.panelGap + (L > 0.5 ? corner : 0) + (o.ir ? corner : 0)
                    if (L - ro < need)
                        return false
                }
            }
            return true
        }
        if (fits(x))
            return { x: x, ok: true, host: "" }
        const cands = []
        for (const o of obs) {
            const lo = o.l - barBlock.absX
            const ro = o.r - barBlock.absX
            const g = o.gap ?? barBlock.panelGap
            for (const extra of [0, corner, 2 * corner]) {
                cands.push(ro + g + extra)
                cands.push(lo - g - extra - w)
            }
        }
        cands.sort((a, b) => Math.abs(a - x) - Math.abs(b - x))
        for (const c of cands) {
            if (fits(c))
                return { x: c, ok: true, host: "" }
        }
        let host = ""
        let best = 0
        for (const o of obs) {
            if (o.transient)
                continue
            const ov = Math.min(x + w, o.r - barBlock.absX) - Math.max(x, o.l - barBlock.absX)
            if (host === "" || ov > best) {
                host = o.id
                best = ov
            }
        }
        return { x: x, ok: false, host: host }
    }

    readonly property real tabBaseX: {
        const w = barBlock.tabNaturalW
        const x = barBlock.mergedSnap(barBlock.alignX(w, barBlock.srcX + barBlock.srcW / 2), w)
        if (barBlock.obstacles.length === 0)
            return x
        return barBlock.avoidX(x, w, barBlock.obstacles).x
    }
    readonly property var crossObstacles: !barBlock.vertical && !barBlock.editMode && barBlock.shownKind !== ""
        && barBlock.frame && barBlock.frame.crossFor ? barBlock.frame.crossFor(barBlock) : []
    readonly property real pushShift: barBlock.frame && barBlock.frame.pushPlan ? (barBlock.frame.pushPlan.shift[barBlock.blockId] ?? 0) : 0
    readonly property real tabNaturalX: barBlock.tabPreX + barBlock.pushShift
    readonly property real tabPreX: barBlock.crossObstacles.length === 0 ? barBlock.tabBaseX
        : barBlock.avoidX(barBlock.tabBaseX, barBlock.tabNaturalW, barBlock.obstacles.concat(barBlock.crossObstacles), barBlock.floating).x

    function centerOfItem(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemId === id)
                return barBlock.pad + s.x + s.width / 2
        }
        return barBlock.width / 2
    }

    readonly property string transientWant: barBlock.popupWant ? "notifPopup" : barBlock.osdWant ? "osd" : ""
    readonly property string tuckHost: {
        const k = barBlock.transientWant
        if (k === "" || barBlock.transientObstacles.length === 0)
            return ""
        const w = barBlock.kindWidth(k)
        const cx = barBlock.centerOfItem(k === "osd" ? BarLayout.osdHostItem : BarLayout.popupHostItem)
        const x = barBlock.mergedSnap(barBlock.alignX(w, cx), w)
        const r = barBlock.avoidX(x, w, barBlock.transientObstacles)
        return r.ok ? "" : r.host
    }

    readonly property bool selfTuck: barBlock.transientWant !== "" && barBlock.shownKind !== ""
        && !barBlock.isTransient(barBlock.shownKind) && !barBlock.closing
    readonly property var tuckers: {
        if (barBlock.shownKind === "" || barBlock.closing)
            return []
        const out = barBlock.selfTuck ? [barBlock] : []
        if (barBlock.frame && barBlock.frame.visibleBlocks)
            for (const b of barBlock.frame.visibleBlocks)
                if (b !== barBlock && b.tuckHost === barBlock.blockId)
                    out.push(b)
        return out
    }
    readonly property bool tuckPopup: barBlock.tuckers.some(b => b.popupWant)
    readonly property bool tuckOsd: barBlock.tuckers.some(b => b.osdWant)
    readonly property real tuckH: !tuckRow.item ? 0 : barBlock.tuckPopup ? tuckRow.item.implicitHeight : 60
    property real tuckShown: barBlock.tuckH
    Behavior on tuckShown { SpatialAnim { speed: "fast" } }

    function syncBody() {
        if (!barBlock.frame || !barBlock.frame.setBody)
            return
        if (barBlock.shownKind === "" || barBlock.closing || barBlock.editMode) {
            barBlock.frame.clearBody(barBlock.blockId)
            return
        }
        const fil = !barBlock.floating
        barBlock.frame.setBody(barBlock.blockId, barBlock.absX + barBlock.tabTargetX,
                               barBlock.absX + barBlock.tabTargetX + barBlock.tabTargetW,
                               fil && barBlock.tabTargetX > 0.5,
                               fil && barBlock.tabTargetX + barBlock.tabTargetW < barBlock.width - 0.5,
                               barBlock.isTransient(barBlock.shownKind))
    }
    function queueSync() {
        Qt.callLater(barBlock.syncBody)
    }
    onTabTargetXChanged: {
        barBlock.queueSync()
        if (barBlock.shownKind !== "")
            barBlock.heldX = barBlock.tabTargetX
    }
    onTabTargetWChanged: {
        barBlock.queueSync()
        if (barBlock.shownKind !== "")
            barBlock.heldW = barBlock.tabTargetW
    }
    onAbsXChanged: barBlock.queueSync()
    onClosingChanged: barBlock.queueSync()
    Component.onDestruction: if (barBlock.frame && barBlock.frame.clearBody) barBlock.frame.clearBody(barBlock.blockId)
    readonly property real tabTargetW: {
        let l = barBlock.tabNaturalX
        let r = l + barBlock.tabNaturalW
        if (barBlock.snapInL(l))
            l = 0
        if (barBlock.snapInR(r))
            r = barBlock.width
        return r - l
    }
    readonly property real sideInset: barBlock.floating ? barBlock.panelGapSetting : 0

    function alignX(w, cx) {
        const x = cx - w / 2
        const sl = barBlock.spanL - barBlock.absX + barBlock.sideInset
        const sr = barBlock.spanR - barBlock.absX - w - barBlock.sideInset
        if (w <= barBlock.width) {
            const bl = Math.max(0, sl)
            const br = Math.min(barBlock.width - w, sr)
            if (bl <= br)
                return Math.max(bl, Math.min(br, x))
        }
        if (sr < sl)
            return Math.max(Math.min(sl, barBlock.spanF - barBlock.absX), sr)
        return Math.max(sl, Math.min(sr, x))
    }

    readonly property real tabTargetX: barBlock.snapInL(barBlock.tabNaturalX) ? 0 : barBlock.tabNaturalX
    readonly property real srcEdgeX: barBlock.snapInL(barBlock.srcX) ? 0 : barBlock.srcX
    readonly property real srcEdgeW: (barBlock.snapInR(barBlock.srcX + barBlock.srcW) ? barBlock.width : barBlock.srcX + barBlock.srcW)
        - barBlock.srcEdgeX

    property string revealMode: ""
    property real revealX: 0
    property real revealW: 0
    property real revealH: 0

    function revealFor(k) {
        const w = barBlock.alongOf(k)
        const x = barBlock.alignX(w, barBlock.srcX + barBlock.srcW / 2)
        const sl = barBlock.spanL - barBlock.absX
        const sr = barBlock.spanR - barBlock.absX
        const atStart = Math.abs(x - sl) <= 0.5
        const atEnd = Math.abs(x + w - sr) <= 0.5
        const farEdge = barBlock.acrossOf(k) >= barBlock.panelRoom - 1
        barBlock.revealX = x
        barBlock.revealW = w
        barBlock.revealH = barBlock.barH + barBlock.acrossOf(k)
        if (barBlock.isPill)
            return ""
        return atStart && atEnd ? "across" : farEdge && atStart ? "start" : farEdge && atEnd ? "end"
            : barBlock.drawer ? "across" : ""
    }

    readonly property bool drawer: barBlock.flatT > 0.5 && !barBlock.isPill && !barBlock.floating && !barBlock.merged

    property real heldX: 0
    property real heldW: 0
    property bool spanSnap: false
    property real handX: 0
    property real handW: 0
    property real handH: 0
    property bool gooSnap: false
    property int snapKick: 0
    property bool handHold: false
    property string handFor: ""
    property bool gliding: false
    property real closedAt: 0

    Timer {
        id: glideEnd
        interval: M3Motion.spatialDuration("move") + 60
        onTriggered: barBlock.gliding = false
    }

    function handoffSource() {
        const f = barBlock.frame
        if (!f || !f.visibleBlocks)
            return null
        const now = Date.now()
        for (const b of f.visibleBlocks) {
            if (b === barBlock || b.leaving || !b.tabOpen || b.panelKind !== "" || b.shownKind !== "")
                continue
            if (now - b.closedAt > 120)
                continue
            return b
        }
        return null
    }

    function tryHandoff() {
        const k = barBlock.handFor
        barBlock.handFor = ""
        if (k === "" || barBlock.shownKind !== k)
            return
        const src = barBlock.handoffSource()
        if (!src)
            return
        tabXAnim.stop()
        tabWAnim.stop()
        tabHAnim.stop()
        gooAnim.stop()
        barBlock.handX = src.absX + src.tabX - barBlock.absX
        barBlock.handW = src.tabW
        barBlock.handH = Math.max(barBlock.barH, src.tabHRaw)
        barBlock.gliding = true
        glideEnd.restart()
        barBlock.tabSnap = true
        barBlock.gooSnap = true
        barBlock.handHold = true
        barBlock.snapKick++
        barBlock.gooSnap = false
        barBlock.tabSnap = false
        barBlock.handHold = false
        src.snapShut()
    }

    function snapShut() {
        tabXAnim.stop()
        tabWAnim.stop()
        tabHAnim.stop()
        gooAnim.stop()
        barBlock.tabSnap = true
        barBlock.gooSnap = true
        barBlock.revealMode = ""
        barBlock.snapKick++
        barBlock.gooSnap = false
        barBlock.tabSnap = false
    }

    readonly property bool morphHold: barBlock.morphFloat && barBlock.shownKind === "" && barBlock.goo > 0.001 && barBlock.gooW > 0
    property real tabX: { barBlock.snapKick; return barBlock.handHold ? barBlock.handX
        : barBlock.shownKind !== "" ? barBlock.tabTargetX
        : barBlock.morphHold ? barBlock.gooX
        : barBlock.caeStyle && barBlock.revealMode === "" && barBlock.heldW > 0 ? barBlock.heldX
        : barBlock.revealMode === "" ? barBlock.srcEdgeX
        : barBlock.revealMode === "end" ? barBlock.revealX + barBlock.revealW : barBlock.revealX }
    property real tabW: { barBlock.snapKick; return barBlock.handHold ? barBlock.handW
        : barBlock.shownKind !== "" ? barBlock.tabTargetW
        : barBlock.morphHold ? barBlock.gooW
        : barBlock.caeStyle && barBlock.revealMode === "" && barBlock.heldW > 0 ? barBlock.heldW
        : barBlock.revealMode === "" ? barBlock.srcEdgeW
        : barBlock.revealMode === "across" ? barBlock.revealW : 0 }
    property bool heightFollow: false
    property bool followLock: false
    property real followAcross: 0
    property real followVel: 0
    property real followSeen: 0
    property real followMoved: 0
    property bool followRun: false
    onLiveAcrossChanged: {
        if (!barBlock.heightFollow)
            return
        barBlock.followRun = true
        barBlock.rememberHeight()
    }
    readonly property real liveAcross: barBlock.shownKind !== "" ? barBlock.acrossOf(barBlock.shownKind) + barBlock.tuckShown : 0

    function startFollow() {
        if (barBlock.heightFollow || barBlock.shownKind === "" || barBlock.closing)
            return
        barBlock.followLock = true
        barBlock.followAcross = barBlock.liveAcross
        barBlock.followSeen = barBlock.liveAcross
        barBlock.followMoved = 0
        barBlock.followVel = 0
        barBlock.followRun = false
        barBlock.heightFollow = true
        barBlock.rememberHeight()
    }

    readonly property var memoKinds: ["notifications"]
    property var heightMemo: ({})

    function measured(k, fallback) {
        const it = barBlock.itemOf(k)
        if (barBlock.memoKinds.indexOf(k) >= 0 && !(barBlock.heightFollow && barBlock.shownKind === k)) {
            const m = barBlock.heightMemo[k]
            if (m !== undefined)
                return m
        }
        return it ? it.implicitHeight : fallback
    }

    function rememberHeight() {
        const k = barBlock.shownKind
        if (!barBlock.heightFollow || barBlock.memoKinds.indexOf(k) < 0)
            return
        const it = barBlock.itemOf(k)
        if (!it || barBlock.heightMemo[k] === it.implicitHeight)
            return
        const m = Object.assign({}, barBlock.heightMemo)
        m[k] = it.implicitHeight
        barBlock.heightMemo = m
    }

    function stopFollow() {
        if (!barBlock.heightFollow)
            return
        barBlock.followLock = false
        barBlock.followRun = false
        barBlock.heightFollow = false
    }

    FrameAnimation {
        running: barBlock.heightFollow && barBlock.followRun
        onTriggered: {
            const live = barBlock.liveAcross
            const step = live - barBlock.followSeen
            const now = Date.now()
            const moving = now - barBlock.followMoved < 120
            barBlock.followSeen = live
            if (Math.abs(step) > 120 && !moving && Math.abs(barBlock.followVel) < 2) {
                barBlock.stopFollow()
                return
            }
            let x = barBlock.followAcross
            let v = barBlock.followVel
            if (Math.abs(step) > 0.01) {
                if (Math.abs(step) <= 6 || (moving && Math.abs(step) <= 120))
                    x += step
                barBlock.followMoved = now
            }
            const w = 22
            const n = 3
            const dt = Math.min(frameTime, 1 / 30) / n
            for (let i = 0; i < n; i++) {
                v += (w * w * (live - x) - 2 * w * v) * dt
                x += v * dt
            }
            if (Math.abs(live - x) < 0.25 && Math.abs(v) < 2) {
                x = live
                v = 0
            }
            barBlock.followVel = v
            if (x !== barBlock.followAcross)
                barBlock.followAcross = x
            if (x === live && v === 0 && Math.abs(step) <= 0.01)
                barBlock.followRun = false
        }
    }

    readonly property real tabH: Math.max(barBlock.barH, barBlock.tabHRaw)
    property real tabHRaw: { barBlock.snapKick; return barBlock.handHold ? barBlock.handH
        : barBlock.shownKind !== "" ? barBlock.barH + (barBlock.heightFollow ? barBlock.followAcross : barBlock.acrossOf(barBlock.shownKind) + barBlock.tuckShown)
        : barBlock.morphHold ? barBlock.barH + barBlock.gooH
        : barBlock.revealMode === "start" || barBlock.revealMode === "end" ? barBlock.revealH : barBlock.barH }
    readonly property bool morphSnap: barBlock.morphFloat && (barBlock.goo < 0.999 || barBlock.shownKind === "")
    Behavior on tabX {
        enabled: !barBlock.tabSnap && !barBlock.spanSnap && !barBlock.resizing && !barBlock.morphSnap
        NumberAnimation {
            id: tabXAnim
            duration: barBlock.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: barBlock.spanCurve
            onRunningChanged: if (!running) barBlock.checkSettled()
        }
    }
    Behavior on tabW {
        enabled: !barBlock.tabSnap && !barBlock.spanSnap && !barBlock.resizing && !barBlock.morphSnap
        NumberAnimation {
            id: tabWAnim
            duration: barBlock.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: barBlock.spanCurve
            onRunningChanged: if (!running) barBlock.checkSettled()
        }
    }
    Behavior on tabHRaw {
        enabled: !barBlock.tabSnap && !barBlock.resizing && !barBlock.followLock && !barBlock.morphSnap
        NumberAnimation {
            id: tabHAnim
            duration: barBlock.dropDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: barBlock.dropCurve
            onRunningChanged: if (!running) barBlock.checkSettled()
        }
    }
    readonly property bool tabMoving: tabXAnim.running || tabWAnim.running || tabHAnim.running
    readonly property bool tabOpen: barBlock.shownKind !== "" || barBlock.tabH > barBlock.barH + 0.5
        || (barBlock.floating && barBlock.goo > 0.001)

    readonly property real tabPathH: barBlock.tabH + (barBlock.merged ? barBlock.floatGap : 0)

    function slotShift(listIndex) {
        const e = barBlock.editor
        if (!e || e.mode !== "item" || listIndex < 0)
            return 0
        const g = e.dragW + barBlock.gap
        const src = e.fromBlock === barBlock.blockId
        const tgt = e.dropBlock === barBlock.blockId && !e.overDrawer
        if (src && listIndex === e.fromIndex)
            return 0
        let s = 0
        let j = listIndex
        if (src && listIndex > e.fromIndex) {
            s -= g
            j = listIndex - 1
        }
        if (tgt && j >= e.dropIndex)
            s += g
        return s
    }

    readonly property real dragExtra: {
        const e = barBlock.editor
        if (!e || e.mode !== "item")
            return 0
        const g = e.dragW + barBlock.gap
        return (e.dropBlock === barBlock.blockId && !e.overDrawer ? g : 0)
             - (e.fromBlock === barBlock.blockId ? g : 0)
    }

    function appGeom() {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || s.leaving || BarLayout.baseId(s.itemId) !== "dockApps" || !s.loaderItem)
                continue
            const it = s.loaderItem
            const base = barBlock.absX + barBlock.pad + s.x + s.contentStart
            return {
                x: base,
                w: s.contentWidth,
                apps: it.appRects.map(r => ({ appId: r.appId, pinned: r.pinned, x: base + r.x, w: r.w }))
            }
        }
        return null
    }

    function slotUnder(localX) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || !s.visible || s.leaving)
                continue
            const left = barBlock.pad + s.x
            if (localX >= left - barBlock.gap / 2 && localX <= left + s.width + barBlock.gap / 2)
                return s
        }
        return null
    }

    function itemSpans() {
        const out = []
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || s.leaving || !s.itemShown || s.width < 1)
                continue
            out.push({ l: barBlock.pad + s.x, r: barBlock.pad + s.x + s.width })
        }
        return out.sort((a, b) => a.l - b.l)
    }

    function dropIndexAt(localX) {
        const e = barBlock.editor
        const src = e.fromBlock === barBlock.blockId
        const g = e.dragW + barBlock.gap
        let n = 0
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (!s || s.leaving || s.listIndex < 0)
                continue
            if (src && s.listIndex === e.fromIndex)
                continue
            const shift = (src && s.listIndex > e.fromIndex) ? -g : 0
            if (barBlock.pad + s.x + shift + s.width / 2 < localX)
                n++
        }
        return n
    }

    function slotGone(id) {
        Qt.callLater(() => {
            BarLayout.dropLeaving(itemModel, barBlock.itemIds, "itemId", barBlock.itemLeaving, id)
            barBlock.slotRev++
        })
    }

    property int slotRev: 0

    readonly property var slotLayout: {
        barBlock.slotRev
        const xs = []
        let x = 0
        let before = 0
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k)
            const pc = o ? Math.min(1, o.pc) : 0
            x += barBlock.gap * Math.min(pc, before)
            xs.push(x)
            x += o ? o.width : 0
            before = Math.max(before, pc)
        }
        return { xs: xs, total: x }
    }

    readonly property int shownCount: {
        let n = 0
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemShown)
                n++
        }
        return n
    }

    readonly property real fixedWidth: {
        let w = barBlock.pad + barBlock.padR
        let before = 0
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k)
            if (!o)
                continue
            const pc = Math.min(1, o.pc)
            w += barBlock.gap * Math.min(pc, before)
            before = Math.max(before, pc)
            w += o.flexible ? (o.fixedPart + o.margin[0] + o.margin[1]) * pc : o.width
        }
        return w
    }

    readonly property string spotlitItem: {
        if (!barBlock.editing || !barBlock.editor)
            return ""
        const sel = barBlock.editor.selectedItem
        return (sel === "" || sel.indexOf("dash:") === 0 || !BarLayout.entry(sel) || !BarLayout.isPlaced(sel)) ? "" : sel
    }

    readonly property bool emptyInEdit: barBlock.editing && barBlock.itemIds.length === 0
    readonly property real naturalWidth: barBlock.emptyInEdit
        ? 96 + Math.max(0, barBlock.dragExtra)
        : barBlock.slotLayout.total + barBlock.pad + barBlock.padR + barBlock.dragExtra
    readonly property real collapsedWidth: barBlock.maxWidth > 0
        ? Math.min(barBlock.naturalWidth, Math.max(barBlock.maxWidth, barBlock.fixedWidth))
        : barBlock.naturalWidth

    readonly property bool isDropTarget: !!barBlock.editor && (barBlock.editor.mode === "item"
        && barBlock.editor.dropBlock === barBlock.blockId && !barBlock.editor.overDrawer
        || barBlock.editor.mode === "block" && barBlock.editor.joinTarget === barBlock.blockId)
    readonly property bool isDraggedBlock: !!barBlock.editor && barBlock.editor.mode === "block"
        && barBlock.editor.fromBlock === barBlock.blockId

    readonly property bool wantedBase: !barBlock.leaving && SettingsConfig.settingsReady
        && (barBlock.editMode || barBlock.panelKind !== "" || barBlock.shownCount > 0)
    readonly property bool folded: !!barBlock.frame && !!barBlock.frame.foldIds
        && barBlock.frame.foldIds.indexOf(barBlock.blockId) >= 0
    readonly property bool wanted: barBlock.wantedBase && !barBlock.folded
    property real presence: 0
    readonly property real pc: Math.max(0, barBlock.presence)
    Behavior on presence {
        enabled: BarLayout.settled
        SpatialAnim { speed: "default" }
    }

    visible: barBlock.pc > 0.001
    z: editLayer.item && editLayer.item.gripHovered ? 1 : 0
    width: barBlock.implicitWidth * barBlock.pc
    implicitWidth: barBlock.collapsedWidth
    implicitHeight: barBlock.barH
    readonly property bool tuckedAway: barBlock.frame && barBlock.frame.pushPlan ? !!barBlock.frame.pushPlan.hide[barBlock.blockId] : false
    property real tuckAwayT: barBlock.tuckedAway ? 1 : 0
    Behavior on tuckAwayT { EffectsAnim { speed: "fast" } }
    enabled: !barBlock.tuckedAway
    opacity: (barBlock.isDraggedBlock ? 0.35 : 1) * Math.min(1, barBlock.pc) * barBlock.hideT * (1 - barBlock.tuckAwayT)

    Behavior on implicitWidth {
        enabled: BarLayout.settled
        NumberAnimation {
            duration: M3Motion.spatialDuration("fast")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
        }
    }

    onPresenceChanged: if (barBlock.leaving && barBlock.presence <= 0.001) barBlock.gone()

    onPanelKindChanged: {
        const k = barBlock.panelKind
        if (k === "" && barBlock.shownKind !== "")
            barBlock.closedAt = Date.now()
        const opening = k !== "" && !barBlock.tabOpen
        barBlock.motionClosing = k === ""
        if (k === "launcher" && (ServiceLauncher.position === "block" || barBlock.tabH <= barBlock.barH + 0.5)) {
            barBlock.resyncSource()
            barBlock.openerId = ""
        } else if (barBlock.previewHost && k === GlobalStates.panelPreview) {
            const opener = barBlock.itemFor(barBlock.previewOpener(k))
            if (barBlock.tabH <= barBlock.barH + 0.5) {
                barBlock.snapSource(opener, k)
            } else {
                barBlock.sourceFrom(opener)
                barBlock.flushSource(k)
            }
            barBlock.openerId = ""
        } else if (k === "notifPopup" && barBlock.tabH <= barBlock.barH + 0.5) {
            barBlock.tabSnap = true
            barBlock.anchorSource(BarLayout.popupHostItem, k)
            barBlock.tabSnap = false
            barBlock.openerId = ""
        } else if (k === "osd" && barBlock.osdHost) {
            barBlock.resyncSource()
            barBlock.openerId = ""
        } else if (barBlock.isSys(k) && barBlock.tabH <= barBlock.barH + 0.5) {
            barBlock.snapSource(BarLayout.panelItemHost(k) && barBlock.hasItem(k) ? barBlock.itemFor(k) : null, k)
            barBlock.openerId = ""
        }
        if (k !== "" && !barBlock.tabOpen) {
            const mode = barBlock.revealFor(k)
            barBlock.tabSnap = true
            barBlock.revealMode = mode
            barBlock.tabSnap = false
        } else if (k !== "") {
            barBlock.revealMode = ""
        } else if (barBlock.drawer && barBlock.revealMode !== "start" && barBlock.revealMode !== "end") {
            barBlock.tabSnap = true
            barBlock.revealX = barBlock.tabX
            barBlock.revealW = barBlock.tabW
            barBlock.revealMode = "across"
            barBlock.tabSnap = false
        }
        if (k !== "")
            barBlock.lastKind = k
        barBlock.stopFollow()
        barBlock.panelSwap = k !== "" && barBlock.shownKind !== ""
        const caeOpen = k !== "" && barBlock.caeStyle && !barBlock.tabOpen
        if (caeOpen)
            barBlock.spanSnap = true
        barBlock.shownKind = k
        barBlock.spanSnap = false
        barBlock.showContent(k)
        if (opening) {
            barBlock.handFor = k
            Qt.callLater(barBlock.tryHandoff)
        }
    }

    function itemOf(k) {
        if (slotA.kind === k && slotA.item)
            return slotA.item
        if (slotB.kind === k && slotB.item)
            return slotB.item
        return null
    }

    property string residentKind: ""
    property bool panelSwap: false
    readonly property var warmKinds: ["calendar", "weather"]

    function preload(k) {
        if (k === "" || barBlock.editMode || barBlock.kindWidth(k) <= 0 || slotA.kind === k || slotB.kind === k)
            return
        const cur = barBlock.curSlot === 0 ? slotA : slotB
        const other = barBlock.curSlot === 0 ? slotB : slotA
        const idle = s => !s.shown && s.opacity < 0.02
        const target = idle(other) ? other : idle(cur) ? cur : null
        if (target)
            target.kind = k
    }

    Timer {
        interval: 6000
        running: true
        onTriggered: {
            if (!layout.isPrimary || !barBlock.visible || barBlock.width <= 0)
                return
            if (barBlock.osdHost) {
                barBlock.residentKind = "osd"
                barBlock.preload("osd")
                return
            }
            const ids = barBlock.itemIds ?? []
            for (let i = 0; i < ids.length; i++) {
                const k = BarLayout.panelFor(ids[i])
                if (barBlock.warmKinds.indexOf(k) >= 0) {
                    barBlock.residentKind = k
                    barBlock.preload(k)
                    return
                }
            }
        }
    }

    function showContent(k) {
        if (k !== "")
            barBlock.residentKind = k
        const cur = barBlock.curSlot === 0 ? slotA : slotB
        const other = barBlock.curSlot === 0 ? slotB : slotA
        if (k === "") {
            cur.shown = false
            other.shown = false
            return
        }
        if (cur.kind === k) {
            cur.shown = true
            other.shown = false
            return
        }
        if (other.kind === k) {
            other.shown = true
            cur.shown = false
            barBlock.curSlot = 1 - barBlock.curSlot
            return
        }
        if (cur.kind === "" || (!cur.shown && cur.opacity < 0.02)) {
            cur.kind = k
            cur.shown = true
            other.shown = false
            return
        }
        other.kind = k
        other.shown = true
        cur.shown = false
        barBlock.curSlot = 1 - barBlock.curSlot
    }


    onEditModeChanged: {
        barBlock.pendingKind = ""
        barBlock.clickedKind = ""
        barBlock.hoverKind = ""
        if (barBlock.editMode)
            barBlock.lastKind = ""
    }

    property string dockAppId: ""
    readonly property var dockAppEntry: {
        if (barBlock.dockAppId === "")
            return null
        const want = barBlock.dockAppId.toLowerCase()
        return ServiceApps.dockModel.find(e => (e.appId ?? "").toLowerCase() === want) ?? null
    }
    readonly property int dockWinCount: barBlock.dockAppEntry ? barBlock.dockAppEntry.toplevels.length : 0
    readonly property real dockPreviewCap: barBlock.vertical ? Math.min(300, barBlock.widthRoom)
        : Math.min(Math.max(barBlock.width, 236), barBlock.widthRoom)
    readonly property real dockPreviewWidth: Math.min(300, barBlock.dockPreviewCap)

    onDockAppEntryChanged: barBlock.checkDockApp()
    onDockWinCountChanged: barBlock.checkDockApp()

    function checkDockApp() {
        if (barBlock.panelKind === "dockMenu" && !barBlock.dockAppEntry)
            barBlock.closePanel()
        else if (barBlock.panelKind === "dockPreview" && barBlock.dockWinCount === 0)
            barBlock.hoverKind = ""
    }

    function appEntered(entry, item) {
        if (barBlock.editing || !entry)
            return
        dockLeaveTimer.stop()
        if (barBlock.panelKind === "dockMenu" || barBlock.clickedKind !== "")
            return
        if (entry.toplevels.length === 0) {
            if (barBlock.panelKind === "dockPreview")
                barBlock.hoverKind = ""
            return
        }
        barBlock.dockAppId = entry.appId ?? ""
        if (barBlock.panelKind === "dockPreview") {
            barBlock.sourceFrom(item)
            barBlock.hoverKind = "dockPreview"
            return
        }
        barBlock.hoverOpen("dockPreview", item)
    }

    function appExited() {
        if (barBlock.panelKind === "dockPreview")
            dockLeaveTimer.restart()
    }

    function appMenu(entry, item) {
        if (barBlock.editing || !entry)
            return
        dockLeaveTimer.stop()
        if (barBlock.panelKind === "dockMenu" && barBlock.dockAppId === (entry.appId ?? "")) {
            barBlock.closePanel()
            return
        }
        barBlock.dockAppId = entry.appId ?? ""
        if (barBlock.panelKind === "dockPreview" || barBlock.panelKind === "dockMenu") {
            barBlock.sourceFrom(item)
            barBlock.clickedKind = "dockMenu"
            return
        }
        barBlock.beginOpen("dockMenu", item, true)
    }

    Timer {
        id: dockLeaveTimer
        interval: 140
        onTriggered: {
            if (barBlock.panelKind === "dockPreview" && !tabHover.hovered)
                barBlock.hoverKind = ""
        }
    }

    ListModel { id: itemModel }

    onItemIdsChanged: {
        BarLayout.syncAnimated(itemModel, barBlock.itemIds, "itemId", barBlock.itemLeaving)
        barBlock.slotRev++
    }

    Component.onCompleted: {
        barBlock.lastInfo = barBlock.liveInfo
        BarLayout.syncModel(itemModel, barBlock.itemIds, "itemId", barBlock.itemLeaving)
        barBlock.slotRev++
        barBlock.presence = Qt.binding(() => barBlock.wanted ? 1 : 0)
    }

    HoverHandler {
        id: blockHover
        onHoveredChanged: if (!hovered && !tabHover.hovered) barBlock.hoverKind = ""
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !barBlock.editMode && !barBlock.leaving && barBlock.panelKind === "" && layout.isPrimary
        visible: enabled
        acceptedButtons: Qt.RightButton
        onClicked: GlobalStates.openEdit("edges")
    }


    Item {
        id: tabHost
        x: Math.round(barBlock.absX + barBlock.tabX) - barBlock.absX
        y: barBlock.far ? barBlock.barH - Math.round(barBlock.tabH) - barBlock.floatGap : 0
        width: Math.round(barBlock.absX + barBlock.tabX + barBlock.tabW) - Math.round(barBlock.absX + barBlock.tabX)
        height: Math.round(barBlock.tabH) + barBlock.floatGap
        visible: barBlock.tabOpen
        clip: true

        HoverHandler {
            id: tabHover
            onHoveredChanged: if (!hovered && !blockHover.hovered) barBlock.hoverKind = ""
        }

        Item {
            id: panelClip
            readonly property real areaY: barBlock.far ? 0 : barBlock.barH + barBlock.floatGap
            readonly property real areaH: Math.max(0, tabHost.height - barBlock.barH - barBlock.floatGap)
            readonly property bool morphing: barBlock.morphFloat && barBlock.goo < 0.999
            readonly property var box: {
                if (!panelClip.morphing)
                    return null
                const g = barBlock.gooShape
                const by = barBlock.far ? barBlock.barH - g.y - g.h : g.y
                const x0 = Math.max(0, g.x - tabHost.x), x1 = Math.min(tabHost.width, g.x + g.w - tabHost.x)
                const y0 = Math.max(panelClip.areaY, by - tabHost.y), y1 = Math.min(panelClip.areaY + panelClip.areaH, by + g.h - tabHost.y)
                return { x: x0, y: y0, w: Math.max(0, x1 - x0), h: Math.max(0, y1 - y0) }
            }
            readonly property real morphS: panelClip.box ? panelClip.box.w / Math.max(1, tabHost.width) : 1
            readonly property real areaTop: panelClip.areaY - panelClip.y
            function morphShift(sx, sy) {
                const tx = panelClip.morphS * (sx + panelClip.x) - sx
                const ty = barBlock.far ? panelClip.height - panelClip.morphS * (panelClip.areaTop + panelClip.areaH - sy) - sy
                                        : panelClip.morphS * (sy - panelClip.areaTop) - sy
                return Qt.point(tx, ty)
            }
            x: panelClip.box ? panelClip.box.x : 0
            y: panelClip.box ? panelClip.box.y : panelClip.areaY
            opacity: barBlock.contentT
            width: panelClip.box ? panelClip.box.w : tabHost.width
            height: panelClip.box ? panelClip.box.h : panelClip.areaH
            clip: true
            layer.enabled: (barBlock.tabMoving || panelClip.morphing) && barBlock.panelCorner > 0
            layer.smooth: true
            layer.effect: GE.OpacityMask { maskSource: panelCornerMask }

            PanelSlot { id: slotA }
            PanelSlot { id: slotB }

            Loader {
                id: tuckRow
                active: barBlock.tuckPopup || barBlock.tuckOsd
                x: barBlock.tuckPopup ? 0 : 12
                width: barBlock.tuckPopup ? panelClip.width : panelClip.width - 24
                y: barBlock.far ? panelClip.height - barBlock.tuckShown + (barBlock.tuckPopup ? 0 : 12)
                                : (barBlock.tuckPopup ? 0 : 12) - (barBlock.tuckH - barBlock.tuckShown)
                opacity: barBlock.tuckH > 0 ? Math.max(0, Math.min(1, barBlock.tuckShown / barBlock.tuckH)) : 0
                sourceComponent: barBlock.tuckPopup ? panels.tuckPopup : panels.tuckOsd
            }
        }

        Rectangle {
            id: panelCornerMask
            readonly property real r: Math.min(barBlock.panelCorner, width / 2, height / 2)
            visible: false
            width: panelClip.width
            height: panelClip.height
            color: "white"
            topLeftRadius: barBlock.far || barBlock.floating || barBlock.merged ? panelCornerMask.r : 0
            topRightRadius: barBlock.far || barBlock.floating || barBlock.merged ? panelCornerMask.r : 0
            bottomLeftRadius: barBlock.far && !barBlock.floating && !barBlock.merged ? 0 : panelCornerMask.r
            bottomRightRadius: barBlock.far && !barBlock.floating && !barBlock.merged ? 0 : panelCornerMask.r
        }

    }

    property bool resizing: false
    property string resizeKind: ""
    readonly property string sizeKind: !barBlock.editing ? ""
        : barBlock.launchHost && GlobalStates.launcherPreview && barBlock.shownKind === "launcher" ? "launcher"
        : barBlock.previewHost && barBlock.shownKind === GlobalStates.panelPreview && !!BarLayout.panelSpecs[barBlock.shownKind]
          && !BarLayout.panelSpecs[barBlock.shownKind].fitOnly
        ? barBlock.shownKind : ""
    readonly property bool sizeHandles: barBlock.sizeKind !== "" && (barBlock.resizing
        || (!tabXAnim.running && !tabWAnim.running && !tabHAnim.running))
    readonly property real tabContentTop: barBlock.far ? barBlock.barH - barBlock.tabH - barBlock.floatGap : barBlock.barH + barBlock.floatGap
    readonly property real tabContentH: Math.max(0, barBlock.tabH - barBlock.barH)
    readonly property bool flushL: Math.abs(barBlock.tabX - (barBlock.spanL - barBlock.absX)) <= 0.5
    readonly property bool flushR: Math.abs(barBlock.tabX + barBlock.tabW - (barBlock.spanR - barBlock.absX)) <= 0.5

    function heightCap(k) {
        const it = barBlock.itemOf(k)
        return it && it.maxContentH !== undefined ? Math.min(barBlock.heightRoom, it.maxContentH) : barBlock.heightRoom
    }

    function beginResize() {
        const k = barBlock.sizeKind
        barBlock.resizing = true
        barBlock.resizeKind = k
        BarLayout.setDraft(k, BarLayout.panelW(k), Math.round(barBlock.contentHeight(k)))
    }

    function updateResize(w, h) {
        const k = barBlock.resizeKind
        const d = BarLayout.draftOf(k)
        if (!d)
            return
        BarLayout.setDraft(k, w === undefined ? d.w : BarLayout.clampPanelW(k, w),
                           h === undefined ? d.h : Math.min(barBlock.heightCap(k), BarLayout.clampPanelH(k, Math.max(0, h))))
    }

    function endResize() {
        const k = barBlock.resizeKind
        const d = BarLayout.draftOf(k)
        barBlock.resizing = false
        if (d)
            BarLayout.setPanelSize(k, d.w, d.h)
    }

    component ResizeHandle: MouseArea {
        id: handle
        property string side: "left"
        readonly property bool vertical: handle.side === "left" || handle.side === "right"
        property real startW: 0
        property real anchorX: 0
        property bool centred: true

        z: 60
        width: handle.vertical ? 16 : 72
        height: handle.vertical ? 72 : 16
        hoverEnabled: true
        preventStealing: true
        cursorShape: handle.vertical !== barBlock.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor

        onPressed: mouse => {
            barBlock.beginResize()
            handle.centred = !barBlock.flushL && !barBlock.flushR
            handle.anchorX = handle.centred ? barBlock.tabX + barBlock.tabW / 2
                : barBlock.flushR ? barBlock.tabX + barBlock.tabW : barBlock.tabX
        }
        onPositionChanged: mouse => {
            if (!handle.pressed)
                return
            const p = handle.mapToItem(barBlock, mouse.x, mouse.y)
            if (handle.vertical) {
                const d = Math.abs(p.x - handle.anchorX)
                const along = handle.centred ? d * 2 : d
                if (barBlock.vertical)
                    barBlock.updateResize(undefined, along)
                else
                    barBlock.updateResize(along, undefined)
            } else {
                const across = barBlock.far ? -p.y : p.y - barBlock.barH
                if (barBlock.vertical)
                    barBlock.updateResize(across, undefined)
                else
                    barBlock.updateResize(undefined, across)
            }
        }
        onReleased: barBlock.endResize()
        onCanceled: barBlock.endResize()

        Rectangle {
            anchors.centerIn: parent
            width: handle.vertical ? 5 : (handle.containsMouse || handle.pressed ? 56 : 44)
            height: handle.vertical ? (handle.containsMouse || handle.pressed ? 56 : 44) : 5
            radius: 2.5
            color: handle.pressed ? Colors.primary : handle.containsMouse ? Qt.alpha(Colors.primary, 0.85)
                                                                          : Qt.alpha(Colors.outline, 0.9)
            Behavior on width { SpatialAnim { speed: "fast" } }
            Behavior on height { SpatialAnim { speed: "fast" } }
            Behavior on color { EffectsColorAnim {} }
        }
    }

    Item {
        id: sizeChrome
        z: 45
        visible: barBlock.sizeHandles
        opacity: barBlock.sizeHandles ? 1 : 0
        x: barBlock.tabX
        y: barBlock.tabContentTop
        width: barBlock.tabW
        height: barBlock.tabContentH

        ResizeHandle {
            side: "left"
            visible: !barBlock.flushL
            x: 0
            anchors.verticalCenter: parent.verticalCenter
        }
        ResizeHandle {
            side: "right"
            visible: !barBlock.flushR
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
        }
        ResizeHandle {
            side: barBlock.far ? "top" : "bottom"
            anchors.horizontalCenter: parent.horizontalCenter
            y: barBlock.far ? 0 : parent.height - height
        }

        Rectangle {
            id: sizeBubble
            visible: barBlock.resizing
            anchors.centerIn: parent
            width: sizeLabel.implicitWidth + 24
            height: 32
            radius: 16
            color: Colors.inverseSurface
            transform: barBlock.vertical ? [sizeFlip] : []

            Matrix4x4 { id: sizeFlip; matrix: barBlock.flipAbout(sizeBubble.width, sizeBubble.height) }

            CustomText {
                id: sizeLabel
                anchors.centerIn: parent
                readonly property var draft: BarLayout.draftOf(barBlock.resizeKind)
                content: draft ? draft.w + " × " + Math.round(draft.h) : ""
                size: 13
                weight: 700
                customColor: Colors.inverseSurfaceText
                font.features: { "tnum": 1 }
            }
        }
    }

    Item {
        id: rowClip
        y: (barBlock.far ? -barBlock.lineUp : barBlock.lineUp) / 2
        width: barBlock.width
        height: barBlock.barH
        clip: !barBlock.split

        Rectangle {
            x: 2
            y: 4
            width: Math.max(0, rowClip.width - 4)
            height: Math.max(0, barBlock.barH - 8)
            radius: barBlock.isPill ? Math.min(height / 2, Math.max(0, barBlock.pillRadius - 4)) : height / 2
            color: Qt.alpha(BarLayout.roleColor(barBlock.tintRole === "none" ? "primary" : barBlock.tintRole), 0.18)
            opacity: barBlock.tintShown ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                EffectsAnim { speed: "fast" }
            }
        }

        Item {
            id: row
            x: barBlock.pad
            width: barBlock.slotLayout.total
            height: barBlock.barH

            Repeater {
                id: rep
                model: itemModel

                delegate: Item {
                    id: slot

                    required property string itemId
                    required property int index
                    required property bool leaving

                    readonly property Item loaderItem: loader.item
                    readonly property var entry: BarLayout.entry(slot.itemId)
                    readonly property bool loaded: loader.status === Loader.Ready && loader.item !== null
                    readonly property bool itemShown: slot.loaded && loader.item.shown
                    readonly property bool ghost: barBlock.editing && !slot.itemShown
                    readonly property bool anchorPin: !!slot.entry && slot.entry.anchor === true
                    readonly property bool flexible: slot.loaded && (loader.item.flexible ?? false)
                    readonly property real fixedPart: slot.loaded ? (loader.item.fixedPart ?? 0) : 0
                    readonly property int listIndex: slot.leaving ? -1 : barBlock.itemIds.indexOf(slot.itemId)
                    readonly property bool dragged: slot.listIndex >= 0 && !!barBlock.editor
                        && barBlock.editor.mode === "item" && barBlock.editor.fromBlock === barBlock.blockId
                        && barBlock.editor.fromIndex === slot.listIndex
                    readonly property var margin: BarLayout.marginsFor(slot.itemId)
                    readonly property string tintRole: BarLayout.itemStyle(slot.itemId, "tint", "none")
                    readonly property bool tinted: slot.tintRole !== "none"
                    readonly property real chipRadius: BarLayout.itemStyle(slot.itemId, "radius", -1)
                    readonly property real rawW: slot.loaded ? loader.item.implicitWidth : 0
                    readonly property real rawH: slot.loaded ? loader.item.implicitHeight : 0
                    readonly property bool turns: slot.loaded && loader.item.rotatesWithBar === true
                    readonly property bool upright: barBlock.vertical && slot.loaded && !slot.turns
                        && (loader.item.verticalReady === true || slot.rawW <= barBlock.barH - 4)
                    readonly property bool sideways: barBlock.vertical && slot.loaded && !slot.turns && !slot.upright
                    readonly property bool fullForm: barBlock.vertical && slot.loaded && loader.item.verticalReady !== true
                    function noteFull() {
                        if (barBlock && slot.fullForm)
                            barBlock.noteFull(slot.itemId, slot.rawW)
                    }
                    onRawWChanged: if (slot.fullForm) Qt.callLater(slot.noteFull)
                    onFullFormChanged: if (slot.fullForm) Qt.callLater(slot.noteFull)
                    readonly property real contentWidth: slot.ghost ? 28 : (slot.upright ? slot.rawH : slot.rawW)
                    readonly property real contentStart: slot.margin[0] + (slot.innerWidth - slot.contentWidth) / 2
                    readonly property real chipWidth: barBlock.split
                        ? BarLayout.plateW(slot.itemId, slot.contentWidth, slot.contentHeight, barBlock.barH)
                        : BarLayout.chipW(slot.itemId, slot.contentWidth, slot.contentHeight, barBlock.barH)
                    readonly property real chipHeight: BarLayout.chipH(slot.itemId, slot.contentHeight,
                                                                       barBlock.barH, slot.contentWidth)
                    readonly property real contentHeight: slot.upright ? slot.rawW : slot.rawH
                    readonly property real innerWidth: Math.max(slot.contentWidth, slot.chipWidth)
                    readonly property real revealT: GlobalStates.barRevealAt(
                        barBlock.absX + slot.x + slot.width / 2, barBlock.frameW)
                    readonly property bool selected: barBlock.editing && !!barBlock.editor
                        && barBlock.editor.selectedItem === slot.itemId
                    readonly property bool isOpener: barBlock.clickedKind !== "" && barBlock.openerId === slot.itemId

                    readonly property bool wanted: !slot.leaving && (slot.itemShown || barBlock.editing)
                    property real presence: 0
                    readonly property real pc: Math.max(0, slot.presence)
                    Behavior on presence {
                        enabled: BarLayout.settled
                        SpatialAnim { speed: "fast" }
                    }

                    onPresenceChanged: if (slot.leaving && slot.presence <= 0.001) barBlock.slotGone(slot.itemId)
                    Component.onCompleted: slot.presence = Qt.binding(() => slot.wanted ? 1 : 0)

                    x: barBlock.slotLayout.xs[slot.index] ?? 0
                    visible: slot.pc > 0.001
                    width: (slot.innerWidth + slot.margin[0] + slot.margin[1]) * slot.pc
                    height: barBlock.barH
                    clip: slot.pc < 0.999
                    readonly property bool dimmed: (barBlock.spotlitItem !== "" && !slot.selected) || barBlock.otherBlockSelected
                    readonly property bool covered: barBlock.coveredAt(slot.x, slot.width)
                    opacity: (slot.dragged || slot.covered ? 0 : Math.min(1, slot.pc))
                        * (slot.dimmed ? 0.45 : 1)

                    Behavior on opacity {
                        enabled: BarLayout.settled
                        EffectsAnim { speed: "fast" }
                    }

                    transform: Translate {
                        x: barBlock.slotShift(slot.listIndex)
                        Behavior on x {
                            SpatialAnim { speed: "fast" }
                        }
                    }

                    BarItemPlate {
                        x: slot.margin[0]
                        anchors.verticalCenter: parent.verticalCenter
                        width: slot.innerWidth
                        height: barBlock.barH
                        itemId: slot.itemId
                        contentWidth: slot.contentWidth
                        contentHeight: slot.contentHeight
                        barH: barBlock.barH
                        turned: barBlock.vertical
                        far: barBlock.far
                        fill: slot.loaded && (loader.item.plateShape ?? "") !== "" ? loader.item.plateTone : barBlock.plateFill
                        shapeOverride: slot.loaded ? (loader.item.plateShape ?? "") : ""
                        shapeInset: slot.loaded ? (loader.item.plateInset ?? 0) : 0
                        hovered: slotHover.hovered && !BarLayout.isGroup(slot.itemId) && (!slot.loaded || loader.item.hoverPlate !== false)
                        shown: slot.itemShown && barBlock.split
                    }

                    BarItemChip {
                        x: slot.margin[0]
                        anchors.verticalCenter: parent.verticalCenter
                        width: slot.innerWidth
                        height: barBlock.barH
                        itemId: slot.itemId
                        contentWidth: slot.contentWidth
                        contentHeight: slot.contentHeight
                        barH: barBlock.barH
                        turned: barBlock.vertical
                        shown: slot.itemShown && !barBlock.split
                        plateColor: slot.loaded && loader.item.plateOn === true
                                    ? loader.item.plateColor : "transparent"
                        hovered: slotHover.hovered && slot.tinted && !BarLayout.isGroup(slot.itemId)
                    }

                    HoverHandler {
                        id: slotHover
                        enabled: slot.tinted || barBlock.split
                    }

                    readonly property string hoverPanel: BarLayout.openOn(slot.itemId) === "hover"
                        ? BarLayout.followKind(slot.itemId) : ""
                    HoverHandler {
                        id: openHover
                        enabled: slot.hoverPanel !== "" && !barBlock.editing && slot.loaded && slot.itemShown
                        onHoveredChanged: {
                            if (openHover.hovered)
                                openDelay.restart()
                            else
                                openDelay.stop()
                        }
                    }
                    Timer {
                        id: openDelay
                        interval: 140
                        onTriggered: if (openHover.hovered && slot.hoverPanel !== "") barBlock.hoverOpen(slot.hoverPanel, slot.loaderItem)
                    }

                    readonly property string clickPanel: !slot.loaded || BarLayout.openOn(slot.itemId) !== "click" ? ""
                        : BarLayout.baseId(slot.itemId) === "clock" ? "calendar"
                        : BarLayout.baseId(slot.itemId) === "music" ? (loader.item.panelKind ?? "")
                        : ""
                    MouseArea {
                        anchors.fill: parent
                        enabled: slot.clickPanel !== "" && !barBlock.editing && slot.itemShown
                        visible: enabled
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barBlock.openPanel(slot.clickPanel, slot.loaderItem)
                    }

                    HoverHandler {
                        enabled: slot.loaded && slot.itemShown && !barBlock.editing && BarLayout.hasOpenChoice(slot.itemId)
                        cursorShape: Qt.PointingHandCursor
                    }

                    Loader {
                        id: loader
                        x: slot.contentStart + (slot.contentWidth - slot.rawW) / 2
                        y: (barBlock.barH - slot.rawH) / 2
                        transform: slot.upright ? [uprightM] : slot.sideways ? [sidewaysM] : []
                        source: Qt.resolvedUrl(BarLayout.fileFor(slot.itemId))

                        Matrix4x4 { id: uprightM; matrix: barBlock.flipAbout(slot.rawW, slot.rawH) }
                        Matrix4x4 { id: sidewaysM; matrix: barBlock.mirrorAbout(slot.rawW, slot.rawH) }
                        visible: slot.itemShown
                        opacity: slot.isOpener || (layout.flyHidden[slot.itemId] ?? false) ? 0 : 1
                        Behavior on opacity {
                            EffectsAnim { speed: "fast" }
                        }
                        onLoaded: {
                            item.host = barBlock
                            if ("itemId" in item)
                                item.itemId = slot.itemId
                        }
                    }

                    Rectangle {
                        visible: slot.ghost && slot.anchorPin && slot.revealT > 0.001
                        opacity: slot.revealT
                        x: slot.margin[0] + 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: slot.selected ? Colors.primary : Colors.primaryContainer
                    }

                    MaterialIconSymbol {
                        id: ghostIcon
                        visible: slot.ghost && slot.revealT > 0.001
                        opacity: (slot.anchorPin ? 1 : 0.6) * slot.revealT
                        x: slot.margin[0] + (28 - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        transform: barBlock.vertical ? [ghostFlip] : []

                        Matrix4x4 { id: ghostFlip; matrix: barBlock.flipAbout(ghostIcon.width, ghostIcon.height) }
                        content: slot.entry ? slot.entry.icon : ""
                        iconSize: slot.anchorPin ? 16 : 18
                        fill: slot.anchorPin ? 1 : 0
                        customColor: !slot.anchorPin ? Colors.outline
                            : slot.selected ? Colors.primaryText : Colors.primaryContainerText
                    }

                    Rectangle {
                        id: closeBadge
                        x: slot.margin[0] + (slot.innerWidth - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: slot.isOpener ? 28 : 12
                        height: width
                        radius: width / 2
                        color: closeArea.containsMouse ? Colors.primary : Colors.primaryContainer
                        opacity: slot.isOpener ? 1 : 0
                        visible: closeBadge.opacity > 0.01
                        Behavior on opacity {
                            EffectsAnim { speed: "fast" }
                        }
                        Behavior on width {
                            SpatialAnim { speed: "fast" }
                        }
                        Behavior on color {
                            EffectsColorAnim { speed: "fast" }
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "close"
                            iconSize: slot.isOpener ? 16 : 7
                            Behavior on iconSize { SpatialAnim { speed: "fast" } }
                            customColor: closeArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            enabled: slot.isOpener
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barBlock.closePanel()
                        }

                        CustomToolTip { content: "Close"; visible: closeArea.containsMouse }
                    }

                    Rectangle {
                        id: selRing
                        visible: slot.selected
                        x: slot.margin[0] - 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: slot.innerWidth + 6
                        height: Math.max(32, slot.chipHeight + 6)
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.primary
                        property real settle: 1
                        scale: 1 + 0.22 * (1 - selRing.settle)
                        onVisibleChanged: if (selRing.visible) ringSettle.restart()

                        NumberAnimation {
                            id: ringSettle
                            target: selRing
                            property: "settle"
                            from: 0
                            to: 1
                            duration: 340
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: selRing.radius + 4
                            color: "transparent"
                            border.width: 3
                            border.color: Qt.alpha(Colors.primary, 0.22)
                        }
                    }
                }
            }
        }

        CustomText {
            id: dropHint
            anchors.centerIn: parent
            visible: barBlock.emptyInEdit
            transform: barBlock.vertical ? [dropFlip] : []

            Matrix4x4 { id: dropFlip; matrix: barBlock.mirrorAbout(dropHint.width, dropHint.height) }
            content: "Drop here"
            size: 11
            weight: 600
            customColor: Colors.outline
        }
    }

    component PanelSlot: Loader {
        id: slot
        property string kind: ""
        property bool shown: false
        property real homeX: 0
        readonly property real clipX: tabHost.x + panelClip.x
        readonly property real clipY: tabHost.y + panelClip.areaY
        readonly property real clipShift: panelClip.y - panelClip.areaY
        readonly property real fw: barBlock.vertical ? slot.height : slot.width
        readonly property real fh: barBlock.vertical ? slot.width : slot.height
        readonly property real slideY: barBlock.far ? Math.max(0, panelClip.areaH - slot.fh)
                                                    : Math.min(0, panelClip.areaH - slot.fh)
        readonly property real pinY: barBlock.far ? panelClip.areaH - slot.fh - barBlock.tuckShown : barBlock.tuckShown
        property real reveal: 1
        property real drift: 0
        property bool quiet: false
        property bool ride: false
        readonly property bool morphKeep: barBlock.morphHold && slot.kind === barBlock.heroKind
        readonly property real rideY: barBlock.far ? Math.max(0, slot.pinY) : Math.min(slot.pinY, panelClip.areaH - slot.fh)

        function enter() {
            if (!slot.shown)
                return
            if (slot.quiet) {
                revealAnim.stop()
                slot.reveal = 1
                slot.drift = 0
                return
            }
            if (slot.status !== Loader.Ready) {
                revealAnim.stop()
                slot.reveal = 0
                slot.drift = 14
                return
            }
            slot.reveal = 0
            slot.drift = 14
            revealAnim.restart()
        }

        onLoaded: slot.enter()

        ParallelAnimation {
            id: revealAnim
            SequentialAnimation {
                PauseAnimation { duration: 40 }
                NumberAnimation {
                    target: slot; property: "reveal"; to: 1
                    duration: 480
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation {
                    target: slot; property: "drift"; to: 0
                    duration: 520
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
                }
            }
        }

        layer.enabled: slot.reveal < 1 && slot.visible
        layer.smooth: true
        layer.effect: GE.OpacityMask { maskSource: wipe }

        Item {
            id: wipe
            visible: false
            width: slot.width
            height: slot.height

            Rectangle {
                id: wipeEdge
                readonly property real feather: 48
                readonly property real span: wipe.height + feather
                width: wipe.width
                height: span
                y: barBlock.far ? (1 - slot.reveal) * span - feather : (slot.reveal - 1) * span
                gradient: Gradient {
                    GradientStop { position: 0; color: barBlock.far ? "transparent" : "white" }
                    GradientStop { position: barBlock.far ? wipeEdge.feather / wipeEdge.span : 1 - wipeEdge.feather / wipeEdge.span; color: "white" }
                    GradientStop { position: 1; color: barBlock.far ? "white" : "transparent" }
                }
            }
        }
        transform: barBlock.vertical ? [slotFlip] : panelClip.morphing ? [slotMorph] : []

        Matrix4x4 { id: slotFlip; matrix: Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Matrix4x4 {
            id: slotMorph
            readonly property point shift: panelClip.morphShift(slot.x, slot.y)
            matrix: Qt.matrix4x4(panelClip.morphS, 0, 0, slotMorph.shift.x, 0, panelClip.morphS, 0, slotMorph.shift.y, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        onShownChanged: {
            if (slot.shown) {
                slotCache.stop()
                slot.quiet = barBlock.panelSwap || barBlock.caeStyle || barBlock.morphFloat
                slot.ride = barBlock.caeStyle && !barBlock.panelSwap
                slot.homeX = Qt.binding(() => barBlock.tabX + (barBlock.tabW - slot.fw) / 2)
                slot.enter()
            } else {
                slotCache.restart()
                slot.ride = barBlock.caeStyle && barBlock.shownKind === ""
                slot.homeX = slot.homeX
            }
        }

        width: barBlock.kindWidth(slot.kind)
        height: barBlock.contentHeight(slot.kind)

        x: Math.round(barBlock.absX + slot.homeX) - barBlock.absX - slot.clipX
        y: Math.round(slot.clipY + (slot.ride ? slot.rideY
            : slot.shown || slot.morphKeep ? slot.pinY + (barBlock.far ? slot.drift : -slot.drift) : slot.slideY)) - slot.clipY - slot.clipShift
        active: slot.kind !== ""
        opacity: slot.shown || slot.morphKeep ? 1 : 0
        visible: slot.opacity > 0.01
        z: slot.shown ? 1 : 0


        Timer {
            id: slotCache
            interval: 30000
            onTriggered: if (!slot.shown && slot.kind !== barBlock.residentKind) slot.kind = ""
        }

        Behavior on opacity {
            enabled: slot.opacity > 0.5 || barBlock.caeStyle
            EffectsAnim { speed: "default" }
        }

        sourceComponent: panels.forKind(slot.kind)
    }

    BarBlockPanels {
        id: panels
        block: barBlock
    }

    Item {
        id: heroLayer
        z: 60
        width: barBlock.width
        height: barBlock.height
        visible: barBlock.heroFlying

        Repeater {
            model: barBlock.heroFlying ? barBlock.heroPairs : []

            delegate: Item {
                id: flight
                required property var modelData
                property rect sr: Qt.rect(0, 0, 1, 1)
                property rect dr: Qt.rect(0, 0, 1, 1)
                property rect cr: Qt.rect(0, 0, 0, 0)
                property rect sLocal: Qt.rect(0, 0, 0, 0)
                property rect dLocal: Qt.rect(0, 0, 0, 0)

                function tight(item) {
                    const cw = item.contentWidth
                    if (cw === undefined || cw <= 0 || cw >= item.width - 1)
                        return Qt.rect(0, 0, 0, 0)
                    const ha = item.horizontalAlignment
                    const ox = ha === Text.AlignHCenter ? (item.width - cw) / 2 : ha === Text.AlignRight ? item.width - cw : 0
                    return Qt.rect(ox, 0, cw, item.height)
                }

                function mapped(item, local) {
                    return local.width > 0 ? heroLayer.mapFromItem(item, local.x, local.y, local.width, local.height)
                                           : heroLayer.mapFromItem(item, 0, 0, item.width, item.height)
                }
                property real cornerR: 0
                readonly property bool clipped: !!flight.modelData.clip && flight.cr.width > 0
                readonly property real p: barBlock.emph(barBlock.heroT)
                readonly property real k: Math.max(0, Math.min(1, (flight.p - 0.1) / 0.5))
                function fit(r) {
                    const a = r.width / Math.max(1, r.height)
                    const w = Math.min(flight.width, flight.height * a)
                    const h = w / Math.max(0.001, a)
                    return Qt.rect((flight.width - w) / 2, (flight.height - h) / 2, w, h)
                }
                readonly property rect srcBox: flight.fit(flight.sr)
                readonly property rect dstBox: flight.fit(flight.dr)

                function measure() {
                    const s = flight.modelData.src, d = flight.modelData.dst
                    if (!s || !d)
                        return
                    flight.sLocal = flight.tight(s)
                    flight.dLocal = flight.tight(d)
                    flight.sr = flight.mapped(s, flight.sLocal)
                    flight.dr = flight.mapped(d, flight.dLocal)
                    const c = flight.modelData.clip
                    if (!c)
                        return
                    flight.cr = heroLayer.mapFromItem(c, 0, 0, c.width, c.height)
                    flight.cornerR = flight.modelData.clipR * heroLayer.mapFromItem(d, 0, 0, d.width, 1).width / Math.max(0.001, d.width)
                }

                Component.onCompleted: flight.measure()

                FrameAnimation {
                    running: barBlock.heroFlying
                    onTriggered: flight.measure()
                }

                x: flight.sr.x + (flight.dr.x - flight.sr.x) * flight.p
                y: flight.sr.y + (flight.dr.y - flight.sr.y) * flight.p
                width: flight.sr.width + (flight.dr.width - flight.sr.width) * flight.p
                height: flight.sr.height + (flight.dr.height - flight.sr.height) * flight.p

                ShaderEffectSource {
                    x: flight.srcBox.x
                    y: flight.srcBox.y
                    width: flight.srcBox.width
                    height: flight.srcBox.height
                    sourceItem: flight.modelData.src
                    sourceRect: flight.sLocal
                    hideSource: true
                    live: true
                    smooth: true
                    mipmap: true
                    textureSize: Qt.size(Math.ceil(flight.dr.width * 1.2), Math.ceil(flight.dr.width * 1.2 * flight.sr.height / Math.max(1, flight.sr.width)))
                    opacity: 1 - flight.k
                }

                ClippingRectangle {
                    id: dstClip
                    x: flight.clipped ? flight.cr.x - flight.x : flight.dstBox.x
                    y: flight.clipped ? flight.cr.y - flight.y : flight.dstBox.y
                    width: flight.clipped ? flight.cr.width : flight.dstBox.width
                    height: flight.clipped ? flight.cr.height : flight.dstBox.height
                    color: "transparent"
                    radius: flight.clipped ? flight.cornerR : 0
                    opacity: flight.k

                    ShaderEffectSource {
                        x: flight.dstBox.x - dstClip.x
                        y: flight.dstBox.y - dstClip.y
                        width: flight.dstBox.width
                        height: flight.dstBox.height
                        sourceItem: flight.modelData.dst
                        sourceRect: flight.dLocal
                        hideSource: true
                        live: true
                        smooth: true
                        mipmap: true
                    }
                }
            }
        }
    }

    Shape {
        z: 40
        x: 0
        y: 0
        width: barBlock.width
        height: barBlock.barH
        visible: barBlock.revealT > 0.001 && BarLayout.gapDragT < 0.999
        opacity: barBlock.revealT * (1 - BarLayout.gapDragT)
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: barBlock.blockSelected && BarLayout.gapModel ? "transparent" : Colors.primary
            strokeWidth: barBlock.isDropTarget || barBlock.blockSelected ? 2 : 1.5
            strokeStyle: barBlock.blockSelected ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: Qt.alpha(Colors.primary, barBlock.isDropTarget ? 0.16 : 0.06)

            PathRectangle {
                x: 2
                y: 3
                width: Math.max(0, barBlock.width - 4)
                height: barBlock.barH - 6
                radius: 14
            }
        }
    }

    readonly property bool gripShown: editLayer.item ? editLayer.item.gripShown : false

    Loader {
        id: editLayer
        z: 50
        opacity: 1 - BarLayout.gapDragT
        active: barBlock.editMode || barBlock.revealT > 0.001
        sourceComponent: BarBlockEditLayer {
            block: barBlock
        }
    }
}
