pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property bool ready: true
    readonly property bool busy: proc.running || root.settling
    readonly property bool animate: SettingsConfig.general.layoutMotion ?? true
    readonly property bool settling: root.flights > 0 || root._patch !== null || root._widgets !== null || root._early
    readonly property var widgetData: ["countdowns", "stickyNoteText"]

    property bool moving: false
    property int flights: 0
    property int _holds: 0
    property var _patch: null
    property var _widgets: null
    property string _stage: "bar"
    property bool _early: false
    property var _queued: null
    property string _name: ""
    property string _lastName: ""
    property string _lastBar: ""

    signal applying()
    signal capture()
    signal applied()
    signal captureWidgets()
    signal widgetsApplied()

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

    function barSig() {
        return root.canon(JSON.parse(JSON.stringify(SettingsConfig.bar ?? null)))
    }

    function apply(patch) {
        root.applying()
        if (patch.general) {
            const live = SettingsConfig.general ?? {}
            if (Object.keys(patch.general).some(k => !root.same(live[k], patch.general[k])))
                SettingsConfig.general = Object.assign({}, live, patch.general)
        }
        for (const key of ["bar", "dashboard", "lockscreen"])
            if (patch[key] !== undefined && !root.same(SettingsConfig[key], patch[key]))
                SettingsConfig[key] = patch[key]
    }

    function applyWidgets(widgets) {
        const live = SettingsConfig.widgets ?? {}
        const next = Object.assign({}, widgets)
        for (const k of root.widgetData)
            if (live[k] !== undefined)
                next[k] = live[k]
        if (!root.same(live, next))
            SettingsConfig.widgets = next
    }

    function startMoving() {
        root.moving = root.animate
        if (root.moving)
            movingTimer.restart()
    }

    function prestart() {
        widgetWait.stop()
        if (root._widgets)
            root.applyWidgets(root._widgets)
        root._widgets = null
        root._patch = null
        root._stage = "bar"
        root._holds = 0
        root._early = true
        root.startMoving()
        root.capture()
    }

    function begin(patch) {
        const early = root._early
        if (!early) {
            widgetWait.stop()
            if (root._widgets)
                root.applyWidgets(root._widgets)
        }
        root._widgets = patch.widgets ?? null
        root._patch = Object.assign({}, patch)
        delete root._patch.widgets
        root._early = false
        root._stage = "bar"
        root.startMoving()
        if (!early) {
            root._holds = 0
            root.capture()
        }
        if (root._holds === 0)
            root.commit()
        else
            holdCap.restart()
    }

    function beginWidgets() {
        widgetWait.stop()
        if (!root._widgets)
            return
        root._stage = "widgets"
        root._holds = 0
        root.captureWidgets()
        if (root._holds === 0)
            root.commitWidgets()
        else
            holdCap.restart()
    }

    function commitWidgets() {
        const widgets = root._widgets
        if (!widgets)
            return
        holdCap.stop()
        try {
            root.applyWidgets(widgets)
        } catch (e) {
            console.warn("[ServiceLayouts] widgets apply failed:", e)
        }
        root._widgets = null
        root.startMoving()
        root.widgetsApplied()
    }

    function afterBar() {
        widgetWait.stop()
        if (root._widgets)
            root.beginWidgets()
    }

    function next() {
        if (root._stage === "widgets")
            root.commitWidgets()
        else
            root.commit()
    }

    onFlightsChanged: if (root.flights === 0 && widgetWait.running) Qt.callLater(root.afterBar)
    onSettlingChanged: if (!root.settling) Qt.callLater(root.pump)

    function hold() {
        root._holds++
    }

    function release() {
        root._holds = Math.max(0, root._holds - 1)
        if (root._holds === 0 && !root._early)
            Qt.callLater(root.next)
    }

    function commit() {
        const patch = root._patch
        if (!patch)
            return
        holdCap.stop()
        try {
            root.apply(patch)
        } catch (e) {
            console.warn("[ServiceLayouts] apply failed:", e)
        }
        root._lastName = root._name
        root._lastBar = root.barSig()
        root._patch = null
        root.applied()
        if (root._widgets) {
            widgetWait.restart()
            if (root.flights === 0)
                Qt.callLater(root.afterBar)
        }
    }

    function run(args, cb) {
        if (proc.running || root.settling) {
            const old = root._queued
            root._queued = { args: args, cb: cb ?? null }
            if (old && old.cb)
                old.cb(1, "", "[nebula] Skipped: another layout was picked")
            return true
        }
        root._cb = cb ?? null
        root._last = ""
        root._name = args[0] === "load" ? (args[1] ?? "") : ""
        proc.command = [Quickshell.shellDir + "/bin/nebula", "layout"].concat(args).concat(["--emit"])
        proc.running = true
        const unchanged = root._name !== "" && root._name === root._lastName && root._lastBar === root.barSig()
        if (root.animate && !unchanged)
            root.prestart()
        return true
    }

    function pump() {
        if (!root._queued || proc.running || root.settling)
            return
        const q = root._queued
        root._queued = null
        root.run(q.args, q.cb)
    }

    function cycle(dir) {
        if (listProc.running)
            return
        listProc.dir = dir
        listProc.running = true
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
                    root.begin(JSON.parse(line).apply ?? {})
                } catch (e) {
                    console.warn("[ServiceLayouts] apply failed:", e)
                }
            }
        }
        stderr: StdioCollector { id: errOut }
        onExited: code => {
            if (root._early) {
                root._early = false
                root.applied()
            }
            const cb = root._cb
            root._cb = null
            if (cb)
                cb(code, root._last, errOut.text)
            Qt.callLater(root.pump)
        }
    }

    Process {
        id: listProc
        property int dir: 1
        command: [Quickshell.shellDir + "/bin/nebula", "layout", "list", "--json"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    const rows = (JSON.parse(listOut.text).layouts ?? []).slice()
                        .sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""))
                    if (!rows.length)
                        return
                    const at = rows.findIndex(r => r.current)
                    const from = at < 0 ? (listProc.dir > 0 ? -1 : 0) : at
                    root.run(["load", rows[(from + listProc.dir + rows.length) % rows.length].id])
                } catch (e) {
                    console.warn("[ServiceLayouts] cycle failed:", e)
                }
            }
        }
    }

    Timer {
        id: holdCap
        interval: 250
        onTriggered: root.next()
    }

    Timer {
        id: widgetWait
        interval: 2500
        onTriggered: root.afterBar()
    }

    Timer {
        id: movingTimer
        interval: 1800
        onTriggered: root.moving = false
    }

    GlobalShortcut {
        name: "layoutNext"
        onPressed: root.cycle(1)
    }

    GlobalShortcut {
        name: "layoutPrevious"
        onPressed: root.cycle(-1)
    }

    IpcHandler {
        target: "layout"
        function load(name: string): string {
            const queued = root.busy
            root.run(["load", name])
            return queued ? "queued" : "ok"
        }
        function undo(): string {
            const queued = root.busy
            root.run(["undo"])
            return queued ? "queued" : "ok"
        }
        function next(): string {
            root.cycle(1)
            return "ok"
        }
        function previous(): string {
            root.cycle(-1)
            return "ok"
        }
    }
}
