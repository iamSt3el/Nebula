pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"

    readonly property var legacyUrls: {
        const opts = SettingsConfig.dashboard?.options ?? {}
        const seen = []
        for (const k in opts) {
            const raw = opts[k] ? opts[k].calendars : undefined
            if (typeof raw !== "string")
                continue
            for (const u of raw.split(/[\s,]+/))
                if (root.isUrl(u) && seen.indexOf(u) < 0)
                    seen.push(u)
        }
        return seen
    }

    readonly property var feeds: {
        const saved = SettingsConfig.calendars?.feeds
        const out = (saved && typeof saved.length === "number" ? Array.from(saved) : [])
            .filter(f => f && root.isUrl(f.url))
            .map(f => ({ url: f.url, name: f.name ?? "", on: f.on !== false }))
        for (const u of root.legacyUrls)
            if (!out.some(f => f.url === u))
                out.push({ url: u, name: "", on: true })
        return out
    }

    readonly property var urls: root.feeds.filter(f => f.on).map(f => f.url)

    property var info: ({})
    property var events: []
    property bool loading: false
    property bool pending: false
    property int _users: 0
    property var now: new Date()

    function isUrl(u) {
        return typeof u === "string" && /^(https?|webcal):\/\/\S+$/i.test(u)
    }

    function hostOf(url) {
        const m = /^[a-z]+:\/\/([^\/?#]+)/i.exec(url)
        return m ? m[1].replace(/^www\./, "") : url
    }

    function nameOf(feed) {
        if (!feed)
            return ""
        if (feed.name)
            return feed.name
        const n = root.info[feed.url]?.name ?? ""
        return n !== "" ? n : root.hostOf(feed.url)
    }

    function saveFeeds(list) {
        SettingsConfig.calendars = Object.assign({}, SettingsConfig.calendars, {
            feeds: list.map(f => ({ url: f.url, name: f.name ?? "", on: f.on !== false }))
        })
        if (root.legacyUrls.length === 0)
            return
        const opts = Object.assign({}, SettingsConfig.dashboard?.options ?? {})
        for (const k in opts) {
            if (opts[k] && opts[k].calendars !== undefined) {
                const o = Object.assign({}, opts[k])
                delete o.calendars
                opts[k] = o
            }
        }
        SettingsConfig.dashboard = Object.assign({}, SettingsConfig.dashboard, { options: opts })
    }

    function addFeed(raw) {
        const url = (raw ?? "").trim()
        if (!root.isUrl(url))
            return "That isn't a calendar link. It should start with https:// or webcal://"
        if (root.feeds.some(f => f.url === url))
            return "That calendar is already added"
        root.saveFeeds(root.feeds.concat([{ url: url, name: "", on: true }]))
        return ""
    }

    function removeFeed(url) {
        root.saveFeeds(root.feeds.filter(f => f.url !== url))
    }

    function setFeed(url, patch) {
        root.saveFeeds(root.feeds.map(f => f.url === url ? Object.assign({}, f, patch) : f))
    }

    function retain() {
        if (root._users++ === 0)
            root.refresh()
    }

    function release() {
        if (root._users > 0)
            root._users--
    }

    function refresh() {
        if (root.urls.length === 0) {
            root.events = []
            return
        }
        if (proc.running) {
            root.pending = true
            return
        }
        root.loading = true
        proc.command = [root.cli, "events"].concat(root.urls)
        proc.running = true
    }

    onUrlsChanged: if (root._users > 0) root.refresh()

    function startMs(e) {
        return e.allDay ? new Date(e.start + "T00:00:00").getTime() : e.start
    }

    function endMs(e) {
        return e.allDay ? new Date(e.end + "T00:00:00").getTime() : e.end
    }

    function holidayEvents(fromMs, toMs) {
        const out = []
        const list = ServiceClock.holidayData ?? []
        for (const h of list) {
            const t = new Date(h.date + "T00:00:00").getTime()
            if (t + 86400000 > fromMs && t < toMs)
                out.push({ title: h.name, allDay: true, holiday: true, calendar: -1,
                           start: h.date, end: Qt.formatDate(new Date(t + 86400000), "yyyy-MM-dd"), location: "" })
        }
        return out
    }

    function between(fromMs, toMs, holidays) {
        const own = root.events.filter(e => root.endMs(e) > fromMs && root.startMs(e) < toMs)
        const all = holidays ? own.concat(root.holidayEvents(fromMs, toMs)) : own
        return all.sort((a, b) => root.startMs(a) - root.startMs(b))
    }

    function upcoming(count, holidays) {
        const t = root.now.getTime()
        return root.between(t, t + 60 * 86400000, holidays).slice(0, count)
    }

    function today() {
        const d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
        return root.between(d.getTime(), d.getTime() + 86400000, false)
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.events = parsed
                    } else if (parsed && Array.isArray(parsed.events)) {
                        root.events = parsed.events
                        const next = Object.assign({}, root.info)
                        for (const c of parsed.calendars ?? [])
                            next[c.url] = { name: c.name ?? "", status: c.status ?? "", count: c.count ?? 0 }
                        root.info = next
                    }
                } catch (e) {}
            }
        }
        onExited: {
            root.loading = false
            if (root.pending) {
                root.pending = false
                Qt.callLater(root.refresh)
            }
        }
    }

    Timer {
        interval: 15 * 60000
        repeat: true
        running: root._users > 0
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root._users > 0
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
