pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string path: Paths.configDir + "/scenes.json"
    readonly property var icons: ["work", "school", "nightlight", "sports_esports", "palette", "code", "coffee", "movie"]

    property var scenes: []
    property bool loaded: false
    property bool restoring: false
    property string status: ""
    property var queue: []
    property var pending: []
    property var claimed: []
    property var draft: null

    function addr(a) {
        const s = String(a ?? "")
        return s.startsWith("0x") ? s : "0x" + s
    }

    function windowsNow() {
        return Hyprland.toplevels.values.map(t => ({ t: t, ipc: t.lastIpcObject ?? {} }))
            .filter(w => (w.ipc.workspace?.id ?? 0) > 0 && (w.ipc.class ?? "") !== "")
    }

    function summaryOf(apps) {
        const ws = new Set(apps.map(a => a.ws))
        return apps.length + (apps.length === 1 ? " app" : " apps") + " on " + ws.size + (ws.size === 1 ? " workspace" : " workspaces")
    }

    function captureCurrent(name, icon) {
        Hyprland.refreshToplevels()
        root.draft = { name: name, icon: icon }
        capture.restart()
    }

    function finishCapture(cmdlines) {
        const apps = root.windowsNow().map(w => {
            const cls = w.ipc.class
            const entry = DesktopEntries.heuristicLookup(cls)
            const cmd = entry && entry.command && entry.command.length ? Array.from(entry.command)
                      : (cmdlines[String(w.ipc.pid)] ?? [])
            return {
                cls: cls,
                title: w.t.title ?? "",
                ws: w.ipc.workspace.id,
                cmd: cmd,
                float: !!w.ipc.floating,
                at: w.ipc.at ?? [0, 0],
                size: w.ipc.size ?? [0, 0]
            }
        }).filter(a => a.cmd.length > 0)
        apps.sort((a, b) => a.ws - b.ws)
        const d = root.draft ?? { name: "Scene", icon: "work" }
        const scene = { id: Date.now().toString(36), name: d.name || "Scene " + (root.scenes.length + 1), icon: d.icon || "work", saved: Date.now(), apps: apps }
        root.scenes = root.scenes.filter(s => s.name !== scene.name).concat([scene])
        root.draft = null
        root.status = "Saved " + scene.name + ", " + root.summaryOf(apps)
        save.restart()
    }

    function remove(id) {
        root.scenes = root.scenes.filter(s => s.id !== id)
        save.restart()
    }

    function restore(id) {
        const scene = root.scenes.find(s => s.id === id)
        if (!scene || root.restoring)
            return
        Hyprland.refreshToplevels()
        root.claimed = []
        root.pending = []
        root.queue = scene.apps.slice()
        root.restoring = true
        root.status = "Restoring " + scene.name + "…"
        step.restart()
    }

    function place(address, app) {
        const a = root.addr(address)
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${a}", workspace = ${app.ws}, follow = false })`)
        if (app.float && app.size[0] > 0) {
            Hyprland.dispatch(`hl.dsp.window.float({ window = "address:${a}", action = "set" })`)
            Hyprland.dispatch(`hl.dsp.window.resize({ window = "address:${a}", x = ${app.size[0]}, y = ${app.size[1]}, relative = false })`)
            Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${a}", x = ${app.at[0]}, y = ${app.at[1]}, relative = false })`)
        }
    }

    function next() {
        if (root.queue.length === 0) {
            if (root.pending.length === 0) {
                root.restoring = false
                root.status = "Restored"
            }
            return
        }
        const app = root.queue[0]
        root.queue = root.queue.slice(1)
        const existing = root.windowsNow().find(w => w.ipc.class.toLowerCase() === app.cls.toLowerCase()
                                                  && root.claimed.indexOf(root.addr(w.t.address)) < 0)
        if (existing) {
            root.claimed = root.claimed.concat([root.addr(existing.t.address)])
            root.place(existing.t.address, app)
            root.status = "Moved " + app.cls + " to workspace " + app.ws
        } else {
            root.pending = root.pending.concat([Object.assign({ deadline: Date.now() + 25000 }, app)])
            Quickshell.execDetached(app.cmd)
            root.status = "Opening " + app.cls + " on workspace " + app.ws + "…"
        }
        step.restart()
    }

    Timer {
        id: step
        interval: 380
        onTriggered: root.next()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pending.length > 0
        onTriggered: {
            const now = Date.now()
            root.pending = root.pending.filter(p => p.deadline > now)
            if (root.pending.length === 0 && root.queue.length === 0 && root.restoring) {
                root.restoring = false
                root.status = "Restored"
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "openwindow" || root.pending.length === 0)
                return
            const parts = event.data.split(",")
            const address = parts[0]
            const cls = (parts[2] ?? "").toLowerCase()
            const i = root.pending.findIndex(p => p.cls.toLowerCase() === cls)
            if (i < 0)
                return
            const app = root.pending[i]
            root.pending = root.pending.filter((_, k) => k !== i)
            root.claimed = root.claimed.concat([root.addr(address)])
            root.place(address, app)
            if (root.pending.length === 0 && root.queue.length === 0) {
                root.restoring = false
                root.status = "Restored"
            }
        }
    }

    Timer {
        id: capture
        interval: 300
        onTriggered: {
            const pids = root.windowsNow().map(w => w.ipc.pid).filter(p => p > 0)
            cmdProc.command = ["sh", "-c", "for p in " + pids.join(" ") + "; do printf '%s\\t' \"$p\"; tr '\\0' '\\037' < /proc/$p/cmdline 2>/dev/null; echo; done"]
            cmdProc.running = true
        }
    }

    Process {
        id: cmdProc
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 0)
                        continue
                    const args = line.slice(tab + 1).split("\x1f").filter(s => s.length > 0)
                    if (args.length)
                        map[line.slice(0, tab)] = args
                }
                root.finishCapture(map)
            }
        }
    }

    Timer {
        id: save
        interval: 400
        onTriggered: store.setText(JSON.stringify({ v: 1, scenes: root.scenes }, null, 1))
    }

    FileView {
        id: store
        path: root.path
        blockLoading: false
        onLoaded: {
            if (root.loaded)
                return
            try {
                const d = JSON.parse(text())
                root.scenes = Array.isArray(d.scenes) ? d.scenes : []
            } catch (e) {
                root.scenes = []
            }
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "scenes"
        function restore(name: string): void {
            const s = root.scenes.find(x => x.name.toLowerCase() === name.toLowerCase())
            if (s) root.restore(s.id)
        }
        function save(name: string): void { root.captureCurrent(name, "work") }
    }
}
