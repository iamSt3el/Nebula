import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.components.Bar
import qs.modules.settings
import qs.modules.services
import "../Bar/BarGeom.js" as Geom

BlobField {
    id: blob

    property var surfaces: []

    smoothing: {
        let k = 0
        for (const s of blob.surfaces)
            if (s && s.visible && s.present)
                k = Math.max(k, s.disX)
        return k > 0 ? k : 14
    }

    readonly property var hole: ({
        l: ServiceGaps.borderFor("left"), t: ServiceGaps.borderFor("top"),
        r: blob.width - ServiceGaps.borderFor("right"), b: blob.height - ServiceGaps.borderFor("bottom")
    })

    frame: {
        if (!ServiceGaps.borderOn)
            return { on: 0 }
        const t = ServiceGaps.borderFor("top")
        const r = ServiceGaps.borderFor("right")
        const b = ServiceGaps.borderFor("bottom")
        const l = ServiceGaps.borderFor("left")
        const cr = Math.min(ServiceGaps.borderRadius, Math.max(0, blob.width - l - r) / 2, Math.max(0, blob.height - t - b) / 2)
        const corner = (a, c) => a > 0 && c > 0 ? cr : 0
        return { on: 1, top: t, right: r, bottom: b, left: l,
                 tl: corner(t, l), tr: corner(t, r), bl: corner(b, l), br: corner(b, r) }
    }

    readonly property var rawBlobs: {
        const all = []
        for (const s of blob.surfaces) {
            if (!s)
                continue
            s.sdfField
            for (const r of s.blobShapes())
                all.push(r)
        }
        return all
    }

    function rebuild() {
        const k = blob.smoothing
        const keys = []
        blob.blobs = Geom.mergeFlush(Geom.squareAll(Geom.snapFaces(blob.rawBlobs), blob.hole, k)).map(r => Object.assign(r, {
            merge: (r.k ?? k) / k, frameMerge: (r.k ?? k) / k,
            goo: Geom.gooCode(r, keys)
        }))
    }

    onRawBlobsChanged: Qt.callLater(blob.rebuild)
    onHoleChanged: Qt.callLater(blob.rebuild)
    onSmoothingChanged: Qt.callLater(blob.rebuild)
    Component.onCompleted: blob.rebuild()

    fillColor: Colors.surface
    edgeColor: Colors.outline
    edgeWidth: KindleMode.outlines ? KindleMode.edge : 0
    shadowColor: BarLayout.shadowTone
    shadowSize: BarLayout.shadowReach
    shadowStrength: BarLayout.shadowAlpha
    shadowOffset: BarLayout.shadowLift
    shadowContact: BarLayout.shadowContact
}
