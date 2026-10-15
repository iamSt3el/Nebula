import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.components.Bar
import qs.modules.settings
import qs.modules.services

BarField {
    id: sdf

    property var surfaces: []

    function fieldOf(s) {
        const f = s.sdfField
        return {
            swap: s.sdfMap.x, flip: s.sdfMap.y, z: s.sdfMap.z,
            top: s.sdfTop, bot: s.sdfBot, rMax: s.detachedField ? 0 : s.sdfRMax, cut: s.sdfCut,
            area: s.sdfArea,
            pills: f.pills, segs: f.segs, flares: f.flares, tabs: f.tabs
        }
    }

    function liftOf(s) {
        const f = s.sdfField.lift
        return {
            swap: s.sdfMap.x, flip: s.sdfMap.y, z: s.sdfMap.z,
            top: s.sdfTop, bot: s.sdfBot, rMax: f.k ?? s.sdfRMax, cut: s.sdfCut,
            area: s.sdfArea, own: 1,
            pills: f.pills, segs: f.segs, flares: [], tabs: f.tabs ?? []
        }
    }

    fields: {
        const live = sdf.surfaces.filter(s => s && s.visible)
        const out = live.filter(s => !s.detachedField).concat(live.filter(s => s.detachedField)).map(s => sdf.fieldOf(s))
        for (const s of live)
            if (out.length < 8 && s.sdfField.lift && (s.sdfField.lift.segs.length > 0 || (s.sdfField.lift.tabs ?? []).length > 0))
                out.push(sdf.liftOf(s))
        return out
    }

    function base(s, side) {
        if (!s || !s.visible || !s.present || s.allPill || s.side !== side)
            return 0
        return s.sdfBot * s.reveal
    }

    function inset(side) {
        let v = ServiceGaps.borderFor(side)
        for (const s of sdf.surfaces)
            v = Math.max(v, sdf.base(s, side))
        return v
    }

    frame: {
        const on = ServiceGaps.borderOn
        const t = sdf.inset("top")
        const r = sdf.inset("right")
        const b = sdf.inset("bottom")
        const l = sdf.inset("left")
        if (!on && t + r + b + l <= 0)
            return { on: 0 }
        const cr = Math.min(ServiceGaps.borderRadius, Math.max(0, sdf.width - l - r) / 2, Math.max(0, sdf.height - t - b) / 2)
        const corner = (a, c) => (on ? a > 0 && c > 0 : a > 0 || c > 0) ? cr : 0
        return {
            on: 1, top: t, right: r, bottom: b, left: l,
            tl: corner(t, l), tr: corner(t, r), bl: corner(b, l), br: corner(b, r)
        }
    }
    fillColor: Colors.surface
    edgeColor: Colors.outline
    edgeWidth: KindleMode.outlines ? KindleMode.edge : 0
    shadowColor: Colors.shadow
    shadowSize: BarLayout.shadowReach
    shadowStrength: BarLayout.shadowAlpha
}
