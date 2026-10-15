pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

// Claude Code usage, totalled from the transcripts in ~/.claude/projects.
//
// Nothing polls until a widget calls retain() — the scan is a subprocess, and an
// unused desktop widget should cost nothing. The scanner itself is incremental
// (transcripts are append-only), so a refresh is ~70ms after the first run.
Singleton {
    id: root

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"

    // Refresh interval. Usage moves in minutes, not seconds.
    readonly property int intervalMs: 120000

    property var today: ({ tokens: 0, output: 0, messages: 0, sessions: 0, models: [] })
    property var series: []
    property var block: ({ active: false, tokens: 0, messages: 0, secondsLeft: 0, peak: 0 })
    property var week: ({ tokens: 0, peak: 0, days: 0 })

    // The real utilisation, straight from the endpoint /usage reads. Empty
    // until the first fetch lands, or if the token has expired.
    property var limits: []
    property bool limitsStale: false
    property int limitsFetchedAt: 0

    // Claude Code owns the OAuth token and refreshes it on an ~8h cycle when it
    // runs. The widget can read the usage endpoint with no session open, but
    // once that token lapses the numbers freeze until Claude Code runs again —
    // so how old they are has to be visible.
    property int limitsCheckedAt: 0
    readonly property int limitsAgeSec: root.limitsFetchedAt > 0
        ? Math.max(0, root.limitsCheckedAt - root.limitsFetchedAt)
        : 0

    function limitFor(group) {
        for (let i = 0; i < root.limits.length; i++)
            if (root.limits[i].group === group)
                return root.limits[i]
        return null
    }
    property int peak: 0
    property bool live: false
    property string project: ""
    property string lastPrompt: ""
    property int lastAgeSec: 0
    property bool ready: false
    property bool failed: false

    property int _refCount: 0

    function retain() {
        _refCount++
        if (_refCount === 1) root.refresh()
    }

    function release() {
        if (_refCount > 0) _refCount--
    }

    function refresh() {
        if (!scan.running) scan.running = true
        if (!limitScan.running) limitScan.running = true
    }

    function formatTokens(n) {
        if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
        if (n >= 1000000)    return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000)       return Math.round(n / 1000) + "K"
        return String(n ?? 0)
    }

    // "6d 23h" / "3h 26m" / "48m". The weekly window is a week away, so hours
    // alone would read as "167h".
    function formatSpan(seconds) {
        const s = Math.max(0, Math.round(seconds))
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // "claude-opus-5" and "claude-sonnet-4-5-20250929" both want to read as one
    // short word on a 320px tile.
    function toneOf(limit) {
        return limit ? (limit.severity ?? "normal") : "normal"
    }

    function colorOf(limit, fallback) {
        const sev = root.toneOf(limit)
        if (sev === "normal") return fallback
        if (sev === "warning") return Qt.hsla(0.09, 0.85, 0.55, 1)
        return Qt.hsla(0.01, 0.78, 0.56, 1)
    }

    function modelLabel(name) {
        const m = String(name ?? "").match(/(opus|sonnet|haiku|fable)-(\d{1,2})(?:-(\d))?(?:-|$)/i)
        if (!m) return ""
        return m[1].charAt(0).toUpperCase() + m[1].slice(1).toLowerCase() + " " + m[2] + (m[3] ? "." + m[3] : "")
    }

    function shortModel(name) {
        const m = String(name ?? "").match(/(opus|sonnet|haiku|fable)/i)
        return m ? m[1].toLowerCase() : "other"
    }

    Timer {
        interval: root.intervalMs
        running: root._refCount > 0
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: limitScan
        command: [root.cli, "claude-limits"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const data = JSON.parse(text)
                    root.limits = data.limits ?? []
                    root.limitsStale = data.stale ?? false
                    root.limitsFetchedAt = data.fetchedAt ?? 0
                    root.limitsCheckedAt = Math.floor(Date.now() / 1000)
                } catch (e) {
                    console.warn("[ServiceClaudeCode] bad limits output:", e)
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "") console.warn("[ServiceClaudeCode/limits]", t)
            }
        }
    }

    Process {
        id: scan
        command: [root.cli, "claude-usage"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    root.failed = true
                    return
                }
                try {
                    const data = JSON.parse(text)
                    if (data.error) {
                        root.failed = true
                        return
                    }
                    root.today      = data.today ?? root.today
                    root.series     = data.series ?? []
                    root.block      = data.block ?? root.block
                    root.week       = data.week ?? root.week
                    root.peak       = data.peak ?? 0
                    root.live       = data.live ?? false
                    root.project    = data.project ?? ""
                    root.lastPrompt = data.lastPrompt ?? ""
                    root.lastAgeSec = data.lastAgeSec ?? 0
                    root.ready      = true
                    root.failed     = false
                } catch (e) {
                    console.warn("[ServiceClaudeCode] bad output:", e)
                    root.failed = true
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "") console.warn("[ServiceClaudeCode]", t)
            }
        }
    }
}
