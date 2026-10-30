import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "claudeCode"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    resizable: true
    minSpan: Qt.size(3, 2)
    maxSpan: Qt.size(6, 2)
    defaultPos: Qt.point(620, 100)

    readonly property var canned: ({
        today: { tokens: 72900000, output: 464000, messages: 356, sessions: 3,
                 models: [{ name: "claude-opus-5", tokens: 61000000 },
                          { name: "claude-sonnet-5", tokens: 11900000 }] },
        series: [{ weekday: "S", tokens: 339000000 }, { weekday: "S", tokens: 161000000 },
                 { weekday: "M", tokens: 139000000 }, { weekday: "T", tokens: 89000000 },
                 { weekday: "W", tokens: 0 },         { weekday: "T", tokens: 24000000 },
                 { weekday: "F", tokens: 72900000 }],
        peak: 339000000, live: true, project: "quickshell",
        limits: [{ group: "session", percent: 86, severity: "warning", secondsLeft: 11812 },
                 { group: "weekly",  percent: 4,  severity: "normal",  secondsLeft: 602212 }]
    })

    readonly property var today:  root.preview ? root.canned.today  : ServiceClaudeCode.today
    readonly property var series: root.preview ? root.canned.series : ServiceClaudeCode.series
    readonly property int peak:   root.preview ? root.canned.peak   : ServiceClaudeCode.peak
    readonly property bool live:  root.preview ? root.canned.live   : ServiceClaudeCode.live
    readonly property string project: root.preview ? root.canned.project : ServiceClaudeCode.project
    readonly property bool ready: root.preview || ServiceClaudeCode.ready
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    readonly property bool limitsStale: !root.preview && ServiceClaudeCode.limitsStale
    readonly property string staleNote: root.limitsStale
        ? ServiceClaudeCode.formatSpan(ServiceClaudeCode.limitsAgeSec) + " old"
        : ""

    readonly property var sessionLimit: root.preview ? root.canned.limits[0] : ServiceClaudeCode.limitFor("session")
    readonly property var weeklyLimit: root.preview ? root.canned.limits[1] : ServiceClaudeCode.limitFor("weekly")

    Component.onCompleted: if (!root.preview) ServiceClaudeCode.retain()
    Component.onDestruction: if (!root.preview) ServiceClaudeCode.release()

    function fmt(n) {
        if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
        if (n >= 1000000)    return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000)       return Math.round(n / 1000) + "K"
        return String(n ?? 0)
    }

    function pct(limit) {
        return (limit !== null && limit !== undefined) ? (limit.percent ?? 0) : 0
    }

    function tone(limit, fallback) {
        const sev = (limit !== null && limit !== undefined) ? (limit.severity ?? "normal") : "normal"
        if (sev === "normal") return fallback
        if (sev === "warning") return Colors.tertiary
        return Colors.error
    }

    readonly property color sessionTone: root.tone(root.sessionLimit, Colors.primary)
    readonly property color weeklyTone: root.tone(root.weeklyLimit, Colors.primary)

    readonly property string modelSplit: {
        const total = root.today.tokens ?? 0
        const models = (root.today.models ?? []).slice(0, 2)
        if (total <= 0 || models.length === 0) return ""
        return models.map(m => ServiceClaudeCode.shortModel(m.name) + " " + Math.round((m.tokens ?? 0) / total * 100)).join(" · ")
    }

    component WavyMeter: Item {
        id: meter
        property real progress: 0
        property color tone: Colors.primary
        readonly property real stroke: 4
        readonly property real end: Math.max(meter.stroke, (meter.width - meter.stroke) * Math.max(0, Math.min(1, meter.progress)))
        implicitHeight: 10

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Colors.surfaceContainerHighest
                strokeWidth: meter.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: Math.min(meter.width - meter.stroke / 2, meter.end + 8)
                startY: meter.height / 2
                PathLine { x: meter.width - meter.stroke / 2; y: meter.height / 2 }
            }
            ShapePath {
                strokeColor: meter.tone
                strokeWidth: meter.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        const pts = []
                        const cy = meter.height / 2
                        for (let x = meter.stroke / 2; x <= meter.end; x += 2)
                            pts.push(Qt.point(x, cy + 2.5 * Math.sin(x / 14 * Math.PI * 2)))
                        if (pts.length < 2) pts.push(Qt.point(meter.end, cy))
                        return pts
                    }
                }
            }
        }
    }

    component LimitRow: ColumnLayout {
        id: lr
        property string label: ""
        property var limit: null
        property color tone: Colors.primary
        readonly property bool known: lr.limit !== null && lr.limit !== undefined
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            CustomText { content: lr.label; size: 11; weight: 700 }
            CustomText {
                content: lr.known ? Math.round(lr.limit.percent ?? 0) + "%" : "—"
                size: 11
                weight: 800
                customColor: lr.tone
                opacity: root.limitsStale ? 0.45 : 1
            }
            Item { Layout.fillWidth: true }
            CustomText {
                content: lr.known ? "resets in " + ServiceClaudeCode.formatSpan(lr.limit.secondsLeft ?? 0) : "no data"
                size: 10
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }
        WavyMeter {
            Layout.fillWidth: true
            progress: root.pct(lr.limit) / 100
            tone: lr.tone
            opacity: root.limitsStale ? 0.45 : 1
        }
    }

    WidgetCard {
        id: card
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16
            visible: root.ready

            ColumnLayout {
                Layout.preferredWidth: 112
                Layout.fillHeight: true
                spacing: 8

                Item {
                    id: ring
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112
                    opacity: root.limitsStale ? 0.45 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    readonly property real p: Math.max(0, Math.min(1, root.pct(root.sessionLimit) / 100))
                    readonly property real r: 46
                    readonly property real c: ring.width / 2
                    readonly property real startDeg: -90
                    readonly property real sweepDeg: 360 * ring.p
                    readonly property real gapDeg: 16

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Colors.surfaceContainerHighest
                            strokeWidth: 8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: ring.c
                                centerY: ring.c
                                radiusX: ring.r
                                radiusY: ring.r
                                startAngle: ring.startDeg + ring.sweepDeg + (ring.p > 0 ? ring.gapDeg : 0)
                                sweepAngle: Math.max(0, 360 - ring.sweepDeg - (ring.p > 0 ? ring.gapDeg * 2 : 0))
                            }
                        }
                        ShapePath {
                            strokeColor: root.sessionTone
                            strokeWidth: 8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathPolyline {
                                path: {
                                    const pts = []
                                    const n = Math.max(2, Math.round(160 * ring.p))
                                    const a0 = ring.startDeg * Math.PI / 180
                                    const span = ring.sweepDeg * Math.PI / 180
                                    for (let i = 0; i <= n; i++) {
                                        const t = span * i / n
                                        const rr = ring.r + 2.5 * Math.sin(t * 12)
                                        pts.push(Qt.point(ring.c + rr * Math.cos(a0 + t), ring.c + rr * Math.sin(a0 + t)))
                                    }
                                    return pts
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: Math.round(root.pct(root.sessionLimit)) + "%"
                            family: root.display
                            size: 26
                            weight: 400
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: "5 h window"
                            size: 10
                            weight: 700
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.modelSplit !== ""
                    implicitWidth: Math.min(112, splitText.implicitWidth + 16)
                    implicitHeight: 22
                    radius: 11
                    color: Colors.secondaryContainer
                    CustomText {
                        id: splitText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 12)
                        content: root.modelSplit
                        size: 10
                        weight: 700
                        elide: Text.ElideRight
                        customColor: Colors.secondaryContainerText
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    CustomText {
                        content: root.fmt(root.today.tokens ?? 0)
                        family: root.display
                        size: 24
                        weight: 400
                    }
                    CustomText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 3
                        content: "today · " + (root.today.sessions ?? 0) + " sessions"
                        size: 11
                        weight: 500
                        elide: Text.ElideRight
                        customColor: Colors.surfaceVariantText
                    }
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.live ? Colors.tertiary : Colors.outline
                    }
                    CustomText {
                        Layout.maximumWidth: 90
                        content: root.limitsStale ? root.staleNote
                               : root.live ? (root.project.length > 0 ? root.project : "active") : "idle"
                        size: 10
                        weight: 600
                        elide: Text.ElideRight
                        customColor: Colors.surfaceVariantText
                    }
                }

                LimitRow { Layout.fillWidth: true; label: "5 h"; limit: root.sessionLimit; tone: root.sessionTone }
                LimitRow { Layout.fillWidth: true; label: "7 day"; limit: root.weeklyLimit; tone: root.weeklyTone }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 6
                    visible: (root.series ?? []).length > 0

                    Repeater {
                        model: root.series ?? []
                        delegate: ColumnLayout {
                            id: day
                            required property var modelData
                            required property int index
                            readonly property bool isToday: day.index === (root.series ?? []).length - 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            spacing: 3

                            Item { Layout.fillHeight: true }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(4, 25 * (root.peak > 0 ? (day.modelData.tokens ?? 0) / root.peak : 0))
                                radius: 6
                                color: day.isToday ? Colors.tertiary : Colors.secondaryContainer
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: day.modelData.weekday ?? ""
                                size: 9
                                weight: 700
                                customColor: day.isToday ? Colors.tertiary : Colors.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }

        CustomText {
            anchors.centerIn: parent
            visible: !root.ready && !ServiceClaudeCode.failed
            content: "Reading transcripts…"
            size: 12
            customColor: Colors.outline
        }

        CustomText {
            anchors.centerIn: parent
            visible: !root.preview && ServiceClaudeCode.failed
            content: "No Claude Code data"
            size: 12
            customColor: Colors.outline
        }
    }
}
