import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

PanelWindow {
    id: panelWindow
    readonly property string edge: {
        const e = SettingsConfig.general.musicVisEdge ?? "bottom"
        return ["bottom", "top", "left", "right", "all"].indexOf(e) >= 0 ? e : "bottom"
    }
    readonly property bool frame: panelWindow.edge === "all"
    readonly property bool vertical: panelWindow.edge === "left" || panelWindow.edge === "right"
    readonly property int depth: {
        const n = parseInt(SettingsConfig.general.musicVisHeight ?? 200)
        return isNaN(n) ? 200 : Math.max(60, Math.min(500, n))
    }

    anchors {
        left: panelWindow.edge !== "right"
        right: panelWindow.edge !== "left"
        top: panelWindow.edge !== "bottom"
        bottom: panelWindow.edge !== "top"
    }
    implicitHeight: panelWindow.frame || panelWindow.vertical ? 0 : panelWindow.depth
    implicitWidth: panelWindow.vertical ? panelWindow.depth : 0
    readonly property bool behind: (SettingsConfig.general.musicVisLayer ?? "behind") !== "front"
    property bool mapped: false
    visible: panelWindow.mapped
    color: "transparent"
    WlrLayershell.namespace: "quickshell:musicVis"
    WlrLayershell.layer: panelWindow.behind ? WlrLayer.Background : WlrLayer.Bottom

    function remap() {
        panelWindow.mapped = false
        remapTimer.restart()
    }
    onBehindChanged: panelWindow.remap()

    Timer {
        id: remapTimer
        interval: 700
        running: true
        onTriggered: panelWindow.mapped = true
    }

    Connections {
        target: Quickshell
        function onScreensChanged() { panelWindow.remap() }
    }
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string visStyle: {
        const s = SettingsConfig.general.musicVisStyle ?? "Wave"
        return ["Wave", "Neon", "LED", "Chart", "String"].indexOf(s) >= 0 ? s : "Wave"
    }
    readonly property bool mirrorOn: SettingsConfig.general.musicVisMirror === true || SettingsConfig.general.musicVisStyle === "Mirror"
    function mirrored(data) {
        const n = data.length
        if (n < 2)
            return data
        const out = new Array(n)
        for (let i = 0; i < n; i++) {
            const x = Math.abs(2 * i / (n - 1) - 1) * (n - 1)
            const j = Math.floor(x)
            const t = x - j
            out[i] = data[j] + ((data[Math.min(n - 1, j + 1)] ?? data[j]) - data[j]) * t
        }
        return out
    }
    readonly property bool chartShown: panelWindow.visStyle === "Chart" && !panelWindow.frame
    readonly property string visColor: SettingsConfig.general.musicVisColor ?? "Primary"

    readonly property color barColor: {
        switch (panelWindow.visColor) {
        case "Secondary": return Colors.secondary
        case "Tertiary":  return Colors.tertiary
        case "Deep":      return Colors.primaryContainer
        case "Warm":      return Colors.error
        default:          return Colors.primary
        }
    }

    readonly property color ghostColor: {
        switch (panelWindow.visColor) {
        case "Secondary": return Qt.alpha(Colors.secondary, 0.3)
        case "Tertiary":  return Qt.alpha(Colors.tertiary, 0.3)
        case "Two-tone":  return Qt.alpha(Colors.tertiary, 0.45)
        case "Deep":      return Qt.alpha(Colors.primary, 0.5)
        case "Warm":      return Qt.alpha(Colors.error, 0.3)
        default:          return Qt.alpha(Colors.primary, 0.3)
        }
    }

    // Activate cava when music visualizer is visible
    Component.onCompleted: ServiceCava.retain()
    Component.onDestruction: ServiceCava.release()

    mask: Region{
        item: maskRect
        intersection: Intersection.Xor;
    }

    Rectangle{
        id: maskRect
        anchors.fill: parent
        color: "transparent"
    }

    readonly property bool beatOn: SettingsConfig.general.musicVisBeat ?? true
    readonly property bool freqOn: SettingsConfig.general.musicVisFreqColors ?? true
    readonly property bool fadeOn: SettingsConfig.general.musicVisFade ?? true
    readonly property real intensity: {
        const n = parseInt(SettingsConfig.general.musicVisBrightness ?? 75)
        return isNaN(n) ? 0.75 : Math.max(0.15, Math.min(1, n / 100))
    }
    readonly property color highColor: panelWindow.visColor === "Tertiary" ? Colors.primary : Colors.tertiary

    property real pulse: 0
    property real bassAvg: 0
    property double lastBeat: 0
    property double lastSound: Date.now()
    property bool quiet: false
    property real presence: panelWindow.fadeOn && panelWindow.quiet ? 0 : 1
    Behavior on presence {
        NumberAnimation {
            duration: panelWindow.presence > 0.5 ? 900 : 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        }
    }

    NumberAnimation {
        id: pulseAnim
        target: panelWindow
        property: "pulse"
        from: 1
        to: 0
        duration: 420
        easing.type: Easing.OutCubic
    }

    Timer {
        interval: 400
        repeat: true
        running: panelWindow.fadeOn
        onTriggered: panelWindow.quiet = Date.now() - panelWindow.lastSound > 1800
    }

    function feed(data) {
        const n = data.length
        if (n < 2)
            return
        const now = Date.now()
        let peak = 0
        for (let i = 0; i < n; i++)
            if (data[i] > peak)
                peak = data[i]
        if (peak > 0.04) {
            panelWindow.lastSound = now
            panelWindow.quiet = false
        }

        if (panelWindow.beatOn) {
            const k = Math.max(2, Math.round(n * 0.08))
            let bass = 0
            for (let i = 0; i < k; i++)
                bass += data[i]
            bass /= k
            const a = 1 - Math.pow(0.94, 30 / Math.max(1, ServiceCava.fps))
            if (bass > 0.25 && bass > panelWindow.bassAvg * 1.4 + 0.06 && now - panelWindow.lastBeat > 200) {
                panelWindow.lastBeat = now
                pulseAnim.restart()
            }
            panelWindow.bassAvg += (bass - panelWindow.bassAvg) * a
        }

        if (!wave.visible)
            return
        bandCanvas.values = data
        bandCanvas.requestPaint()
    }

    Connections {
        target: ServiceCava
        function onCavaDataChanged() { panelWindow.feed(ServiceCava.cavaData) }
    }

    Canvas {
        id: bandCanvas
        property var values: []
        width: 256
        height: 1
        smooth: false
        antialiasing: false
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, 256, 1)
            const v = bandCanvas.values
            for (let i = 0; i < v.length && i < 256; i++) {
                const q = Math.round(Math.max(0, Math.min(1, v[i])) * 65535)
                ctx.fillStyle = Qt.rgba((q >> 8) / 255, (q & 255) / 255, 0, 1)
                ctx.fillRect(i, 0, 1, 1)
            }
        }
    }

    ShaderEffectSource {
        id: bandSource
        width: 256
        height: 1
        sourceItem: bandCanvas
        hideSource: true
        live: true
        smooth: false
        visible: false
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: panelWindow.vertical ? panelWindow.height : panelWindow.width
        height: panelWindow.frame ? panelWindow.height : panelWindow.depth
        rotation: panelWindow.edge === "left" ? 90 : panelWindow.edge === "right" ? -90 : 0
        transform: Scale {
            origin.x: stage.width / 2
            origin.y: stage.height / 2
            yScale: panelWindow.edge === "top" ? -1 : 1
        }

        TrapezoidChart {
            id: chart
            anchors.fill: parent
            visible: panelWindow.chartShown
            opacity: panelWindow.presence * panelWindow.intensity

            values: visible ? (panelWindow.mirrorOn ? panelWindow.mirrored(ServiceCava.cavaData) : ServiceCava.cavaData) : []
            lo: 0
            hi: 1

            backValues: chart.values
            backMax: 0.88
            backColor: panelWindow.ghostColor

            showAxis: false
            gridLabelWidth: 0
            labelHeight: 0
            bottomOffset: 0
            tickHeight: 0
            barColor: panelWindow.beatOn && panelWindow.pulse > 0.01
                ? Qt.tint(panelWindow.barColor, Qt.rgba(1, 1, 1, 0.16 * panelWindow.pulse)) : panelWindow.barColor
            barColorEnd: panelWindow.freqOn ? panelWindow.highColor : "transparent"
            gradientMirrored: panelWindow.mirrorOn
            transform: Scale {
                origin.y: chart.height
                yScale: 1 + (panelWindow.beatOn ? 0.1 * panelWindow.pulse : 0)
            }
        }

        ShaderEffect {
            id: wave
            anchors.fill: parent
            visible: !panelWindow.chartShown && panelWindow.presence > 0.003
            fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/musicvis.frag.qsb")
            opacity: panelWindow.intensity

            property size itemSize: Qt.size(width, height)
            property color lowColor: panelWindow.barColor
            property color highColor: panelWindow.highColor
            property color ghostColor: panelWindow.ghostColor
            property real pulse: panelWindow.beatOn ? panelWindow.pulse : 0
            property real presence: panelWindow.presence
            property real gradient: panelWindow.freqOn ? 1 : 0
            property real glow: 1
            property real style: panelWindow.visStyle === "Neon" ? 1 : panelWindow.visStyle === "LED" ? 2
                : panelWindow.visStyle === "Chart" ? 3 : panelWindow.visStyle === "String" ? 4 : 0
            property real mirror: panelWindow.mirrorOn ? 1 : 0
            property real frame: panelWindow.frame ? 1 : 0
            property real depth: panelWindow.depth
            property real outerRadius: ServiceGaps.borderOn ? ServiceGaps.borderRadius : 0
            property real bands: Math.max(2, Math.min(256, bandCanvas.values.length))
            property real period: {
                const n = parseInt(SettingsConfig.general.musicVisStringGap ?? 12)
                return isNaN(n) ? 12 : Math.max(4, Math.min(60, n))
            }
            property var bandTex: bandSource

            Behavior on gradient { NumberAnimation { duration: 300 } }
        }
    }
}
