pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent
    signal closed

    property real topLeftRadius: 20
    property real topRightRadius: 20
    property real bottomLeftRadius: 20
    property real bottomRightRadius: 20

    implicitHeight: root.fullH
    readonly property real maxContentH: root.fullH

    opacity: 0
    property real _slideX: 400
    transform: Translate { x: root._slideX }

    NumberAnimation on opacity { from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad; running: true }
    NumberAnimation on _slideX { from: 400; to: 0; duration: 300; easing.type: Easing.OutCubic; running: true }

    readonly property bool dark: Qt.color(Colors.surface).hslLightness < 0.5
    readonly property bool dayLight: Qt.color(Colors.primaryContainer).hslLightness >= 0.5
    readonly property color dayBg: Colors.primaryContainer
    readonly property color dayInk: root.dayLight ? Qt.darker(Colors.primaryContainerText, 1.75)
                                                  : Qt.lighter(Colors.primaryContainerText, 1.5)
    readonly property color daySub: Colors.primaryContainerText
    readonly property color nightBg: root.dark ? Colors.surfaceContainerLowest : Colors.inverseSurface
    readonly property color nightInk: root.dark ? Colors.surfaceText : Colors.inverseSurfaceText
    readonly property color nightSub: root.dark ? Colors.surfaceVariantText : Qt.alpha(Colors.inverseSurfaceText, 0.72)
    readonly property color tileBg: root.dark ? Colors.surfaceContainer : Qt.alpha(Colors.inverseSurfaceText, 0.1)
    readonly property color moonLit: root.dark ? Colors.tertiary : Colors.inversePrimary
    readonly property color moonDark: Qt.alpha(root.nightInk, 0.16)
    readonly property string displayFamily: SettingsConfig.general.displayFont ?? "Titan One"

    readonly property bool metric: ServiceWeather.useMetric
    readonly property var cur: ServiceWeather.currentCondition
    readonly property var days: ServiceWeather.forecastDays ?? []
    readonly property var astro: ServiceWeather.astronomy

    property var now: new Date()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function num(v) {
        const n = parseInt(v)
        return isNaN(n) ? 0 : n
    }

    function tempOf(o, c, f) {
        return o ? root.num(root.metric ? o[c] : o[f]) : 0
    }

    function minutesOf(s) {
        const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(s ?? "")
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (m[3].toUpperCase() === "PM") h += 12
        return h * 60 + parseInt(m[2])
    }

    function shortTime(s) {
        return (s ?? "--").replace(/^0/, "")
    }

    function shortHour(h) {
        const hh = ((h % 24) + 24) % 24
        if (hh === 12) return "noon"
        if (hh === 0) return "midnight"
        return (hh % 12) + (hh < 12 ? " AM" : " PM")
    }

    function span(mins) {
        const m = Math.max(0, Math.round(mins))
        const h = Math.floor(m / 60)
        return h > 0 ? h + " h " + (m % 60) + " m" : (m % 60) + " m"
    }

    function kind(code) {
        const c = parseInt(code)
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "storm"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(c) >= 0) return "snow"
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0) return "ice"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(c) >= 0) return "rain"
        if ([143, 248, 260].indexOf(c) >= 0) return "fog"
        if ([119, 122].indexOf(c) >= 0) return "cloud"
        if (c === 116) return "partly"
        return "clear"
    }

    function kindWord(k, night) {
        switch (k) {
        case "storm":  return "Stormy"
        case "snow":   return "Snowy"
        case "ice":    return "Icy"
        case "rain":   return "Rainy"
        case "fog":    return "Foggy"
        case "cloud":  return "Cloudy"
        case "partly": return "Partly cloudy"
        }
        return night ? "Clear" : "Sunny"
    }

    function kindShape(k, night) {
        switch (k) {
        case "storm":  return "softBoom"
        case "snow":   return "flower"
        case "ice":    return "gem"
        case "rain":   return "drop"
        case "fog":    return "pill"
        case "cloud":  return "puffy"
        case "partly": return "sunny"
        }
        return night ? "cookie9" : "verySunny"
    }

    function astroOf(d) {
        const a = root.days[d] ? root.days[d].astronomy : null
        return a && a.length > 0 ? a[0] : null
    }

    readonly property int nowMin: root.now.getHours() * 60 + root.now.getMinutes()
    readonly property int riseMin: root.minutesOf(root.astro ? root.astro.sunrise : "")
    readonly property int setMin: root.minutesOf(root.astro ? root.astro.sunset : "")
    readonly property bool sunKnown: root.riseMin >= 0 && root.setMin > root.riseMin
    readonly property bool night: root.sunKnown ? (root.nowMin < root.riseMin || root.nowMin >= root.setMin)
                                                : ServiceWeather.isNightTime()
    readonly property real sunFrac: root.sunKnown ? Math.max(0, Math.min(1, (root.nowMin - root.riseMin) / (root.setMin - root.riseMin))) : 0

    readonly property int curTemp: root.tempOf(root.cur, "temp_C", "temp_F")
    readonly property string curKind: root.kind(ServiceWeather.weatherCode)

    readonly property var peak: {
        const d = root.days[0]
        if (!d) return null
        const hs = d.hourly ?? []
        let best = null
        for (let i = 0; i < hs.length; i++) {
            const t = root.tempOf(hs[i], "tempC", "tempF")
            if (!best || t > best.temp) best = { temp: t, hour: Math.floor(parseInt(hs[i].time) / 100) }
        }
        return best ? { temp: Math.max(best.temp, root.tempOf(d, "maxtempC", "maxtempF")), hour: best.hour } : null
    }

    readonly property string dayLine: {
        if (!root.cur) return "No weather yet"
        const w = root.kindWord(root.curKind, root.night)
        if (!root.peak) return w
        const past = root.peak.hour * 60 <= root.nowMin
        return w + ", high " + root.peak.temp + "°" + (past ? "" : " at " + root.shortHour(root.peak.hour))
    }

    readonly property string sunText: {
        if (!root.sunKnown) return ""
        if (root.nowMin < root.riseMin) return "Sunrise in " + root.span(root.riseMin - root.nowMin)
        if (root.nowMin < root.setMin) return root.span(root.setMin - root.nowMin) + " of light left"
        const a = root.astroOf(1)
        const next = a ? root.minutesOf(a.sunrise) : root.riseMin
        return "Sunrise in " + root.span(1440 - root.nowMin + next)
    }

    readonly property var upcoming: {
        const out = []
        for (let d = 0; d < root.days.length; d++) {
            const hs = root.days[d].hourly ?? []
            for (let i = 0; i < hs.length; i++) {
                const hr = Math.floor(parseInt(hs[i].time) / 100)
                const abs = d * 1440 + hr * 60
                if (abs <= root.nowMin) continue
                out.push({ hour: hr, abs: abs, temp: root.tempOf(hs[i], "tempC", "tempF") })
            }
        }
        return out
    }

    readonly property var lowTonight: {
        if (root.riseMin < 0) return null
        const until = root.nowMin < root.riseMin ? root.riseMin : 1440 + root.riseMin
        let lo = null
        for (let i = 0; i < root.upcoming.length && root.upcoming[i].abs <= until; i++)
            if (!lo || root.upcoming[i].temp < lo.temp) lo = root.upcoming[i]
        return lo
    }

    readonly property var moons: {
        const out = []
        for (let d = 0; d < Math.min(7, root.days.length); d++) {
            const a = root.astroOf(d)
            if (!a) continue
            const phase = a.moon_phase ?? ""
            const hs = root.days[d].hourly ?? []
            const late = hs.length > 0 ? hs[hs.length - 1] : null
            out.push({
                day: d,
                label: d === 0 ? "Today" : Qt.formatDate(new Date(root.days[d].date + "T00:00:00"), "ddd"),
                date: Qt.formatDate(new Date(root.days[d].date + "T00:00:00"), "ddd d"),
                lit: Math.max(0, Math.min(100, root.num(a.moon_illumination))),
                phase: phase,
                waxing: /waxing|first/i.test(phase),
                sky: late ? root.kindWord(root.kind(late.weatherCode), true).toLowerCase() : ""
            })
        }
        return out
    }

    readonly property var darkest: {
        let best = null
        for (let i = 0; i < root.moons.length; i++)
            if (!best || root.moons[i].lit < best.lit) best = root.moons[i]
        return best
    }

    function moonPath(c, r, lit, waxing) {
        const f = lit / 100
        const rx = (Math.abs(1 - 2 * f) * r).toFixed(2)
        const top = c + " " + (c - r)
        const bottom = c + " " + (c + r)
        if (waxing)
            return "M" + top + "A" + r + " " + r + " 0 0 1 " + bottom + "A" + rx + " " + r + " 0 0 " + (f < 0.5 ? 0 : 1) + " " + top + "Z"
        return "M" + top + "A" + r + " " + r + " 0 0 0 " + bottom + "A" + rx + " " + r + " 0 0 " + (f < 0.5 ? 1 : 0) + " " + top + "Z"
    }

    readonly property real pad: 18
    readonly property real waveH: 22
    readonly property real arcH: 92
    readonly property real heroSize: Math.round(Math.max(76, Math.min(110, root.width * 0.26)))
    readonly property real tempSize: Math.round(Math.max(48, Math.min(68, root.width * 0.17)))
    readonly property real moonsH: 76
    readonly property real tilesH: 78
    readonly property real nightHeadH: 18
    readonly property real dayH: dayCol.implicitHeight + root.pad + root.pad + 10
    readonly property real nightTop: 6 + root.nightHeadH
    readonly property real fullH: root.dayH + root.waveH + root.nightTop
                                  + (root.moons.length > 0 ? 14 + root.moonsH : 0) + 12 + root.tilesH + root.pad
    readonly property real room: root.height - root.dayH - root.waveH - root.nightTop - root.pad
    readonly property bool showMoons: root.moons.length > 0 && root.room >= 14 + root.moonsH
    readonly property bool showTiles: root.room >= (root.moons.length > 0 ? 14 + root.moonsH : 0) + 12 + root.tilesH
                                      || (!root.showMoons && root.room >= 12 + root.tilesH)

    Rectangle {
        anchors.fill: parent
        color: root.nightBg
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    Rectangle {
        id: dayPlate
        x: 0
        y: 0
        width: root.width
        height: root.dayH
        color: root.dayBg
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
    }

    Shape {
        id: wave
        anchors.top: dayPlate.bottom
        anchors.topMargin: -1
        width: root.width
        height: root.waveH + 1
        preferredRendererType: Shape.CurveRenderer

        readonly property string d: {
            const w = Math.max(1, root.width)
            let s = "M0 0L0 11"
            for (let x = 0; x <= w; x += 4)
                s += "L" + x + " " + (11 + Math.sin(x / w * Math.PI * 6) * 5).toFixed(2)
            return s + "L" + w + " 11L" + w + " 0Z"
        }

        ShapePath {
            fillColor: root.dayBg
            strokeColor: "transparent"
            PathSvg { path: wave.d }
        }
    }

    ColumnLayout {
        id: dayCol
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 6

                CustomText {
                    Layout.fillWidth: true
                    content: "DAY · " + (ServiceWeather.cityName !== "Unknown" ? ServiceWeather.cityName : ServiceWeather.location).toUpperCase()
                    size: 12
                    weight: 600
                    font.letterSpacing: 0.8
                    customColor: root.daySub
                }

                CustomText {
                    content: root.cur ? root.curTemp + "°" : "--"
                    size: root.tempSize
                    weight: 400
                    family: root.displayFamily
                    elide: Text.ElideNone
                    customColor: root.dayInk
                }

                CustomText {
                    Layout.fillWidth: true
                    content: root.dayLine
                    size: 15
                    weight: 600
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    customColor: root.dayInk
                }
            }

            Item {
                id: badge
                Layout.preferredWidth: root.heroSize
                Layout.preferredHeight: root.heroSize
                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: -4

                HeroTag { key: "weather"; item: badge; target: true }

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    roundedPolygon: root.kindShape(root.curKind, root.night)
                    color: root.dayInk
                    rotation: 8
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceWeather.refresh()
                }
            }
        }

        Item {
            id: arc
            Layout.fillWidth: true
            Layout.preferredHeight: root.arcH
            Layout.topMargin: 10
            visible: root.sunKnown

            readonly property real cx: arc.width / 2
            readonly property real by: 64
            readonly property real rx: Math.max(10, arc.width / 2 - 14)
            readonly property real ry: 52
            readonly property real ang: Math.PI * (1 + root.sunFrac)
            readonly property real sx: arc.cx + arc.rx * Math.cos(arc.ang)
            readonly property real sy: arc.by + arc.ry * Math.sin(arc.ang)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(root.daySub, root.night ? 0.8 : 0.5)
                    strokeWidth: 2
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1.5, 2.5]
                    capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: arc.cx; centerY: arc.by; radiusX: arc.rx; radiusY: arc.ry; startAngle: 180; sweepAngle: 180 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.night ? "transparent" : root.dayInk
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: arc.cx; centerY: arc.by; radiusX: arc.rx; radiusY: arc.ry; startAngle: 180; sweepAngle: Math.max(0.01, 180 * root.sunFrac) }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(root.daySub, 0.55)
                    strokeWidth: 1
                    PathMove { x: 0; y: arc.by }
                    PathLine { x: arc.width; y: arc.by }
                }
            }

            MaterialShapes.ShapeCanvas {
                width: 26
                height: 26
                x: Math.round(arc.sx - 13)
                y: Math.round(arc.sy - 13)
                visible: !root.night
                roundedPolygon: "sunny"
                color: root.dayInk
            }

            CustomText {
                x: Math.round(arc.cx - arc.rx - width / 2)
                y: arc.by + 6
                content: root.shortTime(root.astro ? root.astro.sunrise : "").replace(/\s*[AP]M/i, "")
                size: 11
                weight: 500
                customColor: root.daySub
            }

            CustomText {
                x: Math.round(arc.cx - width / 2)
                y: arc.by + 6
                content: root.sunText
                size: 11
                weight: 700
                customColor: root.dayInk
            }

            CustomText {
                x: Math.round(arc.cx + arc.rx - width / 2)
                y: arc.by + 6
                content: root.shortTime(root.astro ? root.astro.sunset : "").replace(/\s*[AP]M/i, "")
                size: 11
                weight: 500
                customColor: root.daySub
            }
        }
    }

    ColumnLayout {
        x: root.pad
        y: root.dayH + root.waveH + 6
        width: root.width - root.pad * 2
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.nightHeadH
            spacing: 8

            CustomText {
                content: "NIGHT"
                size: 12
                weight: 600
                font.letterSpacing: 0.8
                customColor: root.nightSub
            }

            CustomText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                visible: root.moons.length > 0
                content: root.moons.length > 0 ? "Moon · " + root.moons[0].phase.toLowerCase() + ", " + root.moons[0].lit + "%" : ""
                size: 12
                weight: 500
                customColor: root.nightSub
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.preferredHeight: root.moonsH
            visible: root.showMoons
            spacing: 4

            Repeater {
                model: root.moons

                Rectangle {
                    id: cell
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    radius: 16
                    color: cell.index === 0 ? root.tileBg : "transparent"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: root.moonDark
                                visible: cell.modelData.lit > 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: "transparent"
                                border.width: 1.5
                                border.color: Qt.alpha(root.nightSub, 0.6)
                                visible: cell.modelData.lit === 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: root.moonLit
                                visible: cell.modelData.lit >= 99
                            }

                            Shape {
                                anchors.fill: parent
                                visible: cell.modelData.lit > 0 && cell.modelData.lit < 99
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: root.moonLit
                                    strokeColor: "transparent"
                                    PathSvg { path: root.moonPath(15, 15, cell.modelData.lit, cell.modelData.waxing) }
                                }
                            }
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: cell.modelData.lit + "%"
                            size: 12
                            weight: 600
                            customColor: root.nightInk
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: cell.modelData.label
                            size: 11
                            weight: 500
                            customColor: root.nightSub
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.preferredHeight: root.tilesH
            visible: root.showTiles
            spacing: 2

            Repeater {
                model: [
                    { label: "Low tonight", value: root.lowTonight ? root.lowTonight.temp + "°" : "--",
                      sub: root.lowTonight ? "by " + root.shortHour(root.lowTonight.hour) : "" },
                    { label: "Darkest sky", value: root.darkest ? root.darkest.date : "--",
                      sub: root.darkest ? root.darkest.phase.toLowerCase() + (root.darkest.sky ? ", " + root.darkest.sky : "") : "" }
                ]

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: root.tileBg
                    topLeftRadius: tile.index === 0 ? 20 : 6
                    bottomLeftRadius: tile.index === 0 ? 20 : 6
                    topRightRadius: tile.index === 1 ? 20 : 6
                    bottomRightRadius: tile.index === 1 ? 20 : 6

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 3

                        CustomText {
                            Layout.fillWidth: true
                            content: tile.modelData.label
                            size: 12
                            weight: 500
                            customColor: root.nightSub
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: tile.modelData.value
                            size: 22
                            weight: 400
                            family: root.displayFamily
                            customColor: root.nightInk
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: tile.modelData.sub
                            size: 12
                            weight: 500
                            customColor: root.nightSub
                        }
                    }
                }
            }
        }
    }
}
