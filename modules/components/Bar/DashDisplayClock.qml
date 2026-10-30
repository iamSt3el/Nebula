import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Item {
    id: root

    property real size: 80
    property real maxWidth: 0
    property color ink: Colors.surfaceText
    property color accent: Colors.primary
    property string hour: ServiceClock.hour
    property string minute: ServiceClock.minute

    readonly property string family: SettingsConfig.general.displayFont ?? "Titan One"
    readonly property var digits: [root.hour.charAt(0), root.hour.charAt(1), root.minute.charAt(0), root.minute.charAt(1)]
    readonly property real widest: {
        fm.font
        let w = 0
        for (const d of "0123456789")
            w = Math.max(w, fm.advanceWidth(d))
        return 4 * w + fm.advanceWidth(":") + 4 * root.u
    }
    readonly property real px: root.maxWidth > 0 ? Math.min(root.size, Math.floor(root.maxWidth / root.widest * 100)) : root.size
    readonly property real k: root.px / 100
    readonly property real u: 100 / 30

    readonly property var xs: {
        fm.font
        const d = root.digits
        const sp = -3 * root.u
        const tuck = -2 * root.u
        const cm = 5 * root.u
        const x = [0, 0, 0, 0, 0]
        x[1] = fm.advanceWidth(d[0]) + tuck
        x[4] = x[1] + fm.advanceWidth(d[1]) + sp + cm
        x[2] = x[4] + fm.advanceWidth(":") + cm + sp
        x[3] = x[2] + fm.advanceWidth(d[2]) + tuck
        return x
    }
    readonly property rect firstBox: { fm.font; return fm.tightBoundingRect(root.digits[0]) }
    readonly property rect lastBox: { fm.font; return fm.tightBoundingRect(root.digits[3]) }
    readonly property rect zeroBox: { fm.font; return fm.tightBoundingRect("0") }
    readonly property rect colonBox: { fm.font; return fm.tightBoundingRect(":") }
    readonly property real lsb: root.firstBox.x
    readonly property real inkW: root.xs[3] + root.lastBox.x + root.lastBox.width - root.lsb
    readonly property real capH: -root.zeroBox.y * root.k
    readonly property real colonShift: ((root.zeroBox.y + root.zeroBox.height / 2) - (root.colonBox.y + root.colonBox.height / 2)) * root.k
    readonly property real ascent: { fm.font; return fm.ascent * root.k }
    readonly property real ring: Math.max(1.5, 0.04 * root.px)
    readonly property real pad: root.ring + 4 + 0.08 * root.px

    implicitWidth: Math.ceil(root.inkW * root.k)
    implicitHeight: Math.ceil(root.capH)

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: 100
    }

    CutText {
        x: -root.pad
        y: -root.pad
        width: Math.ceil(root.implicitWidth + 2 * root.pad)
        height: Math.ceil(root.capH + 2 * root.pad)
        family: root.family
        px: Math.round(root.px)
        ring: root.ring
        round: 0
        glyphs: [0, 1, 2, 3].map(i => ({
            ch: root.digits[i],
            x: root.pad + (root.xs[i] - root.lsb) * root.k,
            y: root.pad + root.capH,
            color: i % 2 === 0 ? root.ink : root.accent
        }))
    }

    Text {
        x: Math.round((root.xs[4] - root.lsb) * root.k)
        y: Math.round(root.capH - root.ascent + root.colonShift)
        text: ":"
        color: root.accent
        font.family: root.family
        font.pixelSize: Math.round(root.px)
        renderType: Text.NativeRendering
    }
}
