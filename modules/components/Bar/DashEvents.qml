import QtQuick
import qs.modules.services
import qs.modules.settings

QtObject {
    id: root

    function startMs(e) {
        return e.allDay ? new Date(e.start + "T00:00:00").getTime() : e.start
    }

    function describe(e) {
        const start = new Date(root.startMs(e))
        const now = new Date()
        const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        const dayS = new Date(start.getFullYear(), start.getMonth(), start.getDate()).getTime()
        const n = Math.round((dayS - day0) / 86400000)
        const rel = n <= 0 ? "Today" : n === 1 ? "Tomorrow" : "in " + n + " days"
        const time = e.allDay ? "" : Qt.formatTime(start, "h:mm AP")
        return {
            title: e.title,
            holiday: !!e.holiday,
            today: n <= 0,
            day: String(start.getDate()),
            mon: Qt.formatDate(start, "MMM"),
            when: n <= 1 ? rel + (time ? ", " + time : "") : Qt.formatDate(start, "dddd d MMMM") + ", " + rel
        }
    }

    function holidaysOnly(count) {
        const now = new Date()
        const t = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        return (ServiceClock.holidayData ?? [])
            .filter(h => {
                const d = new Date(h.date + "T00:00:00").getTime()
                return d >= t && d < t + 60 * 86400000
            })
            .sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : 0)
            .slice(0, count)
            .map(h => root.describe({ title: h.name, allDay: true, holiday: true, start: h.date }))
    }

    function upcoming(count) {
        ServiceClock.holidaysLoaded
        ServiceClock.hour
        if (!Features.events)
            return root.holidaysOnly(count)
        ServiceEvents.events
        return ServiceEvents.upcoming(count, true).map(e => root.describe(e))
    }
}
