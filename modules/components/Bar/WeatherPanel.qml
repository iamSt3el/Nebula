pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
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

    opacity: 0
    property real _slideX: 400
    transform: Translate { x: root._slideX }

    NumberAnimation on opacity { from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad;   running: true }
    NumberAnimation on _slideX { from: 400; to: 0; duration: 300; easing.type: Easing.OutCubic; running: true }

    readonly property real maxContentH: root.fullH

    readonly property bool dark: Qt.color(Colors.surface).hslLightness < 0.5
    readonly property color bg: root.dark ? "transparent" : Colors.tertiaryContainer
    readonly property color ink: root.dark ? Colors.surfaceText : Colors.tertiaryContainerText
    readonly property color subInk: root.dark ? Colors.surfaceVariantText
        : Qt.tint(Colors.tertiaryContainerText, Qt.alpha(Colors.tertiaryContainer, 0.25))
    readonly property color heroFill: root.dark ? Colors.tertiaryContainer : Colors.tertiary
    readonly property color heroInk: root.dark ? Colors.tertiaryContainerText : Colors.tertiaryText
    readonly property color rowBg: root.dark ? Colors.surfaceContainerHigh
        : Qt.tint(Colors.tertiaryContainer, Qt.alpha("#ffffff", 0.45))
    readonly property color rowIcon: root.dark ? Colors.tertiary : Colors.tertiaryContainerText
    readonly property color iconBg: Qt.alpha(root.rowIcon, 0.14)
    readonly property color nowBg: root.dark ? Colors.tertiaryContainer : Colors.tertiaryContainerText
    readonly property color nowInk: root.dark ? Colors.tertiaryContainerText : Colors.tertiaryContainer
    readonly property color btnBg: root.dark ? Colors.tertiaryContainer : Colors.tertiaryContainerText
    readonly property color btnIcon: root.dark ? Colors.tertiaryContainerText : Colors.tertiaryContainer
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

    function pick(o, metricKey, imperialKey) {
        if (!o) return "--"
        return root.metric ? o[metricKey] : o[imperialKey]
    }

    function num(v) {
        const n = parseInt(v)
        return isNaN(n) ? 0 : n
    }

    function dayHi(d) {
        return root.num(root.pick(d, "maxtempC", "maxtempF"))
    }

    function dayLo(d) {
        return root.num(root.pick(d, "mintempC", "mintempF"))
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

    function hourLabel(h) {
        const hh = ((h % 24) + 24) % 24
        if (hh === 12) return "noon"
        if (hh === 0) return "midnight"
        return (hh % 12) + (hh < 12 ? " AM" : " PM")
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

    function shortHour(h) {
        const hh = ((h % 24) + 24) % 24
        return (hh % 12 === 0 ? 12 : hh % 12) + (hh < 12 ? " AM" : " PM")
    }

    function nightAt(min) {
        if (!root.sunKnown) return false
        const m = ((min % 1440) + 1440) % 1440
        return m < root.riseMin || m >= root.setMin
    }

    function partOfDay(h) {
        if (h < 5) return "night"
        if (h < 12) return "morning"
        if (h < 17) return "afternoon"
        if (h < 21) return "evening"
        return "night"
    }

    readonly property string updatedText: {
        root.now
        if (ServiceWeather.isLoading) return "Updating…"
        if (ServiceWeather.hasError && !root.cur) return "Offline"
        if (!ServiceWeather.lastUpdated) return ""
        const mins = Math.floor((root.now - ServiceWeather.lastUpdated) / 60000)
        if (mins < 1) return "Just now"
        if (mins < 60) return mins + "m ago"
        if (mins < 1440) return Math.floor(mins / 60) + "h ago"
        return Math.floor(mins / 1440) + "d ago"
    }

    readonly property int nowMin: root.now.getHours() * 60 + root.now.getMinutes()
    readonly property int riseMin: root.minutesOf(root.astro ? root.astro.sunrise : "")
    readonly property int setMin: root.minutesOf(root.astro ? root.astro.sunset : "")
    readonly property bool sunKnown: root.riseMin >= 0 && root.setMin > root.riseMin
    readonly property bool night: root.sunKnown ? (root.nowMin < root.riseMin || root.nowMin >= root.setMin)
                                                : ServiceWeather.isNightTime()

    readonly property int curTemp: root.num(root.pick(root.cur, "temp_C", "temp_F"))
    readonly property int feels: root.num(root.pick(root.cur, "FeelsLikeC", "FeelsLikeF"))
    readonly property string curKind: root.kind(ServiceWeather.weatherCode)

    readonly property var upcoming: {
        const out = []
        for (let d = 0; d < root.days.length; d++) {
            const hs = root.days[d].hourly ?? []
            for (let i = 0; i < hs.length; i++) {
                const h = hs[i]
                const hr = Math.floor(parseInt(h.time) / 100)
                const abs = d * 1440 + hr * 60
                if (abs <= root.nowMin)
                    continue
                out.push({ day: d, hour: hr, abs: abs, temp: root.num(root.metric ? h.tempC : h.tempF),
                           rain: root.num(h.chanceofrain), code: h.weatherCode })
            }
        }
        return out
    }

    readonly property var hourly: {
        if (!root.cur) return []
        const out = [{ label: "Now", temp: root.curTemp, shape: root.kindShape(root.curKind, root.night), now: true }]
        for (let i = 0; i < root.upcoming.length && out.length < 8; i++) {
            const e = root.upcoming[i]
            out.push({ label: root.shortHour(e.hour), temp: e.temp, now: false,
                       shape: root.kindShape(root.kind(e.code), root.nightAt(e.abs)) })
        }
        return out
    }

    function whenOf(e) {
        const part = root.partOfDay(e.hour)
        if (e.day === 0) return part === "night" ? "tonight" : "this " + part
        if (e.day === 1) return part === "night" && e.hour < 5 ? "overnight" : "tomorrow " + part
        return Qt.formatDate(new Date(root.days[e.day].date + "T00:00:00"), "dddd") + " " + part
    }

    readonly property var rowData: {
        const out = []
        const c = root.cur
        if (c) {
            const hum = root.num(c.humidity)
            out.push({ shape: "cookie4", label: "Feels like",
                       value: root.feels + "°, " + (hum < 40 ? "dry air" : hum < 65 ? "comfortable" : "humid") })
        }
        if (root.upcoming.length > 0 && root.riseMin >= 0) {
            const until = root.nowMin < root.riseMin ? root.riseMin : 1440 + root.riseMin
            let lo = null
            for (let i = 0; i < root.upcoming.length && root.upcoming[i].abs <= until; i++)
                if (!lo || root.upcoming[i].temp < lo.temp) lo = root.upcoming[i]
            if (lo)
                out.push({ shape: "moon", label: root.night ? "Until sunrise" : "Tonight",
                           value: lo.temp + "° by " + root.hourLabel(lo.hour) })
        }
        if (root.sunKnown) {
            const rise = root.night
            out.push({ shape: rise ? "sunny" : "verySunny", label: rise ? "Sunrise" : "Sunset",
                       value: root.shortTime(rise ? root.astro.sunrise : root.astro.sunset) })
        }
        let wet = null
        for (let i = 0; i < root.upcoming.length; i++)
            if (root.upcoming[i].rain >= 30) { wet = root.upcoming[i]; break }
        if (wet)
            out.push({ shape: "drop", label: "Rain", value: wet.rain + "% " + root.whenOf(wet) })
        const t = root.days[1]
        if (t) {
            const hs = t.hourly ?? []
            const mid = hs.length > 4 ? hs[4] : hs[hs.length - 1]
            const sky = mid ? root.kindWord(root.kind(mid.weatherCode), false).toLowerCase() : ""
            out.push({ shape: "squircle", label: "Tomorrow",
                       value: root.dayLo(t) + "–" + root.dayHi(t) + "°" + (sky ? ", " + sky : "") })
        }
        return out
    }

    readonly property real pad: 16
    readonly property real gap: 16
    readonly property real headerH: 40
    readonly property real rowH: 52
    readonly property real rowGap: 2
    readonly property real stripH: 78
    readonly property real stripGap: 10
    readonly property real innerW: Math.max(0, root.width - root.pad * 2)
    readonly property bool wide: root.innerW >= 520
    readonly property real leftW: root.wide ? Math.round((root.innerW - root.gap) * 0.47) : root.innerW
    readonly property real rightW: root.wide ? root.innerW - root.gap - root.leftW : root.innerW
    readonly property string tempText: root.cur ? root.curTemp + "°" : "--"
    readonly property real shapeSize: Math.round(Math.max(130, Math.min(240, root.leftW * 0.56)))
    readonly property real numRatio: Math.max(0.5, numProbe.implicitWidth / 100)
    readonly property real bigSize: Math.round(Math.min(root.shapeSize * 0.6 / root.numRatio, root.shapeSize * 0.42))

    CustomText {
        id: numProbe
        visible: false
        content: root.tempText
        size: 100
        weight: 400
        family: root.displayFamily
        font.letterSpacing: -3
        elide: Text.ElideNone
    }
    readonly property int slotCount: Math.max(3, Math.min(8, Math.floor((root.leftW + root.rowGap) / 58)))
    readonly property var slots: root.hourly.slice(0, root.slotCount)
    readonly property bool hasStrip: root.slots.length > 1
    readonly property real heroH: hero.implicitHeight

    function rowsHeight(n) {
        return n > 0 ? n * root.rowH + (n - 1) * root.rowGap : 0
    }

    readonly property real fullH: {
        const top = root.pad * 2 + root.headerH + 8
        const strip = root.hasStrip ? root.stripH : 0
        const rows = root.rowsHeight(root.rowData.length)
        if (root.wide)
            return top + Math.max(root.heroH + (strip > 0 ? root.gap + strip : 0), rows)
        return top + root.heroH + root.gap + (strip > 0 ? strip + (rows > 0 ? root.stripGap : 0) : 0) + rows
    }

    readonly property real bodyH: Math.max(0, root.height - root.pad * 2 - root.headerH - 8)

    readonly property var fit: {
        const n = root.rowData.length
        if (root.wide) {
            const rows = Math.max(0, Math.min(n, Math.floor((root.bodyH + root.rowGap) / (root.rowH + root.rowGap))))
            return { rows: rows, strip: root.hasStrip && root.bodyH - root.heroH - root.gap >= root.stripH }
        }
        let room = root.bodyH - root.heroH - root.gap
        let rows = 0
        let strip = false
        let rowsDone = false
        const order = [0, 1, -1]
        for (let i = 2; i < n; i++) order.push(i)
        for (let k = 0; k < order.length; k++) {
            if (order[k] === -1) {
                if (!root.hasStrip) continue
                const cost = root.stripH + (rows > 0 ? root.stripGap : 0)
                if (room >= cost) { strip = true; room -= cost }
                continue
            }
            if (rowsDone || order[k] >= n) continue
            const cost = rows > 0 ? root.rowH + root.rowGap : root.rowH + (strip ? root.stripGap : 0)
            if (room >= cost) { rows++; room -= cost } else rowsDone = true
        }
        return { rows: rows, strip: strip }
    }

    readonly property var shownRows: root.rowData.slice(0, root.fit.rows)

    component FactList: ColumnLayout {
        id: list
        required property var host
        spacing: list.host.rowGap

        Repeater {
            model: list.host.shownRows

            Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool first: row.index === 0
                readonly property bool last: row.index === list.host.shownRows.length - 1

                Layout.fillWidth: true
                implicitHeight: list.host.rowH
                color: list.host.rowBg
                topLeftRadius: row.first ? 24 : 6
                topRightRadius: row.first ? 24 : 6
                bottomLeftRadius: row.last ? 24 : 6
                bottomRightRadius: row.last ? 24 : 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: list.host.iconBg

                        MaterialShapes.ShapeCanvas {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            roundedPolygon: row.modelData.shape
                            color: list.host.rowIcon
                        }
                    }

                    CustomText {
                        content: row.modelData.label
                        size: 13
                        weight: 600
                        customColor: list.host.subInk
                    }

                    CustomText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignRight
                        content: row.modelData.value
                        size: 14
                        weight: 800
                        customColor: list.host.ink
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.dark
        color: root.bg
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 0

        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerH
            Layout.leftMargin: 6
            spacing: 8

            CustomText {
                Layout.fillWidth: true
                content: ServiceWeather.cityName !== "Unknown" ? ServiceWeather.cityName : ServiceWeather.location
                size: 14
                weight: 800
                customColor: root.ink
            }

            CustomText {
                visible: root.updatedText !== ""
                content: root.updatedText
                size: 11
                weight: 600
                customColor: root.subInk
            }

            M3IconButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                icon: "refresh"
                iconSize: 18
                color: root.btnBg
                iconColor: root.btnIcon
                iconHoverColor: root.btnIcon
                tip: "Refresh"
                onClicked: ServiceWeather.refresh()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            spacing: root.gap

            ColumnLayout {
                Layout.preferredWidth: root.leftW
                Layout.maximumWidth: root.leftW
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    id: hero
                    Layout.fillWidth: true
                    spacing: 14

                    HeroTag { key: "weather"; item: badge; target: true }

                    Item {
                        id: badge
                        Layout.preferredWidth: root.shapeSize
                        Layout.preferredHeight: root.shapeSize

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: root.kindShape(root.curKind, root.night)
                            color: root.heroFill
                        }

                        CustomText {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: Math.round(root.bigSize * 0.03)
                            content: root.tempText
                            size: root.bigSize
                            weight: 400
                            family: root.displayFamily
                            font.letterSpacing: -Math.round(root.bigSize * 0.03)
                            elide: Text.ElideNone
                            customColor: root.heroInk
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        CustomText {
                            Layout.fillWidth: true
                            content: root.cur ? root.kindWord(root.curKind, root.night) : "No weather yet"
                            size: Math.round(Math.max(20, Math.min(34, root.shapeSize * 0.17)))
                            weight: 400
                            family: root.displayFamily
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            customColor: root.ink
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: root.days.length > 0
                            content: "High " + root.dayHi(root.days[0]) + "°"
                            size: 14
                            weight: 800
                            customColor: root.ink
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: root.days.length > 0
                            content: "Low " + root.dayLo(root.days[0]) + "°"
                            size: 14
                            weight: 600
                            customColor: root.subInk
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.gap
                }

                RowLayout {
                    id: strip
                    Layout.fillWidth: true
                    visible: root.fit.strip
                    spacing: root.rowGap

                    Repeater {
                        model: root.slots

                        Rectangle {
                            id: slot

                            required property var modelData
                            required property int index
                            readonly property bool first: slot.index === 0
                            readonly property bool last: slot.index === root.slots.length - 1

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            implicitHeight: root.stripH
                            color: slot.modelData.now ? root.nowBg : root.rowBg
                            topLeftRadius: slot.first ? 24 : 6
                            bottomLeftRadius: slot.first ? 24 : 6
                            topRightRadius: slot.last ? 24 : 6
                            bottomRightRadius: slot.last ? 24 : 6

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: slot.modelData.label
                                    size: 11
                                    weight: 700
                                    customColor: slot.modelData.now ? root.nowInk : root.subInk
                                }

                                MaterialShapes.ShapeCanvas {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    roundedPolygon: slot.modelData.shape
                                    color: slot.modelData.now ? root.nowInk : root.rowIcon
                                }

                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: slot.modelData.temp + "°"
                                    size: 15
                                    weight: 800
                                    customColor: slot.modelData.now ? root.nowInk : root.ink
                                }
                            }
                        }
                    }
                }

                FactList {
                    host: root
                    Layout.fillWidth: true
                    Layout.topMargin: root.fit.strip && root.fit.rows > 0 ? root.stripGap : 0
                    visible: !root.wide && root.fit.rows > 0
                }
            }

            FactList {
                host: root
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                visible: root.wide && root.fit.rows > 0
            }
        }
    }
}
