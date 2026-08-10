import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property real progress: 0.0
    property bool indeterminate: false

    property real activeThickness: 4
    property real trackThickness:  4
    property real wavelength:      indeterminate ? 20 : 40
    property real waveAmplitude:   3
    property real trackGap:        4
    property real stopSize:        4
    property real waveSpeed:       wavelength

    property bool  showStopIndicator: true
    property color activeColor: Colors.primary
    property color trackColor:  Colors.surfaceContainerHighest

    implicitWidth: 240
    implicitHeight: 10

    readonly property real _p: Math.max(0, Math.min(1, progress))

    // Spec ramp: amplitude reaches full by 10% and returns to zero at 95%.
    property real amp: {
        if (indeterminate) return waveAmplitude
        if (_p <= 0)    return 0
        if (_p < 0.1)   return waveAmplitude * (_p / 0.1)
        if (_p > 0.95)  return waveAmplitude * Math.max(0, (1 - _p) / 0.05)
        return waveAmplitude
    }
    Behavior on amp { NumberAnimation { duration: M3Motion.effects.defaultDuration } }

    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: 2 * Math.PI
        duration: Math.max(1, Math.round(root.wavelength / Math.max(1, root.waveSpeed) * 1000))
        loops: Animation.Infinite
        running: root.visible && root.amp > 0.01
    }

    property real indetStart: 0
    NumberAnimation on indetStart {
        from: -0.35; to: 1.0
        duration: 1400
        loops: Animation.Infinite
        running: root.visible && root.indeterminate
    }

    readonly property real _activeFrom: indeterminate ? Math.max(0, indetStart) : 0
    readonly property real _activeTo: indeterminate
        ? Math.min(1, indetStart + 0.35) : _p

    onProgressChanged: wave.requestPaint()
    onAmpChanged:     wave.requestPaint()
    onPhaseChanged:   wave.requestPaint()
    onWidthChanged:    wave.requestPaint()
    onHeightChanged:   wave.requestPaint()
    onActiveColorChanged: wave.requestPaint()
    onTrackColorChanged:  wave.requestPaint()

    // Headroom so the wave's round caps are never shaved by the item bounds
    // (the trick the old sperm bar used with height * 6).
    Canvas {
        id: wave
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height + root.waveAmplitude * 2 + root.activeThickness * 2
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w  = width
            const cy = height / 2
            if (w <= 0) return

            const half = root.activeThickness / 2
            // Round caps overhang by half the stroke on each end.
            const x0 = half
            const x1 = w - half
            const span = Math.max(0, x1 - x0)

            const aFrom = x0 + span * root._activeFrom
            const aTo   = x0 + span * root._activeTo

            const stopX = root.showStopIndicator && !root.indeterminate
                ? x1 - root.stopSize / 2 : x1

            // ── Inactive track: from after the active end + gap, to the stop dot
            const trackFrom = aTo + root.trackGap + half
            const trackTo   = stopX - (root.showStopIndicator && !root.indeterminate
                                       ? root.stopSize / 2 + 6 : 0)
            if (trackTo > trackFrom) {
                ctx.strokeStyle = root.trackColor
                ctx.lineWidth   = root.trackThickness
                ctx.lineCap     = "round"
                ctx.beginPath()
                ctx.moveTo(trackFrom, cy)
                ctx.lineTo(trackTo, cy)
                ctx.stroke()
            }

            // ── Leading inactive segment (indeterminate only)
            if (root.indeterminate && aFrom > x0 + half) {
                ctx.strokeStyle = root.trackColor
                ctx.lineWidth   = root.trackThickness
                ctx.lineCap     = "round"
                ctx.beginPath()
                ctx.moveTo(x0, cy)
                ctx.lineTo(aFrom - root.trackGap - half, cy)
                ctx.stroke()
            }

            // ── Active wave
            if (aTo > aFrom) {
                ctx.strokeStyle = root.activeColor
                ctx.lineWidth   = root.activeThickness
                ctx.lineCap     = "round"
                ctx.lineJoin    = "round"
                ctx.beginPath()

                const amp = root.amp
                if (amp < 0.01) {
                    ctx.moveTo(aFrom, cy)
                    ctx.lineTo(aTo, cy)
                } else {
                    const k = (2 * Math.PI) / Math.max(1, root.wavelength)
                    const step = 1
                    for (let x = aFrom; x <= aTo; x += step) {
                        const y = cy + amp * Math.sin(k * x - root.phase)
                        if (x === aFrom) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    const yEnd = cy + amp * Math.sin(k * aTo - root.phase)
                    ctx.lineTo(aTo, yEnd)
                }
                ctx.stroke()
            }

            // ── Stop indicator
            if (root.showStopIndicator && !root.indeterminate) {
                ctx.fillStyle = root.activeColor
                ctx.beginPath()
                ctx.arc(stopX, cy, root.stopSize / 2, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }
}
