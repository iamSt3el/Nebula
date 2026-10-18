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

    function closeAll() {
        if (GlobalStates.editKeysOpen) { GlobalStates.editKeysOpen = false; return true }
        if (capRow.closeAll()) return true
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
            if (BarLayout.popupMode === "item")
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
        for (const t of [toolbar, blockBar, styleCard, cornersCard])
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

    readonly property var shapeChoices: [
        { value: "stepped", label: "Stepped", icon: "view_agenda" },
        { value: "flat",    label: "Flat",    icon: "remove" },
        { value: "pill",    label: "Pill",    icon: "circle" }
    ]

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

    MouseArea {
        anchors.fill: parent
        visible: chrome.pop !== ""
        onClicked: chrome.pop = ""
    }

    EditKit.Card {
        id: capsule
        readonly property Item floor: chrome.surfBottom && chrome.surfBottom.visible && chrome.surfBottom.present ? chrome.surfBottom : null
        readonly property real dockTop: capsule.floor ? capsule.floor.bandRect.y : chrome.height
        readonly property real topY: chrome.surfTop && chrome.surfTop.visible && chrome.surfTop.present
            ? chrome.surfTop.thickness + (chrome.topGrips ? 46 : 16)
            : chrome.surfTop && chrome.surfTop.visible ? 56 : 20
        readonly property bool lowered: chrome.topBusy && !chrome.bottomBusy
        function spans(x, w) {
            return x < capsule.restX + capsule.fullW + 8 && x + w > capsule.restX - 8
        }
        readonly property real yieldTo: {
            let b = 0
            if (toolbar.shown && !toolbar.side && toolbar.below && capsule.spans(toolbar.x, toolbar.width))
                b = Math.max(b, chrome.selRect.y + chrome.selRect.height + 44 + toolbar.height)
            if (blockBar.shown && !blockBar.side && blockBar.below && capsule.spans(blockBar.x, blockBar.width))
                b = Math.max(b, chrome.blockRect.y + chrome.blockRect.height + 48 + blockBar.height)
            return b
        }
        readonly property real restY: capsule.lowered ? capsule.dockTop - 56 - 52
            : Math.max(capsule.topY, capsule.yieldTo > 0 ? capsule.yieldTo + 14 : 0)
        property real restYAnim: capsule.restY
        Behavior on restYAnim { SpatialAnim { speed: "default" } }
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
                { key: "panels", icon: "view_quilt", label: "Panels", lit: chrome.stage },
                { key: "reset", icon: "restart_alt", label: chrome.resetArmed ? "Reset layout" : "",
                  tip: chrome.resetArmed ? "" : "Reset layout", danger: chrome.resetArmed, lit: chrome.resetArmed }
            ]
            onLogo: {
                GlobalStates.closeEdit()
                GlobalStates.settingsPage = 9
                GlobalStates.settingsOpen = true
            }
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
                } else if (key === "reset") {
                    if (!chrome.resetArmed) {
                        chrome.resetArmed = true
                        resetDisarm.restart()
                        return
                    }
                    chrome.resetArmed = false
                    resetDisarm.stop()
                    BarLayout.reset()
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

    EditKit.Card {
        id: toolbar
        readonly property var entry: chrome.sel !== "" && chrome.sel.indexOf("dash:") !== 0 ? BarLayout.entry(chrome.sel) : null
        readonly property var styleSpec: toolbar.entry && toolbar.entry.options
            ? toolbar.entry.options.find(o => o.key === "style" && (o.type === "grid" || o.type === "choice") && o.choices) ?? null : null
        readonly property var labelSpec: toolbar.entry && toolbar.entry.options
            ? toolbar.entry.options.find(o => o.key === "showLabel") ?? null : null
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
        readonly property bool side: chrome.selEdge === "left" || chrome.selEdge === "right"
        readonly property bool below: chrome.selEdge !== "bottom"

        property real showT: toolbar.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: toolbar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toolbar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: toolbar.showT > 0.01
        opacity: Math.min(1, toolbar.showT * 1.5)
        transform: Scale {
            origin.x: chrome.selEdge === "left" ? -44
                : chrome.selEdge === "right" ? toolbar.width + 44
                : chrome.selRect.x + chrome.selRect.width / 2 - toolbar.x
            origin.y: toolbar.side ? toolbar.height / 2 : toolbar.below ? -44 : toolbar.height + 44
            xScale: 0.2 + 0.8 * toolbar.showT
            yScale: 0.3 + 0.7 * toolbar.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12,
            chrome.selEdge === "left" ? chrome.selRect.x + chrome.selRect.width + 44
            : chrome.selEdge === "right" ? chrome.selRect.x - width - 44
            : chrome.selRect.x + chrome.selRect.width / 2 - width / 2))
        y: chrome.avoidCap(x, width, toolbar.side ? chrome.selRect.y + chrome.selRect.height / 2 - height / 2
            : toolbar.below ? chrome.selRect.y + chrome.selRect.height + 44
            : chrome.selRect.y - height - 44, height)
        height: 52
        width: toolRow.implicitWidth + 12
        radius: 26

        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 2

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
                        color: dot.modelData.value === "none" ? "transparent" : BarLayout.roleColor(dot.modelData.value)
                        border.width: dot.modelData.value === "none" ? 2 : 0
                        border.color: Colors.outline

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
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (toolbar.colorSpec)
                                    BarLayout.setOption(chrome.sel, "color", dot.modelData.value)
                                else
                                    BarLayout.setItemStyle(chrome.sel, "tint", dot.modelData.value)
                            }
                        }
                    }
                }
            }

            EditKit.Divider { Layout.leftMargin: 4; Layout.rightMargin: 4 }

            EditKit.Pill {
                visible: toolbar.labelSpec !== null && toolbar.placed
                icon: "text_fields"
                lit: toolbar.labelSpec !== null && BarLayout.opt(chrome.sel, "showLabel") === true
                onClicked: BarLayout.setOption(chrome.sel, "showLabel", !(BarLayout.opt(chrome.sel, "showLabel") === true))
            }
            EditKit.Pill {
                id: optsPill
                visible: chrome.toggleOptsOf(chrome.sel).length > 0
                icon: "toggle_on"
                lit: chrome.pop === "opts"
                onClicked: chrome.pop = chrome.pop === "opts" ? "" : "opts"
            }
            EditKit.Pill {
                visible: toolbar.panel !== null
                icon: "open_in_full"
                label: toolbar.panel ? toolbar.panel.label : ""
                lit: true
                onClicked: chrome.openStage(chrome.sel)
            }
            EditKit.Pill {
                readonly property var host: toolbar.placed ? BarLayout.blockOfItem(chrome.sel) : null
                visible: !!host && host.items.indexOf(chrome.sel) > 0
                icon: "call_split"
                tip: "Split the block before this item"
                onClicked: {
                    const id = chrome.sel
                    const blockId = host.id
                    chrome.editor.selectedItem = ""
                    Qt.callLater(() => BarLayout.splitBlockAt(blockId, id))
                }
            }
            EditKit.Pill {
                id: toolTune
                icon: "tune"
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
        readonly property string shape: chrome.selBlock !== "" ? BarLayout.blockShape(chrome.selBlock) : ""
        readonly property var blockInfo: chrome.selBlock !== "" ? BarLayout.blockById(chrome.selBlock) : null
        readonly property string tint: chrome.selBlock !== "" ? BarLayout.blockStyle(chrome.selBlock, "tint", "none") : "none"
        readonly property bool split: chrome.selBlock !== "" && BarLayout.splitBlock(chrome.selBlock)
        readonly property string panels: blockBar.blockInfo ? BarLayout.panelStyleFor(chrome.selBlock, blockBar.blockInfo.edge, blockBar.shape) : ""
        readonly property bool shown: chrome.editing && chrome.selBlock !== "" && chrome.blockFound && !chrome.dragging
                                      && !chrome.stage && !chrome.drawerShown && !chrome.shelfOpen
        readonly property bool side: chrome.blockEdge === "left" || chrome.blockEdge === "right"
        readonly property bool below: chrome.blockEdge !== "bottom"

        property real showT: blockBar.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: blockBar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blockBar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: blockBar.showT > 0.01
        opacity: Math.min(1, blockBar.showT * 1.5)
        transform: Scale {
            origin.x: chrome.blockRect.x + chrome.blockRect.width / 2 - blockBar.x
            origin.y: blockBar.side ? blockBar.height / 2 : blockBar.below ? -44 : blockBar.height + 44
            xScale: 0.2 + 0.8 * blockBar.showT
            yScale: 0.3 + 0.7 * blockBar.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12,
            chrome.blockEdge === "left" ? chrome.blockRect.x + chrome.blockRect.width + 104
            : chrome.blockEdge === "right" ? chrome.blockRect.x - width - 104
            : chrome.blockRect.x + chrome.blockRect.width / 2 - width / 2))
        y: chrome.avoidCap(x, width, blockBar.side ? chrome.blockRect.y + chrome.blockRect.height / 2 - height / 2
            : blockBar.below ? chrome.blockRect.y + chrome.blockRect.height + 48
            : chrome.blockRect.y - height - 48, height)
        height: 52
        width: blockRow.implicitWidth + 12
        radius: 26

        RowLayout {
            id: blockRow
            anchors.centerIn: parent
            spacing: 2

            CustomText {
                Layout.leftMargin: 12
                Layout.rightMargin: 6
                content: chrome.selBlock !== "" ? BarLayout.blockLabel(chrome.selBlock) : ""
                size: 13
                weight: 600
            }

            Repeater {
                model: BarLayout.gapModel ? [] : chrome.shapeChoices

                EditKit.Pill {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    lit: blockBar.shape === modelData.value
                    onClicked: BarLayout.setBlockShape(chrome.selBlock, modelData.value)
                }
            }

            RowLayout {
                id: edgeGapCtl
                visible: BarLayout.gapModel && chrome.selBlock !== ""
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
                    tip: "Follow the edge's gap"
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
                visible: blockBar.shape !== ""
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            Row {
                Layout.leftMargin: 6
                Layout.rightMargin: 8
                spacing: 7
                visible: blockBar.shape !== ""

                Repeater {
                    model: chrome.tints

                    Rectangle {
                        id: blockDot
                        required property var modelData
                        readonly property bool on: blockBar.tint === blockDot.modelData.value
                        width: 22
                        height: 22
                        radius: 11
                        color: blockDot.modelData.value === "none" ? "transparent" : BarLayout.roleColor(blockDot.modelData.value)
                        border.width: blockDot.modelData.value === "none" ? 2 : 0
                        border.color: Colors.outline

                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: 15
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.primary
                            visible: blockDot.on
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarLayout.setBlockStyle(chrome.selBlock, "tint", blockDot.modelData.value)
                        }
                    }
                }
            }

            EditKit.Pill {
                visible: blockBar.shape === "pill"
                icon: "interests"
                label: "Shapes"
                lit: blockBar.split
                onClicked: BarLayout.setBlockSplit(chrome.selBlock, !blockBar.split)
            }

            RowLayout {
                id: cornerChoice
                visible: BarLayout.gapModel && chrome.selBlock !== "" && !blockBar.split
                spacing: 2
                readonly property real full: blockBar.blockInfo ? BarLayout.edge(blockBar.blockInfo.edge).height / 2 : 20
                readonly property var own: BarLayout.blockStyle(chrome.selBlock, "radius", null)
                readonly property bool has: typeof cornerChoice.own === "number" && cornerChoice.own >= 0
                readonly property string pick: !cornerChoice.has ? "follow" : cornerChoice.own <= 0.5 ? "square"
                    : cornerChoice.own >= cornerChoice.full - 0.5 ? "round" : "soft"
                function set(v) {
                    BarLayout.setBlockStyle(chrome.selBlock, "radius", v === "follow" ? undefined
                        : v === "square" ? 0 : v === "round" ? Math.floor(cornerChoice.full) : Math.round(cornerChoice.full / 2))
                }
                function nudge(d) {
                    const cur = cornerChoice.has ? cornerChoice.own : BarLayout.blockGaps(chrome.selBlock, blockBar.blockInfo.edge).radius
                    const base = cur < 0 ? cornerChoice.full : cur
                    BarLayout.setBlockStyle(chrome.selBlock, "radius", Math.max(0, Math.min(Math.floor(cornerChoice.full), Math.round(base) + d)))
                }
                EditKit.Divider {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }
                Repeater {
                    model: [
                        { v: "follow", icon: "link", tip: "Corners follow the edge" },
                        { v: "square", icon: "crop_square", tip: "Square corners" },
                        { v: "soft", icon: "rounded_corner", tip: "Soft corners · scroll to adjust" },
                        { v: "round", icon: "circle", tip: "Fully round" }
                    ]
                    EditKit.Pill {
                        required property var modelData
                        icon: modelData.icon
                        box: 36
                        lit: cornerChoice.pick === modelData.v
                        tip: modelData.tip
                        onClicked: cornerChoice.set(modelData.v)
                    }
                }
                WheelStep {
                    onStepped: dir => cornerChoice.nudge(dir)
                }
            }

            RowLayout {
                id: radiusCtl
                visible: !BarLayout.gapModel && blockBar.shape === "pill" && !blockBar.split
                spacing: 0
                readonly property real full: blockBar.blockInfo ? BarLayout.edge(blockBar.blockInfo.edge).height / 2 : 20
                readonly property real cur: BarLayout.blockStyle(chrome.selBlock, "radius", -1)
                readonly property real now: radiusCtl.cur < 0 ? radiusCtl.full : Math.min(radiusCtl.cur, radiusCtl.full)
                function nudge(d) {
                    const n = Math.max(0, radiusCtl.now + d)
                    BarLayout.setBlockStyle(chrome.selBlock, "radius", n >= radiusCtl.full ? -1 : n)
                }
                MaterialIconSymbol {
                    Layout.leftMargin: 8
                    content: "rounded_corner"
                    iconSize: 18
                    customColor: Colors.surfaceVariantText
                }
                EditKit.Pill {
                    icon: "remove"
                    box: 32
                    tip: "Less rounded"
                    usable: radiusCtl.now > 0
                    onClicked: radiusCtl.nudge(-1)
                }
                CustomText {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignHCenter
                    content: radiusCtl.cur < 0 ? "Full" : Math.round(radiusCtl.now) + ""
                    size: 12
                    weight: 600
                    font.features: { "tnum": 1 }
                }
                EditKit.Pill {
                    icon: "add"
                    box: 32
                    tip: "More rounded"
                    usable: radiusCtl.cur >= 0
                    onClicked: radiusCtl.nudge(1)
                }
                WheelStep {
                    onStepped: dir => radiusCtl.nudge(dir)
                }
            }

            EditKit.Pill {
                id: cornersPill
                visible: radiusCtl.visible || cornerChoice.visible
                icon: "rounded_corner"
                box: 32
                tip: "Each corner"
                lit: chrome.pop === "corners" || cornersCard.custom
                onClicked: chrome.pop = chrome.pop === "corners" ? "" : "corners"
            }

            EditKit.Divider {
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            EditKit.Pill {
                icon: "vertical_align_top"
                label: "Attached"
                lit: blockBar.panels === "attached"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", "attached")
            }

            EditKit.Pill {
                icon: "join_inner"
                label: "Merged"
                lit: blockBar.panels === "merged"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", "merged")
            }

            EditKit.Pill {
                icon: "bubble_chart"
                label: "Floating"
                lit: blockBar.panels === "floating"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", "floating")
            }

            EditKit.Pill {
                visible: BarLayout.ownPanels(chrome.selBlock) !== "" && !(blockBar.shape === "pill" && BarLayout.splitBlock(chrome.selBlock))
                icon: "sync"
                box: 32
                tip: "Follow the edge's panel style"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", undefined)
            }

            RowLayout {
                id: panelGapCtl
                visible: blockBar.panels === "floating" || blockBar.panels === "merged"
                spacing: 0
                readonly property real now: BarLayout.blockPanelGap(chrome.selBlock)
                readonly property bool own: BarLayout.blockStyle(chrome.selBlock, "panelGap", null) !== null
                function nudge(d) {
                    BarLayout.setBlockStyle(chrome.selBlock, "panelGap", Math.max(0, Math.min(40, panelGapCtl.now + d)))
                    BarLayout.flashGap("panelGap", "", chrome.selBlock)
                }
                EditKit.Divider {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }
                MaterialIconSymbol {
                    Layout.leftMargin: 4
                    content: blockBar.side ? "width" : "height"
                    iconSize: 18
                    customColor: Colors.surfaceVariantText
                }
                EditKit.Pill {
                    icon: "remove"
                    box: 32
                    tip: "Smaller panel gap"
                    usable: panelGapCtl.now > 0
                    onClicked: panelGapCtl.nudge(-2)
                }
                CustomText {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignHCenter
                    content: Math.round(panelGapCtl.now) + ""
                    size: 12
                    weight: 600
                    font.features: { "tnum": 1 }
                }
                EditKit.Pill {
                    icon: "add"
                    box: 32
                    tip: "Bigger panel gap"
                    usable: panelGapCtl.now < 40
                    onClicked: panelGapCtl.nudge(2)
                }
                EditKit.Pill {
                    visible: panelGapCtl.own
                    icon: "sync"
                    box: 32
                    tip: "Follow the edge's panel gap"
                    onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panelGap", null)
                }
                WheelStep {
                    onStepped: dir => panelGapCtl.nudge(2 * dir)
                }
                HoverHandler {
                    onHoveredChanged: BarLayout.hoverGap(hovered, "panelGap", "", chrome.selBlock)
                }
            }
        }
    }

    EditKit.Card {
        id: styleCard
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
        x: Math.max(12, Math.min(chrome.width - width - 12, toolbar.x))
        y: styleCard.up ? Math.max(12, toolbar.y - height - 8) : toolbar.y + toolbar.height + 8
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
        id: optsCard
        readonly property var opts: chrome.toggleOptsOf(chrome.sel)
        readonly property bool shown: chrome.pop === "opts" && toolbar.shown && optsCard.opts.length > 0
        readonly property bool up: !toolbar.below || toolbar.y + toolbar.height + 8 + optsCard.height > chrome.height - 12
        readonly property real anchorX: toolbar.x + toolRow.x + optsPill.x + optsPill.width / 2
        property real showT: optsCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: optsCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: optsCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: optsCard.showT > 0.01
        opacity: Math.min(1, optsCard.showT * 1.5)
        transform: Scale {
            origin.x: optsCard.anchorX - optsCard.x
            origin.y: optsCard.up ? optsCard.height + 8 : -8
            xScale: 0.5 + 0.5 * optsCard.showT
            yScale: 0.15 + 0.85 * optsCard.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12, optsCard.anchorX - width / 2))
        y: optsCard.up ? Math.max(12, toolbar.y - height - 8) : toolbar.y + toolbar.height + 8
        width: 340
        height: optsFlow.implicitHeight + 28
        radius: 22

        Flow {
            id: optsFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 6

            Repeater {
                model: optsCard.opts

                EditKit.ChoiceChip {
                    required property var modelData
                    readonly property bool isOn: BarLayout.opt(chrome.sel, modelData.key) === true
                    label: modelData.label
                    lit: isOn
                    onClicked: BarLayout.setOption(chrome.sel, modelData.key, !isOn)
                }
            }
        }
    }

    EditKit.Card {
        id: cornersCard
        readonly property var corners: chrome.selBlock !== "" ? BarLayout.blockCorners(chrome.selBlock) : ({ tl: null, tr: null, br: null, bl: null })
        readonly property bool custom: ["tl", "tr", "br", "bl"].some(k => cornersCard.corners[k] !== null)
        readonly property real full: radiusCtl.full
        readonly property real base: radiusCtl.now
        property bool linked: false
        readonly property bool shown: chrome.pop === "corners" && blockBar.shown && cornersPill.visible
        readonly property bool up: !blockBar.side && !blockBar.below
        readonly property real anchorX: blockBar.x + blockRow.x + cornersPill.x + cornersPill.width / 2
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
        x: Math.max(12, Math.min(chrome.width - width - 12, cornersCard.anchorX - width / 2))
        y: cornersCard.up ? Math.max(12, blockBar.y - height - 8)
            : Math.min(chrome.height - height - 12, blockBar.y + blockBar.height + 8)
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
                CustomText {
                    Layout.fillWidth: true
                    content: "Corners"
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
                    tip: "Follow the block radius"
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
            if ((side === "left" ? roomL : roomR) < 400)
                side = roomL >= roomR ? "left" : "right"
            room = side === "left" ? roomL : roomR
        }
        if (side !== chrome.stageSide)
            chrome.stageSide = side
        if (Math.abs(room - chrome.stageRoom) > 1)
            chrome.stageRoom = room
        const w = Math.min(400, Math.max(320, room))
        const left = side !== "" ? side === "left" : stageCard.defaultLeft
        const cx = left ? chrome.insetLeft + 16 : chrome.width - w - chrome.insetRight - 16
        const hold = closing.some(q => q.width > 0 && q.x < cx + w && q.x + q.width > cx && q.y < stageCard.y + stageCard.height && q.y + q.height > stageCard.y)
        if (hold !== chrome.stageHold)
            chrome.stageHold = hold
    }
    property real capShiftTarget: 0
    property real capShift: chrome.capShiftTarget
    Behavior on capShift { SpatialAnim { speed: "default" } }

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

    function scanBusy() {
        const w = capsule.fullW
        const x = (chrome.width - w) / 2
        const bottomY = capsule.dockTop - 56 - 22
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
        for (const s of chrome.surfaces) {
            if (!s || !s.visible)
                continue
            for (const blk of s.visibleBlocks) {
                if (blk.tabH <= blk.barH + 1)
                    continue
                const r = s.tabRect(blk)
                if (hit(r, bottomY))
                    bottom = true
                if (hit(r, topY))
                    top = true
            }
        }
        if (chrome.bottomBusy !== bottom)
            chrome.bottomBusy = bottom
        if (chrome.topBusy !== top)
            chrome.topBusy = top
        const shift = top && bottom ? chrome.freeShift(chrome.openRects(), w, topY) : 0
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

    BarEdgeLanes {
        id: lanes
        host: chrome
    }

    BarEditPins {
        id: pins
        host: chrome
    }

    BarEditStage {
        id: stageCard
        host: chrome
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
