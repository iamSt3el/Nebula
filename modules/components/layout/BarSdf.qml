import QtQuick
import qs.modules.utils

Item {
    id: sdf

    property Item bar: null
    property Item dock: null

    readonly property var barField: sdf.bar ? sdf.bar.sdfField : null
    readonly property var dockField: sdf.dock && sdf.dock.visible ? sdf.dock.sdfField : null

    readonly property vector4d z4: Qt.vector4d(0, 0, 0, 0)

    readonly property var packed: {
        const b = sdf.barField
        const d = sdf.dockField
        return {
            bp: b ? b.pills : [], dp: d ? d.pills : [],
            bs: b ? b.segs : [], ds: d ? d.segs : [],
            bf: b ? b.flares : [], df: d ? d.flares : [],
            bt: b ? b.tabs : [], dt: d ? d.tabs : []
        }
    }

    function pill(i) {
        const k = sdf.packed
        const n = k.bp.length
        const q = i < n ? k.bp[i] : k.dp[i - n]
        return q ? Qt.vector4d(q.l, q.r, q.bot, i < n ? 0 : 1) : sdf.z4
    }
    function pillRad(i) {
        const k = sdf.packed
        const n = k.bp.length
        const q = i < n ? k.bp[i] : k.dp[i - n]
        return q ? Qt.vector4d(q.rtl, q.rtr, q.rbl, q.rbr) : sdf.z4
    }
    function segAt(i) {
        const k = sdf.packed
        const n = k.bs.length
        return i < n ? k.bs[i] : k.ds[i - n]
    }
    function seg(i) {
        const s = sdf.segAt(i)
        if (!s)
            return sdf.z4
        const dock = i >= sdf.packed.bs.length
        return Qt.vector4d(s.x, s.w, dock ? -s.bot : s.bot, s.gap)
    }
    function fil(i) {
        const s = sdf.segAt(i)
        return s ? Qt.vector4d(s.lineL, s.raL, s.lineR, s.raR) : sdf.z4
    }
    function rad(k) {
        const a = sdf.segAt(k * 2)
        const b = sdf.segAt(k * 2 + 1)
        if (!a && !b)
            return sdf.z4
        return Qt.vector4d(a ? a.rl : 0, a ? a.rr : 0, b ? b.rl : 0, b ? b.rr : 0)
    }
    function tabAt(i) {
        const k = sdf.packed
        const n = k.bt.length
        return i < n ? k.bt[i] : k.dt[i - n]
    }
    function tab(i) {
        const t = sdf.tabAt(i)
        return t ? Qt.vector4d(t.x, t.w, t.bot, i < sdf.packed.bt.length ? 0 : 1) : sdf.z4
    }
    function tabRad(i) {
        const t = sdf.tabAt(i)
        return t ? Qt.vector4d(t.rtl, t.rtr, t.rbl, t.rbr) : sdf.z4
    }
    function tabFil(i) {
        const t = sdf.tabAt(i)
        return t ? Qt.vector4d(t.lineL, t.rfL, t.lineR, t.rfR) : sdf.z4
    }
    function tabCon(i) {
        const t = sdf.tabAt(i)
        return t ? Qt.vector4d(t.conL, t.onL, t.conR, t.onR) : sdf.z4
    }
    function tabFlare(i) {
        const t = sdf.tabAt(i)
        return t ? Qt.vector4d(t.flL, t.mL, t.flR, t.mR) : sdf.z4
    }
    function flare(i) {
        const k = sdf.packed
        const n = k.bf.length
        const c = i < n ? k.bf[i] : k.df[i - n]
        return c ? Qt.vector4d(c.x, c.y, c.r, c.mode + (i < n ? 0 : 8)) : sdf.z4
    }

    readonly property rect none: Qt.rect(0, 0, 0, 0)

    function snap(r) {
        const x = Math.floor(r.x)
        const y = Math.floor(r.y)
        return Qt.rect(x, y, Math.ceil(r.x + r.width) - x, Math.ceil(r.y + r.height) - y)
    }

    readonly property rect areaA: sdf.barField ? sdf.snap(sdf.bar.sdfArea) : sdf.none
    readonly property rect areaB: sdf.dockField ? sdf.snap(sdf.dock.sdfArea) : sdf.none
    readonly property var pieces: {
        const a = sdf.areaA
        const b = sdf.areaB
        const out = []
        if (b.width <= 0 || b.height <= 0)
            return out
        const aR = a.x + a.width
        const aB = a.y + a.height
        const bR = b.x + b.width
        const bB = b.y + b.height
        if (a.width <= 0 || a.height <= 0 || a.x >= bR || b.x >= aR || a.y >= bB || b.y >= aB)
            return [b]
        if (a.y > b.y)
            out.push(Qt.rect(b.x, b.y, b.width, a.y - b.y))
        if (aB < bB)
            out.push(Qt.rect(b.x, aB, b.width, bB - aB))
        const my = Math.max(a.y, b.y)
        const mh = Math.min(aB, bB) - my
        if (a.x > b.x)
            out.push(Qt.rect(b.x, my, a.x - b.x, mh))
        if (aR < bR)
            out.push(Qt.rect(aR, my, bR - aR, mh))
        return out
    }

    readonly property color fillColor: Colors.surface
    readonly property real pillCount: sdf.packed.bp.length + sdf.packed.dp.length
    readonly property real segCount: sdf.packed.bs.length + sdf.packed.ds.length
    readonly property real flareCount: sdf.packed.bf.length + sdf.packed.df.length
    readonly property real tabCount: Math.min(4, sdf.packed.bt.length + sdf.packed.dt.length)
    readonly property vector4d tb0: sdf.tab(0)
    readonly property vector4d tbr0: sdf.tabRad(0)
    readonly property vector4d tbf0: sdf.tabFil(0)
    readonly property vector4d tbx0: sdf.tabFlare(0)
    readonly property vector4d tbc0: sdf.tabCon(0)
    readonly property vector4d tb1: sdf.tab(1)
    readonly property vector4d tbr1: sdf.tabRad(1)
    readonly property vector4d tbf1: sdf.tabFil(1)
    readonly property vector4d tbx1: sdf.tabFlare(1)
    readonly property vector4d tbc1: sdf.tabCon(1)
    readonly property vector4d tb2: sdf.tab(2)
    readonly property vector4d tbr2: sdf.tabRad(2)
    readonly property vector4d tbf2: sdf.tabFil(2)
    readonly property vector4d tbx2: sdf.tabFlare(2)
    readonly property vector4d tbc2: sdf.tabCon(2)
    readonly property vector4d tb3: sdf.tab(3)
    readonly property vector4d tbr3: sdf.tabRad(3)
    readonly property vector4d tbf3: sdf.tabFil(3)
    readonly property vector4d tbx3: sdf.tabFlare(3)
    readonly property vector4d tbc3: sdf.tabCon(3)
    readonly property real topA: sdf.barField ? sdf.bar.sdfTop : 0
    readonly property real rMaxA: sdf.barField ? sdf.bar.sdfRMax : 1
    readonly property real botA: sdf.barField ? sdf.bar.sdfBot : 0
    readonly property real topB: sdf.dockField ? sdf.dock.sdfTop : 0
    readonly property real rMaxB: sdf.dockField ? sdf.dock.sdfRMax : 1
    readonly property real botB: sdf.dockField ? sdf.dock.sdfBot : 0
    readonly property vector4d mapA: sdf.barField ? sdf.bar.sdfMap : sdf.z4
    readonly property vector4d mapB: sdf.dockField ? sdf.dock.sdfMap : sdf.z4
    readonly property real cutA: sdf.barField ? sdf.bar.sdfCut : -1
    readonly property real cutB: sdf.dockField ? sdf.dock.sdfCut : -1
    readonly property real blend: sdf.barField && sdf.dockField ? Math.min(sdf.rMaxA, sdf.rMaxB) : 0
    readonly property vector4d pil0: sdf.pill(0)
    readonly property vector4d pil1: sdf.pill(1)
    readonly property vector4d pil2: sdf.pill(2)
    readonly property vector4d pil3: sdf.pill(3)
    readonly property vector4d pil4: sdf.pill(4)
    readonly property vector4d pil5: sdf.pill(5)
    readonly property vector4d pil6: sdf.pill(6)
    readonly property vector4d pil7: sdf.pill(7)
    readonly property vector4d pir0: sdf.pillRad(0)
    readonly property vector4d pir1: sdf.pillRad(1)
    readonly property vector4d pir2: sdf.pillRad(2)
    readonly property vector4d pir3: sdf.pillRad(3)
    readonly property vector4d pir4: sdf.pillRad(4)
    readonly property vector4d pir5: sdf.pillRad(5)
    readonly property vector4d pir6: sdf.pillRad(6)
    readonly property vector4d pir7: sdf.pillRad(7)
    readonly property vector4d seg0: sdf.seg(0)
    readonly property vector4d seg1: sdf.seg(1)
    readonly property vector4d seg2: sdf.seg(2)
    readonly property vector4d seg3: sdf.seg(3)
    readonly property vector4d seg4: sdf.seg(4)
    readonly property vector4d seg5: sdf.seg(5)
    readonly property vector4d seg6: sdf.seg(6)
    readonly property vector4d seg7: sdf.seg(7)
    readonly property vector4d seg8: sdf.seg(8)
    readonly property vector4d seg9: sdf.seg(9)
    readonly property vector4d seg10: sdf.seg(10)
    readonly property vector4d seg11: sdf.seg(11)
    readonly property vector4d seg12: sdf.seg(12)
    readonly property vector4d seg13: sdf.seg(13)
    readonly property vector4d seg14: sdf.seg(14)
    readonly property vector4d seg15: sdf.seg(15)
    readonly property vector4d seg16: sdf.seg(16)
    readonly property vector4d seg17: sdf.seg(17)
    readonly property vector4d seg18: sdf.seg(18)
    readonly property vector4d seg19: sdf.seg(19)
    readonly property vector4d seg20: sdf.seg(20)
    readonly property vector4d seg21: sdf.seg(21)
    readonly property vector4d seg22: sdf.seg(22)
    readonly property vector4d seg23: sdf.seg(23)
    readonly property vector4d fil0: sdf.fil(0)
    readonly property vector4d fil1: sdf.fil(1)
    readonly property vector4d fil2: sdf.fil(2)
    readonly property vector4d fil3: sdf.fil(3)
    readonly property vector4d fil4: sdf.fil(4)
    readonly property vector4d fil5: sdf.fil(5)
    readonly property vector4d fil6: sdf.fil(6)
    readonly property vector4d fil7: sdf.fil(7)
    readonly property vector4d fil8: sdf.fil(8)
    readonly property vector4d fil9: sdf.fil(9)
    readonly property vector4d fil10: sdf.fil(10)
    readonly property vector4d fil11: sdf.fil(11)
    readonly property vector4d fil12: sdf.fil(12)
    readonly property vector4d fil13: sdf.fil(13)
    readonly property vector4d fil14: sdf.fil(14)
    readonly property vector4d fil15: sdf.fil(15)
    readonly property vector4d fil16: sdf.fil(16)
    readonly property vector4d fil17: sdf.fil(17)
    readonly property vector4d fil18: sdf.fil(18)
    readonly property vector4d fil19: sdf.fil(19)
    readonly property vector4d fil20: sdf.fil(20)
    readonly property vector4d fil21: sdf.fil(21)
    readonly property vector4d fil22: sdf.fil(22)
    readonly property vector4d fil23: sdf.fil(23)
    readonly property vector4d rad0: sdf.rad(0)
    readonly property vector4d rad1: sdf.rad(1)
    readonly property vector4d rad2: sdf.rad(2)
    readonly property vector4d rad3: sdf.rad(3)
    readonly property vector4d rad4: sdf.rad(4)
    readonly property vector4d rad5: sdf.rad(5)
    readonly property vector4d rad6: sdf.rad(6)
    readonly property vector4d rad7: sdf.rad(7)
    readonly property vector4d rad8: sdf.rad(8)
    readonly property vector4d rad9: sdf.rad(9)
    readonly property vector4d rad10: sdf.rad(10)
    readonly property vector4d rad11: sdf.rad(11)
    readonly property vector4d fc0: sdf.flare(0)
    readonly property vector4d fc1: sdf.flare(1)
    readonly property vector4d fc2: sdf.flare(2)
    readonly property vector4d fc3: sdf.flare(3)
    readonly property vector4d fc4: sdf.flare(4)
    readonly property vector4d fc5: sdf.flare(5)
    readonly property vector4d fc6: sdf.flare(6)
    readonly property vector4d fc7: sdf.flare(7)
    readonly property vector4d fc8: sdf.flare(8)
    readonly property vector4d fc9: sdf.flare(9)
    readonly property vector4d fc10: sdf.flare(10)
    readonly property vector4d fc11: sdf.flare(11)

    component Pass: ShaderEffect {
        property rect area
        x: area.x
        y: area.y
        width: area.width
        height: area.height
        visible: area.width > 0 && area.height > 0
        blending: true
        fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/barsdf4.frag.qsb")
        property color strokeColor: "transparent"
        property real strokeW: 0
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d origin: Qt.vector2d(x, y)
        property color fillColor: sdf.fillColor
        property real pillCount: sdf.pillCount
        property real segCount: sdf.segCount
        property real flareCount: sdf.flareCount
        property real tabCount: sdf.tabCount
        property vector4d tb0: sdf.tb0
        property vector4d tbr0: sdf.tbr0
        property vector4d tbf0: sdf.tbf0
        property vector4d tbx0: sdf.tbx0
        property vector4d tbc0: sdf.tbc0
        property vector4d tb1: sdf.tb1
        property vector4d tbr1: sdf.tbr1
        property vector4d tbf1: sdf.tbf1
        property vector4d tbx1: sdf.tbx1
        property vector4d tbc1: sdf.tbc1
        property vector4d tb2: sdf.tb2
        property vector4d tbr2: sdf.tbr2
        property vector4d tbf2: sdf.tbf2
        property vector4d tbx2: sdf.tbx2
        property vector4d tbc2: sdf.tbc2
        property vector4d tb3: sdf.tb3
        property vector4d tbr3: sdf.tbr3
        property vector4d tbf3: sdf.tbf3
        property vector4d tbx3: sdf.tbx3
        property vector4d tbc3: sdf.tbc3
        property real topA: sdf.topA
        property real rMaxA: sdf.rMaxA
        property real botA: sdf.botA
        property real topB: sdf.topB
        property real rMaxB: sdf.rMaxB
        property real botB: sdf.botB
        property vector4d mapA: sdf.mapA
        property vector4d mapB: sdf.mapB
        property real cutA: sdf.cutA
        property real cutB: sdf.cutB
        property real blend: sdf.blend
        property vector4d pil0: sdf.pil0
        property vector4d pil1: sdf.pil1
        property vector4d pil2: sdf.pil2
        property vector4d pil3: sdf.pil3
        property vector4d pil4: sdf.pil4
        property vector4d pil5: sdf.pil5
        property vector4d pil6: sdf.pil6
        property vector4d pil7: sdf.pil7
        property vector4d pir0: sdf.pir0
        property vector4d pir1: sdf.pir1
        property vector4d pir2: sdf.pir2
        property vector4d pir3: sdf.pir3
        property vector4d pir4: sdf.pir4
        property vector4d pir5: sdf.pir5
        property vector4d pir6: sdf.pir6
        property vector4d pir7: sdf.pir7
        property vector4d seg0: sdf.seg0
        property vector4d seg1: sdf.seg1
        property vector4d seg2: sdf.seg2
        property vector4d seg3: sdf.seg3
        property vector4d seg4: sdf.seg4
        property vector4d seg5: sdf.seg5
        property vector4d seg6: sdf.seg6
        property vector4d seg7: sdf.seg7
        property vector4d seg8: sdf.seg8
        property vector4d seg9: sdf.seg9
        property vector4d seg10: sdf.seg10
        property vector4d seg11: sdf.seg11
        property vector4d seg12: sdf.seg12
        property vector4d seg13: sdf.seg13
        property vector4d seg14: sdf.seg14
        property vector4d seg15: sdf.seg15
        property vector4d seg16: sdf.seg16
        property vector4d seg17: sdf.seg17
        property vector4d seg18: sdf.seg18
        property vector4d seg19: sdf.seg19
        property vector4d seg20: sdf.seg20
        property vector4d seg21: sdf.seg21
        property vector4d seg22: sdf.seg22
        property vector4d seg23: sdf.seg23
        property vector4d fil0: sdf.fil0
        property vector4d fil1: sdf.fil1
        property vector4d fil2: sdf.fil2
        property vector4d fil3: sdf.fil3
        property vector4d fil4: sdf.fil4
        property vector4d fil5: sdf.fil5
        property vector4d fil6: sdf.fil6
        property vector4d fil7: sdf.fil7
        property vector4d fil8: sdf.fil8
        property vector4d fil9: sdf.fil9
        property vector4d fil10: sdf.fil10
        property vector4d fil11: sdf.fil11
        property vector4d fil12: sdf.fil12
        property vector4d fil13: sdf.fil13
        property vector4d fil14: sdf.fil14
        property vector4d fil15: sdf.fil15
        property vector4d fil16: sdf.fil16
        property vector4d fil17: sdf.fil17
        property vector4d fil18: sdf.fil18
        property vector4d fil19: sdf.fil19
        property vector4d fil20: sdf.fil20
        property vector4d fil21: sdf.fil21
        property vector4d fil22: sdf.fil22
        property vector4d fil23: sdf.fil23
        property vector4d rad0: sdf.rad0
        property vector4d rad1: sdf.rad1
        property vector4d rad2: sdf.rad2
        property vector4d rad3: sdf.rad3
        property vector4d rad4: sdf.rad4
        property vector4d rad5: sdf.rad5
        property vector4d rad6: sdf.rad6
        property vector4d rad7: sdf.rad7
        property vector4d rad8: sdf.rad8
        property vector4d rad9: sdf.rad9
        property vector4d rad10: sdf.rad10
        property vector4d rad11: sdf.rad11
        property vector4d fc0: sdf.fc0
        property vector4d fc1: sdf.fc1
        property vector4d fc2: sdf.fc2
        property vector4d fc3: sdf.fc3
        property vector4d fc4: sdf.fc4
        property vector4d fc5: sdf.fc5
        property vector4d fc6: sdf.fc6
        property vector4d fc7: sdf.fc7
        property vector4d fc8: sdf.fc8
        property vector4d fc9: sdf.fc9
        property vector4d fc10: sdf.fc10
        property vector4d fc11: sdf.fc11
    }

    Pass { area: sdf.areaA }
    Pass { area: sdf.pieces[0] ?? sdf.none }
    Pass { area: sdf.pieces[1] ?? sdf.none }
    Pass { area: sdf.pieces[2] ?? sdf.none }
    Pass { area: sdf.pieces[3] ?? sdf.none }
}
