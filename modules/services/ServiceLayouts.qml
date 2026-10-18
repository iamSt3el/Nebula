pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property bool ready: true
    readonly property bool busy: proc.running
    readonly property bool quiet: proc.running || quietTimer.running
    readonly property var widgetData: ["habits", "countdowns", "moods", "stickyNoteText", "notebookVault"]

    signal applying()

    property var _cb: null
    property string _last: ""

    function canon(v) {
        if (Array.isArray(v))
            return "[" + v.map(x => root.canon(x)).join(",") + "]"
        if (v !== null && typeof v === "object")
            return "{" + Object.keys(v).filter(k => v[k] !== undefined).sort()
                .map(k => JSON.stringify(k) + ":" + root.canon(v[k])).join(",") + "}"
        return JSON.stringify(v ?? null)
    }

    function same(live, next) {
        return root.canon(JSON.parse(JSON.stringify(live ?? null))) === root.canon(next)
    }

    function apply(patch) {
        root.applying()
        if (patch.general) {
            const live = SettingsConfig.general ?? {}
            if (Object.keys(patch.general).some(k => !root.same(live[k], patch.general[k])))
                SettingsConfig.general = Object.assign({}, live, patch.general)
        }
        if (patch.widgets) {
            const live = SettingsConfig.widgets ?? {}
            const next = Object.assign({}, patch.widgets)
            for (const k of root.widgetData)
                if (live[k] !== undefined)
                    next[k] = live[k]
            if (!root.same(live, next))
                SettingsConfig.widgets = next
        }
        for (const key of ["bar", "dashboard", "lockscreen"])
            if (patch[key] !== undefined && !root.same(SettingsConfig[key], patch[key]))
                SettingsConfig[key] = patch[key]
    }

    function run(args, cb) {
        if (proc.running)
            return false
        root._cb = cb ?? null
        root._last = ""
        proc.command = [Quickshell.shellDir + "/bin/nebula", "layout"].concat(args).concat(["--emit"])
        proc.running = true
        return true
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("{\"apply\"")) {
                    if (line.trim() !== "")
                        root._last = line
                    return
                }
                try {
                    root.apply(JSON.parse(line).apply ?? {})
                } catch (e) {
                    console.warn("[ServiceLayouts] apply failed:", e)
                }
            }
        }
        stderr: StdioCollector { id: errOut }
        onExited: code => {
            quietTimer.restart()
            const cb = root._cb
            root._cb = null
            if (cb)
                cb(code, root._last, errOut.text)
        }
    }

    Timer {
        id: quietTimer
        interval: 2000
    }

    IpcHandler {
        target: "layout"
        function load(name: string): string { return root.run(["load", name]) ? "ok" : "busy" }
        function undo(): string { return root.run(["undo"]) ? "ok" : "busy" }
    }
}
