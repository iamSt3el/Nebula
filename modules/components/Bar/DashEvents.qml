import QtQuick
import qs.modules.services

QtObject {
    id: root

    function describe(e) {
        const start = new Date(ServiceEvents.startMs(e))
        const now = ServiceEvents.now
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

    function upcoming(count) {
        ServiceEvents.events
        ServiceClock.holidaysLoaded
        return ServiceEvents.upcoming(count, true).map(e => root.describe(e))
    }
}
