pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Widgets
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    property var context: null
    property bool preview: false
    property bool exiting: false
    property bool greeter: false
    property var cfg: LockSession.cfg
    property bool handoff: false
    property real handoffReveal: 1
    property bool handoffDate: false

    readonly property Item authField: auth
    readonly property var handoffTargets: ({ restyle: false, clock: cutClock, date: root.handoffDate && root.cfg.showDate !== false ? dateText : null })
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"
    readonly property string _display: SettingsConfig.general.displayFont ?? "Titan One"
    readonly property bool _failed: root.context?.showFailure ?? false
    readonly property bool _busy: root.context?.unlockInProgress ?? false
    readonly property bool _fieldWanted: root.greeter || root._failed || root._busy
        || (root.context?.currentText?.length ?? 0) > 0
    property real fieldVis: root._fieldWanted ? 1 : 0
    Behavior on fieldVis { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1] } }

    readonly property real cx: root.width / 2
    readonly property real cy: root.height / 2
    readonly property real ringR: 380 * root.u
    readonly property real trackW: 40 * root.u
    readonly property real innerR: 330 * root.u
    readonly property real innerW: 13 * root.u

    readonly property color trackColor: Colors.surfaceContainer
    readonly property color innerColor: Colors.surfaceContainerLow
    readonly property color dayColor: Colors.inversePrimary
    readonly property color bgColor: Colors.surfaceContainerLowest

    readonly property real nowH: LockSession.hour24 + (parseInt(LockSession.minute) || 0) / 60

    function minutesOf(s) {
        const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(s ?? "")
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (m[3].toUpperCase() === "PM") h += 12
        return h * 60 + parseInt(m[2])
    }

    readonly property var _astro: !root.greeter && Features.weather ? ServiceWeather.astronomy : null
    readonly property real riseH: { const m = root.minutesOf(root._astro?.sunrise); return m >= 0 ? m / 60 : 6 }
    readonly property real setH: { const m = root.minutesOf(root._astro?.sunset); return m > root.riseH * 60 ? m / 60 : 18 }
    readonly property bool isDay: root.nowH >= root.riseH && root.nowH < root.setH

    function hhmm(h) {
        const m = Math.round(h * 60)
        return String(Math.floor(m / 60) % 24).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0")
    }

    readonly property var events: {
        if (root.greeter || !Features.events)
            return []
        const d = new Date()
        const base = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        const out = []
        const list = ServiceEvents.today()
        for (let i = 0; i < list.length && out.length < 6; i++) {
            const e = list[i]
            if (e.allDay)
                continue
            const a = Math.max(0, (ServiceEvents.startMs(e) - base) / 3600000)
            const b = Math.min(24, (ServiceEvents.endMs(e) - base) / 3600000)
            if (b > a)
                out.push({ a: a, b: Math.max(b, a + 0.25), title: e.title ?? "" })
        }
        return out
    }

    function kind(code) {
        const c = parseInt(code)
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "storm"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0) return "snow"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(c) >= 0) return "rain"
        if ([143, 248, 260].indexOf(c) >= 0) return "fog"
        if ([119, 122].indexOf(c) >= 0) return "cloud"
        if (c === 116) return "partly"
        return "clear"
    }

    function kindIcon(k, night) {
        switch (k) {
        case "storm":  return "thunderstorm"
        case "snow":   return "weather_snowy"
        case "rain":   return "rainy"
        case "fog":    return "foggy"
        case "cloud":  return "cloud"
        case "partly": return night ? "partly_cloudy_night" : "partly_cloudy_day"
        }
        return night ? "bedtime" : "sunny"
    }

    function hourText(h) {
        if (h === 12) return "noon"
        if (h === 0) return "midnight"
        return clock.use24 ? String(h).padStart(2, "0") : (h % 12) + (h < 12 ? " am" : " pm")
    }

    readonly property var forecast: {
        if (root.greeter || !Features.weather)
            return []
        const days = ServiceWeather.forecastDays ?? []
        const hs = days[0] ? (days[0].hourly ?? []) : []
        const next = days[1] ? (days[1].hourly ?? []) : []
        const out = []
        for (let i = 0; i < hs.length; i++) {
            const h = Math.floor(parseInt(hs[i].time) / 100)
            const src = h + 1.5 < root.nowH && next[i] ? next[i] : hs[i]
            if (root._astro && (Math.abs(h - root.riseH) < 1.6 || Math.abs(h - root.setH) < 1.6))
                continue
            const night = h < root.riseH || h >= root.setH
            out.push({ h: h, icon: root.kindIcon(root.kind(src.weatherCode), night),
                       temp: (ServiceWeather.useMetric ? src.tempC : src.tempF) + "°" })
        }
        return out
    }

    readonly property string daylight: {
        if (!root._astro)
            return ""
        const n = root.nowH
        const span = m => { const t = Math.max(0, Math.round(m * 60)); const h = Math.floor(t / 60); return (h > 0 ? h + " h " : "") + (t % 60) + " m" }
        if (n < root.riseH) return "Sunrise in " + span(root.riseH - n)
        if (n < root.setH) return span(root.setH - n) + " of daylight left"
        return "Sunrise in " + span(24 - n + root.riseH)
    }

    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null && (ServiceMusic.activeTrack?.title ?? "") !== ""

    readonly property var nextEvent: {
        for (let i = 0; i < root.events.length; i++)
            if (root.events[i].a > root.nowH)
                return root.events[i]
        return null
    }

    LockStatusModel { id: status }
    ClockParts { id: clock }

    LockTimeline {
        id: tl
        animated: root._animated
        exiting: root.exiting
        inMs: 1800
        outMs: 960
    }

    readonly property var _io: [0.45, 0.0, 0.2, 1.0]
    readonly property var _lin: [0.0, 0.0, 1.0, 1.0]

    readonly property real close: tl.span(0, 850, tl.decel, 200, 640, root._io)
    readonly property real bgIn: tl.span(150, 600, tl.standard, 200, 420, tl.standard)
    readonly property bool trackOn: tl.leaving ? tl.o < 200 : tl.t >= 850
    readonly property real overlay: tl.leaving ? (tl.o >= 200 ? 1 - tl.out(840, 80, root._lin) : 0)
                                               : 1 - tl.seg(850, 160, root._lin)
    readonly property real ticksIn: tl.span(850, 300, tl.standard, 0, 200, tl.standard)
    readonly property real dayIn: tl.span(850, 600, tl.decel, 0, 300, tl.standard)
    readonly property real markIn: tl.span(1000, 200, tl.standard, 0, 200, tl.standard)
    readonly property real markPop: tl.span(1000, 500, tl.spring, 0, 200, tl.standard)
    readonly property real centerIn: tl.span(950, 600, tl.decel, 0, 200, tl.standard)
    readonly property real sideIn: tl.span(1150, 350, tl.standard, 0, 200, tl.standard)
    readonly property real fieldIn: tl.span(1170, 550, tl.decel, 0, 150, tl.standard)

    function eventIn(i) {
        return tl.span(1050 + i * 70, 450, tl.decel, i * 30, 260, tl.standard)
    }

    property real rewind: 0
    NumberAnimation {
        id: rewindAnim
        target: root
        property: "rewind"
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.45, 0.0, 0.2, 1.0, 1, 1]
        onFinished: root.rewind = 0
    }
    readonly property real markH: root.nowH - 24 * root.rewind

    property real secPos: 0
    NumberAnimation {
        id: secRun
        target: root
        property: "secPos"
        easing.type: Easing.Linear
        onFinished: root.syncSec()
    }
    function syncSec() {
        const d = new Date()
        const sec = d.getSeconds() + d.getMilliseconds() / 1000
        secRun.stop()
        secRun.from = sec
        secRun.to = 60
        secRun.duration = Math.max(1, Math.round((60 - sec) * 1000))
        secRun.start()
    }
    Component.onCompleted: if (!root.preview) root.syncSec()

    Connections {
        target: root.context
        function onFailed() { if (!root.exiting) rewindAnim.restart() }
    }

    readonly property int typed: Math.min(23, root.context?.currentText?.length ?? 0)
    property real lit: root.typed
    Behavior on lit { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function lerp(a, b, t) {
        return a + (b - a) * t
    }

    function angleOf(h) {
        return 90 + 15 * h
    }

    function pointAt(h, r) {
        const a = root.angleOf(h) * Math.PI / 180
        return Qt.point(root.cx + r * Math.cos(a), root.cy + r * Math.sin(a))
    }

    readonly property var _frame: ServiceGaps.frame ?? ({ on: 0 })
    readonly property bool _framed: (root._frame.on ?? 0) === 1 && !root.greeter
    readonly property real _fl: root._framed ? root._frame.left : 0
    readonly property real _ft: root._framed ? root._frame.top : 0
    readonly property real _fr: root._framed ? root._frame.right : 0
    readonly property real _fb: root._framed ? root._frame.bottom : 0

    function rrect(x, y, w, h, tlr, trr, brr, blr) {
        const m = Math.min(w, h) / 2
        const a = Math.min(tlr, m), b = Math.min(trr, m), c = Math.min(brr, m), d = Math.min(blr, m)
        const f = v => v.toFixed(2)
        return "M" + f(x + a) + " " + f(y)
            + "H" + f(x + w - b) + "A" + f(b) + " " + f(b) + " 0 0 1 " + f(x + w) + " " + f(y + b)
            + "V" + f(y + h - c) + "A" + f(c) + " " + f(c) + " 0 0 1 " + f(x + w - c) + " " + f(y + h)
            + "H" + f(x + d) + "A" + f(d) + " " + f(d) + " 0 0 1 " + f(x) + " " + f(y + h - d)
            + "V" + f(y + a) + "A" + f(a) + " " + f(a) + " 0 0 1 " + f(x + a) + " " + f(y) + "Z"
    }

    readonly property string morphPath: {
        const t = root.close
        const ro = root.ringR + root.trackW / 2
        const ri = root.ringR - root.trackW / 2
        const L = (a, b) => root.lerp(a, b, t)
        const outer = root.rrect(L(-2, root.cx - ro), L(root._ft, root.cy - ro), L(root.width + 4, 2 * ro),
                                 L(root.height + 2 - root._ft, 2 * ro), L(0, ro), L(0, ro), L(0, ro), L(0, ro))
        const inner = root.rrect(L(root._fl, root.cx - ri), L(root._ft, root.cy - ri),
                                 L(root.width - root._fl - root._fr, 2 * ri), L(root.height - root._ft - root._fb, 2 * ri),
                                 L(root._framed ? root._frame.tl ?? 0 : 0, ri), L(root._framed ? root._frame.tr ?? 0 : 0, ri),
                                 L(root._framed ? root._frame.br ?? 0 : 0, ri), L(root._framed ? root._frame.bl ?? 0 : 0, ri))
        return outer + " " + inner
    }

    readonly property color morphColor: {
        const a = Qt.color(Colors.surface), b = Qt.color(root.trackColor), t = root.close
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        opacity: root.bgIn
        visible: opacity > 0
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.trackOn

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.trackW
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.ringR; radiusY: root.ringR; startAngle: 0; sweepAngle: 360 }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.ticksIn

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.innerColor
            strokeWidth: root.innerW
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.innerR; radiusY: root.innerR; startAngle: 0; sweepAngle: 360 }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.dayIn > 0.004

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.dayColor
            strokeWidth: root.trackW
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.cx; centerY: root.cy; radiusX: root.ringR; radiusY: root.ringR
                startAngle: root.angleOf(root.riseH)
                sweepAngle: 15 * (root.setH - root.riseH) * root.dayIn
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.trackOn && root.markH > 0.01
        opacity: root.ticksIn

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Colors.surfaceText, 0.1)
            strokeWidth: root.trackW
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.cx; centerY: root.cy; radiusX: root.ringR; radiusY: root.ringR
                startAngle: 90
                sweepAngle: 15 * Math.max(0.01, root.markH < 0 ? root.markH + 24 : root.markH)
            }
        }
    }

    Repeater {
        model: root.events

        Item {
            id: ev
            required property var modelData
            required property int index
            anchors.fill: parent
            readonly property real p: root.eventIn(ev.index)
            readonly property bool past: ev.modelData.b < root.nowH
            readonly property color tone: [Colors.tertiaryContainer, Colors.secondaryContainer, Colors.primaryContainer][ev.index % 3]
            visible: ev.p > 0.01

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: ev.past ? 0.35 : 1

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: ev.tone
                    strokeWidth: root.innerW
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: root.cx; centerY: root.cy; radiusX: root.innerR; radiusY: root.innerR
                        startAngle: root.angleOf(ev.modelData.a)
                        sweepAngle: 15 * (ev.modelData.b - ev.modelData.a) * ev.p
                    }
                }
            }

            CustomText {
                readonly property point at: root.pointAt((ev.modelData.a + ev.modelData.b) / 2, root.innerR - 34 * root.u)
                x: Math.round(at.x - width / 2)
                y: Math.round(at.y - height / 2)
                width: Math.min(implicitWidth, 160 * root.u)
                content: ev.modelData.title
                size: Math.round(17 * root.u)
                weight: 500
                customColor: Colors.surfaceVariantText
                opacity: Math.max(0, ev.p * 1.4 - 0.2)
            }
        }
    }

    Item {
        visible: !root.preview
        x: root.cx
        y: root.cy
        opacity: root.ticksIn
        rotation: root.angleOf(root.secPos / 60 * 24)

        Repeater {
            model: 5

            Rectangle {
                required property int index
                readonly property real back: index * 2.6 * Math.PI / 180
                width: (12 - index * 1.6) * root.u
                height: width
                radius: width / 2
                x: root.innerR * Math.cos(-back) - width / 2
                y: root.innerR * Math.sin(-back) - height / 2
                color: Colors.primary
                opacity: 1 - index * 0.2
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.ticksIn

        Repeater {
            model: 24

            Item {
                id: tick
                required property int index
                readonly property int k: ((tick.index - Math.floor(root.nowH) - 1) % 24 + 24) % 24
                readonly property real on: Math.max(0, Math.min(1, root.lit - tick.k))
                readonly property bool major: tick.index % 6 === 0
                readonly property real baseLen: (tick.major ? 15 : 7.5) * root.u
                x: root.cx
                y: root.cy
                rotation: root.angleOf(tick.index)

                Rectangle {
                    x: root.ringR + 31 * root.u
                    y: -height / 2
                    width: tick.baseLen + (27 * root.u - tick.baseLen) * tick.on
                    height: (tick.major ? 3.5 : 2.2) * root.u + 2.5 * root.u * tick.on
                    radius: height / 2
                    color: tick.on > 0.5 ? Colors.primary : tick.major ? Colors.outline : Colors.outlineVariant
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }
    }

    Item {
        id: marker
        readonly property point at: root.pointAt(root.markH, root.ringR)
        readonly property real size: 78 * root.u
        anchors.fill: parent
        opacity: root.markIn
        visible: opacity > 0

        MaterialShapes.ShapeCanvas {
            width: marker.size + 12 * root.u
            height: width
            x: Math.round(marker.at.x - width / 2)
            y: Math.round(marker.at.y - height / 2)
            roundedPolygon: root.isDay ? "sunny" : "moon"
            color: root.bgColor
            scale: 0.4 + 0.6 * root.markPop
        }

        MaterialShapes.ShapeCanvas {
            width: marker.size
            height: width
            x: Math.round(marker.at.x - width / 2)
            y: Math.round(marker.at.y - height / 2)
            roundedPolygon: root.isDay ? "sunny" : "moon"
            color: root._failed ? Colors.error : Colors.primary
            scale: 0.4 + 0.6 * root.markPop
            Behavior on color { ColorAnimation { duration: 240 } }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.overlay > 0.001 && root._animated
        opacity: root.overlay

        ShapePath {
            fillColor: root.morphColor
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: root.morphPath }
        }
    }

    Column {
        id: center
        readonly property real lift: root.handoff ? 0 : (1 - root.centerIn) * 24 * root.u
        x: Math.round(root.cx - width / 2)
        y: Math.round(root.lerp(root.cy - height / 2 + 6 * root.u, root.cy + 118 * root.u - height, root.fieldVis) + center.lift)
        spacing: 14 * root.u

        LockCutClock {
            id: cutClock
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.handoff ? root.handoffReveal : Math.min(1, root.centerIn * 2)
            animated: root._animated
            handoff: root.handoff
            reveal: root.handoffReveal
            exiting: root.exiting
            enterDelay: 900
            hours: clock.hourPad
            minutes: clock.minute
            px: Math.round(186 * root.u)
            ink: Colors.surfaceText
            accent: Colors.primary
        }

        CustomText {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.cfg.showDate !== false
            opacity: root.handoffDate ? root.handoffReveal : root.centerIn
            content: (clock.weekday + "  " + clock.day + " " + clock.month).toUpperCase()
            size: Math.round(22 * root.u)
            weight: 600
            font.letterSpacing: 4 * root.u
            renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
            customColor: Colors.surfaceVariantText
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.nextEvent !== null
            opacity: root.centerIn
            width: nextRow.implicitWidth + 30 * root.u
            height: 48 * root.u
            radius: height / 2
            color: Colors.surfaceContainerHigh

            Row {
                id: nextRow
                anchors.verticalCenter: parent.verticalCenter
                x: 8 * root.u
                spacing: 10 * root.u

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * root.u
                    height: width
                    radius: width / 2
                    color: Colors.tertiaryContainer

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "event"
                        iconSize: Math.round(19 * root.u)
                        fill: 1
                        customColor: Colors.tertiaryContainerText
                    }
                }

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: root.nextEvent ? root.nextEvent.title + " · " + root.hhmm(root.nextEvent.a) : ""
                    size: Math.round(19 * root.u)
                    weight: 500
                }
            }
        }
    }

    Item {
        x: Math.round(root.cx - width / 2)
        y: Math.round(root.cy + 150 * root.u + (1 - root.fieldIn) * 36 * root.u + (1 - root.fieldVis) * 20 * root.u)
        width: auth.implicitWidth
        height: auth.implicitHeight
        opacity: root.fieldIn * root.fieldVis

        LockAuthField {
            id: auth
            context: root.context
            variant: "pill"
            fieldWidth: 360 * root.u
            fieldHeight: 68 * root.u
            fieldColor: Colors.surfaceContainerHigh
            placeholder: root.greeter ? "Sign in as " + LockSession.user : "Password"
            placeholderColor: Colors.surfaceVariantText
            placeholderSize: Math.round(21 * root.u)
            submitAlways: true
        }
    }

    Repeater {
        model: root.forecast

        Column {
            id: fc
            required property var modelData
            readonly property real a: root.angleOf(fc.modelData.h) * Math.PI / 180
            readonly property real reach: root.ringR + 96 * root.u
            x: Math.round(root.cx + fc.reach * Math.cos(fc.a) - width / 2)
            y: Math.round(root.cy + fc.reach * Math.sin(fc.a) - height / 2)
            spacing: 2 * root.u
            opacity: root.sideIn

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: root.hourText(fc.modelData.h)
                size: Math.round(14 * root.u)
                weight: 500
                customColor: Colors.outline
            }
            MaterialIconSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                content: fc.modelData.icon
                iconSize: Math.round(26 * root.u)
                fill: 1
                customColor: Colors.primary
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: fc.modelData.temp
                size: Math.round(18 * root.u)
                weight: 600
            }
        }
    }

    Row {
        visible: root.daylight !== ""
        x: Math.round(root.cx - width / 2)
        y: Math.round(root.cy + root.innerR - 78 * root.u)
        spacing: 8 * root.u
        opacity: root.centerIn * (1 - 0.5 * root.fieldVis)

        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            content: root.isDay ? "wb_sunny" : "bedtime"
            iconSize: Math.round(20 * root.u)
            fill: 1
            customColor: Colors.primary
        }
        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            content: root.daylight
            size: Math.round(18 * root.u)
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    Row {
        visible: root.cfg.showAvatar !== false
        x: 72 * root.u
        y: root.height - height - 64 * root.u
        spacing: 16 * root.u
        opacity: root.sideIn

        LockShapeImage {
            anchors.verticalCenter: parent.verticalCenter
            width: 64 * root.u
            height: width
            source: SettingsConfig.general.profile ?? ""
            shapeName: root._busy ? "softBurst" : root._failed ? "clover4" : (SettingsConfig.general.avatarShape ?? "circle")
            fallbackColor: Colors.tertiaryContainer
            fallbackIconColor: Colors.tertiaryContainerText
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.u

            CustomText {
                content: LockSession.user
                size: Math.round(25 * root.u)
                weight: 600
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
            }
            CustomText {
                content: root.greeter ? "Sign in to continue" : LockSession.greeting
                size: Math.round(17 * root.u)
                customColor: Colors.surfaceVariantText
            }
        }
    }

    Rectangle {
        visible: root._music
        x: root.width - width - 64 * root.u
        y: root.height - height - 64 * root.u
        width: musicRow.implicitWidth + 24 * root.u
        height: 64 * root.u
        radius: height / 2
        color: Colors.surfaceContainerHigh
        opacity: root.sideIn

        Row {
            id: musicRow
            x: 8 * root.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14 * root.u

            LockShapeImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 48 * root.u
                height: width
                source: ServiceMusic.activeTrack?.artUrl ?? ""
                trackKey: (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "")
                sourceSize: 256
                shapeName: "circle"
                fallbackIcon: "music_note"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                width: Math.min(260 * root.u, Math.max(titleText.implicitWidth, artistText.implicitWidth))

                CustomText {
                    id: titleText
                    width: parent.width
                    content: ServiceMusic.activeTrack?.title ?? ""
                    size: Math.round(18 * root.u)
                    weight: 600
                }
                CustomText {
                    id: artistText
                    width: parent.width
                    content: ServiceMusic.activeTrack?.artist ?? ""
                    size: Math.round(15 * root.u)
                    customColor: Colors.surfaceVariantText
                }
            }

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 44 * root.u
                implicitHeight: 44 * root.u
                square: true
                squareRadius: 14 * root.u
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                iconSize: Math.round(24 * root.u)
                iconFill: 1
                iconColor: Colors.primaryText
                color: Colors.primary
                onClicked: ServiceMusic.togglePlaying()
            }
        }
    }

    component SunChip: Rectangle {
        id: chip
        required property real h
        required property string icon
        readonly property real a: root.angleOf(chip.h) * Math.PI / 180
        readonly property real reach: root.ringR + root.trackW / 2 + 22 * root.u
            + Math.abs(Math.cos(chip.a)) * chip.width / 2 + Math.abs(Math.sin(chip.a)) * chip.height / 2
        x: Math.round(root.cx + chip.reach * Math.cos(chip.a) - chip.width / 2)
        y: Math.round(root.cy + chip.reach * Math.sin(chip.a) - chip.height / 2)
        width: chipRow.implicitWidth + 26 * root.u
        height: 44 * root.u
        radius: height / 2
        color: Colors.surfaceContainerHigh
        opacity: root.sideIn

        Row {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            x: 8 * root.u
            spacing: 8 * root.u

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * root.u
                height: width
                radius: width / 2
                color: root.dayColor

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: chip.icon
                    iconSize: Math.round(18 * root.u)
                    fill: 1
                    customColor: Colors.primary
                }
            }

            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.hhmm(chip.h)
                size: Math.round(19 * root.u)
                weight: 600
            }
        }
    }

    SunChip { visible: root._astro !== null; h: root.riseH; icon: "wb_sunny" }
    SunChip { visible: root._astro !== null; h: root.setH; icon: "wb_twilight" }

    Row {
        visible: root.cfg.showStatus !== false && !root.greeter
        x: 72 * root.u
        y: 64 * root.u + (60 * root.u - height) / 2
        opacity: root.sideIn
        spacing: 30 * root.u

        Repeater {
            model: status.entries

            delegate: Row {
                required property var modelData
                spacing: 10 * root.u

                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: parent.modelData.icon
                    iconSize: Math.round(24 * root.u)
                    fill: 1
                    customColor: Colors.primary
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: parent.modelData.value
                    size: Math.round(21 * root.u)
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }
        }
    }

    LockPowerActions {
        visible: root.cfg.showPower !== false
        x: root.width - width - 64 * root.u
        y: 64 * root.u
        opacity: root.sideIn
        variant: "icons"
        box: 60 * root.u
        iconPx: Math.round(24 * root.u)
        spacing: 10 * root.u
        plate: Qt.alpha(Colors.surfaceContainerHigh, 0.8)
        plateHover: Colors.surfaceContainerHighest
    }
}
