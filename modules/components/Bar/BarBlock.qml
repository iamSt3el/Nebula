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
    property string floatOpenerId: ""
    property string edge: "top"
    property Item frame: null
    readonly property bool bottomEdge: barBlock.edge === "bottom"
    readonly property bool far: barBlock.frame ? barBlock.frame.far : barBlock.bottomEdge
    readonly property bool vertical: barBlock.frame ? barBlock.frame.vertical : false
    readonly property real frameW: barBlock.frame ? barBlock.frame.width : layout.width
    readonly property real frameH: barBlock.frame ? barBlock.frame.height : layout.height
    readonly property real iconSize: barBlock.bottomEdge ? BarLayout.dockIconSize : 0

    function flipAbout(w, h) {
        return Qt.matrix4x4(0, 1, 0, (w - h) / 2, 1, 0, 0, (h - w) / 2, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    function mirrorAbout(w, h) {
        return barBlock.frame && barBlock.frame.side === "right"
            ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, h, 0, 0, 1, 0, 0, 0, 0, 1)
            : Qt.matrix4x4(-1, 0, 0, w, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    signal floatRequested(string kind, real centerX, string itemId)
    signal floatCloseRequested()
    signal gone()

    property var lastInfo: null
    readonly property var liveInfo: BarLayout.blockById(barBlock.blockId)
    onLiveInfoChanged: if (barBlock.liveInfo) barBlock.lastInfo = barBlock.liveInfo
    readonly property var info: barBlock.liveInfo ?? barBlock.lastInfo
    readonly property var itemIds: barBlock.info ? barBlock.info.items : []
    readonly property string anchorSide: barBlock.info ? barBlock.info.anchor : "left"

    readonly property bool editMode: GlobalStates.barEditMode && layout.isPrimary
    readonly property bool editing: barBlock.editMode && !barBlock.leaving
    // this block's slice of the edit-mode sweep, from its own place on the screen
    readonly property real revealT: GlobalStates.barRevealAt(barBlock.absX + barBlock.width / 2,
                                                             barBlock.frameW)
    readonly property bool handlesIn: barBlock.revealT > 0.55
    readonly property bool isPill: barBlock.bottomEdge ? BarLayout.dockStyle === "pill" : ServiceGaps.isPill
    readonly property real barH: barBlock.bottomEdge ? BarLayout.dockHeight : Appearance.size.barHeight
    readonly property real pad: barBlock.anchorSide === "center" ? 15 : 10

    readonly property string tintRole: BarLayout.blockStyle(barBlock.blockId, "tint", "none")
    readonly property real tintPad: BarLayout.blockStyle(barBlock.blockId, "pad", 4)
    readonly property real tintRadius: BarLayout.blockStyle(barBlock.blockId, "radius", -1)
    readonly property real gap: barBlock.bottomEdge ? BarLayout.dockItemGap : BarLayout.itemGap

    property string clickedKind: ""
    property string hoverKind: ""
    property string lastKind: ""
    property string shownKind: ""
    property int curSlot: 0
    readonly property Item curSlotItem: barBlock.curSlot === 0 ? slotA : slotB
    readonly property string loadKind: barBlock.curSlotItem ? barBlock.curSlotItem.kind : ""
    property string openerId: ""
    property string pendingKind: ""
    property Item pendingItem: null
    property bool pendingClicked: false
    property bool tabSnap: false
    property var itemLeaving: ({})
    property real srcX: 0
    property real srcW: 0

    readonly property bool hovering: blockHover.hovered || tabHover.hovered
    readonly property bool sysHost: barBlock.bottomEdge && layout.isPrimary && barBlock.blockId === BarLayout.sysHostId
    readonly property string sysKind: !barBlock.sysHost ? ""
        : GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") !== "center" ? "clipboard"
        : GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") !== "center" ? "wallpaper"
        : GlobalStates.osdOpen ? "osd" : ""
    function isSys(k) {
        return k === "clipboard" || k === "wallpaper" || k === "osd"
    }
    readonly property bool launchHost: layout.isPrimary && !barBlock.leaving
        && ServiceLauncher.position === "item" && barBlock.hasItem("launcher")
    function previewOpener(k) {
        return BarLayout.panelHostItem(k)
    }
    readonly property bool previewHost: layout.isPrimary && !barBlock.leaving && GlobalStates.panelPreview !== ""
        && (GlobalStates.panelPreview === "wallpaper" || GlobalStates.panelPreview === "clipboard" ? barBlock.sysHost
            : barBlock.hasItem(barBlock.previewOpener(GlobalStates.panelPreview)))
    readonly property string panelKind: barBlock.launchHost && GlobalStates.launcherPreview ? "launcher"
        : barBlock.previewHost ? GlobalStates.panelPreview
        : barBlock.editMode || barBlock.leaving ? ""
        : barBlock.sysKind !== "" ? barBlock.sysKind
        : barBlock.launchHost && GlobalStates.appLauncherOpen ? "launcher"
        : barBlock.clickedKind !== "" ? barBlock.clickedKind
        : barBlock.hovering ? barBlock.hoverKind : ""

    readonly property real openHeight: barBlock.frameH - (barBlock.isPill ? ServiceGaps.pillMargin * 2 : 0)
    readonly property real panelRoom: barBlock.openHeight - barBlock.barH - (barBlock.frame ? barBlock.frame.borderFar : 0)
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

    function itemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i)
            if (s && !s.leaving && s.itemId === id)
                return s.loaderItem
        }
        return null
    }

    function sourceFrom(item) {
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
        if (!barBlock.closing || barBlock.tabH > barBlock.barH + 0.5)
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
        const tx = barBlock.alignX(w, barBlock.srcX + barBlock.srcW / 2)
        let l = barBlock.srcX
        let r = barBlock.srcX + barBlock.srcW
        if (Math.abs(tx) <= 0.5)
            l = Math.min(l, 0)
        if (Math.abs(tx + w - barBlock.width) <= 0.5)
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
        if (barBlock.panelKind === kind) {
            barBlock.hoverKind = kind
            return
        }
        barBlock.beginOpen(kind, item ?? null, false)
    }

    Connections {
        target: GlobalStates
        function onDashboardRequested() {
            const id = BarLayout.panelHostItem("dashboard")
            if (!layout.isPrimary || !barBlock.hasItem(id) || barBlock.clickedKind === "dashboard")
                return
            const it = barBlock.itemFor(id)
            if (it)
                barBlock.openPanel("dashboard", it)
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
        if (barBlock.floatOpenerId !== "")
            barBlock.floatCloseRequested()
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

    HyprlandFocusGrab {
        windows: [QsWindow.window]
        active: barBlock.panelKind === "trayMenu" || barBlock.panelKind === "dockMenu"
            || (["sound", "network", "bluetooth", "brightness", "powerMode", "power", "battery", "soundscape", "scenes", "notifications", "dashboard", "weather"].indexOf(barBlock.panelKind) >= 0
                && barBlock.clickedKind === barBlock.panelKind
                && !barBlock.panelHeld)
            || (barBlock.panelKind === "tray" && barBlock.clickedKind === "tray")
        onCleared: {
            if (barBlock.panelHeld)
                return
            if (["trayMenu", "dockMenu", "tray", "sound", "network", "bluetooth", "brightness", "powerMode", "power", "battery", "soundscape", "scenes", "notifications", "dashboard", "weather"].indexOf(barBlock.panelKind) >= 0)
                barBlock.closePanel()
        }
    }

    function kindWidth(k) {
        switch (k) {
        case "dashboard": return BarLayout.panelW("dashboard")
        case "weather":   return BarLayout.panelW("weather")
        case "calendar":  return BarLayout.panelW("calendar")
        case "music":     return 440
        case "musicDevelop": return 460
        case "musicDrop": return 400
        case "musicButtons": return 480
        case "musicShelf": return Math.min(900, barBlock.widthRoom)
        case "musicCounter": return 420
        case "musicShape": return 440
        case "tray":      return 28 + barBlock.trayCols * 36 + (barBlock.trayCols - 1) * 6
        case "trayMenu":  return 260
        case "sound":     return 360
        case "soundscape": return 360
        case "scenes":    return 360
        case "network":   return 340
        case "bluetooth": return 340
        case "brightness": return 340
        case "powerMode": return 320
        case "battery":   return 400
        case "power":     return 340
        case "notifications": return 400
        case "dockPreview": return barBlock.dockPreviewWidth
        case "dockMenu":  return 210
        case "clipboard": return Appearance.size.wallpaperPanelWidth
        case "wallpaper": return Math.min(ServiceWallpaper.panelWidth, barBlock.widthRoom)
        case "osd":       return barBlock.vertical ? 60 : 300
        case "launcher":  return BarLayout.panelW("launcher")
        }
        return 0
    }

    function contentHeight(k) {
        switch (k) {
        case "dashboard": {
            const full = barBlock.heightRoom
            const it = barBlock.itemOf("dashboard")
            return BarLayout.panelHeightIn("dashboard",
                                           (it && it.anyFills === false) ? Math.min(full, it.implicitHeight) : full, full)
        }
        case "weather":   return BarLayout.panelHeightIn("weather",
                                                         barBlock.itemOf("weather") ? barBlock.itemOf("weather").implicitHeight : Appearance.size.weatherPanelHeight,
                                                         barBlock.heightCap("weather"))
        case "calendar":  return BarLayout.panelHeightIn("calendar", Appearance.size.calanderHeight, barBlock.heightRoom)
        case "music":     return 200
        case "musicDevelop": return 230
        case "musicDrop": return 380
        case "musicButtons": return 300
        case "musicShelf": return 108
        case "musicCounter": return 272
        case "musicShape": return 240
        case "tray":      return 28 + barBlock.trayRows * 36 + (barBlock.trayRows - 1) * 6
        case "trayMenu":  return barBlock.itemOf("trayMenu") ? barBlock.itemOf("trayMenu").implicitHeight : 160
        case "sound":     return barBlock.itemOf("sound") ? barBlock.itemOf("sound").implicitHeight : 420
        case "soundscape": return barBlock.itemOf("soundscape") ? barBlock.itemOf("soundscape").implicitHeight : 560
        case "scenes":    return barBlock.itemOf("scenes") ? barBlock.itemOf("scenes").implicitHeight : 420
        case "network":   return 460
        case "bluetooth": return 460
        case "brightness": return barBlock.itemOf("brightness") ? barBlock.itemOf("brightness").implicitHeight : 150
        case "powerMode": return barBlock.itemOf("powerMode") ? barBlock.itemOf("powerMode").implicitHeight + 28 : 316
        case "power":     return barBlock.itemOf("power") ? barBlock.itemOf("power").implicitHeight : 460
        case "notifications": return barBlock.itemOf("notifications") ? barBlock.itemOf("notifications").implicitHeight : 480
        case "battery":   return barBlock.itemOf("battery") ? barBlock.itemOf("battery").implicitHeight : 520
        case "dockPreview": return barBlock.itemOf("dockPreview") ? barBlock.itemOf("dockPreview").implicitHeight : 90
        case "dockMenu":  return barBlock.itemOf("dockMenu") ? barBlock.itemOf("dockMenu").implicitHeight : 150
        case "clipboard": return Appearance.size.wallpaperPanelHeight
        case "wallpaper": return ServiceWallpaper.panelHeight
        case "osd":       return barBlock.vertical ? 280 : 60
        case "launcher":  return Math.max(320, Math.min(BarLayout.panelH("launcher"), barBlock.heightRoom))
        }
        return 0
    }

    readonly property bool closing: barBlock.panelKind === ""
    property bool motionClosing: true
    readonly property string animKind: barBlock.motionClosing ? barBlock.lastKind : barBlock.panelKind
    readonly property bool panelMotion: barBlock.animKind !== ""
    readonly property int sizeDuration: barBlock.panelMotion && !barBlock.motionClosing
        ? M3Motion.panel.openDuration : M3Motion.spatialDuration("fast")
    readonly property var sizeCurve: !barBlock.panelMotion ? M3Motion.spatialCurve("fast")
        : barBlock.motionClosing ? M3Motion.panel.closeCurve
        : M3Motion.panel.openCurve

    readonly property int spanDuration: barBlock.panelMotion && barBlock.motionClosing
        ? M3Motion.panel.closeDuration : barBlock.sizeDuration
    readonly property var spanCurve: barBlock.sizeCurve
    readonly property int dropDuration: barBlock.spanDuration
    readonly property var dropCurve: barBlock.sizeCurve

    readonly property real panelCorner: barBlock.frame ? barBlock.frame.disX : 0
    function snapInL(x) {
        return x > 0.5 && x < barBlock.panelCorner
    }
    function snapInR(r) {
        const g = barBlock.width - r
        return g > 0.5 && g < barBlock.panelCorner
    }
    readonly property real tabNaturalW: barBlock.alongOf(barBlock.shownKind)
    readonly property real tabNaturalX: barBlock.alignX(barBlock.tabNaturalW, barBlock.srcX + barBlock.srcW / 2)
    readonly property real tabTargetW: {
        let l = barBlock.tabNaturalX
        let r = l + barBlock.tabNaturalW
        if (barBlock.snapInL(l))
            l = 0
        if (barBlock.snapInR(r))
            r = barBlock.width
        return r - l
    }
    function alignX(w, cx) {
        const x = cx - w / 2
        const sl = barBlock.spanL - barBlock.absX
        const sr = barBlock.spanR - barBlock.absX - w
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
        return atStart && atEnd ? "across" : farEdge && atStart ? "start" : farEdge && atEnd ? "end" : ""
    }

    property real tabX: barBlock.shownKind !== "" ? barBlock.tabTargetX
        : barBlock.revealMode === "" ? barBlock.srcEdgeX
        : barBlock.revealMode === "end" ? barBlock.revealX + barBlock.revealW : barBlock.revealX
    property real tabW: barBlock.shownKind !== "" ? barBlock.tabTargetW
        : barBlock.revealMode === "" ? barBlock.srcEdgeW
        : barBlock.revealMode === "across" ? barBlock.revealW : 0
    property real tabH: barBlock.shownKind !== "" ? barBlock.barH + barBlock.acrossOf(barBlock.shownKind)
        : barBlock.revealMode === "start" || barBlock.revealMode === "end" ? barBlock.revealH : barBlock.barH
    Behavior on tabX {
        enabled: !barBlock.tabSnap && !barBlock.resizing
        NumberAnimation {
            id: tabXAnim
            duration: barBlock.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: barBlock.spanCurve
            onRunningChanged: if (!running) barBlock.checkSettled()
        }
    }
    Behavior on tabW {
        enabled: !barBlock.tabSnap && !barBlock.resizing
        NumberAnimation {
            id: tabWAnim
            duration: barBlock.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: barBlock.spanCurve
            onRunningChanged: if (!running) barBlock.checkSettled()
        }
    }
    Behavior on tabH {
        enabled: !barBlock.tabSnap && !barBlock.resizing
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

    property Item dropSource: null
    property Item dropOwner: null
    property bool dropReleasing: false
    property real dropCenterHeld: 0
    readonly property real dropW: 32
    readonly property real dropHang: 26
    readonly property real dropCenter: {
        barBlock.slotLayout
        barBlock.width
        const s = barBlock.dropSource
        if (!s || !barBlock.dropOwner)
            return barBlock.dropReleasing ? barBlock.dropCenterHeld : 0
        let n = s
        for (let i = 0; i < 8 && n && n !== barBlock; i++) {
            n.x
            n.width
            n = n.parent
        }
        return s.mapToItem(barBlock, s.width / 2, 0).x
    }
    readonly property real dropX: barBlock.dropCenter - barBlock.dropW / 2
    readonly property bool dropWanted: !!barBlock.dropSource && !!barBlock.dropOwner && barBlock.dropOwner.playing
        && !barBlock.tabOpen && !barBlock.vertical && !barBlock.editing
        && !barBlock.coveredAt(barBlock.dropX, barBlock.dropW)
    property real dropDepth: barBlock.dropWanted ? barBlock.dropHang : 0
    Behavior on dropDepth { SpatialAnim {} }
    onDropDepthChanged: if (barBlock.dropReleasing && barBlock.dropDepth < 0.5) barBlock.dropReleasing = false

    function registerDrop(source, owner) {
        barBlock.dropReleasing = false
        barBlock.dropOwner = owner
        barBlock.dropSource = source
    }

    function releaseDrop(source) {
        if (barBlock.dropSource !== source)
            return
        if (barBlock.dropDepth > 0.5) {
            barBlock.dropCenterHeld = barBlock.dropCenter
            barBlock.dropReleasing = true
        }
        barBlock.dropSource = null
        barBlock.dropOwner = null
    }
    readonly property real tabPathH: barBlock.tabH

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
        let w = barBlock.pad * 2
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
        : barBlock.slotLayout.total + barBlock.pad * 2 + barBlock.dragExtra
    readonly property real collapsedWidth: barBlock.maxWidth > 0
        ? Math.min(barBlock.naturalWidth, barBlock.maxWidth)
        : barBlock.naturalWidth

    readonly property bool isDropTarget: !!barBlock.editor && barBlock.editor.mode === "item"
        && barBlock.editor.dropBlock === barBlock.blockId && !barBlock.editor.overDrawer
    readonly property bool refused: !!barBlock.editor && barBlock.editor.mode === "item"
        && barBlock.editor.refusedTarget === barBlock.blockId
    readonly property bool isDraggedBlock: !!barBlock.editor && barBlock.editor.mode === "block"
        && barBlock.editor.fromBlock === barBlock.blockId

    readonly property bool wanted: !barBlock.leaving && SettingsConfig.settingsReady
        && (barBlock.editMode || barBlock.panelKind !== "" || barBlock.shownCount > 0)
    property real presence: 0
    readonly property real pc: Math.max(0, barBlock.presence)
    Behavior on presence {
        enabled: BarLayout.settled
        SpatialAnim { speed: "default" }
    }

    visible: barBlock.pc > 0.001
    width: barBlock.implicitWidth * barBlock.pc
    implicitWidth: barBlock.collapsedWidth
    implicitHeight: barBlock.barH
    opacity: (barBlock.isDraggedBlock ? 0.35 : 1) * Math.min(1, barBlock.pc)

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
        barBlock.motionClosing = k === ""
        if (k === "launcher" && barBlock.tabH <= barBlock.barH + 0.5) {
            barBlock.snapSource(barBlock.itemFor("launcher"), "launcher")
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
        } else if (barBlock.isSys(k) && barBlock.tabH <= barBlock.barH + 0.5) {
            barBlock.snapSource(null, k)
            barBlock.openerId = ""
        }
        if (k !== "" && !barBlock.tabOpen) {
            const mode = barBlock.revealFor(k)
            barBlock.tabSnap = true
            barBlock.revealMode = mode
            barBlock.tabSnap = false
        } else if (k !== "") {
            barBlock.revealMode = ""
        }
        if (k !== "")
            barBlock.lastKind = k
        barBlock.shownKind = k
        barBlock.showContent(k)
    }

    function itemOf(k) {
        if (slotA.kind === k && slotA.item)
            return slotA.item
        if (slotB.kind === k && slotB.item)
            return slotB.item
        return null
    }

    property string residentKind: ""
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

    Binding {
        target: GlobalStates
        property: "launcherHosted"
        value: true
        when: barBlock.launchHost
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
        onClicked: GlobalStates.barEditMode = true
    }


    Item {
        id: tabHost
        x: barBlock.tabX
        y: barBlock.far ? barBlock.barH - barBlock.tabH : 0
        width: barBlock.tabW
        height: barBlock.tabH
        visible: barBlock.tabOpen
        clip: true

        HoverHandler {
            id: tabHover
            onHoveredChanged: if (!hovered && !blockHover.hovered) barBlock.hoverKind = ""
        }

        Item {
            id: panelClip
            x: 0
            y: barBlock.far ? 0 : barBlock.barH
            width: tabHost.width
            height: Math.max(0, tabHost.height - barBlock.barH)
            clip: true
            layer.enabled: barBlock.tabMoving && barBlock.panelCorner > 0
            layer.smooth: true
            layer.effect: GE.OpacityMask { maskSource: panelCornerMask }

            PanelSlot { id: slotA }
            PanelSlot { id: slotB }
        }

        Rectangle {
            id: panelCornerMask
            readonly property real r: Math.min(barBlock.panelCorner, width / 2, height / 2)
            visible: false
            width: panelClip.width
            height: panelClip.height
            color: "white"
            topLeftRadius: barBlock.far ? panelCornerMask.r : 0
            topRightRadius: barBlock.far ? panelCornerMask.r : 0
            bottomLeftRadius: barBlock.far ? 0 : panelCornerMask.r
            bottomRightRadius: barBlock.far ? 0 : panelCornerMask.r
        }

    }

    Item {
        id: dropArt
        readonly property real t: barBlock.dropDepth / barBlock.dropHang
        readonly property real side: barBlock.barH - 18 + 4 * dropArt.t
        readonly property real cy: barBlock.far
            ? barBlock.barH / 2 - (barBlock.barH / 2 + 10) * dropArt.t
            : barBlock.barH / 2 + (barBlock.barH / 2 + 10) * dropArt.t
        z: 2
        visible: (!!barBlock.dropSource || barBlock.dropReleasing) && !barBlock.editing && !barBlock.coveredAt(barBlock.dropX, barBlock.dropW)
        opacity: barBlock.dropSource ? 1 : dropArt.t
        x: Math.round(barBlock.dropCenter - dropArt.side / 2)
        y: Math.round(dropArt.cy - dropArt.side / 2)
        width: dropArt.side
        height: dropArt.side

        ClippingWrapperRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.surfaceContainerHighest

            Image {
                source: ServiceMusic.activeTrack?.artUrl ?? ""
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: barBlock.dropOwner && barBlock.dropOwner.playing ? 1 : 0.7
            }
        }
    }

    property bool resizing: false
    property string resizeKind: ""
    readonly property string sizeKind: !barBlock.editing ? ""
        : barBlock.launchHost && GlobalStates.launcherPreview && barBlock.shownKind === "launcher" ? "launcher"
        : barBlock.previewHost && barBlock.shownKind === GlobalStates.panelPreview && !!BarLayout.panelSpecs[barBlock.shownKind]
        ? barBlock.shownKind : ""
    readonly property bool sizeHandles: barBlock.sizeKind !== "" && (barBlock.resizing
        || (!tabXAnim.running && !tabWAnim.running && !tabHAnim.running))
    readonly property real tabContentTop: barBlock.far ? barBlock.barH - barBlock.tabH : barBlock.barH
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

    Rectangle {
        z: -1
        x: 0
        y: barBlock.tintPad
        width: barBlock.width
        height: Math.max(0, barBlock.barH - barBlock.tintPad * 2)
        visible: barBlock.tintRole !== "none" && barBlock.itemIds.length > 0
        radius: barBlock.tintRadius < 0 ? height / 2 : barBlock.tintRadius
        color: Qt.alpha(BarLayout.roleColor(barBlock.tintRole), 0.18)
        opacity: barBlock.coveredAt(0, barBlock.width) ? 0 : 1

        Behavior on opacity {
            enabled: BarLayout.settled
            EffectsAnim { speed: "fast" }
        }

        Behavior on color {
            EffectsColorAnim {}
        }
    }

    Item {
        id: rowClip
        width: barBlock.width
        height: barBlock.barH
        clip: true

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
                    readonly property real contentWidth: slot.ghost ? 28 : (slot.upright ? slot.rawH : slot.rawW)
                    readonly property real contentStart: slot.margin[0] + (slot.innerWidth - slot.contentWidth) / 2
                    readonly property real chipWidth: BarLayout.chipW(slot.itemId, slot.contentWidth,
                                                                     slot.contentHeight, barBlock.barH)
                    readonly property real chipHeight: BarLayout.chipH(slot.itemId, slot.contentHeight,
                                                                       barBlock.barH, slot.contentWidth)
                    readonly property real contentHeight: slot.upright ? slot.rawW : slot.rawH
                    readonly property real innerWidth: Math.max(slot.contentWidth, slot.chipWidth)
                    readonly property real revealT: GlobalStates.barRevealAt(
                        barBlock.absX + slot.x + slot.width / 2, barBlock.frameW)
                    readonly property bool selected: barBlock.editing && !!barBlock.editor
                        && barBlock.editor.selectedItem === slot.itemId
                    readonly property bool isOpener: (barBlock.clickedKind !== "" && barBlock.openerId === slot.itemId)
                        || (barBlock.floatOpenerId !== "" && barBlock.floatOpenerId === slot.itemId)

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
                    readonly property bool dimmed: barBlock.spotlitItem !== "" && !slot.selected
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

                    BarItemChip {
                        x: slot.margin[0]
                        anchors.verticalCenter: parent.verticalCenter
                        width: slot.innerWidth
                        height: barBlock.barH
                        itemId: slot.itemId
                        contentWidth: slot.contentWidth
                        contentHeight: slot.contentHeight
                        barH: barBlock.barH
                        shown: slot.itemShown
                        plateColor: slot.loaded && loader.item.plateOn === true
                                    ? loader.item.plateColor : "transparent"
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
                        opacity: slot.isOpener ? 0 : 1
                        Behavior on opacity {
                            EffectsAnim { speed: "fast" }
                        }
                        onLoaded: {
                            item.host = barBlock
                            if ("itemId" in item)
                                item.itemId = slot.itemId
                        }
                    }

                    MaterialIconSymbol {
                        id: ghostIcon
                        visible: slot.ghost && slot.revealT > 0.001
                        opacity: 0.6 * slot.revealT
                        x: slot.margin[0] + (28 - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        transform: barBlock.vertical ? [ghostFlip] : []

                        Matrix4x4 { id: ghostFlip; matrix: barBlock.flipAbout(ghostIcon.width, ghostIcon.height) }
                        content: slot.entry ? slot.entry.icon : ""
                        iconSize: 18
                        customColor: Colors.outline
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

                        SequentialAnimation {
                            running: slot.selected
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) selRing.opacity = 1

                            NumberAnimation {
                                target: selRing
                                property: "opacity"
                                from: 1
                                to: 0.35
                                duration: 700
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: selRing
                                property: "opacity"
                                from: 0.35
                                to: 1
                                duration: 700
                                easing.type: Easing.InOutSine
                            }
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
        readonly property real clipX: tabHost.x
        readonly property real clipY: tabHost.y + panelClip.y
        readonly property real fw: barBlock.vertical ? slot.height : slot.width
        readonly property real fh: barBlock.vertical ? slot.width : slot.height
        readonly property real slideY: barBlock.far ? Math.max(0, panelClip.height - slot.fh)
                                                    : Math.min(0, panelClip.height - slot.fh)
        readonly property real pinY: barBlock.far ? panelClip.height - slot.fh : 0
        property real reveal: 1
        property real drift: 0

        function enter() {
            if (!slot.shown)
                return
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
        transform: barBlock.vertical ? [slotFlip] : []

        Matrix4x4 { id: slotFlip; matrix: Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

        onShownChanged: {
            if (slot.shown) {
                slotCache.stop()
                slot.homeX = Qt.binding(() => barBlock.tabX + (barBlock.tabW - slot.fw) / 2)
                slot.enter()
            } else {
                slotCache.restart()
                slot.homeX = slot.homeX
            }
        }

        width: barBlock.kindWidth(slot.kind)
        height: barBlock.contentHeight(slot.kind)

        x: Math.round(slot.homeX) - slot.clipX
        y: Math.round(slot.clipY + (slot.shown ? slot.pinY + (barBlock.far ? slot.drift : -slot.drift) : slot.slideY)) - slot.clipY
        active: slot.kind !== ""
        asynchronous: true
        opacity: slot.shown ? 1 : 0
        visible: slot.opacity > 0.01
        z: slot.shown ? 1 : 0


        Timer {
            id: slotCache
            interval: 30000
            onTriggered: if (!slot.shown && slot.kind !== barBlock.residentKind) slot.kind = ""
        }

        Behavior on opacity {
            enabled: slot.opacity > 0.5
            EffectsAnim { speed: "default" }
        }

        sourceComponent: {
            switch (slot.kind) {
            case "calendar":  return calendarComp
            case "music":     return musicComp
            case "musicDevelop": return musicDevelopComp
            case "musicDrop": return musicDropComp
            case "musicButtons": return musicButtonsComp
            case "musicShelf": return musicShelfComp
            case "musicCounter": return musicCounterComp
            case "musicShape": return musicShapeComp
            case "tray":      return trayComp
            case "trayMenu":  return trayMenuComp
            case "sound":     return soundComp
            case "soundscape": return soundscapeComp
            case "scenes":    return scenesComp
            case "network":   return networkComp
            case "bluetooth": return bluetoothComp
            case "brightness": return brightnessComp
            case "powerMode": return powerModeComp
            case "power":     return powerComp
            case "notifications": return notificationsComp
            case "battery":   return batteryComp
            case "dockPreview": return dockPreviewComp
            case "dockMenu":  return dockMenuComp
            case "weather":   return weatherComp
            case "dashboard": return dashboardComp
            case "clipboard": return (SettingsConfig.general.clipboardStyle ?? "list") === "fan" ? clipFanComp
                : (SettingsConfig.general.clipboardStyle ?? "list") === "board" ? clipBoardComp : clipComp
            case "wallpaper": return wallComp
            case "osd":       return osdComp
            case "launcher":  return launcherComp
            }
            return null
        }
    }

    Component {
        id: calendarComp
        Item {
            id: calHost
            anchors.fill: parent
            readonly property string calStyle: BarLayout.opt("clock", "panel") ?? "rail"
            Loader {
                anchors.fill: parent
                sourceComponent: calHost.calStyle === "rail" ? calRailComp : calAltComp
            }
            Component { id: calRailComp; Calander {} }
            Component { id: calAltComp; CalendarPanelAlt { style: calHost.calStyle } }
        }
    }
    Component { id: musicComp;     BarMusicPanel {} }
    Component { id: musicDevelopComp; BarMusicPanelDevelop {} }
    Component { id: musicDropComp; BarMusicPanelDrop {} }
    Component { id: musicButtonsComp; BarMusicPanelButtons {} }
    Component { id: musicShelfComp; BarMusicPanelShelf {} }
    Component { id: musicCounterComp; BarMusicPanelCounter {} }
    Component { id: musicShapeComp; BarMusicPanelShape {} }
    Component {
        id: trayComp
        Item {
            SystemTray {
                anchors.centerIn: parent
                columns: 6
                spacing: 6
                iconPx: 20
                plate: 36
                offset: barBlock.trayOffset
                onMenuRequested: (it, src) => barBlock.openTrayMenu(it, null)
                onActivated: barBlock.closePanel()
            }
        }
    }
    Component {
        id: dockPreviewComp
        DockPreview {
            appEntry: barBlock.dockAppEntry
            maxWidth: barBlock.dockPreviewCap
            onActivated: barBlock.closePanel()
        }
    }
    Component {
        id: dockMenuComp
        CustomContextMenu {
            appEntry: barBlock.dockAppEntry
            onClose: barBlock.closePanel()
        }
    }
    Component {
        id: networkComp
        Wifi {
            showBack: false
            onBackClicked: barBlock.closePanel()
        }
    }
    Component {
        id: bluetoothComp
        Bluetooth {
            showBack: false
            onBackClicked: barBlock.closePanel()
        }
    }
    Component { id: brightnessComp; BarBrightnessPanel {} }
    Component { id: powerModeComp; ModesPanel { onBackClicked: barBlock.closePanel() } }
    Component { id: powerComp;     BarPowerPanel {} }
    Component {
        id: notificationsComp
        BarNotificationsPanel {
            maxHeight: Math.max(320, barBlock.openHeight - barBlock.barH - 40)
        }
    }
    Component { id: batteryComp;   BarBatteryPanel {} }
    Component {
        id: soundComp
        BarSoundPanel {
            maxHeight: Math.max(240, barBlock.openHeight - barBlock.barH - 40)
        }
    }
    Component {
        id: scenesComp
        BarScenesPanel {
            maxHeight: Math.max(240, barBlock.openHeight - barBlock.barH - 40)
        }
    }
    Component {
        id: soundscapeComp
        BarSoundscapePanel {
            maxHeight: Math.max(240, barBlock.openHeight - barBlock.barH - 40)
        }
    }
    Component {
        id: trayMenuComp
        TrayMenuContent {
            handle: barBlock.trayMenuAlive ? barBlock.trayMenuItem.menu : null
            title: barBlock.trayMenuAlive ? (barBlock.trayMenuItem.tooltipTitle || barBlock.trayMenuItem.title
                                             || barBlock.trayMenuItem.id || "") : ""
            maxHeight: Math.max(160, barBlock.openHeight - barBlock.barH - 40)
            onDone: barBlock.closePanel()
        }
    }
    Component { id: weatherComp;   WeatherPanel { onClosed: barBlock.closePanel() } }
    Component {
        id: dashboardComp
        Dashboard {
            editing: GlobalStates.dashboardPreview
            onToggleDashboard: barBlock.closePanel()
        }
    }
    Component {
        id: clipComp
        ClipboardContent {
            bottomLeftRadius: barBlock.isPill ? 20 : 0
            bottomRightRadius: barBlock.isPill ? 20 : 0
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: clipFanComp
        ClipboardFan {
            bottomLeftRadius: barBlock.isPill ? 20 : 0
            bottomRightRadius: barBlock.isPill ? 20 : 0
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: clipBoardComp
        ClipboardBoard {
            bottomLeftRadius: barBlock.isPill ? 20 : 0
            bottomRightRadius: barBlock.isPill ? 20 : 0
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: wallComp
        WallpaperContent {
            bottomLeftRadius: barBlock.isPill ? Appearance.radius.large : 0
            bottomRightRadius: barBlock.isPill ? Appearance.radius.extraLarge : 0
        }
    }
    Component { id: osdComp; OsdContent { vertical: barBlock.vertical } }
    Component {
        id: launcherComp
        AppLauncherContent {
            preview: GlobalStates.launcherPreview
            enabled: !GlobalStates.launcherPreview
            onClosed: GlobalStates.appLauncherOpen = false
        }
    }

    Shape {
        z: 40
        x: 0
        y: 0
        width: barBlock.width
        height: barBlock.barH
        visible: barBlock.revealT > 0.001
        opacity: barBlock.revealT
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: barBlock.refused ? Colors.error : Colors.primary
            strokeWidth: barBlock.isDropTarget || barBlock.refused ? 2 : 1.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: barBlock.refused ? Qt.alpha(Colors.error, 0.12)
                : Qt.alpha(Colors.primary, barBlock.isDropTarget ? 0.16 : 0.06)

            PathRectangle {
                x: 2
                y: 3
                width: Math.max(0, barBlock.width - 4)
                height: barBlock.barH - 6
                radius: 14
            }
        }
    }

    MouseArea {
        id: editArea
        z: 50
        x: 0
        y: 0
        width: barBlock.width
        height: barBlock.barH
        enabled: barBlock.editing
        visible: barBlock.editing
        cursorShape: barBlock.editor && barBlock.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property string pressId: ""
        property int pressList: -1
        property Item pressGrab: null
        property string pressGrabId: ""
        property real pressW: 28
        property real pressX: 0
        property real pressY: 0
        property string pressApp: ""
        property bool pressAppPinned: false
        property real pressAppW: 0

        function clearPress() {
            editArea.pressId = ""
            editArea.pressList = -1
            editArea.pressApp = ""
            editArea.pressAppPinned = false
            editArea.pressGrab = null
            editArea.pressGrabId = ""
        }

        onPressed: mouse => {
            const s = barBlock.slotUnder(mouse.x)
            editArea.pressId = s ? s.itemId : ""
            editArea.pressList = s ? s.listIndex : -1
            editArea.pressW = s ? s.width : 28
            editArea.pressApp = ""
            editArea.pressAppPinned = false
            if (s && BarLayout.baseId(s.itemId) === "dockApps" && s.loaderItem) {
                const lx = mouse.x - (barBlock.pad + s.x + s.contentStart)
                const r = s.loaderItem.appRects.find(a => lx >= a.x && lx <= a.x + a.w)
                if (r) {
                    editArea.pressApp = r.appId
                    editArea.pressAppPinned = r.pinned
                    editArea.pressAppW = r.w
                }
            }
            editArea.pressX = mouse.x
            editArea.pressY = mouse.y
            const ed = barBlock.editor
            if (ed) {
                ed.liftUrl = ""
                ed.liftFor = ""
                const it = s && editArea.pressApp === "" ? s.loaderItem : null
                if (it && it.width > 0 && it.height > 0) {
                    const lp = editArea.mapToItem(it, mouse.x, mouse.y)
                    ed.liftDX = lp.x
                    ed.liftDY = lp.y
                    ed.liftW = it.width
                    ed.liftH = it.height
                    editArea.pressGrab = it
                    editArea.pressGrabId = s.itemId
                } else {
                    editArea.pressGrab = null
                    editArea.pressGrabId = ""
                }
            }
        }
        onPositionChanged: mouse => {
            if (!editArea.pressed)
                return
            const e = barBlock.editor
            if (e.mode === "" && Math.hypot(mouse.x - editArea.pressX, mouse.y - editArea.pressY) > 4) {
                if (editArea.pressApp !== "")
                    e.beginApp(editArea.pressApp, editArea.pressAppPinned, editArea.pressAppW)
                else if (editArea.pressList >= 0) {
                    const it = editArea.pressGrab
                    const want = editArea.pressGrabId
                    if (it && it.width > 0 && it.height > 0)
                        it.grabToImage(r => {
                            e.liftUrl = r.url
                            e.liftFor = want
                        })
                    e.beginItem(editArea.pressId, barBlock.blockId, editArea.pressList, editArea.pressW)
                }
            }
            if (e.mode !== "") {
                const p = editArea.mapToItem(null, mouse.x, mouse.y)
                e.update(p.x, p.y)
            }
        }
        onReleased: {
            const id = editArea.pressId
            const app = editArea.pressApp
            const pinned = editArea.pressAppPinned
            editArea.clearPress()
            if (barBlock.editor.mode !== "")
                barBlock.editor.finish()
            else if (app !== "" && !pinned)
                Qt.callLater(() => ServiceApps.pinById(app))
            else
                barBlock.editor.selectedItem = id
        }
        onCanceled: {
            editArea.clearPress()
            barBlock.editor.cancel()
        }
    }

    Item {
        id: gripClip
        z: 60
        readonly property real across: barBlock.vertical ? gripPill.width : gripPill.height
        x: -60
        width: barBlock.width + 120
        y: barBlock.far ? -(gripClip.across + 12) : barBlock.barH
        height: gripClip.across + 12
        clip: true
        visible: barBlock.revealT > 0.001 && gripPill.slide > 0.01

        Rectangle {
            id: gripPill
            readonly property bool shown: barBlock.handlesIn && !barBlock.tabOpen
                && GlobalStates.panelPreview === "" && !GlobalStates.launcherPreview
            property real slide: gripPill.shown ? 1 : 0
            Behavior on slide { SpatialAnim { speed: "fast" } }
            opacity: Math.max(0, Math.min(1, gripPill.slide * 2))
            readonly property real across: barBlock.vertical ? width : height
            readonly property real off: (1 - gripPill.slide) * (gripPill.across + 8) * (barBlock.far ? 1 : -1)
            y: (barBlock.far ? gripClip.height - 6 - across : 6) + (across - height) / 2 + gripPill.off
            anchors.horizontalCenter: parent.horizontalCenter
            width: handleRow.implicitWidth + 8
            height: 28
            transform: barBlock.vertical ? [gripFlip] : []

            Matrix4x4 { id: gripFlip; matrix: barBlock.flipAbout(gripPill.width, gripPill.height) }
            radius: 14
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colors.outline, 0.25)

            Row {
                id: handleRow
                anchors.centerIn: parent
                spacing: 2

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: gripArea.containsMouse || gripArea.pressed ? Qt.alpha(Colors.primary, 0.16) : "transparent"

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "drag_indicator"
                        iconSize: 16
                        customColor: Colors.surfaceText
                    }

                    MouseArea {
                        id: gripArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            barBlock.editor.beginBlock(barBlock.blockId)
                            const p = gripArea.mapToItem(null, mouse.x, mouse.y)
                            barBlock.editor.update(p.x, p.y)
                        }
                        onPositionChanged: mouse => {
                            if (!gripArea.pressed)
                                return
                            const p = gripArea.mapToItem(null, mouse.x, mouse.y)
                            barBlock.editor.update(p.x, p.y)
                        }
                        onReleased: barBlock.editor.finish()
                        onCanceled: barBlock.editor.cancel()
                    }

                    CustomToolTip { content: "Drag to move this block"; visible: gripArea.containsMouse && !gripArea.pressed }
                }

                Rectangle {
                    visible: barBlock.bottomEdge || BarLayout.blocks.length > 1
                    width: 24
                    height: 24
                    radius: 12
                    color: removeArea.containsMouse ? Qt.alpha(Colors.error, 0.16) : "transparent"

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"
                        iconSize: 16
                        customColor: removeArea.containsMouse ? Colors.error : Colors.surfaceText
                    }

                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const id = barBlock.blockId
                            Qt.callLater(() => BarLayout.removeBlock(id))
                        }
                    }

                    CustomToolTip { content: "Remove block · its items go to the drawer"; visible: removeArea.containsMouse }
                }
            }
        }
    }
}
