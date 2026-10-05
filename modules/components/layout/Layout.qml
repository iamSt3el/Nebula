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
    property Item dashEditor: null
    property Item dashInspector: null
    readonly property Item editTopSurface: topSurface
    readonly property Item editBottomSurface: bottomSurface
    function loadEditors() {
        layout.editChrome = editChromeComp.createObject(root)
        layout.drawerHost = drawerComp.createObject(root)
        layout.dashEditor = dashEditorComp.createObject(root)
        layout.dashInspector = dashInspectorComp.createObject(root)
        layout.syncDrawer()
        Qt.callLater(() => layout.editorsLive = true)
    }
    function unloadEditors() {
        for (const o of [layout.editChrome, layout.drawerHost, layout.dashEditor, layout.dashInspector])
            if (o) o.destroy()
        layout.editChrome = null
        layout.drawerHost = null
        layout.dashEditor = null
        layout.dashInspector = null
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
        const opener = layout.panelPreview === "dashboard" || barEditor.selectedItem.indexOf("dash:") === 0
            ? BarLayout.panelHostItem("dashboard") : barEditor.selectedItem
        const b = BarLayout.allBlocks.find(x => x.items.indexOf(opener) >= 0)
        return b ? b.anchor : "right"
    }
    readonly property bool previewRight: layout.dashPreview
        ? layout.dashAnchor !== "left"
        : ServiceLauncher.position === "item"
          && BarLayout.allBlocks.some(b => b.anchor === "right" && b.items.indexOf("launcher") >= 0)
    readonly property real popupY: topSurface.rowItem.y + Appearance.size.barHeight + (topSurface.barMode === "pill" ? 8 : 4)

    WlrLayershell.namespace: "quickshell:bar"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: layout.barEditing ? WlrKeyboardFocus.Exclusive
                               : isPrimary && ((GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") !== "center")
                                               || (GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") !== "center")
                                               || GlobalStates.powerPanelOpen
                                               || GlobalStates.scenesPanelOpen
                                               || GlobalStates.dockSearchActive
                                               || (GlobalStates.appLauncherOpen && GlobalStates.launcherHosted)) ? WlrKeyboardFocus.OnDemand
                                                             : WlrKeyboardFocus.None

    onBarEditingChanged: {
        topSurface.floatKind = ""
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
        && !(barEditor.drawerMode === "options" && barEditor.selectedItem === "dashboard")
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
            d.tab = "bar"
        if (layout.drawerWanted) d.open()
        else d.close()
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
        active: layout.isPrimary && GlobalStates.appLauncherOpen && GlobalStates.launcherHosted
        onCleared: if (!active) GlobalStates.appLauncherOpen = false
    }

    mask: Region{
        item: maskRect;
        intersection: Intersection.Xor;

        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[0] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[1] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[2] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[3] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[4] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[5] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[6] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: isPrimary ? (topSurface.visibleBlocks[7] ?? null) : null
            readonly property rect r: blk ? topSurface.blockRect(blk) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }

        Region {
            readonly property Item tb: isPrimary ? (topSurface.openTabs[0] ?? null) : null
            readonly property rect r: tb ? topSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item tb: isPrimary ? (topSurface.openTabs[1] ?? null) : null
            readonly property rect r: tb ? topSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item tb: isPrimary ? (topSurface.openTabs[2] ?? null) : null
            readonly property rect r: tb ? topSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item tb: isPrimary ? (topSurface.openTabs[3] ?? null) : null
            readonly property rect r: tb ? topSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }

        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[0] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[1] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[2] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[3] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[4] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item blk: bottomSurface.visible ? (bottomSurface.visibleBlocks[5] ?? null) : null
            readonly property rect r: blk ? (bottomSurface.dockHidden ? bottomSurface.hiddenRect(blk) : bottomSurface.blockRect(blk)) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item tb: bottomSurface.visible ? (bottomSurface.openTabs[0] ?? null) : null
            readonly property rect r: tb ? bottomSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
        Region {
            readonly property Item tb: bottomSurface.visible ? (bottomSurface.openTabs[1] ?? null) : null
            readonly property rect r: tb ? bottomSurface.tabRect(tb) : Qt.rect(0, 0, 0, 0)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }

        Region {
            x: 0; y: 0
            width:  layout.barEditing ? layout.width  : 0
            height: layout.barEditing ? layout.height : 0
            intersection: Intersection.Subtract
        }

        Region{
            x: 0
            y: ServiceGaps.barSide === "bottom" ? layout.height - Appearance.size.barHeight : 0
            width:  isPrimary ? 0 : layout.width
            height: isPrimary ? 0 : Appearance.size.barHeight
            intersection: Intersection.Subtract
        }

        Region {
            x:      topSurface.dashCard.x
            y:      topSurface.dashCard.y
            width:  topSurface.dashCard.visible ? topSurface.dashCard.width  : 0
            height: topSurface.dashCard.visible ? topSurface.dashCard.height : 0
            intersection: Intersection.Subtract
        }
        Region {
            x:      topSurface.weatherCard.x
            y:      topSurface.weatherCard.y
            width:  topSurface.weatherCard.visible ? topSurface.weatherCard.width  : 0
            height: topSurface.weatherCard.visible ? topSurface.weatherCard.height : 0
            intersection: Intersection.Subtract
        }
        Region {
            x:      bottomSurface.dashCard.x
            y:      bottomSurface.dashCard.y
            width:  bottomSurface.dashCard.visible ? bottomSurface.dashCard.width  : 0
            height: bottomSurface.dashCard.visible ? bottomSurface.dashCard.height : 0
            intersection: Intersection.Subtract
        }
        Region {
            x:      bottomSurface.weatherCard.x
            y:      bottomSurface.weatherCard.y
            width:  bottomSurface.weatherCard.visible ? bottomSurface.weatherCard.width  : 0
            height: bottomSurface.weatherCard.visible ? bottomSurface.weatherCard.height : 0
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
            if (bottomSurface.visible && BarLayout.dockOn) {
                const p = bottomSurface.toFrame(x, y)
                if (bottomSurface.inBand(p.x, p.y, 40))
                    return bottomSurface
            }
            const q = topSurface.toFrame(x, y)
            if (topSurface.inBand(q.x, q.y, 36))
                return topSurface
            return null
        }

        function trackApp(x, y) {
            barEditor.overDrawer = root.inDrawerAt(x, y)
            let g = null
            for (const b of bottomSurface.visibleBlocks) {
                g = b.appGeom()
                if (g)
                    break
            }
            const f = bottomSurface.toFrame(x, y)
            if (barEditor.overDrawer || !g || root.surfaceAt(x, y) !== bottomSurface
                    || f.x < g.x - 30 || f.x > g.x + g.w + 30) {
                barEditor.appDropIndex = -1
                return
            }
            barEditor.appDropIndex = BarOps.appDropIndex(g.apps, barEditor.appId, f.x)
        }

        function trackItem(x, y) {
            const inDrawer = root.inDrawerAt(x, y)
            barEditor.overDrawer = inDrawer
            barEditor.refusedTarget = ""
            const surf = inDrawer ? null : root.surfaceAt(x, y)
            if (!surf) {
                barEditor.dropBlock = ""
                return
            }
            const f = surf.toFrame(x, y)
            x = f.x
            y = f.y
            let best = null
            let bestD = 1e9
            for (const b of surf.visibleBlocks) {
                if (b.leaving || b.blockId === "__sys")
                    continue
                const bx = surf.rowItem.x + b.parent.x + b.x
                const d = x < bx ? bx - x : (x > bx + b.width ? x - bx - b.width : 0)
                if (d < bestD) {
                    bestD = d
                    best = b
                }
            }
            if (!best || bestD > 80) {
                barEditor.dropBlock = ""
                return
            }
            if (!BarLayout.allows(barEditor.itemId, surf.edge)) {
                barEditor.dropBlock = ""
                barEditor.refusedTarget = best.blockId
                return
            }
            barEditor.dropBlock = best.blockId
            barEditor.dropIndex = best.dropIndexAt(x - (surf.rowItem.x + best.parent.x + best.x))
        }

        function trackBlock(sx, sy) {
            const surf = root.surfaceAt(sx, sy) ?? root.nearestSurface(sx, sy)
            const f = surf.toFrame(sx, sy)
            const x = f.x
            const W = surf.rowItem.width
            const rel = x - surf.rowItem.x
            const side = rel < W / 3 ? "left" : (rel > 2 * W / 3 ? "right" : "center")
            const rep = side === "left" ? surf.leftRepeater : (side === "center" ? surf.centerRepeater : surf.rightRepeater)
            const group = side === "left" ? surf.leftGroupItem : (side === "center" ? surf.centerGroupItem : surf.rightGroupItem)
            const others = []
            for (let i = 0; i < rep.count; i++) {
                const b = rep.itemAt(i)
                if (b && b.blockId !== barEditor.fromBlock && b.visible && !b.leaving)
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
            barEditor.dropAnchor = side
            barEditor.dropEdge = surf.edge
            barEditor.dropBlockIndex = idx
            const cr = surf.toScreen(surf.rowItem.x + Math.max(4, Math.min(W - 4, caret)) - 1.5,
                                     surf.rowItem.y + group.y + 4, 3, surf.barH - 8)
            barEditor.caretX = cr.x
            barEditor.caretY = cr.y
            barEditor.caretW = cr.width
            barEditor.caretH = cr.height
        }

        function nearestSurface(x, y) {
            if (!bottomSurface.visible || !BarLayout.dockOn)
                return topSurface
            const dist = s => {
                const r = s.bandRect
                const dx = x < r.x ? r.x - x : (x > r.x + r.width ? x - r.x - r.width : 0)
                const dy = y < r.y ? r.y - y : (y > r.y + r.height ? y - r.y - r.height : 0)
                return Math.hypot(dx, dy)
            }
            return dist(bottomSurface) < dist(topSurface) ? bottomSurface : topSurface
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
            property string dropEdge: "top"
            property real caretY: 0
            property real caretW: 3
            property real caretH: 0
            property string refusedTarget: ""
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

            onSelectedItemChanged: {
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
                if (mode === "item" && !hide && toBlock !== "")
                    dragGhost.beginLanding(id)
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
                    } else if (toBlock !== "") {
                        Qt.callLater(() => BarLayout.moveItem(id, toBlock, toIndex))
                    }
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
                barEditor.refusedTarget = ""
                barEditor.appId = ""
                barEditor.appPinned = false
                barEditor.appDropIndex = -1
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
            color: Qt.alpha(Colors.surface, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    editKeys.forceActiveFocus()
                    if (barEditor.mode !== "")
                        return
                    if (editChrome && editChrome.closeAll())
                        return
                    if (barEditor.selectedItem !== "")
                        barEditor.selectedItem = ""
                    else if (!root.surfaceAt(mouse.x, mouse.y))
                        GlobalStates.barEditMode = false
                }
            }
        }

        Shape {
            id: screenBorder
            anchors.fill: parent
            visible: ServiceGaps.borderOn
            preferredRendererType: Shape.CurveRenderer

            function base(s, side) {
                if (!s || !s.visible || s.barMode === "pill" || s.side !== side)
                    return 0
                return s.sdfBot * (s.isDock ? s.reveal : 1)
            }
            function inset(side) {
                return Math.max(ServiceGaps.borderFor(side),
                                screenBorder.base(topSurface, side), screenBorder.base(bottomSurface, side))
            }
            readonly property real insetT: screenBorder.inset("top")
            readonly property real insetR: screenBorder.inset("right")
            readonly property real insetB: screenBorder.inset("bottom")
            readonly property real insetL: screenBorder.inset("left")
            readonly property real holeW: Math.max(0, width - insetL - insetR)
            readonly property real holeH: Math.max(0, height - insetT - insetB)
            readonly property real cornerR: Math.min(ServiceGaps.borderRadius, holeW / 2, holeH / 2)

            ShapePath {
                fillColor: Colors.surface
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                PathRectangle { x: 0; y: 0; width: screenBorder.width; height: screenBorder.height }
                PathRectangle {
                    x: screenBorder.insetL
                    y: screenBorder.insetT
                    width: screenBorder.holeW
                    height: screenBorder.holeH
                    topLeftRadius: screenBorder.insetT > 0 && screenBorder.insetL > 0 ? screenBorder.cornerR : 0
                    topRightRadius: screenBorder.insetT > 0 && screenBorder.insetR > 0 ? screenBorder.cornerR : 0
                    bottomLeftRadius: screenBorder.insetB > 0 && screenBorder.insetL > 0 ? screenBorder.cornerR : 0
                    bottomRightRadius: screenBorder.insetB > 0 && screenBorder.insetR > 0 ? screenBorder.cornerR : 0
                }
            }
        }

        BarSdf {
            anchors.fill: parent
            bar: topSurface
            dock: bottomSurface
        }

        BarSurface {
            id: topSurface
            isPrimary: layout.isPrimary
            editor: barEditor
        }

        BarSurface {
            id: bottomSurface
            edge: "bottom"
            isPrimary: layout.isPrimary
            editor: barEditor
            visible: layout.isPrimary && !ServiceGameMode.hideWidgets && BarLayout.dockOn
        }

        Rectangle {
            z: 250
            visible: barEditor.mode === "block" && barEditor.caretX >= 0
            x: barEditor.caretX
            y: barEditor.caretY
            width: barEditor.caretW
            height: barEditor.caretH
            radius: 1.5
            color: Colors.primary
        }

        Component {
            id: editChromeComp
            BarEditChrome {
                z: 210
                editor: barEditor
                topSurface: layout.editTopSurface
                bottomSurface: layout.editBottomSurface
                editing: layout.barEditing && layout.editorsLive
                previewRight: layout.previewRight
            }
        }

        Component {
            id: drawerComp
            BarEditDrawer {
                z: 220
                editor: barEditor
                maxHeight: layout.height * 0.7
                width: Math.min(640, root.width - 32)
                x: !layout.anyPreview ? (root.width - width) / 2
                    : layout.previewRight ? 24 : root.width - width - 24
                y: BarLayout.barSide === "top" ? layout.editTopSurface.rowItem.y + Appearance.size.barHeight + 48
                    : BarLayout.dockSide === "top" ? ServiceGaps.topFinal + 24 : 48
                Behavior on x {
                    SpatialAnim { speed: "default" }
                }
            }
        }

        Component {
            id: dashEditorComp
            DashEditorWindow {
                z: 221
                editor: barEditor
                editing: layout.barEditing && layout.editorsLive
                topLimit: 96
            }
        }

        Component {
            id: dashInspectorComp
            DashInspector {
                z: 221
                editor: barEditor
                editing: layout.barEditing && layout.editorsLive
                topLimit: 96
            }
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
                for (const surf of [topSurface, bottomSurface]) {
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

        Item {
            id: editKeys
            anchors.fill: parent
            focus: layout.barEditing
            Keys.onEscapePressed: {
                if (barEditor.mode !== "") barEditor.cancel()
                else if (editChrome && editChrome.closeAll()) return
                else if (barEditor.selectedItem !== "") barEditor.selectedItem = ""
                else GlobalStates.barEditMode = false
            }
            Keys.onPressed: event => {
                if (!(event.modifiers & Qt.ControlModifier) || !editChrome)
                    return
                if (event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) editChrome.redo()
                else if (event.key === Qt.Key_Z) editChrome.undo()
                else if (event.key === Qt.Key_Y) editChrome.redo()
                else return
                event.accepted = true
            }
        }

    }

    property bool isToolsWidgetClicked: false
    property bool isSettingClicked: false
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
        anchors.rightMargin: topSurface.side === "right" ? topSurface.bandRect.width
            : bottomSurface.visible && bottomSurface.side === "right" ? bottomSurface.bandRect.width : 0
        anchors.bottomMargin: topSurface.side === "bottom" ? topSurface.bandRect.height : 0
        active: isPrimary && (SettingsConfig.general?.notifPopupStyle ?? "corner") === "corner"
        sourceComponent: NotificationPanel {}
    }

    NotificationPopups {
        id: notifStyled
        anchors.fill: parent
        visible: isPrimary
        topSurface: topSurface
        bottomSurface: bottomSurface
    }

    readonly property int _topGap: ServiceGaps.topFinal
}
