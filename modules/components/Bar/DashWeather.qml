import QtQuick
import qs.modules.services

QtObject {
    id: root

    readonly property var cur: ServiceWeather.currentCondition
    readonly property bool ok: !!root.cur
    readonly property bool metric: ServiceWeather.useMetric
    readonly property bool night: { ServiceClock.hour; return ServiceWeather.isNightTime() }
    readonly property var days: ServiceWeather.forecastDays ?? []
    readonly property var today: root.days[0] ?? null

    readonly property string temp: root.ok ? ServiceWeather.temperature : "--"
    readonly property string desc: root.ok ? ServiceWeather.description : "No weather"
    readonly property string icon: ServiceWeather.getWeatherIcon(ServiceWeather.weatherCode, root.night).icon
    readonly property string hi: root.today ? (root.metric ? root.today.maxtempC : root.today.maxtempF) + "°" : "--"
    readonly property string lo: root.today ? (root.metric ? root.today.mintempC : root.today.mintempF) + "°" : "--"
    readonly property string sunrise: root.clean(ServiceWeather.astronomy?.sunrise ?? "")
    readonly property string sunset: root.clean(ServiceWeather.astronomy?.sunset ?? "")
    readonly property real sunriseH: root.hourOf(ServiceWeather.astronomy?.sunrise ?? "")
    readonly property real sunsetH: root.hourOf(ServiceWeather.astronomy?.sunset ?? "")

    function clean(s) {
        return String(s).replace(/^0/, "")
    }

    function hourOf(s) {
        const m = String(s).match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!m)
            return -1
        let h = parseInt(m[1]) % 12
        if (m[3].toUpperCase() === "PM")
            h += 12
        return h + parseInt(m[2]) / 60
    }

    function tempOf(h) {
        return (root.metric ? h.tempC : h.tempF) + "°"
    }

    function upcomingHours(count) {
        const now = new Date()
        const at = now.getHours() * 60 + now.getMinutes()
        const out = []
        for (let d = 0; d < root.days.length && out.length < count; d++) {
            for (const h of root.days[d].hourly ?? []) {
                const t = parseInt(h.time) / 100
                if (d === 0 && t * 60 <= at)
                    continue
                out.push({ label: (t < 10 ? "0" : "") + t + ":00", temp: root.tempOf(h),
                           icon: ServiceWeather.getWeatherIcon(h.weatherCode, t < 6 || t >= 18).icon })
                if (out.length >= count)
                    break
            }
        }
        return out
    }

    function dayHours() {
        return (root.today?.hourly ?? []).map(h => ({ hour: parseInt(h.time) / 100, temp: root.tempOf(h) }))
    }

    function week(count) {
        return root.days.slice(0, count).map((d, i) => {
            const dt = new Date(d.date + "T00:00:00")
            const mid = (d.hourly ?? [])[4] ?? (d.hourly ?? [])[0]
            return {
                label: i === 0 ? "Today" : Qt.formatDate(dt, "ddd"),
                hi: parseInt(root.metric ? d.maxtempC : d.maxtempF),
                lo: parseInt(root.metric ? d.mintempC : d.mintempF),
                icon: ServiceWeather.getWeatherIcon(mid?.weatherCode ?? "113", false).icon,
                rain: Math.max(0, ...(d.hourly ?? []).map(h => parseInt(h.chanceofrain) || 0))
            }
        })
    }
}
