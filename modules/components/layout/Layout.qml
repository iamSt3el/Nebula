import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
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
import "../Bar/BarOps.js" as BarOps

PanelWindow{
    id: layout
    color: "transparent"
    anchors{
        top: true
        left: true
        right: true
        bottom: true
    }

    property bool isPrimary: true

    readonly property bool barEditing: GlobalStates.barEditMode && isPrimary
    property bool editorsLive: false
    property Item editChrome: null
    property Item drawerHost: null
    readonly property var surfaces: [surfTop, surfRight, surfBottom, surfLeft]
    readonly property var flyHidden: barFlight.hidden

    function cornerFor(side, atEnd, top, bottom) {
        if (!side.visible || side.panelDepth <= 0)
            return { start: 0, end: 0, dropStart: false, dropEnd: false }
        const rs = top.visible ? top.reachBase(atEnd, side.panelDepth) : 0
        const re = bottom.visible ? bottom.reachBase(atEnd, side.panelDepth) : 0
        if (side.fitsWith(rs, re))
            return { start: rs, end: re, dropStart: false, dropEnd: false }
        if (re > 0 && side.fitsWith(rs, 0))
            return { start: rs, end: 0, dropStart: false, dropEnd: true }
        if (rs > 0 && side.fitsWith(0, re))
            return { start: 0, end: re, dropStart: true, dropEnd: false }
        return { start: 0, end: 0, dropStart: rs > 0, dropEnd: re > 0 }
    }
    function cornerPill(across, side, atEnd) {
        if (!across.visible || !side.visible || !side.present)
            return null
        const bl = across.visibleBlocks
        if (!bl.length)
            return null
        const b = atEnd ? bl[bl.length - 1] : bl[0]
        if (!b.isPill)
            return null
        const x = across.restX(b)
        const inside = atEnd ? x + b.width > across.width - side.thickness : x < side.thickness
        return inside ? b : null
    }
    readonly property var leftCorner: layout.cornerFor(surfLeft, false, surfTop, surfBottom)
    readonly property var rightCorner: layout.cornerFor(surfRight, true, surfTop, surfBottom)
    function crossFor(end) {
        const drop = end ? "dropEnd" : "dropStart"
        let out = []
        if (surfLeft.visible)
            out = out.concat(surfLeft.blockRects("left", end))
        if (surfRight.visible)
            out = out.concat(surfRight.blockRects("right", end))
        if (layout.leftCorner[drop])
            out = out.concat(surfLeft.openRects("left"))
        if (layout.rightCorner[drop])
            out = out.concat(surfRight.openRects("right"))
        return out
    }

    property int panelClock: 0
    function nextPanelSeq() {
        layout.panelClock++
        return layout.panelClock
    }

    function panelRect(s, b) {
        const near = s.blockTop(b) + s.barH
        const far = near + b.acrossOf(b.shownKind) + (b.floating ? b.floatGap : 0)
        const a0 = b.absX + b.tabTargetX
        const a1 = a0 + b.tabTargetW
        switch (s.edge) {
        case "top": return { l: a0, r: a1, t: near, b: far }
        case "bottom": return { l: a0, r: a1, t: layout.height - far, b: layout.height - near }
        case "left": return { l: near, r: far, t: a0, b: a1 }
        default: return { l: layout.width - far, r: layout.width - near, t: a0, b: a1 }
        }
    }

    readonly property var openPanels: {
        const out = []
        if (layout.barEditing)
            return out
        for (const s of layout.surfaces) {
            if (!s.visible)
                continue
            for (const b of s.visibleBlocks) {
                if (b.shownKind === "" || b.closing || b.isTransient(b.shownKind) || b.tabTargetW < 1)
                    continue
                out.push({ block: b, seq: b.openSeq, clicked: b.clickedKind !== "", rect: layout.panelRect(s, b) })
            }
        }
        return out
    }
    onOpenPanelsChanged: if (layout.openPanels.length > 1) panelArbiter.restart()

    Timer {
        id: panelArbiter
        interval: 180
        onTriggered: {
            const list = layout.openPanels
            for (let i = 0; i < list.length; i++) {
                for (let j = i + 1; j < list.length; j++) {
                    const a = list[i].rect
                    const c = list[j].rect
                    if (Math.min(a.r, c.r) - Math.max(a.l, c.l) <= 1 || Math.min(a.b, c.b) - Math.max(a.t, c.t) <= 1)
                        continue
                    const newer = list[i].seq > list[j].seq ? list[i] : list[j]
                    const older = newer === list[i] ? list[j] : list[i]
                    const loser = !newer.clicked && older.clicked ? newer : older
                    loser.block.closePanel()
                    return
                }
            }
        }
    }

    Binding {
        target: ServiceGaps
        property: "frame"
        when: layout.isPrimary
        value: barBlob.frame
    }

    Binding {
        target: ServiceGaps
        property: "barItem"
        when: layout.isPrimary
        value: root
    }

    Binding {
        target: ServiceGaps
        property: "occupied"
        when: layout.isPrimary
        value: ({ top: surfTop.occupied, right: surfRight.occupied, bottom: surfBottom.occupied, left: surfLeft.occupied })
    }
    function loadEditors() {
        layout.editChrome = editChromeComp.createObject(root)
        layout.drawerHost = drawerComp.createObject(root)
        layout.syncDrawer()
        Qt.callLater(() => layout.editorsLive = true)
    }
    function unloadEditors() {
        for (const o of [layout.editChrome, layout.drawerHost])
            if (o) o.destroy()
        layout.editChrome = null
        layout.drawerHost = null
        layout.editorsLive = false
    }
    Timer {
        id: editorsUnload
        interval: 10000
        onTriggered: if (!layout.barEditing) layout.unloadEditors()
    }
    readonly property bool launcherPreview: layout.barEditing && barEditor.panelStage && barEditor.selectedItem === "launcher"
    readonly property string panelPreview: {
        const k = layout.barEditing && barEditor.panelStage ? BarLayout.panelFor(barEditor.selectedItem) : ""
        return k === "launcher" ? "" : k
    }
    readonly property bool dashPreview: layout.panelPreview !== ""
    readonly property bool anyPreview: layout.launcherPreview || layout.dashPreview
    readonly property string dashAnchor: {
        if (layout.panelPreview === "wallpaper" || layout.panelPreview === "clipboard")
            return "center"
        const opener = barEditor.selectedItem
        const b = BarLayout.allBlocks.find(x => x.items.indexOf(opener) >= 0)
        return b ? b.anchor : "right"
    }
    readonly property bool previewRight: layout.dashPreview
        ? layout.dashAnchor !== "left"
        : ServiceLauncher.position === "item"
          && BarLayout.allBlocks.some(b => b.anchor === "right" && b.items.indexOf("launcher") >= 0)
    readonly property real popupY: surfTop.present ? surfTop.rowItem.y + surfTop.maxDrop + surfTop.barH + (surfTop.anyPill ? 8 : 4) : 8

    WlrLayershell.namespace: "quickshell:bar"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: layout.barEditing ? WlrKeyboardFocus.Exclusive
                               : isPrimary && ((GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") !== "center")
                                               || (GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") !== "center")
                                               || GlobalStates.powerPanelOpen
                                               || GlobalStates.phoneNotifsPanelOpen
                                               || GlobalStates.phoneCallPanelOpen
                                               || GlobalStates.scenesPanelOpen
                                               || GlobalStates.dockSearchActive
                                               || (GlobalStates.appLauncherOpen && GlobalStates.launcherHosted)) ? WlrKeyboardFocus.OnDemand
                                                             : WlrKeyboardFocus.None

    onBarEditingChanged: {
        BarLayout.gapHover = null
        root.queueGapMarks()
        barEditor.cancel()
        barEditor.selectedItem = ""
        barEditor.panelStage = false
        barEditor.drawerMode = ""
        if (layout.barEditing) {
            editorsUnload.stop()
            if (!layout.editChrome)
                layout.loadEditors()
        } else if (layout.editChrome) {
            editorsUnload.restart()
        }
    }

    readonly property bool drawerWanted: layout.barEditing && barEditor.drawerMode !== "" && barEditor.drawerMode !== "inspector"
    onDrawerWantedChanged: {
        layout.syncDrawer()
        if (!layout.drawerWanted && layout.barEditing)
            editKeys.forceActiveFocus()
    }

    Connections {
        target: layout.editChrome
        ignoreUnknownSignals: true
        function onShelfOpenChanged() {
            if (layout.editChrome && !layout.editChrome.shelfOpen && layout.barEditing)
                editKeys.forceActiveFocus()
        }
    }
    function syncDrawer() {
        const d = layout.drawerHost
        if (!d)
            return
        if (layout.drawerWanted && barEditor.drawerMode === "settings" && d.tab === "add")
            d.tab = "edges"
        if (layout.drawerWanted) {
            if (!d.alive)
                d.placeNow()
            d.open()
        }
        else d.close()
    }

    Binding {
        target: GlobalStates
        property: "editEdgeRects"
        when: layout.isPrimary
        value: layout.surfaces.filter(s => s.visible && s.present).map(s => s.bandRect)
    }

    Binding {
        target: GlobalStates
        property: "editEdgeScreen"
        when: layout.isPrimary
        value: layout.screen ? layout.screen.name : ""
    }

    Binding {
        target: GlobalStates
        property: "editTopInset"
        when: layout.isPrimary
        value: surfTop.visible && surfTop.present ? surfTop.thickness : (surfTop.visible ? 40 : 0)
    }

    Binding {
        target: GlobalStates
        property: "editBottomInset"
        when: layout.isPrimary
        value: surfBottom.visible && surfBottom.present ? surfBottom.thickness : 0
    }

    function widgetAt(x, y) {
        const hosts = WidgetLayout.hosts
        for (let i = hosts.length - 1; i >= 0; i--) {
            const h = hosts[i]
            if (!h || !h.visible || h.preview || h.configKey === "")
                continue
            const w = h.Window.window
            if (w && layout.screen && w.screen && w.screen.name !== layout.screen.name)
                continue
            const p = h.mapToItem(null, 0, 0)
            if (x >= p.x && x <= p.x + h.width && y >= p.y && y <= p.y + h.height)
                return h
        }
        return null
    }

    Binding {
        target: GlobalStates
        property: "launcherHosted"
        value: BarLayout.launcherItemHost
        when: layout.isPrimary
    }

    Binding {
        target: GlobalStates
        property: "launcherPreview"
        value: true
        when: layout.isPrimary && layout.launcherPreview
    }

    Binding {
        target: GlobalStates
        property: "previewInsetRight"
        value: (barEditor.drawerMode !== "" && drawerHost ? drawerHost.width : 400) + 48
        when: layout.isPrimary && layout.launcherPreview && !layout.previewRight
    }

    Binding {
        target: GlobalStates
        property: "previewInsetLeft"
        value: (barEditor.drawerMode !== "" && drawerHost ? drawerHost.width : 400) + 48
        when: layout.isPrimary && layout.launcherPreview && layout.previewRight
    }

    Binding {
        target: GlobalStates
        property: "panelPreview"
        value: layout.panelPreview
        when: layout.isPrimary && layout.dashPreview
    }

    HyprlandFocusGrab {
        windows: [layout]
        active: !GlobalStates.capturing && layout.isPrimary && GlobalStates.appLauncherOpen && GlobalStates.launcherHosted
        onCleared: if (!active && !GlobalStates.capturing) GlobalStates.appLauncherOpen = false
    }

    mask: Region{
        item: maskRect;
        intersection: Intersection.Xor;

        SurfaceMask { surface: surfTop }
        SurfaceMask { surface: surfRight }
        SurfaceMask { surface: surfBottom }
        SurfaceMask { surface: surfLeft }
        Region {
            x: 0; y: 0
            width:  layout.barEditing ? layout.width  : 0
            height: layout.barEditing ? layout.height : 0
            intersection: Intersection.Subtract
        }

        Region{
            x: 0
            y: ServiceGaps.secondaryEdge === "bottom" ? layout.height - Appearance.size.barHeight : 0
            width:  isPrimary ? 0 : layout.width
            height: isPrimary ? 0 : Appearance.size.barHeight
            intersection: Intersection.Subtract
        }

        Region {
            x:      notifPopups.item ? notifPopups.x + notifPopups.item.x : 0
            y:      notifPopups.item ? notifPopups.y + notifPopups.item.y : 0
            width:  (isPrimary && notifPopups.item && notifPopups.item.height > 0) ? notifPopups.item.width : 0
            height: isPrimary && notifPopups.item ? notifPopups.item.height : 0
            intersection: Intersection.Subtract
        }

        Region {
            x:      notifStyled.hit.x
            y:      notifStyled.hit.y
            width:  isPrimary ? notifStyled.hit.width : 0
            height: isPrimary ? notifStyled.hit.height : 0
            intersection: Intersection.Subtract
        }
    }
    Rectangle{
        id: maskRect
        implicitHeight: parent.height
        implicitWidth: parent.width
        anchors.bottom: parent.bottom
        color: "transparent"
    }

    SecondaryBar {
        visible: !isPrimary
    }

    Item{
        id: root
        anchors.fill: parent
        visible: isPrimary

        function inDrawerAt(x, y) {
            if (!editChrome || !drawerHost)
                return false
            const r = editChrome.shelfRect
            if (r.width > 0 && x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height)
                return true
            return drawerHost.visible
                && x >= drawerHost.x && x <= drawerHost.x + drawerHost.width
                && y >= drawerHost.y && y <= drawerHost.y + drawerHost.height
        }

        function surfaceAt(x, y) {
            let best = null
            let bestD = Infinity
            for (const s of layout.surfaces) {
                if (!s.visible || !s.present)
                    continue
                const p = s.toFrame(x, y)
                if (!s.inBand(p.x, p.y, 40))
                    continue
                const d = s.far ? s.height - p.y : p.y
                if (d < bestD) {
                    bestD = d
                    best = s
                }
            }
            return best
        }

        function edgeAt(x, y) {
            const hit = root.surfaceAt(x, y)
            if (hit)
                return hit
            for (const s of layout.surfaces) {
                if (!s.visible || s.present)
                    continue
                const p = s.toFrame(x, y)
                if (s.inBand(p.x, p.y, 24))
                    return s
            }
            return null
        }

        function trackApp(x, y) {
            barEditor.overDrawer = root.inDrawerAt(x, y)
            const surf = root.surfaceAt(x, y)
            let g = null
            for (const b of (surf ? surf.visibleBlocks : [])) {
                g = b.appGeom()
                if (g)
                    break
            }
            const f = surf ? surf.toFrame(x, y) : Qt.point(0, 0)
            if (barEditor.overDrawer || !g || f.x < g.x - 30 || f.x > g.x + g.w + 30) {
                barEditor.appDropIndex = -1
                return
            }
            barEditor.appDropIndex = BarOps.appDropIndex(g.apps, barEditor.appId, f.x)
        }

        function trackItem(x, y) {
            const inDrawer = root.inDrawerAt(x, y)
            barEditor.overDrawer = inDrawer
            const surf = inDrawer ? null : root.edgeAt(x, y)
            if (!surf) {
                barEditor.caretX = -1
                barEditor.dropBlock = ""
                return
            }
            const f = surf.toFrame(x, y)
            if (!surf.present) {
                barEditor.caretX = -1
                const rel = f.x - surf.rowItem.x
                const W = surf.rowItem.width
                const anchor = rel < W / 3 ? "left" : rel > 2 * W / 3 ? "right" : "center"
                const onEdge = BarLayout.blocksOn(surf.edge)
                const reuse = onEdge.find(b => b.anchor === anchor) ?? onEdge[0]
                barEditor.dropBlock = reuse ? reuse.id : "+" + surf.edge + ":" + anchor
                barEditor.dropIndex = reuse ? reuse.items.length : 0
                return
            }
            x = f.x
            let inside = null
            for (const b of surf.visibleBlocks) {
                if (b.leaving || b.blockId === "__sys" || b.width <= 0)
                    continue
                const bx = surf.rowItem.x + b.parent.x + b.x
                if (x >= bx - 2 && x <= bx + b.width + 2) {
                    inside = b
                    break
                }
            }
            if (inside) {
                barEditor.caretX = -1
                barEditor.dropBlock = inside.blockId
                barEditor.dropIndex = inside.dropIndexAt(x - (surf.rowItem.x + inside.parent.x + inside.x))
                return
            }
            const src = BarLayout.blockById(barEditor.fromBlock)
            const emptied = src && src.items.length === 1 && src.items[0] === barEditor.itemId ? src.id : ""
            const slot = root.slotAt(surf, x, emptied)
            barEditor.dropBlock = "+" + surf.edge + ":" + slot.side + ":" + slot.idx
            barEditor.dropIndex = 0
        }

        function slotAt(surf, x, exclude) {
            const W = surf.rowItem.width
            const rel = x - surf.rowItem.x
            const side = rel < W / 3 ? "left" : (rel > 2 * W / 3 ? "right" : "center")
            const rep = side === "left" ? surf.leftRepeater : (side === "center" ? surf.centerRepeater : surf.rightRepeater)
            const group = side === "left" ? surf.leftGroupItem : (side === "center" ? surf.centerGroupItem : surf.rightGroupItem)
            const others = []
            for (let i = 0; i < rep.count; i++) {
                const b = rep.itemAt(i)
                if (b && b.blockId !== exclude && b.visible && !b.leaving)
                    others.push(b)
            }
            let idx = 0
            for (const b of others) {
                if (surf.rowItem.x + group.x + b.x + b.width / 2 < x)
                    idx++
            }
            let caret
            if (others.length === 0)
                caret = side === "left" ? 8 : (side === "right" ? W - 8 : W / 2)
            else if (idx < others.length)
                caret = group.x + others[idx].x - surf.groupGap / 2
            else {
                const l = others[others.length - 1]
                caret = group.x + l.x + l.width + surf.groupGap / 2
            }
            const cr = surf.toScreen(surf.rowItem.x + Math.max(4, Math.min(W - 4, caret)) - 1.5,
                                     surf.rowItem.y + group.y + 4, 3, surf.barH - 8)
            barEditor.caretX = cr.x
            barEditor.caretY = cr.y
            barEditor.caretW = cr.width
            barEditor.caretH = cr.height
            return { side: side, idx: idx }
        }

        function gapMarks(f) {
            if (!f || !layout.barEditing)
                return []
            const out = []
            const pt = (s, along, depth) => {
                const r = s.toScreen(along, s.far ? s.height - depth : depth, 0, 0)
                return { x: r.x, y: r.y }
            }
            const along = (s, a, b, depth) => {
                if (b - a > 0.5)
                    out.push({ p0: pt(s, a, depth), p1: pt(s, b, depth), label: b - a })
            }
            const across = (s, at, d0, d1) => {
                if (d1 - d0 > 0.5)
                    out.push({ p0: pt(s, at, d0), p1: pt(s, at, d1), label: d1 - d0 })
            }
            for (const s of layout.surfaces) {
                if (!s.visible || !s.present)
                    continue
                const mine = f.edge === "" || f.edge === s.edge
                const vb = s.visibleBlocks.filter(o => !o.leaving && o.width > 0)
                const mid = o => s.blockTop(o) + s.barH / 2
                if (f.key === "panelGap") {
                    for (const o of vb) {
                        if (f.block !== "" ? o.blockId !== f.block : !(o.floating || o.merged))
                            continue
                        const d0 = s.blockTop(o) + s.barH
                        across(s, s.blockX(o) + o.width / 2, d0, d0 + BarLayout.blockPanelGap(o.blockId))
                    }
                    continue
                }
                if (!mine || !vb.length)
                    continue
                if (f.key === "blockGap") {
                    for (let i = 1; i < vb.length; i++)
                        along(s, s.blockX(vb[i - 1]) + vb[i - 1].width, s.blockX(vb[i]), mid(vb[i]))
                } else if (f.key === "itemGap") {
                    for (const o of vb) {
                        const sp = o.itemSpans()
                        for (let i = 1; i < sp.length; i++)
                            along(s, s.blockX(o) + sp[i - 1].r, s.blockX(o) + sp[i].l, mid(o))
                    }
                } else if (f.key === "pillGap") {
                    for (const o of vb)
                        if (o.isPill)
                            across(s, s.blockX(o) + o.width / 2, s.edgeInset, s.blockTop(o))
                } else if (f.key === "edges") {
                    const corner = [surfLeft.cornerPillStart, surfLeft.cornerPillEnd,
                                    surfRight.cornerPillStart, surfRight.cornerPillEnd].filter(p => !!p)
                    for (const o of vb)
                        if (o.isPill && corner.indexOf(o) < 0)
                            across(s, s.blockX(o) + o.width / 2, 0, s.blockTop(o))
                    const first = vb[0]
                    const last = vb[vb.length - 1]
                    if (s.vertical) {
                        const ps = s.cornerPillStart
                        const pe = s.cornerPillEnd
                        if (ps)
                            along(s, surfTop.blockTop(ps) + surfTop.barH, s.blockX(first), mid(first))
                        else
                            along(s, Math.max(0, s.sideStart), s.blockX(first), mid(first))
                        if (pe)
                            along(s, s.blockX(last) + last.width, s.width - surfBottom.blockTop(pe) - surfBottom.barH, mid(last))
                        else
                            along(s, s.blockX(last) + last.width, s.width - Math.max(0, s.sideEnd), mid(last))
                    } else {
                        along(s, 0, s.blockX(first), mid(first))
                        along(s, s.blockX(last) + last.width, s.width, mid(last))
                    }
                } else if (f.key === "around") {
                    const i = vb.findIndex(o => o.blockId === f.block)
                    if (i < 0)
                        continue
                    const o = vb[i]
                    if (i > 0)
                        along(s, s.blockX(vb[i - 1]) + vb[i - 1].width, s.blockX(o), mid(o))
                    if (i < vb.length - 1)
                        along(s, s.blockX(o) + o.width, s.blockX(vb[i + 1]), mid(vb[i + 1]))
                    const corner = [surfLeft.cornerPillStart, surfLeft.cornerPillEnd,
                                    surfRight.cornerPillStart, surfRight.cornerPillEnd].filter(p => !!p)
                    if (o.isPill && corner.indexOf(o) < 0)
                        across(s, s.blockX(o) + o.width / 2, 0, s.blockTop(o))
                } else if (f.key === "pillStart") {
                    const e = s.rowItem.x - s.cornerGapStart
                    along(s, e - s.pillStartGap * s.startPill, e, mid(vb[0]))
                } else if (f.key === "pillEnd") {
                    const e = s.rowItem.x + s.rowItem.width + s.cornerGapEnd
                    along(s, e, e + s.pillEndGap * s.endPill, mid(vb[vb.length - 1]))
                }
            }
            return out
        }

        function trackBlock(sx, sy) {
            const surf = root.surfaceAt(sx, sy) ?? root.nearestSurface(sx, sy)
            const f = surf.toFrame(sx, sy)
            const x = f.x
            const depth = surf.far ? surf.height - f.y : f.y
            const onto = surf.visibleBlocks.find(b => b.blockId !== barEditor.fromBlock && !b.leaving && b.width > 0
                && x >= surf.blockX(b) + b.width * 0.2 && x <= surf.blockX(b) + b.width * 0.8
                && depth >= surf.blockTop(b) - 6 && depth <= surf.blockTop(b) + surf.barH + 6)
            barEditor.joinTarget = onto ? onto.blockId : ""
            barEditor.joinAtEnd = !!onto && x > surf.blockX(onto) + onto.width / 2
            barEditor.label = onto ? "Join" : "Block"
            barEditor.icon = onto ? "join_inner" : "drag_indicator"
            if (onto) {
                barEditor.dropAnchor = ""
                barEditor.caretX = -1
                return
            }
            const slot = root.slotAt(surf, x, barEditor.fromBlock)
            barEditor.dropAnchor = slot.side
            barEditor.dropEdge = surf.edge
            barEditor.dropBlockIndex = slot.idx
        }

        function nearestSurface(x, y) {
            const dist = s => {
                const r = s.bandRect
                const dx = x < r.x ? r.x - x : (x > r.x + r.width ? x - r.x - r.width : 0)
                const dy = y < r.y ? r.y - y : (y > r.y + r.height ? y - r.y - r.height : 0)
                return Math.hypot(dx, dy)
            }
            let best = layout.surfaces[0]
            for (const s of layout.surfaces) {
                if (s.visible && dist(s) < dist(best))
                    best = s
            }
            return best
        }

        QtObject {
            id: barEditor

            property string mode: ""
            property string itemId: ""
            property string fromBlock: ""
            property int fromIndex: -1
            property real dragW: 0
            property string label: ""
            property string icon: ""
            property real px: 0
            property real py: 0
            property string dropBlock: ""
            property int dropIndex: 0
            property bool overDrawer: false
            property string dropAnchor: ""
            property int dropBlockIndex: 0
            property real caretX: -1
            property string selectedItem: ""
            property string selectedBlock: ""
            property string joinTarget: ""
            property bool joinAtEnd: false
            property string dropEdge: "top"
            property real caretY: 0
            property real caretW: 3
            property real caretH: 0
            property string appId: ""
            property bool appPinned: false
            property int appDropIndex: -1
            property bool panelStage: false
            property string drawerMode: ""
            property rect drawerFrom: Qt.rect(0, 0, 0, 0)
            property string liftUrl: ""
            property string liftFor: ""
            property real liftDX: 0
            property real liftDY: 0
            property real liftW: 0
            property real liftH: 0

            onDrawerModeChanged: {
                if (barEditor.drawerMode === "options" && barEditor.selectedItem.indexOf("dash:") === 0)
                    barEditor.drawerMode = "inspector"
            }

            onSelectedBlockChanged: {
                if (barEditor.selectedBlock !== "")
                    barEditor.selectedItem = ""
            }

            onSelectedItemChanged: {
                if (barEditor.selectedItem !== "")
                    barEditor.selectedBlock = ""
                if (barEditor.selectedItem === "") {
                    barEditor.panelStage = false
                    if (barEditor.drawerMode === "options" || barEditor.drawerMode === "inspector") barEditor.drawerMode = ""
                } else if (barEditor.selectedItem.indexOf("dash:") === 0) {
                    if (barEditor.drawerMode === "options") barEditor.drawerMode = "inspector"
                } else if (barEditor.drawerMode === "inspector") {
                    barEditor.drawerMode = barEditor.selectedItem === "dashboard" ? "options" : ""
                }
            }

            function beginItem(id, blockId, idx, w) {
                const e = BarLayout.entry(id)
                if (blockId === "")
                    barEditor.liftUrl = ""
                barEditor.itemId = id
                barEditor.fromBlock = blockId
                barEditor.fromIndex = idx
                barEditor.dragW = w
                barEditor.label = e ? e.label : id
                barEditor.icon = e ? e.icon : ""
                barEditor.dropBlock = blockId
                barEditor.dropIndex = Math.max(0, idx)
                barEditor.overDrawer = false
                barEditor.mode = "item"
            }

            function beginBlock(blockId) {
                barEditor.fromBlock = blockId
                barEditor.label = "Block"
                barEditor.icon = "drag_indicator"
                barEditor.dropAnchor = ""
                barEditor.caretX = -1
                barEditor.mode = "block"
            }

            function beginApp(appId, pinned, w) {
                const e = DesktopEntries.heuristicLookup(appId)
                barEditor.appId = appId
                barEditor.appPinned = pinned
                barEditor.appDropIndex = -1
                barEditor.fromBlock = ""
                barEditor.dragW = w
                barEditor.label = e && e.name ? e.name : appId
                barEditor.icon = pinned ? "drag_indicator" : "push_pin"
                barEditor.overDrawer = false
                barEditor.mode = "app"
            }

            function update(x, y) {
                barEditor.px = x
                barEditor.py = y
                if (barEditor.mode === "item") root.trackItem(x, y)
                else if (barEditor.mode === "block") root.trackBlock(x, y)
                else if (barEditor.mode === "app") root.trackApp(x, y)
            }

            function finish() {
                const mode = barEditor.mode
                const id = barEditor.itemId
                const from = barEditor.fromBlock
                const toBlock = barEditor.dropBlock
                const toIndex = barEditor.dropIndex
                const hide = barEditor.overDrawer
                const side = barEditor.dropAnchor
                const sideIndex = barEditor.dropBlockIndex
                const edge = barEditor.dropEdge
                const appId = barEditor.appId
                const appPinned = barEditor.appPinned
                const appIndex = barEditor.appDropIndex
                const join = barEditor.joinTarget
                const joinEnd = barEditor.joinAtEnd
                if (mode === "item" && !hide && toBlock !== "")
                    dragGhost.beginLanding(id)
                if (mode === "item")
                    EditSession.hint = id
                barEditor.cancel()
                if (mode === "app") {
                    if (hide) {
                        if (appPinned) Qt.callLater(() => ServiceApps.unpinById(appId))
                    } else if (appIndex >= 0) {
                        Qt.callLater(() => ServiceApps.movePin(appId, appIndex))
                    }
                    return
                }
                if (mode === "item") {
                    if (hide) {
                        if (id === barEditor.selectedItem) barEditor.selectedItem = ""
                        if (from !== "") Qt.callLater(() => BarLayout.hideItem(id))
                    } else if (toBlock.indexOf("+") === 0) {
                        const spec = toBlock.slice(1).split(":")
                        const at = spec.length > 2 ? parseInt(spec[2]) : 1e9
                        Qt.callLater(() => BarLayout.placeInNewBlock(id, spec[1], at, spec[0]))
                    } else if (toBlock !== "") {
                        Qt.callLater(() => BarLayout.moveItem(id, toBlock, toIndex))
                    }
                } else if (mode === "block" && join !== "") {
                    Qt.callLater(() => BarLayout.joinBlocks(from, join, joinEnd))
                } else if (mode === "block" && side !== "") {
                    Qt.callLater(() => BarLayout.moveBlock(from, side, sideIndex, edge))
                }
            }

            function cancel() {
                barEditor.mode = ""
                barEditor.itemId = ""
                barEditor.fromBlock = ""
                barEditor.fromIndex = -1
                barEditor.dropBlock = ""
                barEditor.overDrawer = false
                barEditor.dropAnchor = ""
                barEditor.caretX = -1
                barEditor.appId = ""
                barEditor.appPinned = false
                barEditor.appDropIndex = -1
                barEditor.joinTarget = ""
            }
        }

        Binding {
            target: BarLayout
            property: "editor"
            value: barEditor
            when: layout.isPrimary
        }
        Rectangle {
            anchors.fill: parent
            z: -1
            visible: layout.barEditing
            color: Qt.alpha(Colors.surface, EditSession.peek ? 0 : 0.45)
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    editKeys.forceActiveFocus()
                    if (barEditor.mode !== "")
                        return
                    if (editChrome && editChrome.closeAll())
                        return
                    if (!root.surfaceAt(mouse.x, mouse.y)) {
                        const w = layout.widgetAt(mouse.x, mouse.y)
                        if (w) {
                            GlobalStates.widgetSettingsKey = w.configKey
                            GlobalStates.editLayer = "desktop"
                            return
                        }
                    }
                    if (barEditor.selectedItem !== "" || barEditor.selectedBlock !== "") {
                        barEditor.selectedItem = ""
                        barEditor.selectedBlock = ""
                    } else if (!root.surfaceAt(mouse.x, mouse.y))
                        GlobalStates.closeEdit()
                }
            }
        }

        BarBlobLayer {
            id: barBlob
            anchors.fill: parent
            opacity: barFlight.shapeIn
            surfaces: layout.surfaces
        }

        component EdgeSurface: BarSurface {
            opacity: barFlight.shapeIn
            isPrimary: layout.isPrimary
            editor: barEditor
            visible: layout.isPrimary && !cfg.hidden && !(ServiceGameMode.hideWidgets && cfg.gameHide)
        }

        EdgeSurface {
            id: surfTop
            edge: "top"
            sideStart: surfLeft.visible ? surfLeft.panelBand : 0
            sideEnd: surfRight.visible ? surfRight.panelBand : 0
            farBand: surfBottom.visible ? surfBottom.stripBand : 0
            farReserve: surfBottom.visible ? surfBottom.panelBand : 0
            crossPanels: layout.crossFor(false)
            stripStart: surfLeft.visible ? surfLeft.stripInset : 0
            stripEnd: surfRight.visible ? surfRight.stripInset : 0
        }

        EdgeSurface {
            id: surfBottom
            edge: "bottom"
            sideStart: surfLeft.visible ? surfLeft.panelBand : 0
            sideEnd: surfRight.visible ? surfRight.panelBand : 0
            farBand: surfTop.visible ? surfTop.stripBand : 0
            farReserve: surfTop.visible ? surfTop.panelBand : 0
            crossPanels: layout.crossFor(true)
            stripStart: surfLeft.visible ? surfLeft.stripInset : 0
            stripEnd: surfRight.visible ? surfRight.stripInset : 0
        }

        EdgeSurface {
            id: surfLeft
            edge: "left"
            sideStart: layout.leftCorner.start
            sideEnd: layout.leftCorner.end
            cornerPillStart: layout.cornerPill(surfTop, surfLeft, false)
            cornerPillEnd: layout.cornerPill(surfBottom, surfLeft, false)
            farBand: surfRight.visible ? surfRight.stripBand : 0
            farReserve: surfRight.visible ? surfRight.panelBand : 0
            crossStart: surfTop.visible ? surfTop.panelBand : 0
            crossEnd: surfBottom.visible ? surfBottom.panelBand : 0
        }

        EdgeSurface {
            id: surfRight
            edge: "right"
            sideStart: layout.rightCorner.start
            sideEnd: layout.rightCorner.end
            cornerPillStart: layout.cornerPill(surfTop, surfRight, true)
            cornerPillEnd: layout.cornerPill(surfBottom, surfRight, true)
            farBand: surfLeft.visible ? surfLeft.stripBand : 0
            farReserve: surfLeft.visible ? surfLeft.panelBand : 0
            crossStart: surfTop.visible ? surfTop.panelBand : 0
            crossEnd: surfBottom.visible ? surfBottom.panelBand : 0
        }

        ListModel {
            id: gapMarkModel
        }

        function collectGapMarks() {
            if (!layout.barEditing)
                return []
            const all = []
            const seen = {}
            const add = list => {
                for (const m of list) {
                    const r = {
                        x0: Math.round(Math.min(m.p0.x, m.p1.x)), x1: Math.round(Math.max(m.p0.x, m.p1.x)),
                        y0: Math.round(Math.min(m.p0.y, m.p1.y)), y1: Math.round(Math.max(m.p0.y, m.p1.y)),
                        label: Math.round(m.label)
                    }
                    const k = r.x0 + "," + r.y0 + "," + r.x1 + "," + r.y1
                    if (!seen[k]) {
                        seen[k] = true
                        all.push(r)
                    }
                }
            }
            if (root.allGaps) {
                for (const key of ["blockGap", "edges"])
                    add(root.gapMarks({ key: key, edge: "", block: "" }))
            } else if (root.gapFocus !== "") {
                add(root.gapMarks({ key: "around", edge: "", block: root.gapFocus }))
            }
            add(root.gapMarks(BarLayout.gapFlash ?? BarLayout.gapHover))
            return all
        }

        function refreshGapMarks() {
            const rows = root.collectGapMarks()
            if (rows.length !== gapMarkModel.count) {
                gapMarkModel.clear()
                for (const r of rows)
                    gapMarkModel.append(r)
                return
            }
            for (let i = 0; i < rows.length; i++) {
                const r = rows[i]
                const c = gapMarkModel.get(i)
                if (c.x0 !== r.x0 || c.x1 !== r.x1 || c.y0 !== r.y0 || c.y1 !== r.y1 || c.label !== r.label)
                    gapMarkModel.set(i, r)
            }
        }

        function queueGapMarks() {
            Qt.callLater(root.refreshGapMarks)
        }

        readonly property bool allGaps: GlobalStates.showGaps
        property string gapFocus: ""

        Connections {
            target: GlobalStates
            function onShowGapsChanged() {
                root.queueGapMarks()
            }
        }

        function focusBlock() {
            if (barEditor.mode !== "")
                return ""
            for (const s of layout.surfaces) {
                if (!s || !s.visible || !s.present)
                    continue
                const h = s.visibleBlocks.find(o => o.hovering && !o.leaving && o.blockId !== barEditor.selectedBlock)
                if (h)
                    return h.blockId
            }
            if (barEditor.selectedBlock !== "")
                return ""
            if (barEditor.selectedItem !== "") {
                const b = BarLayout.allBlocks.find(o => o.items.indexOf(barEditor.selectedItem) >= 0)
                if (b)
                    return b.id
            }
            return ""
        }

        Timer {
            interval: 120
            repeat: true
            running: layout.barEditing && !root.allGaps
            onTriggered: {
                const f = root.focusBlock()
                if (f !== root.gapFocus) {
                    root.gapFocus = f
                    root.queueGapMarks()
                }
            }
        }

        Connections {
            target: layout
            function onBarEditingChanged() {
                if (!layout.barEditing) {
                    root.allGaps = false
                    root.gapFocus = ""
                }
            }
        }

        Connections {
            target: surfTop
            function onGeometryUpdated() { if (layout.barEditing) root.queueGapMarks() }
        }
        Connections {
            target: surfRight
            function onGeometryUpdated() { if (layout.barEditing) root.queueGapMarks() }
        }
        Connections {
            target: surfBottom
            function onGeometryUpdated() { if (layout.barEditing) root.queueGapMarks() }
        }
        Connections {
            target: surfLeft
            function onGeometryUpdated() { if (layout.barEditing) root.queueGapMarks() }
        }
        Connections {
            target: BarLayout
            function onGapHoverChanged() { root.queueGapMarks() }
        }

        Timer {
            id: gapFlashOff
            interval: 1500
            onTriggered: BarLayout.gapFlash = null
        }
        Connections {
            target: BarLayout
            function onGapFlashChanged() {
                if (BarLayout.gapFlash)
                    gapFlashOff.restart()
                root.queueGapMarks()
            }
        }

        Repeater {
            model: gapMarkModel

            Item {
                id: mark
                required property real x0
                required property real x1
                required property real y0
                required property real y1
                required property real label
                visible: !EditSession.peek
                readonly property bool flat: mark.x1 - mark.x0 >= mark.y1 - mark.y0
                z: 208
                anchors.fill: parent

                Rectangle {
                    x: mark.flat ? mark.x0 : mark.x0 - 1
                    y: mark.flat ? mark.y0 - 1 : mark.y0
                    width: mark.flat ? mark.x1 - mark.x0 : 2
                    height: mark.flat ? 2 : mark.y1 - mark.y0
                    radius: 1
                    color: Colors.tertiary
                }

                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        readonly property real at: mark.flat ? (index ? mark.x1 : mark.x0) : (index ? mark.y1 : mark.y0)
                        x: mark.flat ? at - 1 : mark.x0 - 5
                        y: mark.flat ? mark.y0 - 5 : at - 1
                        width: mark.flat ? 2 : 10
                        height: mark.flat ? 10 : 2
                        radius: 1
                        color: Colors.tertiary
                    }
                }

                Rectangle {
                    readonly property real cx: (mark.x0 + mark.x1) / 2
                    readonly property real cy: (mark.y0 + mark.y1) / 2
                    x: mark.flat ? cx - width / 2 : (cx > mark.width / 2 ? cx - width - 8 : cx + 8)
                    y: mark.flat ? (cy > mark.height / 2 ? cy - height - 8 : cy + 8) : cy - height / 2
                    width: markLabel.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: Colors.tertiary

                    CustomText {
                        id: markLabel
                        anchors.centerIn: parent
                        content: mark.label + ""
                        size: 11
                        weight: 600
                        customColor: Colors.tertiaryText
                    }
                }
            }
        }

        Rectangle {
            z: 250
            visible: barEditor.caretX >= 0 && (barEditor.mode === "block"
                || (barEditor.mode === "item" && barEditor.dropBlock.indexOf("+") === 0 && !barEditor.overDrawer))
            x: barEditor.caretX
            y: barEditor.caretY
            width: barEditor.caretW
            height: barEditor.caretH
            radius: 1.5
            color: Colors.primary
        }

        BarEdgeCompass {
            z: 205
            anchors.centerIn: parent
            editor: barEditor
            drawerHost: layout.drawerHost
            live: layout.barEditing
        }

        BarBlockGimbal {
            z: 252
            anchors.fill: parent
            surfaces: layout.surfaces
            editor: barEditor
            live: layout.barEditing && barEditor.mode === "" && barEditor.drawerMode === "" && !barEditor.panelStage
        }

        Component {
            id: editChromeComp
            BarEditChrome {
                z: 210
                opacity: 1 - BarLayout.gapDragT
                visible: BarLayout.gapDragT < 0.999
                editor: barEditor
                surfaces: layout.surfaces
                editing: layout.barEditing && layout.editorsLive
                previewRight: layout.previewRight
            }
        }

        Component {
            id: drawerComp
            BarEditDrawer {
                id: drawerItem
                z: 220
                editor: barEditor
                chrome: layout.editChrome
                readonly property bool beside: barEditor.drawerMode === "options" && !layout.anyPreview
                    && !!layout.editChrome && layout.editChrome.selFound
                readonly property real liveW: barEditor.drawerMode === "options" ? Math.min(360, root.width - 32) : Math.min(640, root.width - 32)
                readonly property real liveX: drawerItem.beside ? layout.editChrome.besideX(drawerItem.liveW)
                    : !layout.anyPreview ? (root.width - drawerItem.liveW) / 2
                    : layout.previewRight ? (surfLeft.visible && surfLeft.present ? surfLeft.thickness : 0) + 16
                    : root.width - drawerItem.liveW - (surfRight.visible && surfRight.present ? surfRight.thickness : 0) - 16
                readonly property real liveY: drawerItem.beside ? layout.editChrome.besideY(drawerItem.liveW, drawerItem.height)
                    : layout.editChrome ? layout.editChrome.cardTop : surfTop.thickness + 48
                maxHeight: layout.height * 0.7
                width: Math.min(640, root.width - 32)
                opacity: EditSession.peek ? 0 : 1
                Behavior on opacity { EffectsAnim { speed: "fast" } }

                function placeNow() {
                    drawerItem.width = drawerItem.liveW
                    drawerItem.x = drawerItem.liveX
                    drawerItem.y = drawerItem.liveY
                }
                function placeIfWanted() {
                    if (layout.drawerWanted)
                        drawerItem.placeNow()
                }
                onLiveWChanged: Qt.callLater(drawerItem.placeIfWanted)
                onLiveXChanged: Qt.callLater(drawerItem.placeIfWanted)
                onLiveYChanged: Qt.callLater(drawerItem.placeIfWanted)
                Component.onCompleted: drawerItem.placeNow()

                Behavior on y {
                    enabled: drawerItem.alive
                    SpatialAnim { speed: "move" }
                }
                Behavior on x {
                    enabled: drawerItem.alive
                    SpatialAnim { speed: "move" }
                }
            }
        }

        BarFlight {
            id: barFlight
            anchors.fill: parent
            z: 290
            surfaces: layout.surfaces
            shape: barBlob
        }

        Item {
            id: dragGhost
            z: 300
            readonly property bool lifted: barEditor.mode === "item" && barEditor.liftUrl !== ""
                && barEditor.liftFor === barEditor.itemId
            property bool landing: false
            property bool landLifted: false
            property string landUrl: ""
            property string landId: ""
            property real landX: 0
            property real landY: 0
            readonly property bool useImage: dragGhost.landing ? dragGhost.landLifted : dragGhost.lifted

            visible: barEditor.mode !== "" || dragGhost.landing
            width: dragGhost.useImage ? liftBox.width : labelPill.width
            height: dragGhost.useImage ? liftBox.height : labelPill.height
            x: dragGhost.landing ? dragGhost.landX
                : dragGhost.useImage ? barEditor.px - barEditor.liftDX - 6 : barEditor.px - width / 2
            y: dragGhost.landing ? dragGhost.landY
                : dragGhost.useImage ? barEditor.py - barEditor.liftDY - 12 : barEditor.py - height / 2
            Behavior on x { enabled: dragGhost.landing; SpatialAnim {} }
            Behavior on y { enabled: dragGhost.landing; SpatialAnim {} }

            function beginLanding(id) {
                dragGhost.landLifted = dragGhost.lifted
                dragGhost.landUrl = barEditor.liftUrl
                dragGhost.landId = id
                dragGhost.landX = dragGhost.x
                dragGhost.landY = dragGhost.y
                dragGhost.opacity = 1
                dragGhost.landing = true
                landFind.restart()
            }

            function cancelLanding() {
                landFind.stop()
                landFade.stop()
                dragGhost.landing = false
                dragGhost.opacity = 1
            }

            Connections {
                target: barEditor
                function onModeChanged() {
                    if (barEditor.mode !== "" && dragGhost.landing)
                        dragGhost.cancelLanding()
                }
            }

            function itemRect(id) {
                for (const surf of layout.surfaces) {
                    if (!surf || !surf.visible)
                        continue
                    for (const b of surf.visibleBlocks) {
                        if (!b.hasItem(id))
                            continue
                        const it = b.itemFor(id)
                        if (it)
                            return it.mapToItem(dragGhost.parent, 0, 0, it.width, it.height)
                    }
                }
                return null
            }

            Timer {
                id: landFind
                interval: 90
                onTriggered: {
                    const r = dragGhost.itemRect(dragGhost.landId)
                    if (r) {
                        dragGhost.landX = dragGhost.landLifted ? r.x - 6 : r.x + r.width / 2 - dragGhost.width / 2
                        dragGhost.landY = dragGhost.landLifted ? r.y - 6 : r.y + r.height / 2 - dragGhost.height / 2
                    }
                    landFade.restart()
                }
            }

            SequentialAnimation {
                id: landFade
                PauseAnimation { duration: 340 }
                NumberAnimation { target: dragGhost; property: "opacity"; to: 0; duration: 140 }
                ScriptAction {
                    script: {
                        dragGhost.landing = false
                        dragGhost.opacity = 1
                    }
                }
            }

            Rectangle {
                id: liftBox
                visible: dragGhost.useImage
                width: barEditor.liftW + 12
                height: barEditor.liftH + 12
                radius: 14
                color: Colors.surfaceContainerHighest
                layer.enabled: dragGhost.useImage
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.8
                    shadowVerticalOffset: 6
                    autoPaddingEnabled: true
                }

                Image {
                    x: 6
                    y: 6
                    width: barEditor.liftW
                    height: barEditor.liftH
                    source: dragGhost.landing ? dragGhost.landUrl : barEditor.liftUrl
                    cache: false
                }
            }

            Rectangle {
                id: labelPill
                visible: !dragGhost.useImage
                width: ghostRow.implicitWidth + 20
                height: 32
                radius: 16
                color: Colors.primaryContainer

                Row {
                    id: ghostRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        content: barEditor.icon
                        iconSize: 16
                        customColor: Colors.primaryContainerText
                    }
                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: barEditor.label
                        size: 12
                        weight: 700
                        customColor: Colors.primaryContainerText
                    }
                }
            }
        }

        function navItems() {
            const out = []
            for (const side of ["top", "right", "bottom", "left"]) {
                const surf = layout.surfaces.find(x => x.edge === side)
                if (!surf || !surf.visible || !surf.present)
                    continue
                const vertical = side === "left" || side === "right"
                const list = []
                for (const b of surf.visibleBlocks) {
                    if (b.leaving || b.blockId === "__sys" || BarLayout.isMore(b.blockId))
                        continue
                    const data = BarLayout.blockById(b.blockId)
                    if (!data)
                        continue
                    for (const id of data.items) {
                        const it = b.itemFor(id)
                        if (!it || !it.visible)
                            continue
                        const r = it.mapToItem(null, 0, 0, it.width, it.height)
                        list.push({ id: id, block: b.blockId, edge: side, pos: vertical ? r.y : r.x })
                    }
                }
                list.sort((p, q) => p.pos - q.pos)
                for (const n of list)
                    out.push(n)
            }
            return out
        }

        function cycleItem(dir) {
            const nav = root.navItems()
            if (nav.length === 0)
                return
            const cur = nav.findIndex(n => n.id === barEditor.selectedItem)
            const next = cur < 0 ? (dir > 0 ? 0 : nav.length - 1) : (cur + dir + nav.length) % nav.length
            barEditor.selectedItem = nav[next].id
        }

        function arrowItem(key, alt, shift) {
            const nav = root.navItems()
            const info = nav.find(n => n.id === barEditor.selectedItem)
            if (!info) {
                root.cycleItem(1)
                return
            }
            const vertical = info.edge === "left" || info.edge === "right"
            const along = vertical ? (key === Qt.Key_Up ? -1 : key === Qt.Key_Down ? 1 : 0)
                                   : (key === Qt.Key_Left ? -1 : key === Qt.Key_Right ? 1 : 0)
            if (along === 0)
                return
            const same = nav.filter(n => n.edge === info.edge)
            if (alt && shift) {
                const blocks = []
                for (const n of same)
                    if (blocks.indexOf(n.block) < 0)
                        blocks.push(n.block)
                const bi = blocks.indexOf(info.block) + along
                if (bi < 0 || bi >= blocks.length)
                    return
                const target = BarLayout.blockById(blocks[bi])
                const id = info.id
                EditSession.hint = id
                Qt.callLater(() => BarLayout.moveItem(id, target.id, along > 0 ? 0 : target.items.length))
            } else if (alt) {
                const blk = BarLayout.blockById(info.block)
                const idx = blk.items.indexOf(info.id)
                const to = idx + along
                if (to < 0 || to >= blk.items.length)
                    return
                const id = info.id
                EditSession.hint = id
                Qt.callLater(() => BarLayout.moveItem(id, blk.id, to))
            } else {
                const i = same.findIndex(n => n.id === info.id) + along
                if (i >= 0 && i < same.length)
                    barEditor.selectedItem = same[i].id
            }
        }

        function removeSelected() {
            const id = barEditor.selectedItem
            if (id === "" || id.indexOf("dash:") === 0 || !BarLayout.isPlaced(id))
                return
            const nav = root.navItems()
            const i = nav.findIndex(n => n.id === id)
            const near = nav[i + 1] && nav[i + 1].edge === nav[i].edge ? nav[i + 1] : (i > 0 && nav[i - 1].edge === nav[i].edge ? nav[i - 1] : null)
            barEditor.selectedItem = near ? near.id : ""
            Qt.callLater(() => BarLayout.hideItem(id))
        }

        function upLevel() {
            const sel = barEditor.selectedItem
            if (sel !== "" && sel.indexOf("dash:") !== 0) {
                const blk = BarLayout.allBlocks.find(b => b.items.indexOf(sel) >= 0)
                if (blk)
                    barEditor.selectedBlock = blk.id
                return
            }
            if (barEditor.selectedBlock !== "") {
                const blk = BarLayout.blockById(barEditor.selectedBlock)
                if (blk && drawerHost) {
                    drawerHost.edgeSide = blk.edge
                    drawerHost.tab = "edges"
                }
                barEditor.drawerMode = "settings"
                barEditor.selectedBlock = ""
            }
        }

        Item {
            id: editKeys
            anchors.fill: parent
            focus: layout.barEditing
        }

        Keys.onEscapePressed: event => {
            if (!layout.barEditing) {
                event.accepted = false
                return
            }
            if (barEditor.mode !== "") barEditor.cancel()
            else if (editChrome && editChrome.closeOverlays()) return
            else if (drawerHost && drawerHost.sidePage !== "") drawerHost.sidePage = ""
            else if (editChrome && editChrome.stageSideOpen()) return
            else if (editChrome && editChrome.closeAll()) return
            else if (barEditor.selectedItem !== "") barEditor.selectedItem = ""
            else if (barEditor.selectedBlock !== "") barEditor.selectedBlock = ""
            else GlobalStates.closeEdit()
        }
        Keys.onReleased: event => {
            if (!layout.barEditing) {
                event.accepted = false
                return
            }
            if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
                EditSession.peek = false
                event.accepted = true
            } else if (event.key === Qt.Key_Alt && !event.isAutoRepeat) {
                GlobalStates.showGaps = false
                root.queueGapMarks()
            }
        }
        Keys.onPressed: event => {
            if (!layout.barEditing) {
                event.accepted = false
                return
            }
            const ctrl = event.modifiers & Qt.ControlModifier
            const alt = event.modifiers & Qt.AltModifier
            const shift = event.modifiers & Qt.ShiftModifier
            const k = event.key
            if (k === Qt.Key_Alt) {
                if (!event.isAutoRepeat && !GlobalStates.showGaps) {
                    GlobalStates.showGaps = true
                    root.queueGapMarks()
                }
                event.accepted = true
                return
            }
            if (ctrl) {
                if (k === Qt.Key_Z && shift) EditSession.redo()
                else if (k === Qt.Key_Z) EditSession.undo()
                else if (k === Qt.Key_Y) EditSession.redo()
                else if (k === Qt.Key_S) GlobalStates.closeEdit()
                else return
                event.accepted = true
                return
            }
            if (barEditor.mode !== "")
                return
            if (k === Qt.Key_Space) {
                if (!event.isAutoRepeat) EditSession.peek = true
            } else if (k === Qt.Key_Question || k === Qt.Key_Slash) {
                GlobalStates.editKeysOpen = !GlobalStates.editKeysOpen
            } else if (k === Qt.Key_1) {
                GlobalStates.editLayer = "edges"
            } else if (k === Qt.Key_2) {
                GlobalStates.editLayer = "desktop"
            } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                root.cycleItem(k === Qt.Key_Backtab || shift ? -1 : 1)
            } else if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
                root.arrowItem(k, alt, shift)
            } else if (k === Qt.Key_Delete) {
                root.removeSelected()
            } else if (k === Qt.Key_Backspace) {
                root.upLevel()
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (barEditor.selectedItem === "" || barEditor.selectedItem.indexOf("dash:") === 0)
                    return
                if (editChrome)
                    barEditor.drawerFrom = editChrome.selRect
                barEditor.drawerMode = barEditor.drawerMode === "options" ? "" : "options"
            } else if (k === Qt.Key_A) {
                GlobalStates.editOpenAdd = "parts"
            } else {
                return
            }
            event.accepted = true
        }

    }

    property bool isToolsWidgetClicked: false
    property bool showOsd: false

    GlobalShortcut{
        name: "toolsWidget"
        onPressed:{
            if(Hyprland.focusedMonitor.name === layout.screen.name){
                layout.isToolsWidgetClicked = !layout.isToolsWidgetClicked
            }
        }
    }

    Loader {
        id: notifPopups
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: surfRight.visible && surfRight.present ? surfRight.bandRect.width : 0
        anchors.bottomMargin: surfBottom.visible && surfBottom.present && !surfBottom.autoHide ? surfBottom.bandRect.height : 0
        active: isPrimary && BarLayout.popupMode === "corner"
        sourceComponent: NotificationPanel {}
    }

    NotificationPopups {
        id: notifStyled
        anchors.fill: parent
        visible: isPrimary
        mode: BarLayout.popupMode
        surfaces: layout.surfaces
    }
}
