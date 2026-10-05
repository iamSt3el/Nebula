import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Item {
    id: root
    anchors.fill: parent
    signal closed

    implicitHeight: root.fullH

    opacity: 0
    property real _slideX: 400
    transform: Translate { x: root._slideX }

    NumberAnimation on opacity { from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad;   running: true }
    NumberAnimation on _slideX { from: 400; to: 0; duration: 300; easing.type: Easing.OutCubic; running: true }

    readonly property real maxContentH: root.implicitHeight

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

    function celsius(t) {
        return root.metric ? t : (t - 32) * 5 / 9
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
        return (hh % 12 === 0 ? 12 : hh % 12) + (hh < 12 ? " AM" : " PM")
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

    function kindSky(k) {
        switch (k) {
        case "storm":  return "with storms around"
        case "snow":   return "with snow"
        case "ice":    return "with sleet"
        case "rain":   return "with some rain"
        case "fog":    return "after a foggy start"
        case "cloud":  return "under cloudy skies"
        case "partly": return "with some cloud"
        }
        return "under clear skies"
    }

    function feelWord(t) {
        const c = root.celsius(t)
        if (c < 5) return "cold"
        if (c < 15) return "cool"
        if (c < 24) return "mild"
        if (c < 33) return "warm"
        return "hot"
    }

    function partOfDay(h) {
        if (h < 5) return "night"
        if (h < 12) return "morning"
        if (h < 17) return "afternoon"
        if (h < 21) return "evening"
        return "night"
    }

    function strong(v) {
        return "<font color=\"" + Colors.surfaceText + "\"><b>" + v + "</b></font>"
    }

    readonly property string updatedText: {
        root.now
        if (ServiceWeather.isLoading) return "Updating…"
        if (ServiceWeather.hasError && !root.cur) return "Offline"
        if (!ServiceWeather.lastUpdated) return "—"
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
    readonly property int todayHi: root.dayHi(root.days[0])
    readonly property int todayLo: root.dayLo(root.days[0])

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

    readonly property string headline: {
        if (!root.cur) return "No weather yet."
        const h = root.now.getHours()
        const when = h >= 21 || h < 5 || (root.night && h >= 17) ? "tonight" : "this " + root.partOfDay(h)
        return root.kindWord(root.kind(ServiceWeather.weatherCode), root.night) + " and "
             + root.feelWord(root.feels) + " " + when + "."
    }

    readonly property string nextLine: {
        if (root.upcoming.length === 0) return ""
        if (root.night) {
            const until = root.riseMin >= 0
                ? (root.nowMin < root.riseMin ? root.riseMin : 1440 + root.riseMin) : root.nowMin + 600
            let lo = null
            for (let i = 0; i < root.upcoming.length && root.upcoming[i].abs <= until; i++)
                if (!lo || root.upcoming[i].temp < lo.temp) lo = root.upcoming[i]
            return lo ? "Cools to " + root.strong(lo.temp + "°") + " by sunrise." : ""
        }
        const until = root.setMin >= 0 ? root.setMin : 18 * 60
        let hi = null
        for (let i = 0; i < root.upcoming.length && root.upcoming[i].abs <= until; i++)
            if (!hi || root.upcoming[i].temp > hi.temp) hi = root.upcoming[i]
        if (hi && hi.temp > root.curTemp)
            return "Warms to " + root.strong(hi.temp + "°") + " around " + root.hourLabel(hi.hour) + "."
        const mid = root.upcoming.find(e => e.day === 1 && e.hour === 0)
        return mid ? "Cools to " + root.strong(mid.temp + "°") + " by midnight." : ""
    }

    readonly property string tomorrowLine: {
        const t = root.days[1]
        if (!t) return ""
        const hs = t.hourly ?? []
        let peak = null
        for (let i = 0; i < hs.length; i++) {
            const v = root.num(root.metric ? hs[i].tempC : hs[i].tempF)
            if (!peak || v > peak.v) peak = { v: v, hour: Math.floor(parseInt(hs[i].time) / 100), code: hs[i].weatherCode }
        }
        if (!peak) return ""
        const verb = peak.v >= root.todayHi ? "climbs to " : "reaches "
        return "Tomorrow " + verb + root.strong(peak.v + "°") + " around " + root.hourLabel(peak.hour)
             + " " + root.kindSky(root.kind(peak.code)) + "."
    }

    readonly property string rainLine: {
        let wet = null
        let best = null
        for (let i = 0; i < root.upcoming.length; i++) {
            const e = root.upcoming[i]
            if (!wet && e.rain >= 30) wet = e
            if (!best || e.rain > best.rain) best = e
        }
        const whenOf = e => {
            const part = root.partOfDay(e.hour)
            if (e.day === 0) return part === "night" ? "tonight" : "this " + part
            if (e.day === 1) return part === "night" && e.hour < 5 ? "overnight" : "tomorrow " + part
            const name = Qt.formatDate(new Date(root.days[e.day].date + "T00:00:00"), "dddd")
            return name + " " + part
        }
        if (wet) return "Rain is likely " + whenOf(wet) + ", " + root.strong(wet.rain + "%") + "."
        if (best && best.rain > 0)
            return "The best chance of rain is " + whenOf(best) + ", and it is only " + root.strong(best.rain + "%") + "."
        return root.upcoming.length > 0 ? "No rain in the forecast." : ""
    }

    readonly property string story: [root.nextLine, root.tomorrowLine, root.rainLine].filter(s => s !== "").join(" ")

    readonly property var facts: {
        const c = root.cur
        if (!c) return []
        const hum = root.num(c.humidity)
        const diff = root.feels - root.curTemp
        const out = [
            { icon: "thermostat", label: "Feels like", value: root.feels + "°",
              note: Math.abs(diff) <= 1 ? "same" : diff > 0 ? "warmer" : "cooler" },
            { icon: "humidity_percentage", label: "Humidity", value: hum + "%",
              note: hum < 40 ? "dry" : hum < 65 ? "comfortable" : "humid" },
            { icon: "air", label: "Wind", value: root.pick(c, "windspeedKmph", "windspeedMiles") + (root.metric ? " km/h" : " mph"),
              note: "from " + ServiceWeather.windDirection },
            { icon: "compress", label: "Pressure", value: String(root.pick(c, "pressure", "pressureInches")),
              note: root.metric ? "hPa" : "inHg" },
            { icon: "visibility", label: "Visibility", value: root.pick(c, "visibility", "visibilityMiles") + (root.metric ? " km" : " mi"),
              note: root.num(c.visibility) >= 10 ? "clear" : root.num(c.visibility) >= 4 ? "hazy" : "poor" }
        ]
        if (root.sunKnown) {
            const rise = root.night
            const at = rise ? root.riseMin : root.setMin
            const left = at > root.nowMin ? at - root.nowMin : at + 1440 - root.nowMin
            out.push({ icon: rise ? "wb_twilight" : "nights_stay", label: rise ? "Sunrise" : "Sunset",
                       value: root.shortTime(rise ? root.astro.sunrise : root.astro.sunset),
                       note: left >= 60 ? "in " + Math.round(left / 60) + " h" : "in " + left + " min" })
        }
        return out
    }

    readonly property real pad: 18
    readonly property real gap: 14
    readonly property real rowH: 42
    readonly property real innerW: Math.max(0, root.width - root.pad * 2)
    readonly property real availH: Math.max(0, root.height - root.pad * 2)
    readonly property bool wide: root.innerW >= 520
    readonly property real leftW: root.wide ? Math.round((root.innerW - 24) * 0.55) : root.innerW
    readonly property real factsW: root.wide ? root.innerW - 24 - root.leftW : root.innerW
    readonly property real storyH: root.story !== "" ? storyProbe.implicitHeight : 0
    readonly property real weekH: root.days.length > 0 ? week.implicitHeight : 0
    readonly property real topH: header.implicitHeight + root.gap + hero.implicitHeight

    readonly property real fullH: {
        const story = root.storyH > 0 ? root.gap + root.storyH : 0
        const facts = root.facts.length * root.rowH
        const week = root.weekH > 0 ? root.gap + root.weekH : 0
        const body = root.wide
            ? root.gap + Math.max(hero.implicitHeight + story, facts) + header.implicitHeight
            : root.topH + story + (facts > 0 ? root.gap + facts : 0)
        return root.pad * 2 + body + week
    }

    readonly property bool showWeek: {
        if (root.weekH <= 0) return false
        return root.availH - root.topH >= root.gap + root.weekH
    }

    readonly property real bodyH: root.availH - header.implicitHeight - root.gap
                                  - (root.showWeek ? root.gap + root.weekH : 0)

    readonly property bool showStory: root.storyH > 0 && root.bodyH - hero.implicitHeight >= root.gap + root.storyH

    readonly property int factCount: {
        const room = root.wide
            ? root.bodyH
            : root.bodyH - hero.implicitHeight - (root.showStory ? root.gap + root.storyH : 0) - root.gap
        return Math.max(0, Math.min(root.facts.length, Math.floor(room / root.rowH)))
    }

    readonly property int weekCount: Math.max(1, Math.min(root.days.length, Math.floor((root.innerW - 12) / 40)))

    CustomText {
        id: storyProbe
        visible: false
        width: root.leftW
        content: root.story
        textFormat: Text.StyledText
        size: 14
        weight: 400
        lineHeight: 1.35
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap
        clip: true

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 6

            CustomText {
                Layout.fillWidth: true
                content: ((ServiceWeather.cityName !== "Unknown" ? ServiceWeather.cityName : ServiceWeather.location)
                          + "  ·  " + Qt.formatDate(root.now, "ddd d MMM")).toUpperCase()
                size: 11
                weight: 600
                font.letterSpacing: 1.2
                customColor: Colors.outline
                elide: Text.ElideRight
            }

            CustomText {
                content: root.updatedText
                size: 11
                customColor: ServiceWeather.isLoading ? Colors.primary : Colors.outline
            }

            M3IconButton {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                icon: "refresh"
                iconSize: 16
                iconColor: ServiceWeather.isLoading ? Colors.primary : Colors.surfaceVariantText
                onClicked: ServiceWeather.refresh()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.wide ? 2 : 1
            columnSpacing: 24
            rowSpacing: root.gap

            ColumnLayout {
                Layout.preferredWidth: root.leftW
                Layout.maximumWidth: root.leftW
                Layout.alignment: Qt.AlignTop
                spacing: root.gap

                RowLayout {
                    id: hero
                    Layout.fillWidth: true
                    spacing: 12

                    CustomText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        content: root.headline
                        size: root.wide ? 30 : 26
                        weight: 400
                        family: SettingsConfig.general.displayFont ?? "Titan One"
                        renderType: Text.QtRendering
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        lineHeight: 1.1
                        verticalAlignment: Text.AlignTop
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 4

                        CustomText {
                            Layout.alignment: Qt.AlignRight
                            content: root.cur ? root.curTemp + "°" : "--"
                            size: root.wide ? 64 : 56
                            weight: 400
                            family: SettingsConfig.general.displayFont ?? "Titan One"
                            renderType: Text.QtRendering
                            customColor: Colors.primary
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignRight
                            visible: root.days.length > 0
                            content: "H " + root.todayHi + "°  ·  L " + root.todayLo + "°"
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: root.showStory
                    content: root.story
                    textFormat: Text.StyledText
                    size: 14
                    weight: 400
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    customColor: Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.preferredWidth: root.factsW
                Layout.maximumWidth: root.factsW
                Layout.alignment: Qt.AlignTop
                visible: root.factCount > 0
                spacing: 0

                Repeater {
                    model: root.facts.slice(0, root.factCount)

                    delegate: Item {
                        id: factRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: root.rowH

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Colors.outlineVariant
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.topMargin: 1
                            spacing: 12

                            MaterialIconSymbol {
                                content: factRow.modelData.icon
                                iconSize: 18
                                customColor: Colors.outline
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: factRow.modelData.label
                                size: 13
                                weight: 400
                                customColor: Colors.surfaceVariantText
                            }

                            CustomText {
                                content: factRow.modelData.value
                                size: 13
                                weight: 600
                            }

                            CustomText {
                                visible: root.factsW >= 280
                                Layout.preferredWidth: 78
                                horizontalAlignment: Text.AlignRight
                                content: factRow.modelData.note
                                size: 11
                                weight: 400
                                customColor: Colors.outline
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            id: week
            Layout.fillWidth: true
            visible: root.showWeek
            implicitHeight: weekRow.implicitHeight + 24
            radius: 18
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: weekRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 2

                Repeater {
                    model: root.days.slice(0, root.weekCount)

                    delegate: ColumnLayout {
                        id: dayCol
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: Infinity
                        spacing: 4

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: dayCol.index === 0 ? "Today"
                                   : Qt.formatDate(new Date(dayCol.modelData.date + "T00:00:00"), "ddd")
                            size: 11
                            weight: 600
                            customColor: dayCol.index === 0 ? Colors.primary : Colors.outline
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: root.dayHi(dayCol.modelData) + "°"
                            size: 14
                            weight: 600
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: root.dayLo(dayCol.modelData) + "°"
                            size: 11
                            weight: 400
                            customColor: Colors.outline
                        }
                    }
                }
            }
        }
    }
}
