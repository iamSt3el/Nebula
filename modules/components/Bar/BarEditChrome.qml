pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit

Item {
    id: chrome
    anchors.fill: parent

    property QtObject editor: null
    property var surfaces: []
    readonly property Item surfTop: chrome.surfaces.find(s => s && s.edge === "top") ?? null
    readonly property Item surfBottom: chrome.surfaces.find(s => s && s.edge === "bottom") ?? null
    readonly property Item surfLeft: chrome.surfaces.find(s => s && s.edge === "left") ?? null
    readonly property Item surfRight: chrome.surfaces.find(s => s && s.edge === "right") ?? null
    readonly property real insetLeft: chrome.surfLeft && chrome.surfLeft.visible && chrome.surfLeft.present ? chrome.surfLeft.thickness : 0
    readonly property real insetRight: chrome.surfRight && chrome.surfRight.visible && chrome.surfRight.present ? chrome.surfRight.thickness : 0
    property bool editing: false
    property bool previewRight: true

    readonly property string sel: chrome.editor ? chrome.editor.selectedItem : ""
    readonly property string selBlock: chrome.editor ? chrome.editor.selectedBlock : ""
    readonly property bool dragging: chrome.editor !== null && chrome.editor.mode !== ""
    readonly property bool stage: chrome.editor !== null && chrome.editor.panelStage
    readonly property bool drawerShown: chrome.editor !== null && chrome.editor.drawerMode !== ""

    property bool shelfOpen: false
    property string pop: ""
    property real t: 0

    visible: chrome.t > 0.01
    opacity: EditSession.peek ? 0 : 1
    Behavior on opacity { EffectsAnim { speed: "fast" } }
    Behavior on t { SpatialAnim { speed: "default" } }

    onEditingChanged: {
        chrome.t = chrome.editing ? 1 : 0
        chrome.shelfOpen = false
        chrome.resetArmed = false
        chrome.pop = ""
        if (chrome.editing) Qt.callLater(chrome.takeOpenAdd)
    }

    function takeOpenAdd() {
        if (!chrome.editing || GlobalStates.editOpenAdd !== "parts")
            return
        GlobalStates.editOpenAdd = ""
        chrome.pop = ""
        if (chrome.editor) {
            chrome.editor.drawerMode = ""
            chrome.editor.panelStage = false
        }
        chrome.shelfOpen = true
    }

    Connections {
        target: GlobalStates
        function onEditOpenAddChanged() { chrome.takeOpenAdd() }
    }
    onSelChanged: chrome.pop = ""
    onSelBlockChanged: chrome.pop = ""

    readonly property rect shelfRect: shelf.visible ? Qt.rect(shelf.x, shelf.y, shelf.width, shelf.height) : Qt.rect(0, 0, 0, 0)

    function closeOverlays() {
        if (GlobalStates.editKeysOpen) { GlobalStates.editKeysOpen = false; return true }
        return capRow.closeAll()
    }

    function closeAll() {
        if (chrome.closeOverlays()) return true
        if (chrome.pop !== "") { chrome.pop = ""; return true }
        if (lanes.popSurf !== null) { lanes.closePop(); return true }
        if (chrome.resetArmed) { chrome.resetArmed = false; return true }
        if (chrome.shelfOpen) { chrome.shelfOpen = false; return true }
        if (chrome.editor && chrome.editor.drawerMode !== "") { chrome.editor.drawerMode = ""; return true }
        if (chrome.stage) { chrome.editor.panelStage = false; return true }
        return false
    }

    readonly property var panelList: [
        { item: "clock",         kind: "calendar",      label: "Calendar",      icon: "calendar_month" },
        { item: "weather",       kind: "weather",       label: "Weather",       icon: "partly_cloudy_day" },
        { item: "notifications", kind: "notifications", label: "Notifications", icon: "notifications" },
        { item: "dashboard",     kind: "dashboard",     label: "Dashboard",     icon: "space_dashboard" },
        { item: "launcher",      kind: "launcher",      label: "Apps",          icon: "apps" },
        { item: "wallpaper",     kind: "wallpaper",     label: "Wallpaper",     icon: "wallpaper" },
        { item: "clipboard",     kind: "clipboard",     label: "Clipboard",     icon: "content_paste" },
        { item: "popups",        kind: "notifPopup",    label: "Popups",        icon: "notifications_active" },
        { item: "osd",           kind: "osd",           label: "OSD",           icon: "volume_up" }
    ]

    function panelOf(id) {
        const k = BarLayout.panelFor(id)
        if (k !== "")
            return chrome.panelList.find(p => p.kind === k) ?? null
        const base = id ? BarLayout.baseId(id) : ""
        return chrome.panelList.find(p => p.item === base && (p.kind === "notifPopup" || p.kind === "osd")) ?? null
    }

    function toggleOptsOf(id) {
        const e = id && id.indexOf("dash:") !== 0 ? BarLayout.entry(id) : null
        return e && e.options ? e.options.filter(o => o.type === "toggle" && o.key !== "showLabel") : []
    }

    function blockOfItem(id) {
        return BarLayout.allBlocks.find(b => b.id !== "__sys" && b.items.indexOf(id) >= 0) ?? null
    }

    function hostOf(p) {
        const placed = id => id !== "" && BarLayout.isPlaced(id)
        const gen = SettingsConfig.general ?? {}
        switch (p.kind) {
        case "calendar":
        case "weather":
        case "notifications":
        case "dashboard":
            return placed(p.item) ? { type: "item", item: p.item } : { type: "none", item: "" }
        case "launcher":
            return BarLayout.launcherItemHost ? { type: "item", item: "launcher" } : { type: "center", item: "" }
        case "wallpaper":
        case "clipboard": {
            const mode = p.kind === "wallpaper" ? gen.wallpaperPanelMode : gen.clipboardPanelMode
            if ((mode ?? "dock") === "center")
                return { type: "center", item: "" }
            return BarLayout.panelItemHost(p.kind) ? { type: "item", item: p.item } : { type: "sys", item: "" }
        }
        case "notifPopup":
            if (BarLayout.popupMode === "item" || (BarLayout.popupMode === "island" && BarLayout.popupHostItem !== ""))
                return { type: "item", item: BarLayout.popupHostItem }
            return BarLayout.popupMode === "icon" ? { type: "icons", item: "" } : { type: "corner", item: "" }
        case "osd":
            return BarLayout.osdHostItem !== "" ? { type: "item", item: BarLayout.osdHostItem } : { type: "sys", item: "" }
        }
        return { type: "none", item: "" }
    }

    function hostText(p) {
        const h = chrome.hostOf(p)
        const name = id => {
            const e = BarLayout.entry(id)
            return e ? e.label : id
        }
        switch (h.type) {
        case "item": return h.item === p.item || BarLayout.baseId(h.item) === p.item
            ? "From its " + name(p.item) + " item" : "From the " + name(h.item) + " item"
        case "sys": return "Centre of the " + BarLayout.sysEdge + " edge"
        case "center": return "Centre of the screen"
        case "icons": return "Over the app's dock icon"
        case "corner": return "Screen corner"
        }
        return "Its " + name(p.item) + " item isn't placed"
    }

    function dragItemOf(p) {
        return p.item
    }

    function startPinDrag(p, mx, my, w) {
        const item = chrome.dragItemOf(p)
        const blk = chrome.blockOfItem(item)
        chrome.editor.beginItem(item, blk ? blk.id : "", blk ? blk.items.indexOf(item) : -1, w)
        chrome.editor.update(mx, my)
    }

    function finishPinDrag(p) {
        const e = chrome.editor
        const landed = e.dropBlock !== "" && !e.overDrawer
        e.finish()
        if (!landed)
            return
        if (p.kind === "launcher")
            BarLayout.setOption("launcher", "position", "item")
        else if (p.kind === "wallpaper" || p.kind === "clipboard")
            BarLayout.setOption(p.item, "place", "dock")
    }

    function openRects() {
        const out = []
        for (const s of chrome.surfaces) {
            if (!s || !s.visible)
                continue
            for (const blk of s.visibleBlocks)
                if (blk.tabH > blk.barH + 1)
                    out.push(s.tabRect(blk))
        }
        return out
    }

    function toolRects() {
        const out = []
        for (const t of [toolbar, blockBar, styleCard, cornersCard, tintCard, blockCard])
            if (t.visible)
                out.push(Qt.rect(t.x, t.y, t.width, t.height))
        return out
    }

    function openStage(itemId) {
        if (!chrome.editor) return
        chrome.shelfOpen = false
        chrome.pop = ""
        chrome.editor.drawerMode = ""
        chrome.editor.selectedItem = itemId
        chrome.editor.panelStage = true
    }

    readonly property var tints: [
        { value: "none",        label: "None" },
        { value: "primary",     label: "Primary" },
        { value: "secondary",   label: "Secondary" },
        { value: "tertiary",    label: "Tertiary" },
        { value: "surfaceText", label: "Neutral" }
    ]

    function undo() { EditSession.undo() }
    function redo() { EditSession.redo() }

    function avoidCap(x, w, y, h) {
        const cx = capsule.restX
        const cw = capsule.fullW
        const cy = capsule.restY
        const lo = 12
        const hi = chrome.height - h - 12
        let out = Math.max(lo, Math.min(hi, y))
        if (x + w <= cx - 8 || x >= cx + cw + 8)
            return out
        if (out < cy + 56 + 12 && out + h > cy - 12)
            out = capsule.lowered ? Math.min(out, cy - h - 12) : Math.max(out, cy + 56 + 12)
        return Math.max(lo, Math.min(hi, out))
    }

    readonly property real cardTop: capsule.lowered ? capsule.topY : capsule.topY + 56 + 14

    function besideX(w) {
        const r = chrome.selRect
        if (chrome.selEdge === "left")
            return Math.max(12, Math.min(chrome.width - w - 12, r.x + r.width + 28))
        if (chrome.selEdge === "right")
            return Math.max(12, r.x - w - 28)
        return Math.max(12, Math.min(chrome.width - w - 12, r.x + r.width / 2 - w / 2))
    }

    function besideY(w, h) {
        const r = chrome.selRect
        const x = chrome.besideX(w)
        if (chrome.selEdge === "left" || chrome.selEdge === "right")
            return chrome.avoidCap(x, w, r.y + r.height / 2 - h / 2, h)
        if (chrome.selEdge === "bottom")
            return chrome.avoidCap(x, w, r.y - h - 28, h)
        return chrome.avoidCap(x, w, r.y + r.height + 28, h)
    }

    property rect selRect: Qt.rect(0, 0, 0, 0)
    property string selEdge: "top"
    property bool selFound: false

    function locate() {
        const id = chrome.sel
        for (const surf of chrome.surfaces) {
            if (!surf || !surf.visible) continue
            for (const b of surf.visibleBlocks) {
                if (!b.hasItem(id)) continue
                const it = b.itemFor(id)
                if (!it) continue
                chrome.selRect = it.mapToItem(chrome, 0, 0, it.width, it.height)
                chrome.selEdge = surf.side
                chrome.selFound = true
                return
            }
        }
        chrome.selFound = false
    }

    Timer {
        interval: 60
        repeat: true
        running: chrome.editing && chrome.sel !== ""
        triggeredOnStart: true
        onTriggered: chrome.locate()
    }

    property rect blockRect: Qt.rect(0, 0, 0, 0)
    property string blockEdge: "top"
    property bool blockFound: false

    function locateBlock() {
        for (const surf of chrome.surfaces) {
            if (!surf || !surf.visible) continue
            const b = surf.visibleBlocks.find(v => v.blockId === chrome.selBlock)
            if (!b) continue
            chrome.blockRect = b.mapToItem(chrome, 0, 0, b.width, b.barH)
            chrome.blockEdge = surf.side
            chrome.blockFound = true
            return
        }
        chrome.blockFound = false
    }

    Timer {
        interval: 60
        repeat: true
        running: chrome.editing && chrome.selBlock !== ""
        triggeredOnStart: true
        onTriggered: chrome.locateBlock()
    }


    function addTarget(id) {
        const real = BarLayout.allBlocks.filter(b => b.id !== "__sys")
        if (chrome.selBlock !== "") {
            const blk = real.find(b => b.id === chrome.selBlock)
            if (blk)
                return { block: blk.id, index: blk.items.length }
        }
        if (chrome.sel !== "") {
            const own = real.find(b => b.items.indexOf(chrome.sel) >= 0)
            if (own)
                return { block: own.id, index: own.items.indexOf(chrome.sel) + 1 }
        }
        const entry = BarLayout.entry(id)
        const dockish = !!entry && entry.id.indexOf("dock") === 0
        const onEdge = real.filter(b => b.edge === (dockish ? "bottom" : "top"))
        const blocks = onEdge.length > 0 ? onEdge : real
        const pref = blocks.find(b => b.anchor === "right") ?? blocks.find(b => b.anchor === "center") ?? blocks[0]
        return pref ? { block: pref.id, index: pref.items.length } : null
    }

    function addItem(id) {
        const tgt = chrome.addTarget(id)
        if (!tgt) return
        Qt.callLater(() => {
            BarLayout.moveItem(id, tgt.block, tgt.index)
            if (!BarLayout.entry(id) || !BarLayout.entry(id).multi)
                chrome.editor.selectedItem = id
        })
    }

    BarEdgeLanes {
        id: lanes
        host: chrome
    }

    BarEditPins {
        id: pins
        host: chrome
    }

    MouseArea {
        anchors.fill: parent
        visible: chrome.pop !== "" || capRow.moreOpen
        onClicked: {
            chrome.pop = ""
            capRow.moreOpen = false
            chrome.resetArmed = false
        }
    }

    EditKit.Card {
        id: capsule
        readonly property Item floor: chrome.surfBottom && chrome.surfBottom.visible && chrome.surfBottom.present ? chrome.surfBottom : null
        readonly property real dockTop: capsule.floor ? capsule.floor.bandRect.y : chrome.height
        readonly property real topY: chrome.surfTop && chrome.surfTop.visible && chrome.surfTop.present
            ? chrome.surfTop.thickness + (chrome.topGrips ? 46 : 16)
            : chrome.surfTop && chrome.surfTop.visible ? 56 : 20
        readonly property bool lowered: !(chrome.bottomBusy && !chrome.topBusy)
        function spans(x, w) {
            return x < capsule.restX + capsule.fullW + 8 && x + w > capsule.restX - 8
        }
        readonly property real yieldTo: {
            let b = 0
            if (toolbar.shown && !toolbar.side && toolbar.below && capsule.spans(toolbar.x, toolbar.width))
                b = Math.max(b, chrome.selRect.y + chrome.selRect.height + 16 + toolbar.height)
            if (blockBar.shown && !blockBar.side && blockBar.below && capsule.spans(blockBar.x, blockBar.width))
                b = Math.max(b, chrome.blockRect.y + chrome.blockRect.height + 42 + blockBar.height)
            return b
        }
        readonly property real restY: capsule.lowered ? capsule.dockTop - 56 - 52
            : Math.max(capsule.topY, capsule.yieldTo > 0 ? capsule.yieldTo + 14 : 0)
        property real restYAnim: capsule.restY
        Behavior on restYAnim { SpatialAnim { speed: "move" } }
        readonly property real fullW: capRow.implicitWidth + 12
        readonly property real restX: (chrome.width - capsule.fullW) / 2 + chrome.capShift

        property real capT: chrome.editing ? 1 : 0
        Behavior on capT {
            NumberAnimation {
                duration: chrome.editing ? 560 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: chrome.editing ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        readonly property real wipe: Math.max(0, Math.min(1, (capsule.capT - 0.5) / 0.5))
        readonly property rect dockRect: {
            chrome.editing
            const f = capsule.floor
            if (!f)
                return Qt.rect(0, 0, 0, 0)
            let l = 1e9
            let r = -1e9
            let top = 1e9
            for (const blk of f.visibleBlocks) {
                const q = blk.mapToItem(chrome, 0, 0, blk.width, blk.height)
                l = Math.min(l, q.x)
                r = Math.max(r, q.x + q.width)
                top = Math.min(top, q.y)
            }
            return l < r ? Qt.rect(l, top, r - l, 0) : Qt.rect(0, 0, 0, 0)
        }
        readonly property bool fromDock: capsule.dockRect.width > 0 && capsule.lowered
        readonly property real startW: capsule.fromDock ? Math.min(capsule.fullW, capsule.dockRect.width) : capsule.fullW * 0.6
        readonly property real startX: capsule.fromDock ? capsule.dockRect.x + capsule.dockRect.width / 2 - capsule.startW / 2
                                                        : (chrome.width - capsule.startW) / 2
        readonly property real startY: capsule.fromDock ? capsule.dockRect.y - 4 : capsule.restYAnim + (capsule.lowered ? 26 : -26)

        property real shelfFactor: chrome.shelfOpen ? 0 : 1
        Behavior on shelfFactor { EffectsAnim { speed: "fast" } }

        x: capsule.startX + (capsule.restX - capsule.startX) * capsule.capT
        y: capsule.startY + (capsule.restYAnim - capsule.startY) * capsule.capT
        width: capsule.startW + (capsule.fullW - capsule.startW) * capsule.capT
        height: 4 + 52 * capsule.capT
        radius: height / 2
        opacity: Math.min(1, capsule.capT * 5) * capsule.shelfFactor
        visible: opacity > 0.01

        Item {
            id: capWipe
            anchors.fill: capRow
            visible: false
            layer.enabled: true

            Rectangle {
                width: capWipe.width * 2
                height: capWipe.height
                x: -capWipe.width * 2 * (1 - capsule.wipe)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: 0.6; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        EditCapsuleRow {
            id: capRow
            anchors.centerIn: parent
            layer.enabled: capsule.wipe < 0.999
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: capWipe
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            addLabel: "Add"
            addLit: chrome.shelfOpen
            actions: [
                { key: "panels", icon: "view_quilt", label: "Panels", lit: chrome.stage }
            ]
            onAdd: {
                chrome.pop = ""
                if (chrome.editor) {
                    chrome.editor.drawerMode = ""
                    chrome.editor.panelStage = false
                }
                chrome.shelfOpen = !chrome.shelfOpen
            }
            onAction: key => {
                const e = chrome.editor
                if (key === "panels") {
                    if (chrome.stage) {
                        e.panelStage = false
                        return
                    }
                    const own = chrome.panelOf(chrome.sel)
                    const first = chrome.panelList.find(p => BarLayout.isPlaced(p.item) || p.kind === "wallpaper" || p.kind === "launcher" || p.kind === "clipboard")
                    chrome.openStage(own ? chrome.sel : first ? first.item : "wallpaper")
                } else if (key === "edges") {
                    if (!e) return
                    if (e.drawerMode === "settings") {
                        e.drawerMode = ""
                        return
                    }
                    e.panelStage = false
                    e.selectedItem = ""
                    e.drawerFrom = Qt.rect(capsule.x + capsule.width / 2 - 60, capsule.y, 120, capsule.height)
                    e.drawerMode = "settings"
                }
            }
        }
    }

    EditHistoryCard {
        z: 5
        open: capRow.historyOpen && chrome.editing
        x: Math.max(12, Math.min(chrome.width - width - 12, capsule.x + capsule.width / 2 - width / 2))
        y: capsule.lowered ? capsule.y - height - 10 : capsule.y + capsule.height + 10
        onPicked: capRow.historyOpen = false
    }

    Rectangle {
        id: altHint
        z: 3
        readonly property bool shown: chrome.editing && !chrome.dragging && !chrome.shelfOpen && !chrome.stage
            && !chrome.drawerShown && !capRow.moreOpen && !capRow.historyOpen && capsule.capT > 0.99
        opacity: altHint.shown && altHint.x > chrome.insetLeft + 12 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        x: capsule.restX - width - 12
        y: capsule.restYAnim + (56 - height) / 2
        width: altRow.implicitWidth + 24
        height: 34
        radius: 17
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.18)

        Row {
            id: altRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: altKey.implicitWidth + 12
                height: 20
                radius: 6
                color: Colors.surfaceContainerHighest

                CustomText {
                    id: altKey
                    anchors.centerIn: parent
                    content: "Alt"
                    size: 11
                    weight: 600
                }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: "Hold to see every gap"
                size: 12
                customColor: Colors.surfaceVariantText
            }
        }
    }

    EditMoreMenu {
        z: 6
        open: capRow.moreOpen && chrome.editing
        x: Math.max(12, Math.min(chrome.width - width - 12, capsule.x + capRow.x + capRow.moreX - width / 2))
        y: capsule.lowered ? capsule.y - height - 10 : capsule.y + capsule.height + 10
        armed: chrome.resetArmed ? "reset" : ""
        entries: [
            { key: "keys", icon: "keyboard", label: "Keys and shortcuts", keys: "?" },
            { key: "peek", icon: "visibility", label: "Peek at the result", keys: "hold Space", hold: true },
            { key: "settings", icon: "tune", label: "Bar settings", external: true },
            { key: "reset", icon: "restart_alt", label: "Reset layout", sub: "Puts the default bar back · asks first",
              armedLabel: "Press again to reset the bar", danger: true, divider: true }
        ]
        onPicked: key => {
            if (key === "keys") {
                capRow.moreOpen = false
                GlobalStates.editKeysOpen = !GlobalStates.editKeysOpen
            } else if (key === "settings") {
                capRow.moreOpen = false
                GlobalStates.closeEdit()
                GlobalStates.settingsPage = 9
                GlobalStates.settingsOpen = true
            } else if (key === "reset") {
                if (!chrome.resetArmed) {
                    chrome.resetArmed = true
                    resetDisarm.restart()
                    return
                }
                chrome.resetArmed = false
                resetDisarm.stop()
                capRow.moreOpen = false
                BarLayout.reset()
            }
        }
    }

    EditFirstTip {
        z: 4
        allowed: chrome.editing && chrome.sel === "" && chrome.selBlock === "" && chrome.pop === ""
            && !chrome.shelfOpen && !chrome.drawerShown && !chrome.stage && !capRow.historyOpen && !capRow.moreOpen
        x: Math.max(12, Math.min(chrome.width - width - 12, capsule.restX + capsule.fullW / 2 - width / 2))
        y: capsule.lowered ? capsule.restYAnim - height - 14 : capsule.restYAnim + 56 + 14
    }

    EditKit.Card {
        id: toolbar
        function place() {
            if (!toolbar.shown)
                return
            toolbar.side = toolbar.liveSide
            toolbar.below = toolbar.liveBelow
            toolbar.ox = toolbar.liveOx
            toolbar.x = toolbar.liveX
            toolbar.y = toolbar.liveY
        }
        onShownChanged: toolbar.place()
        readonly property var entry: chrome.sel !== "" && chrome.sel.indexOf("dash:") !== 0 ? BarLayout.entry(chrome.sel) : null
        readonly property var styleSpec: toolbar.entry && toolbar.entry.options
            ? toolbar.entry.options.find(o => o.key === "style" && (o.type === "grid" || o.type === "choice") && o.choices) ?? null : null
        readonly property var styleValue: toolbar.styleSpec ? BarLayout.opt(chrome.sel, "style") : undefined
        readonly property string styleLabel: {
            if (!toolbar.styleSpec) return ""
            const c = toolbar.styleSpec.choices.find(x => x.value === toolbar.styleValue)
            return c ? c.label : ""
        }
        readonly property var panel: chrome.panelOf(chrome.sel)
        readonly property string tint: chrome.sel !== "" ? BarLayout.itemStyle(chrome.sel, "tint", "none") : "none"
        readonly property var colorSpec: {
            const opts = toolbar.entry && toolbar.entry.options ? toolbar.entry.options : []
            const c = opts.find(o => o.key === "color" && o.type === "choice")
            if (!c)
                return null
            if (c.onlyIf && c.onlyIf.values.indexOf(BarLayout.opt(chrome.sel, c.onlyIf.key)) < 0)
                return null
            return c
        }
        readonly property string colorValue: toolbar.colorSpec ? String(BarLayout.opt(chrome.sel, "color")) : ""
        readonly property bool placed: chrome.sel !== "" && BarLayout.isPlaced(chrome.sel)
        readonly property bool shown: chrome.editing && toolbar.entry !== null && chrome.selFound && !chrome.dragging
                                      && !chrome.stage && !chrome.drawerShown && !chrome.shelfOpen
        property bool side: false
        readonly property bool liveSide: chrome.selEdge === "left" || chrome.selEdge === "right"
        onLiveSideChanged: Qt.callLater(toolbar.place)
        property bool below: false
        readonly property bool liveBelow: chrome.selEdge !== "bottom"
        onLiveBelowChanged: Qt.callLater(toolbar.place)

        property real ox: 0
        readonly property real liveOx: chrome.selEdge === "left" ? -16 : chrome.selEdge === "right" ? toolbar.width + 16 : chrome.selRect.x + chrome.selRect.width / 2 - toolbar.x
        onLiveOxChanged: Qt.callLater(toolbar.place)

        property real showT: toolbar.shown || styleCard.showT > 0.02 ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: toolbar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toolbar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: toolbar.showT > 0.01 || toolGrip.area.pressed
        opacity: chrome.dragging ? 0 : Math.min(1, toolbar.showT * 1.5)
        transform: Scale {
            origin.x: toolbar.ox
            origin.y: toolbar.side ? toolbar.height / 2 : toolbar.below ? -16 : toolbar.height + 16
            xScale: 0.2 + 0.8 * toolbar.showT
            yScale: 0.3 + 0.7 * toolbar.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - toolbar.width - 12,
                chrome.selEdge === "left" ? chrome.selRect.x + chrome.selRect.width + 16
                : chrome.selEdge === "right" ? chrome.selRect.x - toolbar.width - 16
                : chrome.selRect.x + chrome.selRect.width / 2 - toolbar.width / 2))
        onLiveXChanged: Qt.callLater(toolbar.place)
        readonly property real liveY: chrome.avoidCap(toolbar.x, toolbar.width, toolbar.side ? chrome.selRect.y + chrome.selRect.height / 2 - toolbar.height / 2
                : toolbar.below ? chrome.selRect.y + chrome.selRect.height + 16
                : chrome.selRect.y - toolbar.height - 16, toolbar.height)
        onLiveYChanged: Qt.callLater(toolbar.place)
        height: 52
        width: toolRow.implicitWidth + 12
        radius: 26
        Behavior on x {
            enabled: toolbar.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        Behavior on y {
            enabled: toolbar.showT > 0.99
            SpatialAnim { speed: "move" }
        }

        Notch {
            card: toolbar
            side: toolbar.side
            below: toolbar.below
            towardLeft: chrome.selEdge === "left"
            target: toolbar.side ? chrome.selRect.y + chrome.selRect.height / 2 - toolbar.y : chrome.selRect.x + chrome.selRect.width / 2 - toolbar.x
        }

        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 2

            DragGrip {
                id: toolGrip
                host: chrome
                tip: "Drag to move"
                starter: () => {
                    const id = chrome.sel
                    const blk = chrome.blockOfItem(id)
                    if (!blk)
                        return false
                    chrome.editor.beginItem(id, blk.id, blk.items.indexOf(id), chrome.selRect.width)
                    return true
                }
            }

            Rectangle {
                id: nameBtn
                implicitHeight: 40
                implicitWidth: nameRow.implicitWidth + 22
                radius: 20
                color: chrome.pop === "style" ? Colors.secondaryContainer
                    : nameArea.containsMouse && toolbar.styleSpec ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: nameRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        color: Colors.primaryContainer
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: toolbar.entry ? toolbar.entry.icon : "widgets"
                            iconSize: 15
                            customColor: Colors.primaryContainerText
                        }
                    }

                    CustomText {
                        content: !toolbar.entry ? ""
                            : toolbar.styleLabel !== "" ? toolbar.styleLabel + " · " + toolbar.entry.label
                            : toolbar.entry.label
                        size: 13
                        weight: 600
                    }

                    MaterialIconSymbol {
                        visible: toolbar.styleSpec !== null
                        content: chrome.pop === "style" ? "expand_less" : "expand_more"
                        iconSize: 18
                        customColor: Colors.surfaceVariantText
                    }
                }

                MouseArea {
                    id: nameArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: toolbar.styleSpec !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chrome.pop = chrome.pop === "style" ? "" : "style"
                }
            }

            Row {
                Layout.leftMargin: 10
                Layout.rightMargin: 8
                spacing: 7
                visible: toolbar.placed

                Repeater {
                    model: toolbar.colorSpec ? toolbar.colorSpec.choices : chrome.tints

                    Rectangle {
                        id: dot
                        required property var modelData
                        readonly property bool on: toolbar.colorSpec ? toolbar.colorValue === dot.modelData.value
                                                                     : toolbar.tint === dot.modelData.value
                        width: 22
                        height: 22
                        radius: 11
                        color: dot.modelData.value === "none" ? Colors.surfaceContainerHighest : BarLayout.roleColor(dot.modelData.value)

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            visible: dot.modelData.value === "none"
                            content: "format_color_reset"
                            iconSize: 14
                            customColor: Colors.surfaceVariantText
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: 15
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.primary
                            visible: dot.on
                        }

                        MouseArea {
                            id: dotArea
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (toolbar.colorSpec)
                                    BarLayout.setOption(chrome.sel, "color", dot.modelData.value)
                                else
                                    BarLayout.setItemStyle(chrome.sel, "tint", dot.modelData.value)
                            }
                        }

                        CustomToolTip {
                            content: dot.modelData.label ?? ""
                            visible: dotArea.containsMouse && (dot.modelData.label ?? "") !== ""
                        }
                    }
                }
            }

            EditKit.Divider { Layout.leftMargin: 4; Layout.rightMargin: 4 }

            EditKit.Pill {
                visible: toolbar.panel !== null
                icon: toolbar.panel ? toolbar.panel.icon : ""
                label: toolbar.panel ? toolbar.panel.label + " panel" : ""
                lit: true
                tip: "Preview its panel and change how it opens"
                onClicked: chrome.openStage(chrome.sel)
            }
            EditKit.Pill {
                id: toolTune
                icon: "tune"
                label: "Settings"
                tonal: true
                tip: "Everything about this item · Enter"
                onClicked: {
                    if (!chrome.editor)
                        return
                    chrome.editor.drawerFrom = toolTune.mapToItem(chrome, 0, 0, toolTune.width, toolTune.height)
                    chrome.editor.drawerMode = "options"
                }
            }
            EditKit.Pill {
                visible: toolbar.placed
                icon: "delete"
                danger: true
                tip: "Remove from the bar · Del"
                onClicked: {
                    const id = chrome.sel
                    chrome.editor.selectedItem = ""
                    Qt.callLater(() => BarLayout.hideItem(id))
                }
            }
        }
    }

    EditKit.Card {
        id: blockBar
        function place() {
            if (!blockBar.shown)
                return
            blockBar.side = blockBar.liveSide
            blockBar.below = blockBar.liveBelow
            blockBar.ox = blockBar.liveOx
            blockBar.x = blockBar.liveX
            blockBar.y = blockBar.liveY
        }
        onShownChanged: blockBar.place()
        readonly property string shape: chrome.selBlock !== "" ? BarLayout.blockShape(chrome.selBlock) : ""
        readonly property var blockInfo: chrome.selBlock !== "" ? BarLayout.blockById(chrome.selBlock) : null
        readonly property string tint: chrome.selBlock !== "" ? BarLayout.blockStyle(chrome.selBlock, "tint", "none") : "none"
        readonly property bool split: chrome.selBlock !== "" && BarLayout.splitBlock(chrome.selBlock)
        readonly property real opacityPct: chrome.selBlock !== "" ? BarLayout.blockStyle(chrome.selBlock, "opacity", 100) : 100
        readonly property bool fadable: blockBar.shape === "pill" && !blockBar.split
        readonly property string panels: blockBar.blockInfo ? BarLayout.panelStyleFor(chrome.selBlock, blockBar.blockInfo.edge, blockBar.shape) : ""
        readonly property bool shown: chrome.editing && chrome.selBlock !== "" && chrome.blockFound && !chrome.dragging
                                      && !chrome.stage && !chrome.drawerShown && !chrome.shelfOpen
        property bool side: false
        readonly property bool liveSide: chrome.blockEdge === "left" || chrome.blockEdge === "right"
        onLiveSideChanged: Qt.callLater(blockBar.place)
        property bool below: false
        readonly property bool liveBelow: chrome.blockEdge !== "bottom"
        onLiveBelowChanged: Qt.callLater(blockBar.place)

        property real ox: 0
        readonly property real liveOx: chrome.blockRect.x + chrome.blockRect.width / 2 - blockBar.x
        onLiveOxChanged: Qt.callLater(blockBar.place)

        property real showT: blockBar.shown || tintCard.showT > 0.02 || blockCard.showT > 0.02 || cornersCard.showT > 0.02 ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: blockBar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blockBar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: blockBar.showT > 0.01 || blockGrip.area.pressed
        opacity: chrome.dragging ? 0 : Math.min(1, blockBar.showT * 1.5)
        transform: Scale {
            origin.x: blockBar.ox
            origin.y: blockBar.side ? blockBar.height / 2 : blockBar.below ? -42 : blockBar.height + 42
            xScale: 0.2 + 0.8 * blockBar.showT
            yScale: 0.3 + 0.7 * blockBar.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - blockBar.width - 12,
                chrome.blockEdge === "left" ? chrome.blockRect.x + chrome.blockRect.width + 42
                : chrome.blockEdge === "right" ? chrome.blockRect.x - blockBar.width - 42
                : chrome.blockRect.x + chrome.blockRect.width / 2 - blockBar.width / 2))
        onLiveXChanged: Qt.callLater(blockBar.place)
        readonly property real liveY: chrome.avoidCap(blockBar.x, blockBar.width, blockBar.side ? chrome.blockRect.y + chrome.blockRect.height / 2 - blockBar.height / 2
                : blockBar.below ? chrome.blockRect.y + chrome.blockRect.height + 42
                : chrome.blockRect.y - blockBar.height - 42, blockBar.height)
        onLiveYChanged: Qt.callLater(blockBar.place)
        height: 52
        width: blockRow.implicitWidth + 12
        radius: 26
        Behavior on x {
            enabled: blockBar.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        Behavior on y {
            enabled: blockBar.showT > 0.99
            SpatialAnim { speed: "move" }
        }

        Notch {
            card: blockBar
            side: blockBar.side
            below: blockBar.below
            towardLeft: chrome.blockEdge === "left"
            target: blockBar.side ? chrome.blockRect.y + chrome.blockRect.height / 2 - blockBar.y : chrome.blockRect.x + chrome.blockRect.width / 2 - blockBar.x
        }

        RowLayout {
            id: blockRow
            anchors.centerIn: parent
            spacing: 2

            DragGrip {
                id: blockGrip
                tip: "Drag to move the block"
                host: chrome
                starter: () => {
                    chrome.editor.beginBlock(chrome.selBlock)
                    return true
                }
            }

            CustomText {
                Layout.leftMargin: 4
                Layout.rightMargin: 6
                content: chrome.selBlock !== "" ? BarLayout.blockName(chrome.selBlock) : ""
                size: 13
                weight: 600
            }

            RowLayout {
                id: edgeGapCtl
                visible: chrome.selBlock !== ""
                spacing: 2
                readonly property string side: blockBar.blockInfo ? blockBar.blockInfo.edge : "top"
                readonly property var own: BarLayout.blockStyle(chrome.selBlock, "edgeGap", null)
                readonly property real barGap: BarLayout.edgeGaps(edgeGapCtl.side).edge
                readonly property real now: chrome.selBlock !== "" ? BarLayout.blockGaps(chrome.selBlock, edgeGapCtl.side).edge : 0
                readonly property string pos: typeof edgeGapCtl.own !== "number" ? "follow" : edgeGapCtl.own <= 0.5 ? "edge" : "lift"
                function pick(v) {
                    BarLayout.setBlockStyle(chrome.selBlock, "edgeGap", v === "follow" ? undefined
                        : v === "edge" ? 0 : Math.max(0, edgeGapCtl.barGap) + 10)
                    BarLayout.flashGap("edges", edgeGapCtl.side, chrome.selBlock)
                }
                function nudge(d) {
                    BarLayout.setBlockStyle(chrome.selBlock, "edgeGap", Math.max(0, Math.min(60, Math.round(edgeGapCtl.now) + d)))
                    BarLayout.flashGap("edges", edgeGapCtl.side, chrome.selBlock)
                }
                EditKit.Pill {
                    icon: "link"
                    label: "With bar"
                    box: 36
                    lit: edgeGapCtl.pos === "follow"
                    tip: "Sit like the rest of the edge"
                    onClicked: edgeGapCtl.pick("follow")
                }
                EditKit.Pill {
                    icon: blockBar.side ? (chrome.blockEdge === "left" ? "align_horizontal_right" : "align_horizontal_left") : (chrome.blockEdge === "top" ? "vertical_align_bottom" : "vertical_align_top")
                    label: edgeGapCtl.pos === "lift" ? "Lifted " + Math.round(edgeGapCtl.now) : "Lifted"
                    box: 36
                    lit: edgeGapCtl.pos === "lift"
                    tip: "Float above the rest of the bar · scroll to adjust"
                    onClicked: edgeGapCtl.pick("lift")
                }
                EditKit.Pill {
                    icon: blockBar.side ? (chrome.blockEdge === "left" ? "align_horizontal_left" : "align_horizontal_right") : (chrome.blockEdge === "top" ? "vertical_align_top" : "vertical_align_bottom")
                    label: "On edge"
                    box: 36
                    lit: edgeGapCtl.pos === "edge"
                    tip: "Sit on the screen edge"
                    onClicked: edgeGapCtl.pick("edge")
                }
                WheelStep {
                    onStepped: dir => edgeGapCtl.nudge(dir)
                }
                HoverHandler {
                    onHoveredChanged: BarLayout.hoverGap(hovered, "edges", edgeGapCtl.side, chrome.selBlock)
                }
            }

            EditKit.Divider {
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            Rectangle {
                id: tintBtn
                implicitHeight: 40
                implicitWidth: tintRow.implicitWidth + 18
                radius: tintArea.pressed ? 12 : 20
                color: chrome.pop === "tint" ? Colors.secondaryContainer : "transparent"
                Behavior on radius { SpatialAnim { speed: "fast" } }
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: tintRow
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        color: blockBar.tint === "none" ? "transparent" : BarLayout.roleColor(blockBar.tint)
                        border.width: blockBar.tint === "none" ? 2 : 0
                        border.color: Colors.outline
                    }
                    MaterialIconSymbol {
                        content: chrome.pop === "tint" ? "expand_less" : "expand_more"
                        iconSize: 18
                        customColor: Colors.surfaceVariantText
                    }
                }

                RippleEffect {
                    id: tintArea
                    anchors.fill: parent
                    radius: tintBtn.radius
                    hoverColor: Qt.alpha(Colors.surfaceText, 0.08)
                    onClicked: chrome.pop = chrome.pop === "tint" ? "" : "tint"
                }

                CustomToolTip { content: "Colour"; visible: tintArea.containsMouse }
            }

            EditKit.Pill {
                id: morePill
                icon: "tune"
                label: "More"
                tonal: chrome.pop !== "block" && chrome.pop !== "corners"
                lit: chrome.pop === "block" || chrome.pop === "corners"
                tip: "Spacing, corners, colour and panels"
                onClicked: chrome.pop = chrome.pop === "block" || chrome.pop === "corners" ? "" : "block"
            }

            EditKit.Pill {
                visible: BarLayout.allBlocks.length > 1
                icon: "delete"
                danger: true
                tip: "Remove block · its items go to the drawer"
                onClicked: {
                    const id = chrome.selBlock
                    chrome.editor.selectedBlock = ""
                    Qt.callLater(() => BarLayout.removeBlock(id))
                }
            }
        }
    }

    component Notch: Rectangle {
        id: notch
        required property Item card
        property bool side: false
        property bool below: true
        property bool towardLeft: false
        property real target: 0
        z: -1
        width: 14
        height: 14
        radius: 3
        rotation: 45
        color: notch.card.color
        border.width: notch.card.border.width
        border.color: notch.card.border.color
        x: notch.side ? (notch.towardLeft ? -6 : notch.card.width - 8)
            : Math.max(22, Math.min(notch.card.width - 36, notch.target - 7))
        y: notch.side ? Math.max(14, Math.min(notch.card.height - 28, notch.target - 7))
            : notch.below ? -6 : notch.card.height - 8
    }

    component DragGrip: Rectangle {
        id: grip
        required property Item host
        property string tip: ""
        property var starter: null
        readonly property alias area: gripMouse
        implicitWidth: 30
        implicitHeight: 40
        radius: 15
        color: gripMouse.containsMouse || gripMouse.pressed ? Qt.alpha(Colors.primary, 0.14) : "transparent"
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "drag_indicator"
            iconSize: 18
            customColor: Colors.surfaceVariantText
        }

        MouseArea {
            id: gripMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: grip.host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point pressAt: Qt.point(0, 0)
            property bool live: false
            onPressed: mouse => {
                gripMouse.pressAt = gripMouse.mapToItem(null, mouse.x, mouse.y)
                gripMouse.live = false
            }
            onPositionChanged: mouse => {
                const e = grip.host.editor
                if (!gripMouse.pressed || !e)
                    return
                const p = gripMouse.mapToItem(null, mouse.x, mouse.y)
                if (!gripMouse.live) {
                    if (Math.hypot(p.x - gripMouse.pressAt.x, p.y - gripMouse.pressAt.y) <= 4)
                        return
                    gripMouse.live = grip.starter ? grip.starter() === true : false
                    if (!gripMouse.live)
                        return
                }
                e.update(p.x, p.y)
            }
            onReleased: {
                if (gripMouse.live && grip.host.editor && grip.host.editor.mode !== "")
                    grip.host.editor.finish()
                gripMouse.live = false
            }
            onCanceled: {
                if (gripMouse.live && grip.host.editor && grip.host.editor.mode !== "")
                    grip.host.editor.cancel()
                gripMouse.live = false
            }
        }

        CustomToolTip { content: grip.tip; visible: gripMouse.containsMouse && !gripMouse.pressed }
    }

    component TintDots: Row {
        id: dots
        property string current: "none"
        property var choices: []
        signal picked(string value)
        spacing: 9

        Repeater {
            model: dots.choices

            Rectangle {
                id: tdot
                required property var modelData
                readonly property bool on: dots.current === tdot.modelData.value
                width: 24
                height: 24
                radius: 12
                color: tdot.modelData.value === "none" ? Colors.surfaceContainerHighest : BarLayout.roleColor(tdot.modelData.value)

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    visible: tdot.modelData.value === "none"
                    content: "format_color_reset"
                    iconSize: 15
                    customColor: Colors.surfaceVariantText
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.primary
                    visible: tdot.on
                }

                MouseArea {
                    id: tdotArea
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dots.picked(tdot.modelData.value)
                }

                CustomToolTip { content: tdot.modelData.label; visible: tdotArea.containsMouse }
            }
        }
    }

    EditKit.Card {
        id: tintCard
        function place() {
            if (!tintCard.shown)
                return
            tintCard.x = tintCard.liveX
            tintCard.y = tintCard.liveY
        }
        onShownChanged: tintCard.place()
        readonly property bool shown: chrome.pop === "tint" && blockBar.shown
        readonly property bool up: !blockBar.side && !blockBar.below
        readonly property real anchorX: blockBar.x + blockRow.x + tintBtn.x + tintBtn.width / 2
        property real showT: tintCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: tintCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: tintCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: tintCard.showT > 0.01
        opacity: Math.min(1, tintCard.showT * 1.5)
        transform: Scale {
            origin.x: tintCard.anchorX - tintCard.x
            origin.y: tintCard.up ? tintCard.height + 8 : -8
            xScale: 0.5 + 0.5 * tintCard.showT
            yScale: 0.15 + 0.85 * tintCard.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - tintCard.width - 12, tintCard.anchorX - tintCard.width / 2))
        onLiveXChanged: Qt.callLater(tintCard.place)
        readonly property real liveY: tintCard.up ? Math.max(12, blockBar.y - tintCard.height - 8)
                : Math.min(chrome.height - tintCard.height - 12, blockBar.y + blockBar.height + 8)
        onLiveYChanged: Qt.callLater(tintCard.place)
        width: tintCardRow.implicitWidth + 32
        height: 56
        radius: 28

        Row {
            id: tintCardRow
            anchors.centerIn: parent
            spacing: 12

            TintDots {
                id: tintDots
                anchors.verticalCenter: parent.verticalCenter
                current: blockBar.tint
                choices: chrome.tints
                onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "tint", v)
            }
            EditStepper {
                visible: blockBar.fadable
                anchors.verticalCenter: parent.verticalCenter
                value: blockBar.opacityPct
                from: 0
                to: 100
                stepSize: 10
                unit: "%"
                onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "opacity", v >= 100 ? undefined : v)
            }
        }
    }

    EditKit.Card {
        id: blockCard
        function place() {
            if (!blockCard.shown)
                return
            blockCard.x = blockCard.liveX
            blockCard.y = blockCard.liveY
        }
        onShownChanged: blockCard.place()
        readonly property bool shown: chrome.pop === "block" && blockBar.shown
        readonly property bool up: !blockBar.side && !blockBar.below
        readonly property string side: blockBar.blockInfo ? blockBar.blockInfo.edge : "top"
        readonly property var gaps: chrome.selBlock !== "" ? BarLayout.blockGaps(chrome.selBlock, blockCard.side) : null
        readonly property bool ownLift: typeof BarLayout.blockStyle(chrome.selBlock, "edgeGap", null) === "number"
        readonly property real lift: blockCard.gaps ? Math.max(0, blockCard.gaps.edge) : 0
        readonly property bool hasPrev: {
            const b = blockBar.blockInfo
            if (!b)
                return false
            const group = BarLayout.allBlocks.filter(o => o.id !== "__sys" && o.edge === b.edge && o.anchor === b.anchor)
            return group.findIndex(o => o.id === b.id) > 0
        }
        readonly property var ownGap: BarLayout.blockStyle(chrome.selBlock, "gapBefore", null)
        readonly property bool hasOwnGap: typeof blockCard.ownGap === "number" && blockCard.ownGap >= 0
        readonly property real gapNow: blockCard.gaps && blockCard.gaps.gapBefore >= 0 ? blockCard.gaps.gapBefore : BarLayout.edgeGaps(blockCard.side).block
        readonly property real full: blockBar.blockInfo ? BarLayout.edge(blockBar.blockInfo.edge).height / 2 : 20
        readonly property var ownRadius: BarLayout.blockStyle(chrome.selBlock, "radius", null)
        readonly property bool hasRadius: typeof blockCard.ownRadius === "number" && blockCard.ownRadius >= 0
        readonly property string corner: !blockCard.hasRadius ? "follow" : blockCard.ownRadius <= 0.5 ? "square"
            : blockCard.ownRadius >= blockCard.full - 0.5 ? "round" : "soft"
        readonly property real radiusNow: {
            if (blockCard.hasRadius)
                return Math.min(blockCard.ownRadius, blockCard.full)
            const r = blockCard.gaps ? blockCard.gaps.radius : -1
            return r < 0 ? blockCard.full : Math.min(r, blockCard.full)
        }
        function setCorner(v) {
            BarLayout.setBlockStyle(chrome.selBlock, "radius", v === "follow" ? undefined
                : v === "square" ? 0 : v === "round" ? Math.floor(blockCard.full) : Math.round(blockCard.full / 2))
        }
        readonly property bool hasPanelGap: blockBar.panels === "floating" || blockBar.panels === "merged"

        property real showT: blockCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: blockCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blockCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: blockCard.showT > 0.01
        opacity: Math.min(1, blockCard.showT * 1.5)
        transform: Scale {
            origin.x: blockBar.x + blockRow.x + morePill.x + morePill.width / 2 - blockCard.x
            origin.y: blockCard.up ? blockCard.height + 8 : -8
            xScale: 0.6 + 0.4 * blockCard.showT
            yScale: 0.2 + 0.8 * blockCard.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - blockCard.width - 12, blockBar.x + blockRow.x + morePill.x + morePill.width / 2 - blockCard.width / 2))
        onLiveXChanged: Qt.callLater(blockCard.place)
        readonly property real liveY: blockCard.up ? Math.max(12, blockBar.y - blockCard.height - 8)
                : Math.max(12, Math.min(chrome.height - blockCard.height - 12, blockBar.y + blockBar.height + 8))
        onLiveYChanged: Qt.callLater(blockCard.place)
        width: 420
        height: blockCol.implicitHeight + 32
        radius: 28

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: blockCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                CustomText {
                    Layout.fillWidth: true
                    content: chrome.selBlock !== "" ? BarLayout.blockName(chrome.selBlock) : ""
                    size: 15
                    weight: 600
                }
                EditKit.Pill {
                    icon: "sync"
                    label: "Match the edge"
                    box: 34
                    usable: chrome.selBlock !== "" && BarLayout.blockHasOwnStyle(chrome.selBlock)
                    tip: "Use the edge's spacing, corners and panel style again"
                    onClicked: BarLayout.matchEdge(chrome.selBlock)
                }
            }

            EditKit.SectionLabel { content: "Spacing" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                HoverHandler {
                    onHoveredChanged: BarLayout.hoverGap(hovered, "edges", blockCard.side, chrome.selBlock)
                }
                CustomText {
                    Layout.preferredWidth: 120
                    content: "Lift off the edge"
                    size: 12
                }
                EditStepper {
                    Layout.fillWidth: true
                    value: Math.round(blockCard.lift)
                    from: 0
                    to: 60
                    stepSize: 1
                    canAuto: true
                    isAuto: !blockCard.ownLift
                    autoLabel: "Like the edge"
                    autoText: Math.round(blockCard.lift) + " px"
                    offValue: Math.round(blockCard.lift)
                    onPicked: v => {
                        BarLayout.setBlockStyle(chrome.selBlock, "edgeGap", v)
                        BarLayout.flashGap("edges", blockCard.side, chrome.selBlock)
                    }
                    onAutoPicked: BarLayout.setBlockStyle(chrome.selBlock, "edgeGap", undefined)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: blockCard.hasPrev
                spacing: 12
                CustomText {
                    Layout.preferredWidth: 120
                    content: "Space before it"
                    size: 12
                }
                EditStepper {
                    Layout.fillWidth: true
                    value: Math.round(blockCard.gapNow)
                    from: 0
                    to: 60
                    stepSize: 1
                    canAuto: true
                    isAuto: !blockCard.hasOwnGap
                    autoLabel: "Like the edge"
                    autoText: Math.round(blockCard.gapNow) + " px"
                    offValue: Math.round(blockCard.gapNow)
                    onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "gapBefore", v)
                    onAutoPicked: BarLayout.setBlockStyle(chrome.selBlock, "gapBefore", undefined)
                }
            }

            EditKit.SectionLabel {
                visible: !blockBar.split
                content: "Corners"
            }

            EditChoice {
                Layout.fillWidth: true
                visible: !blockBar.split
                maxPerRow: 4
                minCell: 70
                rowHeight: 34
                choices: [
                    { value: "follow", label: "Like the edge" },
                    { value: "square", label: "Square" },
                    { value: "soft", label: "Soft" },
                    { value: "round", label: "Round" }
                ]
                value: blockCard.corner
                onPicked: v => blockCard.setCorner(v)
            }
            EditSideRow {
                visible: !blockBar.split
                icon: "rounded_corner"
                label: "Each corner"
                value: cornersCard.custom ? "Set one by one" : ""
                lit: cornersCard.custom
                onClicked: chrome.pop = "corners"
            }

            EditKit.SectionLabel { content: "Colour" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                TintDots {
                    current: blockBar.tint
                    choices: chrome.tints
                    onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "tint", v)
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    visible: blockBar.shape === "pill"
                    content: "Split into shapes"
                    size: 12
                }
                CustomToogle {
                    visible: blockBar.shape === "pill"
                    isToggleOn: blockBar.split
                    onToggled: state => BarLayout.setBlockSplit(chrome.selBlock, state)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: blockBar.fadable
                spacing: 10
                CustomText {
                    Layout.fillWidth: true
                    content: "Opacity"
                    size: 12
                }
                EditStepper {
                    value: blockBar.opacityPct
                    from: 0
                    to: 100
                    stepSize: 10
                    unit: "%"
                    onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "opacity", v >= 100 ? undefined : v)
                }
            }

            EditKit.SectionLabel { content: "Panels open" }

            EditTextChoice {
                id: panelsChoice
                readonly property bool own: BarLayout.ownPanels(chrome.selBlock) !== ""
                Layout.fillWidth: true
                cols: 2
                model: [{
                    value: "follow",
                    label: "Like the edge",
                    desc: panelsChoice.own ? "Use the edge's style" : ((BarLayout.panelStyleInfo.find(p => p.value === blockBar.panels) ?? { label: "" }).label)
                }].concat(BarLayout.panelStyleInfo)
                current: panelsChoice.own ? blockBar.panels : "follow"
                onPicked: v => BarLayout.setBlockStyle(chrome.selBlock, "panels", v === "follow" ? undefined : v)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: blockCard.hasPanelGap
                spacing: 12
                HoverHandler {
                    onHoveredChanged: BarLayout.hoverGap(hovered, "panelGap", "", chrome.selBlock)
                }
                CustomText {
                    Layout.preferredWidth: 120
                    content: "Gap to its panels"
                    size: 12
                }
                EditStepper {
                    readonly property bool own: BarLayout.blockStyle(chrome.selBlock, "panelGap", null) !== null
                    Layout.fillWidth: true
                    value: Math.round(BarLayout.blockPanelGap(chrome.selBlock))
                    from: 0
                    to: 40
                    stepSize: 2
                    canAuto: true
                    isAuto: !own
                    autoLabel: "Like the edge"
                    autoText: Math.round(BarLayout.blockPanelGap(chrome.selBlock)) + " px"
                    offValue: Math.round(BarLayout.blockPanelGap(chrome.selBlock))
                    onPicked: v => {
                        BarLayout.setBlockStyle(chrome.selBlock, "panelGap", v)
                        BarLayout.flashGap("panelGap", "", chrome.selBlock)
                    }
                    onAutoPicked: BarLayout.setBlockStyle(chrome.selBlock, "panelGap", null)
                }
            }
        }
    }

    EditKit.Card {
        id: styleCard
        function place() {
            if (!styleCard.shown)
                return
            styleCard.x = styleCard.liveX
            styleCard.y = styleCard.liveY
        }
        onShownChanged: styleCard.place()
        readonly property bool shown: chrome.pop === "style" && toolbar.shown && toolbar.styleSpec !== null
        readonly property bool up: !toolbar.below || toolbar.y + toolbar.height + 8 + styleCard.height > chrome.height - 12
        property real showT: styleCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: styleCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: styleCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: styleCard.showT > 0.01
        opacity: Math.min(1, styleCard.showT * 1.5)
        transform: Scale {
            origin.x: toolbar.x + 6 + nameBtn.width / 2 - styleCard.x
            origin.y: styleCard.up ? styleCard.height + 8 : -8
            xScale: 0.5 + 0.5 * styleCard.showT
            yScale: 0.15 + 0.85 * styleCard.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - styleCard.width - 12, toolbar.x))
        onLiveXChanged: Qt.callLater(styleCard.place)
        readonly property real liveY: styleCard.up ? Math.max(12, toolbar.y - styleCard.height - 8) : toolbar.y + toolbar.height + 8
        onLiveYChanged: Qt.callLater(styleCard.place)
        width: 380
        height: styleFlow.implicitHeight + 28
        radius: 22

        Flow {
            id: styleFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 6

            Repeater {
                model: toolbar.styleSpec ? toolbar.styleSpec.choices : []

                EditKit.ChoiceChip {
                    required property var modelData
                    label: modelData.label
                    icon: modelData.icon ?? ""
                    lit: toolbar.styleValue === modelData.value
                    onClicked: BarLayout.setOption(chrome.sel, "style", modelData.value)
                }
            }
        }
    }

    EditKit.Card {
        id: cornersCard
        function place() {
            if (!cornersCard.shown)
                return
            cornersCard.x = cornersCard.liveX
            cornersCard.y = cornersCard.liveY
        }
        onShownChanged: cornersCard.place()
        readonly property var corners: chrome.selBlock !== "" ? BarLayout.blockCorners(chrome.selBlock) : ({ tl: null, tr: null, br: null, bl: null })
        readonly property bool custom: ["tl", "tr", "br", "bl"].some(k => cornersCard.corners[k] !== null)
        readonly property real full: blockCard.full
        readonly property real base: blockCard.radiusNow
        property bool linked: false
        readonly property bool shown: chrome.pop === "corners" && blockBar.shown && !blockBar.split
        readonly property bool up: !blockBar.side && !blockBar.below
        readonly property real anchorX: blockBar.x + blockRow.x + morePill.x + morePill.width / 2
        function valueOf(k) {
            const v = cornersCard.corners[k]
            return v === null ? cornersCard.base : Math.min(v, cornersCard.full)
        }
        function nudge(k, d) {
            const n = Math.max(0, Math.min(cornersCard.full, cornersCard.valueOf(k) + d))
            BarLayout.setBlockCorner(chrome.selBlock, cornersCard.linked ? "all" : k, n)
        }
        property real showT: cornersCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: cornersCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: cornersCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: cornersCard.showT > 0.01
        opacity: Math.min(1, cornersCard.showT * 1.5)
        transform: Scale {
            origin.x: cornersCard.anchorX - cornersCard.x
            origin.y: cornersCard.up ? cornersCard.height + 8 : -8
            xScale: 0.5 + 0.5 * cornersCard.showT
            yScale: 0.15 + 0.85 * cornersCard.showT
        }
        readonly property real liveX: Math.max(12, Math.min(chrome.width - cornersCard.width - 12, cornersCard.anchorX - cornersCard.width / 2))
        onLiveXChanged: Qt.callLater(cornersCard.place)
        readonly property real liveY: cornersCard.up ? Math.max(12, blockBar.y - cornersCard.height - 8)
                : Math.min(chrome.height - cornersCard.height - 12, blockBar.y + blockBar.height + 8)
        onLiveYChanged: Qt.callLater(cornersCard.place)
        width: 340
        height: cornersCol.implicitHeight + 28
        radius: 22

        ColumnLayout {
            id: cornersCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                EditKit.Pill {
                    icon: "arrow_back"
                    box: 30
                    tip: "Back to the block"
                    onClicked: chrome.pop = "block"
                }
                CustomText {
                    Layout.fillWidth: true
                    content: "Each corner"
                    size: 13
                    weight: 600
                }
                EditKit.Pill {
                    icon: cornersCard.linked ? "link" : "link_off"
                    box: 30
                    tip: cornersCard.linked ? "Changing one changes all" : "Corners change separately"
                    lit: cornersCard.linked
                    onClicked: cornersCard.linked = !cornersCard.linked
                }
                EditKit.Pill {
                    icon: "restart_alt"
                    box: 30
                    tip: "Back to the block's corners"
                    usable: cornersCard.custom
                    onClicked: BarLayout.setBlockCorner(chrome.selBlock, "all", null)
                }
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                rowSpacing: 8
                columnSpacing: 10

                EditCornerStep { key: "tl"; card: cornersCard }
                Rectangle {
                    Layout.rowSpan: 2
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: 64
                    implicitHeight: 40
                    readonly property real k: 40 / Math.max(1, cornersCard.full * 2)
                    color: Colors.secondaryContainer
                    topLeftRadius: cornersCard.valueOf("tl") * k
                    topRightRadius: cornersCard.valueOf("tr") * k
                    bottomRightRadius: cornersCard.valueOf("br") * k
                    bottomLeftRadius: cornersCard.valueOf("bl") * k
                }
                EditCornerStep { key: "tr"; card: cornersCard }
                EditCornerStep { key: "bl"; card: cornersCard }
                EditCornerStep { key: "br"; card: cornersCard }
            }
        }
    }

    property bool resetArmed: false

    Timer {
        id: resetDisarm
        interval: 3500
        onTriggered: chrome.resetArmed = false
    }

    property bool bottomBusy: false
    property bool topBusy: false
    property bool topGrips: false
    property string stageSide: ""
    property real stageRoom: 1e9
    property bool stageHold: false

    function placeStage() {
        if (!chrome.stage) {
            chrome.stageSide = ""
            chrome.stageRoom = 1e9
            chrome.stageHold = false
            return
        }
        let l = 1e9
        let r = -1e9
        const closing = []
        for (const s of chrome.surfaces) {
            if (!s || !s.visible)
                continue
            for (const blk of s.visibleBlocks) {
                if (blk.shownKind !== "") {
                    const q = s.tabGoalRect(blk)
                    l = Math.min(l, q.x)
                    r = Math.max(r, q.x + q.width)
                } else if (blk.tabOpen) {
                    closing.push(s.tabRect(blk))
                }
            }
        }
        let side = chrome.stageSide
        let room = 1e9
        if (l < r) {
            const roomL = l - chrome.insetLeft - 32
            const roomR = chrome.width - chrome.insetRight - r - 32
            if (side === "")
                side = stageCard.defaultLeft ? "left" : "right"
            if ((side === "left" ? roomL : roomR) < stageCard.maxW)
                side = roomL >= roomR ? "left" : "right"
            room = side === "left" ? roomL : roomR
        }
        if (side !== chrome.stageSide)
            chrome.stageSide = side
        if (Math.abs(room - chrome.stageRoom) > 1)
            chrome.stageRoom = room
        const w = Math.min(stageCard.maxW, Math.max(stageCard.minW, room))
        const left = side !== "" ? side === "left" : stageCard.defaultLeft
        const cx = left ? chrome.insetLeft + 16 : chrome.width - w - chrome.insetRight - 16
        const hold = closing.some(q => q.width > 0 && q.x < cx + w && q.x + q.width > cx && q.y < stageCard.y + stageCard.height && q.y + q.height > stageCard.y)
        if (hold !== chrome.stageHold)
            chrome.stageHold = hold
    }
    property real capShiftTarget: 0
    property real capShift: chrome.capShiftTarget
    Behavior on capShift { SpatialAnim { speed: "move" } }

    function freeShift(rects, w, y) {
        const lane = rects.filter(r => r.width > 0 && r.y < y + 68 && r.y + r.height > y - 12)
                          .map(r => ({ l: r.x - 12, r: r.x + r.width + 12 }))
                          .sort((a, b) => a.l - b.l)
        const gaps = []
        let cur = 12
        for (const b of lane) {
            if (b.l > cur)
                gaps.push({ l: cur, r: b.l })
            cur = Math.max(cur, b.r)
        }
        if (chrome.width - 12 > cur)
            gaps.push({ l: cur, r: chrome.width - 12 })
        const centre = (chrome.width - w) / 2
        let best = null
        for (const g of gaps) {
            if (g.r - g.l < w)
                continue
            const x = Math.max(g.l, Math.min(g.r - w, centre))
            if (best === null || Math.abs(x - centre) < Math.abs(best - centre))
                best = x
        }
        return best === null ? 0 : best - centre
    }

    property var openNow: []
    property string openKey: ""

    function placeBeside(card, w, h, anchorY, avoid) {
        const pad = 12
        const top = 12
        const bottom = chrome.height - 12
        const left = chrome.insetLeft + pad
        const right = chrome.width - chrome.insetRight - pad
        const yAt = Math.max(top, Math.min(bottom - h, anchorY))
        const xAt = Math.max(left, Math.min(right - w, card.x + card.width / 2 - w / 2))
        const blocked = (avoid ?? []).concat(chrome.editing && capsule.visible ? [Qt.rect(capsule.restX, capsule.restY, capsule.fullW, 56)] : [])
        const hits = (x, y) => blocked.some(r => r.width > 0 && r.height > 0
            && x < r.x + r.width + pad && x + w > r.x - pad && y < r.y + r.height + pad && y + h > r.y - pad)
        const cands = [
            { side: "right", x: card.x + card.width + pad, y: yAt },
            { side: "left", x: card.x - w - pad, y: yAt },
            { side: "below", x: xAt, y: card.y + card.height + pad },
            { side: "above", x: xAt, y: card.y - h - pad }
        ]
        const order = card.x + card.width / 2 > chrome.width / 2 ? [1, 0, 2, 3] : [0, 1, 2, 3]
        const inside = c => c.x >= left && c.x + w <= right && c.y >= top && c.y + h <= bottom
        for (const i of order)
            if (inside(cands[i]) && !hits(cands[i].x, cands[i].y))
                return cands[i]
        for (const i of order)
            if (inside(cands[i]))
                return cands[i]
        return { side: "over", x: Math.max(left, card.x + card.width - w), y: yAt }
    }

    function scanBusy() {
        const rects = chrome.openRects()
        const key = rects.map(r => [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)].join(",")).join(";")
        if (key !== chrome.openKey) {
            chrome.openKey = key
            chrome.openNow = rects
        }
        const w = capsule.fullW
        const x = (chrome.width - w) / 2
        const bottomY = capsule.dockTop - 56 - 52
        const topY = chrome.surfTop && chrome.surfTop.present ? chrome.surfTop.thickness + 16 : 20
        const hit = (r, y) => r.width > 0 && r.x < x + w + 12 && r.x + r.width > x - 12 && r.y < y + 68 && r.y + r.height > y - 12
        let bottom = false
        let top = false
        let grips = false
        if (chrome.surfTop && chrome.surfTop.visible && chrome.surfTop.present) {
            for (const blk of chrome.surfTop.visibleBlocks) {
                const q = blk.mapToItem(chrome, 0, 0, blk.width, blk.height)
                if (q.x < x + w + 8 && q.x + q.width > x - 8)
                    grips = true
            }
        }
        if (chrome.topGrips !== grips)
            chrome.topGrips = grips
        chrome.placeStage()
        for (const r of rects) {
            if (hit(r, bottomY))
                bottom = true
            if (hit(r, topY))
                top = true
        }
        if (chrome.bottomBusy !== bottom)
            chrome.bottomBusy = bottom
        if (chrome.topBusy !== top)
            chrome.topBusy = top
        const shift = top && bottom ? chrome.freeShift(rects, w, bottomY) : 0
        if (Math.abs(shift - chrome.capShiftTarget) > 1)
            chrome.capShiftTarget = shift
    }

    Timer {
        interval: 120
        repeat: true
        running: chrome.editing
        onTriggered: chrome.scanBusy()
    }

    Connections {
        target: GlobalStates
        function onPanelPreviewChanged() { Qt.callLater(chrome.placeStage) }
        function onLauncherPreviewChanged() { Qt.callLater(chrome.placeStage) }
    }

    BarEditStage {
        id: stageCard
        host: chrome
    }

    function stageSideOpen() {
        if (stageCard.sidePage === "")
            return false
        stageCard.sidePage = ""
        return true
    }

    EditSidePanel {
        id: stageSide
        z: 5
        readonly property var spec: stageCard.sideSpec
        open: stageCard.sidePage !== "" && stageCard.visible && stageCard.fade > 0.5
        maxHeight: chrome.height * 0.7
        readonly property var spot: chrome.placeBeside(Qt.rect(stageCard.x, stageCard.y, stageCard.width, stageCard.height),
            stageSide.width, stageSide.height, stageCard.y + stageCard.sideY - 14, chrome.openNow)
        fromLeft: stageSide.spot.side === "left"
        x: stageSide.spot.x
        y: stageSide.spot.y
        Behavior on x {
            enabled: stageSide.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        Behavior on y {
            enabled: stageSide.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        title: stageCard.sidePage === "size" ? (stageCard.spec !== null ? "Size and corners" : "Corners")
            : stageSide.spec ? (stageSide.spec.label ?? "") : ""
        canReset: stageCard.sidePage === "size"
        resetLabel: "Default"
        onBack: stageCard.sidePage = ""
        onReset: {
            if (stageCard.spec !== null)
                BarLayout.clearPanelSize(stageCard.kind)
            BarLayout.setPanelRadius(stageCard.kind, -1)
        }

        EditChoice {
            Layout.fillWidth: true
            visible: stageCard.sidePage === "size" && stageCard.spec !== null
            maxPerRow: 3
            rowHeight: 34
            minCell: 70
            choices: stageCard.spec !== null ? BarLayout.panelPresets(stageCard.kind) : []
            isActive: function(v) { return BarLayout.presetActive(stageCard.kind, v) }
            onPicked: v => BarLayout.applyPreset(stageCard.kind, v)
        }

        PanelSizeSliders {
            Layout.fillWidth: true
            visible: stageCard.sidePage === "size" && stageCard.spec !== null && !stageCard.spec.fitOnly
            kind: stageCard.sidePage === "size" ? stageCard.kind : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: stageCard.sidePage === "size" && stageCard.cornerEdge !== ""
            spacing: 6
            CustomText {
                visible: stageCard.spec !== null
                content: "Corners"
                size: 13
            }
            EditStepper {
                Layout.fillWidth: true
                value: stageCard.cornerOwn >= 0 ? stageCard.cornerOwn : stageCard.cornerEdgeR
                from: 0
                to: 40
                stepSize: 1
                canAuto: true
                isAuto: stageCard.cornerOwn < 0
                autoLabel: "Like the bar"
                autoText: Math.round(stageCard.cornerEdgeR) + " px"
                onPicked: v => BarLayout.setPanelRadius(stageCard.kind, v)
                onAutoPicked: BarLayout.setPanelRadius(stageCard.kind, -1)
            }
        }

        EditPickList {
            visible: stageCard.sidePage === "opt" && !!stageSide.spec && stageSide.spec.type !== "shape"
            choices: stageCard.sidePage === "opt" && stageSide.spec && stageSide.spec.type !== "shape" ? (stageSide.spec.choices ?? []) : []
            value: stageSide.spec && stageCard.panelOpts ? BarLayout.opt(stageCard.panelOpts.item, stageSide.spec.key) : undefined
            onPicked: v => BarLayout.setOption(stageCard.panelOpts.item, stageSide.spec.key, v)
        }
    }

    BarEditShelf {
        id: shelf
        host: chrome
        capsuleItem: capsule
    }

    EditKeysSheet {
        z: 400
        desktop: false
    }
}
