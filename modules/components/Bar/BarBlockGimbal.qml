pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: gimbal

    property var surfaces: []
    property QtObject editor: null
    property bool live: false

    readonly property string blockId: gimbal.editor ? gimbal.editor.gimbalBlock : ""
    property int rev: 0
    property string dragKey: ""
    property string hoverKey: ""
    property string tip: ""
    property bool tipSnap: false
    property var snap: null

    readonly property var found: {
        gimbal.rev
        if (gimbal.blockId === "")
            return null
        for (const s of gimbal.surfaces) {
            if (!s || !s.visible || !s.present)
                continue
            const list = s.visibleBlocks.filter(o => !o.leaving && o.width > 0 && !o.tuckedAway)
            const i = list.findIndex(o => o.blockId === gimbal.blockId)
            if (i < 0)
                continue
            const b = list[i]
            const prev = i > 0 && list[i - 1].anchorSide === b.anchorSide ? list[i - 1] : null
            const next = i + 1 < list.length && list[i + 1].anchorSide === b.anchorSide ? list[i + 1] : null
            const group = list.filter(o => o.anchorSide === b.anchorSide)
            return { s: s, b: b, prev: prev, next: next, first: group[0], last: group[group.length - 1] }
        }
        return null
    }

    readonly property bool shown: gimbal.live && BarLayout.gapModel && gimbal.found !== null && !EditSession.peek
    property real showT: gimbal.shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    visible: gimbal.showT > 0.01
    opacity: gimbal.showT

    onShownChanged: if (!gimbal.shown) gimbal.endDrag()

    Repeater {
        model: gimbal.surfaces
        Item {
            required property var modelData
            Connections {
                target: modelData
                function onGeometryUpdated() { gimbal.rev++ }
            }
        }
    }
    Connections {
        target: SettingsConfig
        function onBarChanged() { gimbal.rev++ }
    }

    function pt(s, along, depth) {
        const r = s.toScreen(along, s.far ? s.height - depth : depth, 0, 0)
        return Qt.point(r.x, r.y)
    }

    readonly property var geo: {
        gimbal.rev
        const f = gimbal.found
        if (!f)
            return null
        const s = f.s
        const b = f.b
        const g = BarLayout.blockGaps(b.blockId, s.edge)
        const x0 = s.blockX(b)
        const x1 = x0 + b.width
        const top = s.blockTop(b)
        const far = top + s.barH
        const mid = top + s.barH / 2
        const r = Math.min(g.radius < 0 ? s.disX : g.radius, s.barH / 2)
        const o = gimbal.pt(s, 0, 0)
        const a = gimbal.pt(s, 1, 0)
        const d = gimbal.pt(s, 0, 1)
        const c0 = gimbal.pt(s, x0 - 5, top - 5)
        const c1 = gimbal.pt(s, x1 + 5, far + 5)
        return {
            ua: Qt.point(a.x - o.x, a.y - o.y), ud: Qt.point(d.x - o.x, d.y - o.y),
            left: gimbal.pt(s, x0 - 22, mid), leftFoot: gimbal.pt(s, x0 - 4, mid),
            right: gimbal.pt(s, x1 + 22, mid), rightFoot: gimbal.pt(s, x1 + 4, mid),
            lift: gimbal.pt(s, (x0 + x1) / 2, far + 34), liftFoot: gimbal.pt(s, (x0 + x1) / 2, far + 4),
            corner: gimbal.pt(s, x0 + r * 0.29, far - r * 0.29),
            box: Qt.rect(Math.min(c0.x, c1.x), Math.min(c0.y, c1.y), Math.abs(c1.x - c0.x), Math.abs(c1.y - c0.y)),
            radius: r + 5, vertical: s.vertical, edge: s.edge,
            gapL: f.prev ? (g.gapBefore >= 0 ? g.gapBefore : BarLayout.edgeGaps(s.edge).block) : -1,
            lifted: g.edge, rad: r, full: s.barH / 2
        }
    }

    function sideSpec(side) {
        const f = gimbal.found
        if (!f)
            return null
        const nb = side === "left" ? f.prev : f.next
        if (nb)
            return { mode: "gap", owner: side === "left" ? f.b.blockId : f.next.blockId }
        const a = f.b.anchorSide
        if (a !== "left" && a !== "right")
            return null
        const owner = a === "left" ? f.first.blockId : f.last.blockId
        const towardEnd = (a === "left") === (side === "left")
        if (towardEnd && BarLayout.blockGaps(owner, f.s.edge).offset < 28)
            return null
        return { mode: "offset", owner: owner, sign: a === "left" ? 1 : -1 }
    }

    readonly property var specL: { gimbal.rev; return gimbal.sideSpec("left") }
    readonly property var specR: { gimbal.rev; return gimbal.sideSpec("right") }

    function offsetOf(id) {
        const f = gimbal.found
        return f ? BarLayout.blockGaps(id, f.s.edge).offset : 0
    }

    function gapAfter() {
        const f = gimbal.found
        if (!f || !f.next)
            return -1
        const own = BarLayout.blockGaps(f.next.blockId, f.s.edge).gapBefore
        return own >= 0 ? own : BarLayout.edgeGaps(f.s.edge).block
    }

    function nameOf(b) {
        if (!b)
            return ""
        const blk = BarLayout.blockById(b.blockId)
        const names = (blk ? blk.items : []).map(i => BarLayout.entry(i)).filter(e => !!e).map(e => e.label)
        if (!names.length)
            return BarLayout.blockLabel(b.blockId)
        return names.length > 2 ? names.slice(0, 2).join(" · ") + " +" + (names.length - 2) : names.join(" · ")
    }

    function words(key, v) {
        const f = gimbal.found
        if (!f)
            return ""
        if ((key === "left" || key === "right") && gimbal.sideSpec(key) && gimbal.sideSpec(key).mode === "offset") {
            if (v === undefined)
                return "Drag to move this group along the edge · click to put it back at the end"
            return v <= 0 ? "!At the end of the bar" : v + " px from the end of the bar"
        }
        if (key === "left" || key === "right") {
            const other = key === "left" ? f.prev : f.next
            if (v === undefined) {
                const cur = key === "left" ? gimbal.geo.gapL : gimbal.gapAfter()
                return (cur <= 0 ? "Merged with " : "Apart from ") + gimbal.nameOf(other) + " · drag to change · click to " + (cur <= 0 ? "separate" : "merge")
            }
            return v <= 0 ? "!Merged with " + gimbal.nameOf(other) : v + " px from " + gimbal.nameOf(other)
        }
        if (key === "lift") {
            if (v === undefined)
                return "Drag away from the edge to lift this block, toward it to set it on the edge"
            return v <= 0 ? "!On the edge" : "Lifted " + v + " px"
        }
        if (key === "corner") {
            if (v === undefined)
                return "Drag inward to round this block's corners"
            return v <= 0 ? "!Square corners" : v >= gimbal.geo.full ? "!Fully round" : "Corners " + v + " px"
        }
        return ""
    }

    function say(text) {
        gimbal.tipSnap = text.startsWith("!")
        gimbal.tip = gimbal.tipSnap ? text.slice(1) : text
    }

    function startDrag(key) {
        const f = gimbal.found
        if (!f)
            return
        const g = gimbal.geo
        const spec = key === "left" || key === "right" ? gimbal.sideSpec(key) : null
        gimbal.snap = {
            key: key, edge: f.s.edge, id: f.b.blockId, next: f.next ? f.next.blockId : "", anchor: f.b.anchorSide,
            spec: spec, offset: spec && spec.mode === "offset" ? gimbal.offsetOf(spec.owner) : 0,
            ua: g.ua, ud: g.ud, left: g.gapL, right: gimbal.gapAfter(), lift: g.lifted, rad: g.rad, full: Math.floor(g.full),
            moved: false
        }
        gimbal.dragKey = key
        EditSession.holding = true
    }

    function moveDrag(dx, dy) {
        const sn = gimbal.snap
        if (!sn)
            return
        if (Math.hypot(dx, dy) > 3)
            sn.moved = true
        if (!sn.moved)
            return
        const da = dx * sn.ua.x + dy * sn.ua.y
        const dd = dx * sn.ud.x + dy * sn.ud.y
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
        const gap = v => v < 3 ? 0 : v
        if (sn.spec && sn.spec.mode === "offset") {
            const v = clamp(gap(sn.offset + sn.spec.sign * da), 0, 800)
            BarLayout.draftBlockStyle(sn.edge, sn.spec.owner, { offset: v })
            gimbal.say(gimbal.words(sn.key, Math.round(v)))
        } else if (sn.key === "left") {
            const k = sn.anchor === "left" ? 1 : sn.anchor === "right" ? -1 : 2
            const v = clamp(gap(sn.left + k * da), 0, 60)
            BarLayout.draftBlockStyle(sn.edge, sn.id, { gapBefore: v })
            gimbal.say(gimbal.words("left", Math.round(v)))
        } else if (sn.key === "right") {
            const k = sn.anchor === "left" ? 1 : sn.anchor === "right" ? -1 : -2
            const v = clamp(gap(sn.right + k * da), 0, 60)
            BarLayout.draftBlockStyle(sn.edge, sn.next, { gapBefore: v })
            gimbal.say(gimbal.words("right", Math.round(v)))
        } else if (sn.key === "lift") {
            const v = clamp(gap(sn.lift + dd), 0, 60)
            BarLayout.draftBlockStyle(sn.edge, sn.id, { edgeGap: v })
            gimbal.say(gimbal.words("lift", Math.round(v)))
        } else if (sn.key === "corner") {
            let v = clamp(sn.rad + (da - dd) / 0.58, 0, sn.full)
            v = v >= sn.full - 1 ? sn.full : v < 1 ? 0 : v
            BarLayout.draftBlockStyle(sn.edge, sn.id, { radius: v })
            gimbal.say(gimbal.words("corner", Math.round(v)))
        }
    }

    function endDrag() {
        const sn = gimbal.snap
        if (!sn)
            return
        if (sn.moved) {
            BarLayout.commitGapDraft(null)
        } else if (sn.spec && sn.spec.mode === "offset") {
            BarLayout.setBlockStyle(sn.spec.owner, "offset", undefined)
        } else if (sn.key === "left" || sn.key === "right") {
            const id = sn.key === "left" ? sn.id : sn.next
            const cur = sn.key === "left" ? sn.left : sn.right
            const base = BarLayout.edgeGaps(sn.edge).block
            BarLayout.setBlockStyle(id, "gapBefore", cur > 0 ? 0 : base > 0 ? undefined : 10)
        }
        gimbal.snap = null
        gimbal.dragKey = ""
        EditSession.release()
        gimbal.say(gimbal.hoverKey !== "" ? gimbal.words(gimbal.hoverKey) : "")
        if (gimbal.hoverKey === "")
            gimbal.tip = ""
    }

    component Stem: Rectangle {
        property point from
        property point to
        readonly property real len: Math.hypot(to.x - from.x, to.y - from.y)
        x: (from.x + to.x) / 2 - len / 2
        y: (from.y + to.y) / 2 - 1
        width: len
        height: 2
        radius: 1
        rotation: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
        antialiasing: true
    }

    component Knob: Item {
        id: knob
        required property string key
        property point at
        property string icon: ""
        property color fill: Colors.primaryContainer
        property color ink: Colors.primaryContainerText
        property real base: 30
        property real iconRot: 0
        property bool shownKnob: true
        readonly property bool active: gimbal.dragKey === knob.key
        readonly property bool hot: knob.active || area.containsMouse
        visible: knob.shownKnob && (gimbal.dragKey === "" || knob.active)
        x: Math.round(knob.at.x - width / 2)
        y: Math.round(knob.at.y - height / 2)
        width: knob.base + (knob.hot ? 6 : 0)
        height: width
        z: knob.active ? 3 : 2
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: knob.hot ? Colors.primary : knob.fill
            border.width: 2
            border.color: Qt.alpha(Colors.surface, 0.9)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            visible: knob.icon !== ""
            content: knob.icon
            iconSize: Math.round(knob.width * 0.58)
            rotation: knob.iconRot
            customColor: knob.hot ? Colors.primaryText : knob.ink
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            preventStealing: true
            cursorShape: knob.key === "corner" ? Qt.SizeFDiagCursor : Qt.SizeAllCursor
            property point start
            onEntered: {
                gimbal.hoverKey = knob.key
                if (gimbal.dragKey === "")
                    gimbal.say(gimbal.words(knob.key))
            }
            onExited: {
                if (gimbal.hoverKey === knob.key)
                    gimbal.hoverKey = ""
                if (gimbal.dragKey === "")
                    gimbal.tip = ""
            }
            onPressed: mouse => {
                area.start = area.mapToItem(gimbal, mouse.x, mouse.y)
                gimbal.startDrag(knob.key)
            }
            onPositionChanged: mouse => {
                if (!area.pressed)
                    return
                const p = area.mapToItem(gimbal, mouse.x, mouse.y)
                gimbal.moveDrag(p.x - area.start.x, p.y - area.start.y)
            }
            onReleased: gimbal.endDrag()
            onCanceled: gimbal.endDrag()
        }
    }

    Item {
        id: rig
        anchors.fill: parent
        opacity: gimbal.dragKey === "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Rectangle {
            visible: !!gimbal.geo
            x: gimbal.geo ? gimbal.geo.box.x : 0
            y: gimbal.geo ? gimbal.geo.box.y : 0
            width: gimbal.geo ? gimbal.geo.box.width : 0
            height: gimbal.geo ? gimbal.geo.box.height : 0
            radius: gimbal.geo ? Math.min(gimbal.geo.radius, Math.min(width, height) / 2) : 0
            color: Qt.alpha(Colors.primary, 0.06)
            border.width: 2
            border.color: Colors.primary
        }

        Stem {
            visible: !!gimbal.geo && gimbal.specL !== null && (gimbal.dragKey === "" || gimbal.dragKey === "left")
            from: gimbal.geo ? gimbal.geo.leftFoot : Qt.point(0, 0)
            to: gimbal.geo ? gimbal.geo.left : Qt.point(0, 0)
            color: Colors.primary
        }
        Stem {
            visible: !!gimbal.geo && gimbal.specR !== null && (gimbal.dragKey === "" || gimbal.dragKey === "right")
            from: gimbal.geo ? gimbal.geo.rightFoot : Qt.point(0, 0)
            to: gimbal.geo ? gimbal.geo.right : Qt.point(0, 0)
            color: Colors.primary
        }
        Stem {
            visible: !!gimbal.geo && (gimbal.dragKey === "" || gimbal.dragKey === "lift")
            from: gimbal.geo ? gimbal.geo.liftFoot : Qt.point(0, 0)
            to: gimbal.geo ? gimbal.geo.lift : Qt.point(0, 0)
            color: Colors.tertiary
        }

        Knob {
            key: "left"
            readonly property bool linked: gimbal.specL !== null && gimbal.specL.mode === "gap" && !!gimbal.geo && gimbal.geo.gapL <= 0
            shownKnob: !!gimbal.geo && gimbal.specL !== null
            at: gimbal.geo ? gimbal.geo.left : Qt.point(0, 0)
            icon: linked ? "link" : "chevron_left"
            iconRot: gimbal.geo && gimbal.geo.vertical && !linked ? 90 : 0
            fill: linked ? Colors.primary : Colors.primaryContainer
        }
        Knob {
            key: "right"
            readonly property real cur: { gimbal.rev; return gimbal.gapAfter() }
            readonly property bool linked: gimbal.specR !== null && gimbal.specR.mode === "gap" && cur === 0
            shownKnob: !!gimbal.geo && gimbal.specR !== null
            at: gimbal.geo ? gimbal.geo.right : Qt.point(0, 0)
            icon: linked ? "link" : "chevron_right"
            iconRot: gimbal.geo && gimbal.geo.vertical && !linked ? 90 : 0
            fill: linked ? Colors.primary : Colors.primaryContainer
        }
        Knob {
            key: "lift"
            at: gimbal.geo ? gimbal.geo.lift : Qt.point(0, 0)
            icon: "unfold_more"
            iconRot: gimbal.geo && gimbal.geo.vertical ? 90 : 0
            fill: Colors.tertiaryContainer
            ink: Colors.tertiaryContainerText
        }
        Knob {
            key: "corner"
            base: 16
            at: gimbal.geo ? gimbal.geo.corner : Qt.point(0, 0)
        }

        Rectangle {
            id: nameChip
            readonly property point liftAt: gimbal.geo ? gimbal.geo.lift : Qt.point(0, 0)
            readonly property bool side: !!gimbal.geo && gimbal.geo.vertical
            readonly property bool onLeft: !!gimbal.geo && gimbal.geo.edge === "left"
            visible: !!gimbal.geo && gimbal.dragKey === "" && gimbal.tip === ""
            x: Math.round(nameChip.side && !nameChip.onLeft ? liftAt.x - width - 24 : liftAt.x + 24)
            y: Math.round(liftAt.y - height / 2)
            width: nameRow.implicitWidth + 20
            height: 28
            radius: 14
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colors.outline, 0.3)

            Row {
                id: nameRow
                anchors.centerIn: parent
                spacing: 6
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: gimbal.found ? gimbal.nameOf(gimbal.found.b) : ""
                    size: 12
                    weight: 600
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "· right-click to close"
                    size: 11
                    customColor: Colors.outline
                }
            }
        }
    }

    Rectangle {
        id: tipBox
        readonly property point at: {
            const g = gimbal.geo
            if (!g)
                return Qt.point(0, 0)
            const k = gimbal.dragKey !== "" ? gimbal.dragKey : gimbal.hoverKey
            return k === "left" ? g.left : k === "right" ? g.right : k === "corner" ? g.corner : g.lift
        }
        visible: gimbal.tip !== "" && !!gimbal.geo && (gimbal.dragKey === "" || gimbal.dragKey === "corner")
        z: 5
        x: Math.round(Math.max(8, Math.min(gimbal.width - width - 8, tipBox.at.x - width / 2)))
        y: Math.round(tipBox.at.y > gimbal.height / 2 ? tipBox.at.y - height - 30 : tipBox.at.y + 30)
        width: tipText.implicitWidth + 22
        height: 30
        radius: 10
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: gimbal.tipSnap ? Colors.primary : Colors.outlineVariant

        CustomText {
            id: tipText
            anchors.centerIn: parent
            content: gimbal.tip
            size: 12
            weight: 500
            customColor: gimbal.tipSnap ? Colors.primary : Colors.surfaceText
        }
    }
}
