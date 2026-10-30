import QtQuick

Canvas {
    id: root

    property var glyphs: []
    property string family: "Titan One"
    property int px: 100
    property real ring: 4
    property real islandRatio: 0.06

    antialiasing: true

    onGlyphsChanged: root.requestPaint()
    onPxChanged: root.requestPaint()
    onRingChanged: root.requestPaint()
    onFamilyChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: root.px
    }

    function removeIslands(ctx, g) {
        const r = fm.tightBoundingRect(g.ch)
        const pad = root.ring + 6
        const bx = Math.max(0, Math.floor(g.x + r.x - pad))
        const by = Math.max(0, Math.floor(g.y + r.y - pad))
        const bw = Math.min(Math.floor(root.width) - bx, Math.ceil(r.width + 2 * pad))
        const bh = Math.min(Math.floor(root.height) - by, Math.ceil(r.height + 2 * pad))
        const s = 3
        if (bw < 3 * s || bh < 3 * s)
            return
        const gw = Math.floor(bw / s)
        const gh = Math.floor(bh / s)
        const img = ctx.getImageData(bx, by, gw * s, gh * s)
        const d = img.data
        const rowLen = gw * s
        const occ = new Uint8Array(gw * gh)
        for (let gy = 0; gy < gh; gy++) {
            const row = (gy * s + 1) * rowLen
            for (let gx = 0; gx < gw; gx++)
                occ[gy * gw + gx] = d[(row + gx * s + 1) * 4 + 3] > 40 ? 1 : 0
        }
        const label = new Int32Array(gw * gh)
        const edge = [false]
        const stack = []
        let next = 1
        for (let i = 0; i < occ.length; i++) {
            if (!occ[i] || label[i])
                continue
            let touches = false
            label[i] = next
            stack.push(i)
            while (stack.length) {
                const c = stack.pop()
                const cx = c % gw
                const cy = (c - cx) / gw
                if (cx === 0 || cy === 0 || cx === gw - 1 || cy === gh - 1)
                    touches = true
                if (cx > 0 && occ[c - 1] && !label[c - 1]) { label[c - 1] = next; stack.push(c - 1) }
                if (cx < gw - 1 && occ[c + 1] && !label[c + 1]) { label[c + 1] = next; stack.push(c + 1) }
                if (cy > 0 && occ[c - gw] && !label[c - gw]) { label[c - gw] = next; stack.push(c - gw) }
                if (cy < gh - 1 && occ[c + gw] && !label[c + gw]) { label[c + gw] = next; stack.push(c + gw) }
            }
            edge.push(touches)
            next++
        }
        for (let i = 0; i < label.length; i++) {
            const l = label[i]
            if (!l || edge[l])
                continue
            const gx = i % gw
            const gy = (i - gx) / gw
            ctx.clearRect(bx + gx * s - s, by + gy * s - s, 3 * s, 3 * s)
        }
    }

    onPaint: {
        const ctx = root.getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, root.width, root.height)
        ctx.font = root.px + "px \"" + root.family + "\""
        ctx.textBaseline = "alphabetic"
        ctx.lineJoin = "round"
        for (let i = 0; i < root.glyphs.length; i++) {
            const g = root.glyphs[i]
            if (i > 0) {
                ctx.globalCompositeOperation = "destination-out"
                ctx.fillStyle = "black"
                ctx.strokeStyle = "black"
                ctx.lineWidth = root.ring * 2
                ctx.fillText(g.ch, g.x, g.y)
                ctx.strokeText(g.ch, g.x, g.y)
                ctx.globalCompositeOperation = "source-over"
                if (root.islandRatio > 0)
                    root.removeIslands(ctx, g)
            }
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = g.color
            ctx.fillText(g.ch, g.x, g.y)
        }
    }
}
