pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: pins

    required property Item host

    anchors.fill: parent

    readonly property var ed: pins.host.editor
    readonly property bool calm: pins.host.editing && !pins.host.shelfOpen && !pins.host.drawerShown
    readonly property bool dragging: !!pins.ed && pins.ed.mode !== ""
    property var groups: []
    property string groupsKey: ""

    function itemRect(id) {
        for (const s of pins.host.surfaces) {
            if (!s || !s.visible || !s.present)
                continue
            for (const b of s.visibleBlocks) {
                if (!b.hasItem(id))
                    continue
                const it = b.itemFor(id)
                if (!it)
                    continue
                return { r: it.mapToItem(pins, 0, 0, it.width, it.height), side: s.side,
                         busy: b.blockId === pins.host.selBlock || b.hovering || b.gripShown }
            }
        }
        return null
    }

    function edgeSpot(side) {
        const s = pins.host.surfaces.find(x => x && x.edge === side)
        if (s && s.visible && s.present) {
            const b = s.bandRect
            return s.vertical ? Qt.rect(b.x, pins.height / 2 - 20, b.width, 40) : Qt.rect(pins.width / 2 - 20, b.y, 40, b.height)
        }
        switch (side) {
        case "top": return Qt.rect(pins.width / 2 - 20, 0, 40, 4)
        case "left": return Qt.rect(0, pins.height / 2 - 20, 4, 40)
        case "right": return Qt.rect(pins.width - 4, pins.height / 2 - 20, 4, 40)
        }
        return Qt.rect(pins.width / 2 - 20, pins.height - 4, 40, 4)
    }

    function scan() {
        const out = {}
        const order = []
        const sel = pins.host.stage ? pins.host.panelOf(pins.host.sel) : null
        for (const p of pins.host.panelList) {
            const anchorKind = p.kind === "notifPopup" || p.kind === "osd"
            if (!pins.host.stage && !anchorKind)
                continue
            const h = pins.host.hostOf(p)
            if (!pins.host.stage && h.type !== "item")
                continue
            let spot = null
            let key = h.type
            if (h.type === "item") {
                spot = pins.itemRect(h.item)
                key = "item:" + h.item
            } else if (h.type === "sys") {
                spot = { r: pins.edgeSpot(BarLayout.sysEdge), side: BarLayout.sysEdge }
            } else if (h.type === "icons") {
                const dock = BarLayout.allBlocks.flatMap(b => b.items).find(i => BarLayout.baseId(i) === "dockApps")
                spot = dock ? pins.itemRect(dock) : null
                if (!spot)
                    spot = { r: pins.edgeSpot(BarLayout.sysEdge), side: BarLayout.sysEdge }
            } else if (h.type === "center") {
                spot = { r: Qt.rect(pins.width / 2 - 1, pins.height / 2 - 1, 2, 2), side: "center" }
            } else if (h.type === "corner") {
                spot = { r: Qt.rect(pins.width - 2, pins.height - 2, 2, 2), side: "corner" }
            }
            if (!spot)
                continue
            if (!out[key]) {
                out[key] = { key: key, side: spot.side, x: Math.round(spot.r.x), y: Math.round(spot.r.y),
                             w: Math.round(spot.r.width), h: Math.round(spot.r.height), busy: spot.busy === true, pins: [] }
                order.push(key)
            }
            const via = h.type === "item" && BarLayout.baseId(h.item) !== p.item && p.kind !== "notifPopup" && p.kind !== "osd"
            const viaEntry = via ? BarLayout.entry(h.item) : null
            out[key].pins.push({ item: p.item, kind: p.kind, label: p.label, icon: p.icon,
                                 sub: viaEntry ? "via " + viaEntry.label.toLowerCase() : "",
                                 on: sel !== null && sel.kind === p.kind,
                                 tag: !pins.host.stage })
        }
        const rects = pins.host.openRects().concat(pins.host.toolRects()).map(r => [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)])
        if (JSON.stringify(rects) !== JSON.stringify(pins.open))
            pins.open = rects
        const list = order.map(k => out[k])
        const json = JSON.stringify(list)
        if (json !== pins.groupsKey) {
            pins.groupsKey = json
            pins.groups = list
        }
        pins.resolve()
    }

    Timer {
        interval: 180
        repeat: true
        triggeredOnStart: true
        running: pins.host.editing && !pins.dragging
        onTriggered: pins.scan()
    }

    function startDrag(p, mx, my, w) {
        pins.host.startPinDrag(p, mx, my, w)
    }

    function finishDrag(p) {
        pins.host.finishPinDrag(p)
    }

    property var open: []
    property var nudges: ({})
    property string nudgeKey: ""

    function resolve() {
        const placed = []
        const out = {}
        for (let i = 0; i < groupRep.count; i++) {
            const it = groupRep.itemAt(i)
            if (!it || it.rw <= 0)
                continue
            const along = it.g.side === "left" || it.g.side === "right"
            let x = it.baseX
            let y = it.baseY
            for (let n = 0; n < 8; n++) {
                const hit = placed.find(r => x < r.x + r.w + 6 && x + it.rw + 6 > r.x && y < r.y + r.h + 6 && y + 30 + 6 > r.y)
                if (!hit)
                    break
                if (along)
                    y = hit.y + hit.h + 6
                else
                    x = hit.x + hit.w + 6
            }
            placed.push({ x: x, y: y, w: it.rw, h: 30 })
            if (x !== it.baseX || y !== it.baseY)
                out[it.g.key] = { dx: x - it.baseX, dy: y - it.baseY }
        }
        const json = JSON.stringify(out)
        if (json !== pins.nudgeKey) {
            pins.nudgeKey = json
            pins.nudges = out
        }
    }

    Repeater {
        id: groupRep
        model: pins.groups

        delegate: Item {
            id: group

            required property var modelData
            readonly property var g: group.modelData
            readonly property real rw: row.implicitWidth
            readonly property real cx: group.g.x + group.g.w / 2
            readonly property real cy: group.g.y + group.g.h / 2

            readonly property var nudge: pins.nudges[group.g.key] ?? null
            readonly property real baseX: group.g.side === "left" ? group.g.x + group.g.w + 10
                : group.g.side === "right" ? group.g.x - 10 - group.rw
                : group.g.side === "corner" ? pins.width - group.rw - 24 - pins.host.insetRight
                : Math.max(pins.host.insetLeft + 12, Math.min(pins.width - pins.host.insetRight - group.rw - 12, group.cx - group.rw / 2))
            readonly property real baseY: group.g.side === "top" ? group.g.y + group.g.h + 10
                : group.g.side === "bottom" ? group.g.y - 40
                : group.g.side === "corner" ? pins.height - 30 - 24
                : group.cy - 15
            x: group.baseX + (group.nudge ? group.nudge.dx : 0)
            y: group.baseY + (group.nudge ? group.nudge.dy : 0)
            width: group.rw
            height: 30
            readonly property bool covered: pins.open.some(r => group.x < r[0] + r[2] && group.x + group.width > r[0]
                                                               && group.y < r[1] + r[3] && group.y + group.height > r[1])
            opacity: pins.calm && !pins.dragging && !GlobalStates.barEditTest && !group.covered && !group.g.busy ? 1 : 0
            visible: opacity > 0.01 || pinDragActive
            property bool pinDragActive: false
            Behavior on opacity { EffectsAnim { speed: "fast" } }

            Row {
                id: row
                spacing: 6

                Repeater {
                    model: group.g.pins

                    delegate: Rectangle {
                        id: pin

                        required property var modelData
                        readonly property var p: pin.modelData

                        width: pinRow.implicitWidth + 22
                        height: 30
                        radius: pinArea.pressed ? 10 : 15
                        color: pin.p.on ? Colors.primary
                            : pin.p.tag ? Colors.primaryContainer
                            : pinArea.containsMouse ? Colors.surfaceContainerHighest : Colors.secondaryContainer
                        border.width: 1
                        border.color: Qt.alpha(Colors.outline, 0.25)
                        Behavior on color { EffectsColorAnim { speed: "fast" } }
                        Behavior on radius { SpatialAnim { speed: "fast" } }

                        readonly property color ink: pin.p.on ? Colors.primaryText
                            : pin.p.tag ? Colors.primaryContainerText
                            : pinArea.containsMouse ? Colors.surfaceText : Colors.secondaryContainerText

                        RowLayout {
                            id: pinRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                content: pin.p.icon
                                iconSize: 16
                                customColor: pin.ink
                            }
                            CustomText {
                                content: pin.p.label
                                size: 12
                                weight: 600
                                customColor: pin.ink
                            }
                            CustomText {
                                visible: pin.p.sub !== ""
                                content: pin.p.sub
                                size: 11
                                customColor: Qt.alpha(pin.ink, 0.7)
                            }
                        }

                        MouseArea {
                            id: pinArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: pins.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                            property real sx: 0
                            property real sy: 0

                            onPressed: mouse => {
                                pinArea.sx = mouse.x
                                pinArea.sy = mouse.y
                            }
                            onPositionChanged: mouse => {
                                if (!pinArea.pressed)
                                    return
                                const sp = pinArea.mapToItem(null, mouse.x, mouse.y)
                                if (!pins.dragging && Math.hypot(mouse.x - pinArea.sx, mouse.y - pinArea.sy) > 6) {
                                    group.pinDragActive = true
                                    pins.startDrag(pin.p, sp.x, sp.y, 28)
                                } else if (pins.dragging) {
                                    pins.ed.update(sp.x, sp.y)
                                }
                            }
                            onReleased: {
                                if (group.pinDragActive) {
                                    group.pinDragActive = false
                                    pins.finishDrag(pin.p)
                                    return
                                }
                                pins.host.openStage(pin.p.item)
                            }
                            onCanceled: {
                                if (group.pinDragActive) {
                                    group.pinDragActive = false
                                    pins.ed.cancel()
                                }
                            }
                        }

                        CustomToolTip {
                            content: pin.p.tag ? pin.p.label + " appear here · click for options, drag to move"
                                               : "Click to preview · drag onto a block to open it from there"
                            visible: pinArea.containsMouse && !pinArea.pressed
                        }
                    }
                }
            }
        }
    }
}
