import QtQuick
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root

    property bool preview: false

    visible: false

    readonly property bool metric: SettingsConfig.weather.useMetric ?? true
    readonly property var cur: ServiceWeather.currentCondition
    readonly property var today: (ServiceWeather.forecastDays ?? [])[0] ?? null
    readonly property bool ready: root.preview || !!root.cur

    property int minute: root.clockMinute()

    function clockMinute() {
        const d = new Date()
        return d.getHours() * 60 + d.getMinutes()
    }

    Timer {
        interval: 60000
        running: !root.preview
        repeat: true
        onTriggered: root.minute = root.clockMinute()
    }

    function num(v) {
        const n = parseInt(String(v ?? "").replace(/[^-\d]/g, ""), 10)
        return isNaN(n) ? 0 : n
    }

    function minutesOf(str) {
        const m = String(str ?? "").match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (m[3].toUpperCase() === "PM") h += 12
        return h * 60 + parseInt(m[2])
    }

    function hourOf(label) {
        const m = String(label).match(/(\d{1,2})\s*(AM|PM)/i)
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (m[2].toUpperCase() === "PM") h += 12
        return h
    }

    function short(h) {
        return h === 0 ? "12a" : h < 12 ? h + "a" : h === 12 ? "12p" : (h - 12) + "p"
    }

    function clock(min) {
        if (min < 0) return "--"
        const h = Math.floor(min / 60), m = min % 60
        return ((h + 11) % 12 + 1) + ":" + String(m).padStart(2, "0")
    }

    readonly property int riseMin: root.preview ? 406 : root.minutesOf(ServiceWeather.astronomy?.sunrise)
    readonly property int setMin: root.preview ? 1055 : root.minutesOf(ServiceWeather.astronomy?.sunset)
    readonly property int nowMin: root.preview ? 860 : root.minute

    function nightAtMinute(m) {
        if (root.riseMin < 0 || root.setMin < 0) return m < 360 || m >= 1080
        return m < root.riseMin || m >= root.setMin
    }

    readonly property bool night: root.nightAtMinute(root.nowMin)

    function iconFor(code, night) {
        return ServiceWeather.getWeatherIcon(String(code), night).icon
    }

    function shapeFor(icon, night) {
        const s = String(icon)
        if (s.indexOf("thunder") >= 0) return MaterialShapeFn.getSoftBoom()
        if (s.indexOf("snow") >= 0) return MaterialShapeFn.getClover8Leaf()
        if (s.indexOf("rain") >= 0 || s.indexOf("grain") >= 0) return MaterialShapeFn.getBun()
        if (s.indexOf("cloud") >= 0 || s.indexOf("fog") >= 0) return MaterialShapeFn.getPuffy()
        return night ? MaterialShapeFn.getCookie9Sided() : MaterialShapeFn.getCookie12Sided()
    }

    readonly property int now: root.preview ? 27 : root.num(root.metric ? root.cur?.temp_C : root.cur?.temp_F)
    readonly property int feels: root.preview ? 26 : root.num(root.metric ? root.cur?.FeelsLikeC : root.cur?.FeelsLikeF)
    readonly property int humidity: root.preview ? 32 : root.num(root.cur?.humidity)
    readonly property int wind: root.preview ? 9 : root.num(root.metric ? root.cur?.windspeedKmph : root.cur?.windspeedMiles)
    readonly property string windUnit: root.metric ? "km/h" : "mph"
    readonly property real windDeg: root.preview ? 315 : (parseFloat(root.cur?.winddirDegree ?? 0) || 0)
    readonly property string windFrom: root.preview ? "NW" : (root.cur?.winddir16Point ?? "")
    readonly property int uv: root.preview ? 5 : root.num(root.cur?.uvIndex)
    readonly property string desc: {
        if (root.preview) return "Sunny"
        const d = String(root.cur?.weatherDesc?.[0]?.value ?? "").trim()
        return root.night && /^sunny$/i.test(d) ? "Clear" : d
    }
    readonly property string icon: root.preview ? "clear_day" : root.iconFor(root.cur?.weatherCode ?? "113", root.night)
    readonly property string shape: root.shapeFor(root.icon, root.night)
    readonly property int hi: root.preview ? 30 : root.num(root.metric ? root.today?.maxtempC : root.today?.maxtempF)
    readonly property int lo: root.preview ? 14 : root.num(root.metric ? root.today?.mintempC : root.today?.mintempF)

    readonly property string uvLabel: root.uv >= 11 ? "Extreme" : root.uv >= 8 ? "Very high" : root.uv >= 6 ? "High" : root.uv >= 3 ? "Moderate" : "Low"

    readonly property var hours: {
        if (root.preview) {
            const t = [27, 28, 28, 27, 25, 22, 20, 19]
            const ic = ["clear_day", "clear_day", "clear_day", "partly_cloudy_day", "partly_cloudy_day", "clear_night", "clear_night", "clear_night"]
            const r = [0, 0, 0, 5, 5, 0, 0, 0]
            return t.map((v, i) => ({ hour: (14 + i) % 24, temp: v, icon: ic[i], rain: r[i], now: i === 0,
                                      h24: String((14 + i) % 24).padStart(2, "0") + "h", h12: root.short((14 + i) % 24) }))
        }
        const list = ServiceWeather.todayHourly ?? []
        return list.map((h, i) => {
            const hour = i === 0 ? Math.floor(root.nowMin / 60) : root.hourOf(h.time)
            const rain = root.num(h.chanceofrain)
            return {
                hour: hour,
                temp: root.num(root.metric ? h.tempC : h.tempF),
                icon: root.iconFor(h.weatherCode, root.nightAtMinute(hour * 60 + (i === 0 ? root.nowMin % 60 : 0))),
                rain: rain,
                now: i === 0,
                h24: String(hour).padStart(2, "0") + "h",
                h12: root.short(hour)
            }
        })
    }

    readonly property var days: {
        if (root.preview) return [
            { label: "Today", icon: "clear_day", hi: 30, lo: 14 },
            { label: "Wed", icon: "partly_cloudy_day", hi: 29, lo: 15 },
            { label: "Thu", icon: "cloud", hi: 26, lo: 13 },
            { label: "Fri", icon: "rainy", hi: 23, lo: 12 },
            { label: "Sat", icon: "partly_cloudy_day", hi: 25, lo: 12 },
            { label: "Sun", icon: "clear_day", hi: 28, lo: 13 },
            { label: "Mon", icon: "clear_day", hi: 29, lo: 14 }
        ]
        const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (ServiceWeather.forecastDays ?? []).map((d, i) => {
            const mid = (d.hourly ?? [])[4] ?? (d.hourly ?? [])[0] ?? {}
            const date = new Date(String(d.date) + "T12:00:00")
            return {
                label: i === 0 ? "Today" : (isNaN(date.getTime()) ? "" : names[date.getDay()]),
                icon: root.iconFor(mid.weatherCode ?? "113", false),
                hi: root.num(root.metric ? d.maxtempC : d.maxtempF),
                lo: root.num(root.metric ? d.mintempC : d.mintempF)
            }
        })
    }

    readonly property int rainPeak: Math.max(0, ...root.hours.slice(0, 6).map(h => h.rain))
}
