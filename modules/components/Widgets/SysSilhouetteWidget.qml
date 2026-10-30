import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysSilhouette"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(2))
    defaultPos: Qt.point(1245, 605)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: {
        root.si.retain()
        root.si.getUptime?.()
        root.syncShape()
    }
    Component.onDestruction: root.si.release()

    Timer {
        interval: 60000
        repeat: true
        running: !root.preview && root.visible
        onTriggered: root.si.getUptime?.()
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v || 0)) }
    function short(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + "M"
        if (bps >= 1024) return Math.round(bps / 1024) + "K"
        return Math.round(bps) + ""
    }

    readonly property bool threads: !root.preview && (SettingsConfig.widgets.sysSilhouetteThreads ?? false)
    function toggleThreads() {
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { sysSilhouetteThreads: !root.threads })
    }

    readonly property real cpuTemp: root.si.cpuTemp ?? 0
    readonly property real netBps: root.si.netDownloadBps ?? 0
    readonly property var cores: (root.si.cpuCores ?? []).slice(0, 16).map(v => root.clamp01(v))
    readonly property var targets: root.threads && root.cores.length >= 3 ? root.cores : [
        root.clamp01(root.si.cpuUsage),
        root.clamp01(root.si.gpuUsage),
        root.clamp01(root.si.memUsage),
        root.clamp01(root.si.diskUsage),
        root.clamp01((root.cpuTemp - 30) / 65),
        root.clamp01(Math.log10(1 + root.netBps / 1024) / 4)
    ]
    readonly property int n: root.targets.length
    readonly property bool coreMode: root.n !== 6 || root.threads
    readonly property var hots: root.coreMode ? root.targets.map(v => v > 0.85) : [
        root.targets[0] > 0.85,
        root.targets[1] > 0.85,
        root.targets[2] > 0.85,
        root.targets[3] > 0.92,
        root.cpuTemp >= 85,
        false
    ]
    readonly property bool anyHot: root.hots.some(h => h)
    readonly property int lead: {
        let best = 0
        const pool = root.coreMode ? root.targets.map((v, i) => i) : [0, 1, 2, 4]
        for (const i of pool)
            if (root.targets[i] > root.targets[best])
                best = i
        return best
    }
    readonly property var axes: [
        { icon: "developer_board", name: "CPU" },
        { icon: "stadia_controller", name: "GPU" },
        { icon: "memory_alt", name: "RAM" },
        { icon: "hard_drive", name: "Disk" },
        { icon: "device_thermostat", name: "Temp" },
        { icon: "swap_vert", name: "Net" }
    ]
    function valueText(i) {
        if (root.coreMode) return Math.round(root.targets[i] * 100) + "%"
        switch (i) {
        case 0: return Math.round(root.targets[0] * 100) + "%"
        case 1: return Math.round(root.targets[1] * 100) + "%"
        case 2: return (root.si.memUsedGb ?? 0).toFixed(1) + " GB"
        case 3: return Math.round(root.targets[3] * 100) + "%"
        case 4: return Math.round(root.cpuTemp) + "°C"
        }
        return root.short(root.netBps) + "B/s"
    }

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: root.preview || (root.dev?.isLaptopBattery ?? false)
    readonly property real battery: root.preview ? 0.82 : (root.dev?.percentage ?? 0)
    readonly property string uptime: String(root.si.uptime ?? "")
        .replace(/\s*weeks?/, "w").replace(/\s*days?/, "d").replace(/\s+/g, " ").trim()

    property var log: []
    onThreadsChanged: root.log = []
    Timer {
        interval: 1000
        repeat: true
        running: !root.preview && root.visible
        onTriggered: {
            const next = root.log.filter(e => e.length === root.n).slice(-59)
            next.push(root.targets.slice())
            root.log = next
        }
    }
    readonly property var ghostTargets: {
        const g = root.targets.slice()
        if (root.preview)
            return g.map((v, i) => Math.min(1, v + [0.3, 0.12, 0.05, 0, 0.18, 0.2][i % 6]))
        for (const e of root.log)
            if (e.length === g.length)
                for (let i = 0; i < g.length; i++)
                    g[i] = Math.max(g[i], e[i])
        return g
    }

    property var cur: []
    property var vel: []
    property var ghost: []
    property int frame: 0

    function syncShape() {
        if (root.cur.length !== root.n) {
            root.cur = root.targets.slice()
            root.vel = root.targets.map(() => 0)
            root.ghost = root.ghostTargets.slice()
            root.frame++
        }
        spring.running = true
    }
    onTargetsChanged: root.syncShape()
    onGhostTargetsChanged: root.syncShape()

    FrameAnimation {
        id: spring
        running: false
        onTriggered: {
            const t = root.targets, g = root.ghostTargets
            const c = root.cur, v = root.vel, gh = root.ghost
            const steps = Math.max(1, Math.min(4, Math.round(spring.frameTime * 60)))
            let moving = false
            for (let s = 0; s < steps; s++) {
                for (let i = 0; i < t.length && i < c.length; i++) {
                    v[i] = v[i] * 0.78 + (t[i] - c[i]) * 0.06
                    c[i] += v[i]
                    gh[i] += (g[i] - gh[i]) * 0.06
                }
            }
            for (let i = 0; i < t.length && i < c.length; i++)
                if (Math.abs(v[i]) > 1e-4 || Math.abs(t[i] - c[i]) > 1e-4 || Math.abs(g[i] - gh[i]) > 1e-3)
                    moving = true
            root.frame++
            if (!moving)
                spring.running = false
        }
    }

    readonly property real cx: 100
    readonly property real cy: 100
    readonly property real reach: 62
    readonly property color tone: root.anyHot ? Colors.error : Colors.primary

    function angle(i) { return -Math.PI / 2 + i * 2 * Math.PI / root.n }
    function point(i, v) {
        const r = root.reach * (0.2 + 0.8 * Math.max(0, Math.min(1.08, v)))
        return Qt.point(root.cx + r * Math.cos(root.angle(i)), root.cy + r * Math.sin(root.angle(i)))
    }
    function pathOf(vals) {
        const p = vals.map((v, i) => root.point(i, v))
        const k = p.length
        if (k < 3)
            return ""
        const f = v => v.toFixed(2)
        let d = "M" + f(p[0].x) + " " + f(p[0].y)
        for (let i = 0; i < k; i++) {
            const p0 = p[(i - 1 + k) % k], p1 = p[i], p2 = p[(i + 1) % k], p3 = p[(i + 2) % k]
            d += " C" + f(p1.x + (p2.x - p0.x) / 6) + " " + f(p1.y + (p2.y - p0.y) / 6)
                + " " + f(p2.x - (p3.x - p1.x) / 6) + " " + f(p2.y - (p3.y - p1.y) / 6)
                + " " + f(p2.x) + " " + f(p2.y)
        }
        return d + " Z"
    }
    readonly property var points: {
        void root.frame
        return root.cur.map((v, i) => root.point(i, v))
    }
    readonly property string blobPath: {
        void root.frame
        return root.pathOf(root.cur)
    }
    readonly property string ghostPath: {
        void root.frame
        return root.pathOf(root.ghost)
    }
    readonly property bool ghostShown: {
        void root.frame
        return root.ghost.some((g, i) => g - (root.cur[i] ?? 0) > 0.04)
    }
    readonly property string spokesPath: {
        let d = ""
        for (let i = 0; i < root.n; i++) {
            const a = root.angle(i)
            d += "M" + (root.cx + 7 * Math.cos(a)).toFixed(1) + " " + (root.cy + 7 * Math.sin(a)).toFixed(1)
                + " L" + (root.cx + root.reach * Math.cos(a)).toFixed(1) + " " + (root.cy + root.reach * Math.sin(a)).toFixed(1) + " "
        }
        return d
    }

    WidgetCard {
        anchors.fill: parent

        Item {
            id: plot
            width: 200
            height: 200
            anchors.verticalCenter: parent.verticalCenter

            TapHandler {
                enabled: !root.preview && !root.lifted
                onTapped: root.toggleThreads()
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Qt.alpha(Colors.outlineVariant, 0.7)
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: root.cx
                        centerY: root.cy
                        radiusX: root.reach
                        radiusY: root.reach
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeColor: Qt.alpha(Colors.outlineVariant, 0.7)
                    strokeWidth: 1
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [2, 3]
                    PathAngleArc {
                        centerX: root.cx
                        centerY: root.cy
                        radiusX: root.reach / 2
                        radiusY: root.reach / 2
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeColor: Qt.alpha(Colors.outlineVariant, 0.5)
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathSvg { path: root.spokesPath }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: root.ghostShown ? 1 : 0
                Behavior on opacity { EffectsAnim {} }

                ShapePath {
                    strokeColor: Qt.alpha(root.tone, 0.5)
                    strokeWidth: 1.2
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 2.5]
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: root.ghostPath }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.tone
                    strokeWidth: 2
                    fillColor: Qt.alpha(root.tone, 0.2)
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: root.blobPath }
                }
            }

            Repeater {
                model: root.n

                Rectangle {
                    required property int index
                    readonly property point at: root.points[index] ?? Qt.point(root.cx, root.cy)
                    x: at.x - width / 2
                    y: at.y - height / 2
                    width: root.coreMode ? 4.4 : 5.2
                    height: width
                    radius: width / 2
                    antialiasing: true
                    color: root.hots[index] ? Colors.error : root.tone
                }
            }

            Repeater {
                model: root.coreMode ? 0 : 6

                MaterialIconSymbol {
                    required property int index
                    x: root.cx + (root.reach + 15) * Math.cos(root.angle(index)) - width / 2
                    y: root.cy + (root.reach + 15) * Math.sin(root.angle(index)) - height / 2
                    content: root.axes[index].icon
                    iconSize: 14
                    fill: 1
                    customColor: root.hots[index] ? Colors.error
                        : index === root.lead ? Colors.primary : Colors.outline
                }
            }

            Repeater {
                model: root.coreMode ? root.n : 0

                CustomText {
                    required property int index
                    x: root.cx + (root.reach + 13) * Math.cos(root.angle(index)) - width / 2
                    y: root.cy + (root.reach + 13) * Math.sin(root.angle(index)) - height / 2
                    content: String(index + 1)
                    size: 10
                    weight: 600
                    customColor: root.hots[index] ? Colors.error
                        : index === root.lead ? Colors.primary : Colors.outline
                }
            }

            CustomText {
                visible: root.coreMode
                x: 14
                y: 12
                content: root.n + " THREADS"
                size: 8
                weight: 600
                font.letterSpacing: 1.4
                customColor: Colors.outline
            }
        }

        ColumnLayout {
            x: 200
            y: 20
            width: 90
            height: 160
            spacing: 0
            visible: !root.coreMode

            Repeater {
                model: 6

                LegendRow {
                    required property int index
                    icon: root.axes[index].icon
                    name: root.axes[index].name
                    value: root.coreMode ? "" : root.valueText(index)
                    tint: root.hots[index] ? Colors.error : index === root.lead ? Colors.primary : ""
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                color: Colors.outlineVariant
            }

            LegendRow {
                icon: root.hasBattery ? "battery_charging_full" : "power"
                name: "Battery"
                value: root.hasBattery ? Math.round(root.battery * 100) + "%" : "AC"
                tint: ""
            }

            LegendRow {
                icon: "schedule"
                name: "Up"
                value: root.uptime === "" ? "—" : root.uptime
                tint: ""
            }
        }

        GridLayout {
            x: 200
            y: 20
            width: 90
            height: 160
            visible: root.coreMode
            columns: root.n > 8 ? 2 : 1
            columnSpacing: 8
            rowSpacing: 0

            Repeater {
                model: root.coreMode ? root.n : 0

                LegendRow {
                    required property int index
                    icon: ""
                    name: (root.n > 8 ? "" : "Thread ") + (index + 1)
                    value: root.valueText(index)
                    tint: root.hots[index] ? Colors.error : index === root.lead ? Colors.primary : ""
                }
            }
        }
    }

    component LegendRow: RowLayout {
        id: row
        property string icon: ""
        property string name: ""
        property string value: ""
        property string tint: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        MaterialIconSymbol {
            visible: row.icon !== ""
            Layout.preferredWidth: 14
            content: row.icon
            iconSize: 13
            fill: 1
            customColor: row.tint !== "" ? row.tint : Colors.outline
        }

        CustomText {
            content: row.name
            size: 11
            customColor: Colors.surfaceVariantText
        }

        Item { Layout.fillWidth: true }

        CustomText {
            content: row.value
            size: 11
            weight: 600
            customColor: row.tint !== "" ? row.tint : Colors.surfaceText
        }
    }
}
