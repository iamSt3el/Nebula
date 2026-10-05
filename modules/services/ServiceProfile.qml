pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string name: SettingsConfig.profileName
    readonly property string user: Quickshell.env("USER") ?? "user"
    readonly property string avatar: SettingsConfig.general?.profile ?? ""
    readonly property string shell: (Quickshell.env("SHELL") ?? "sh").split("/").pop()
    readonly property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP") ?? "Hyprland"

    property string host: ""
    property string kernel: ""
    property string os: "Linux"
    property int packages: 0
    property var since: null
    property real bootAt: 0
    property real now: Date.now()

    readonly property string osShort: root.os.split(" ")[0]
    readonly property string sinceText: root.since ? Qt.formatDate(root.since, "MMM yyyy") : "—"
    readonly property string bootText: root.bootAt > 0 ? Qt.formatTime(new Date(root.bootAt), "h:mm AP") : "—"
    readonly property string uptimeText: root.bootAt > 0 ? root.span(root.now - root.bootAt) : "—"

    readonly property real midnight: {
        const d = new Date(root.now)
        d.setHours(0, 0, 0, 0)
        return d.getTime()
    }
    readonly property real dayFrac: Math.max(0, Math.min(1, (root.now - root.midnight) / 86400000))

    readonly property string greeting: {
        const h = new Date(root.now).getHours()
        if (h < 5) return "Still up,"
        if (h < 12) return "Good morning,"
        if (h < 17) return "Good afternoon,"
        if (h < 21) return "Good evening,"
        return "Good night,"
    }

    readonly property var segments: (ServiceScreenTime.segments ?? []).filter(s => s[2] > root.midnight)

    readonly property var appTotals: {
        const t = {}
        for (const s of root.segments) {
            const ms = s[2] - Math.max(s[1], root.midnight)
            t[s[0]] = (t[s[0]] ?? 0) + ms
        }
        return Object.keys(t).map(k => ({ id: k, ms: t[k] })).sort((a, b) => b.ms - a.ms)
    }

    readonly property real screenMs: root.appTotals.reduce((n, a) => n + a.ms, 0)
    readonly property var topApp: root.appTotals.length > 0 ? root.appTotals[0] : null

    readonly property var timeline: {
        const out = []
        const sorted = root.segments.slice().sort((a, b) => a[1] - b[1])
        for (const s of sorted) {
            const a = Math.max(s[1], root.midnight)
            const last = out.length ? out[out.length - 1] : null
            if (last && a - last.b < 600000)
                last.b = Math.max(last.b, s[2])
            else
                out.push({ a: a, b: s[2] })
        }
        return out.map(o => ({ x: (o.a - root.midnight) / 86400000, w: Math.max(0.004, (o.b - o.a) / 86400000) }))
    }

    readonly property string liveApp: ServiceScreenTime.liveApp ?? ""
    readonly property real liveAppMs: {
        const hit = root.appTotals.find(a => a.id === root.liveApp)
        return hit ? hit.ms : 0
    }

    readonly property int commitsToday: (ServicePersonal.git.days ?? {})[ServicePersonal.todayKey(0)] ?? 0
    readonly property int commitsWeek: {
        const days = ServicePersonal.git.days ?? {}
        let n = 0
        for (let i = 0; i < 7; i++)
            n += days[ServicePersonal.todayKey(-i)] ?? 0
        return n
    }

    function appName(id) {
        if (!id) return ""
        return DesktopEntries.heuristicLookup(id)?.name ?? id
    }

    function span(ms) {
        const m = Math.max(0, Math.floor(ms / 60000))
        if (m < 60) return m + " min"
        const h = Math.floor(m / 60)
        if (h < 24) return h + " h " + (m % 60) + " m"
        return Math.floor(h / 24) + " d " + (h % 24) + " h"
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: info.running = true
    }

    Process {
        id: info
        running: true
        command: ["bash", "-c",
            "cat /etc/hostname 2>/dev/null || echo; uname -r; pacman -Qq 2>/dev/null | wc -l; "
            + "head -c 40 /var/log/pacman.log 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true; echo; "
            + "(. /etc/os-release 2>/dev/null && echo \"$NAME\") || echo Linux; cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                root.host = (l[0] ?? "").trim()
                root.kernel = (l[1] ?? "").trim()
                root.packages = parseInt(l[2]) || 0
                const d = (l[3] ?? "").trim()
                root.since = d !== "" ? new Date(d + "T00:00:00") : null
                const rest = l.slice(4).map(s => s.trim()).filter(s => s !== "")
                root.os = rest[0] ?? "Linux"
                const up = parseFloat(rest[1])
                if (!isNaN(up))
                    root.bootAt = Date.now() - up * 1000
            }
        }
    }
}
