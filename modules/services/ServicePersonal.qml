pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    property var stats: ({})
    readonly property bool loaded: root.stats.generated !== undefined
    readonly property var git: root.stats.git ?? ({ days: {}, repos: [], total: 0 })
    readonly property var shell: root.stats.shell ?? ({ total: 0, top: [], timed: false })
    readonly property var vaults: root.stats.vaults ?? []
    readonly property var photos: root.stats.photos ?? ({ total: 0, pick: null, since: 0 })

    readonly property var _w: SettingsConfig.widgets ?? ({})

    function todayKey(offset) {
        const d = new Date()
        d.setDate(d.getDate() + (offset ?? 0))
        return Qt.formatDate(d, "yyyy-MM-dd")
    }

    function _save(patch) {
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function refresh() {
        if (!statsProc.running) statsProc.running = true
    }

    Process {
        id: statsProc
        command: [Quickshell.shellDir + "/bin/nebula", "stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.stats = JSON.parse(text) } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    readonly property var activeVault: {
        const want = root._w.notebookVault ?? ""
        return root.vaults.find(v => v.name === want) ?? root.vaults[0] ?? null
    }

    function dailyNotePath() {
        const v = root.activeVault
        if (!v) return ""
        const folder = (v.dailyFolder ?? "").replace(/^\/+|\/+$/g, "")
        return v.path + (folder !== "" ? "/" + folder : "") + "/" + root.todayKey(0) + ".md"
    }

    function jot(text) {
        const t = (text ?? "").trim()
        const path = root.dailyNotePath()
        if (t === "" || path === "") return false
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf -- '- %s %s\\n' \"$2\" \"$3\" >> \"$1\"",
            "jot", path, Qt.formatTime(new Date(), "HH:mm"), t])
        return true
    }

    function openNote(path) {
        Quickshell.execDetached(["xdg-open", "obsidian://open?path=" + encodeURIComponent(path)])
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    readonly property var habits: root._w.habits ?? []

    function addHabit(name) {
        const n = (name ?? "").trim()
        if (n === "") return
        root._save({ habits: root.habits.concat([{ name: n, done: {} }]) })
    }

    function removeHabit(i) {
        root._save({ habits: root.habits.filter((_, k) => k !== i) })
    }

    function toggleHabit(i, day) {
        const list = root.habits.map(h => ({ name: h.name, done: Object.assign({}, h.done ?? {}) }))
        if (!list[i]) return
        if (list[i].done[day]) delete list[i].done[day]
        else list[i].done[day] = true
        root._save({ habits: list })
    }

    readonly property var countdowns: root._w.countdowns ?? []

    function parseDate(s) {
        const t = (s ?? "").trim()
        let m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
        if (m) return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
        const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        m = t.toLowerCase().match(/^(\d{1,2})\s*([a-z]{3})[a-z]*\s*(\d{4})?$/) || null
        let day, mon, year
        if (m) {
            day = parseInt(m[1]); mon = months.indexOf(m[2]); year = m[3] ? parseInt(m[3]) : -1
        } else {
            m = t.toLowerCase().match(/^([a-z]{3})[a-z]*\s*(\d{1,2})(?:,?\s*(\d{4}))?$/)
            if (!m) return null
            mon = months.indexOf(m[1]); day = parseInt(m[2]); year = m[3] ? parseInt(m[3]) : -1
        }
        if (mon < 0 || day < 1 || day > 31) return null
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        let d = new Date(year > 0 ? year : now.getFullYear(), mon, day)
        if (year < 0 && d < today) d = new Date(now.getFullYear() + 1, mon, day)
        return d
    }

    function addCountdown(name, dateText) {
        const d = root.parseDate(dateText)
        const n = (name ?? "").trim()
        if (!d || n === "") return false
        root._save({ countdowns: root.countdowns.concat([{ name: n, date: Qt.formatDate(d, "yyyy-MM-dd"), yearly: !/\d{4}/.test(dateText) }]) })
        return true
    }

    function removeCountdown(i) {
        root._save({ countdowns: root.countdowns.filter((_, k) => k !== i) })
    }

    function daysUntil(iso, yearly) {
        const p = String(iso).split("-")
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        let d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        if (yearly) {
            d = new Date(now.getFullYear(), d.getMonth(), d.getDate())
            if (d < today) d = new Date(now.getFullYear() + 1, d.getMonth(), d.getDate())
        }
        return Math.round((d - today) / 86400000)
    }

    readonly property var moods: root._w.moods ?? ({})

    function setMood(v) {
        const next = Object.assign({}, root.moods)
        const k = root.todayKey(0)
        if (next[k] === v) delete next[k]
        else next[k] = v
        const keys = Object.keys(next).sort()
        while (keys.length > 400) delete next[keys.shift()]
        root._save({ moods: next })
    }
}
