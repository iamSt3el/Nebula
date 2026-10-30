pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property bool enabled: SettingsConfig.general?.screenTimeLog ?? true
    readonly property string dir: Paths.stateDir + "/screentime"
    property string dayKey: root.keyFor(new Date())

    property var closed: []
    property string curApp: ""
    property real curStart: 0
    property real now: Date.now()
    property bool loaded: false

    readonly property string focusedApp: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.appId ?? "") : ""
    readonly property bool away: idle.isIdle || GlobalStates.sessionLocked
    readonly property string liveApp: root.enabled && !root.away ? root.focusedApp : ""

    readonly property var segments: {
        const out = root.closed.slice()
        if (root.curApp !== "" && root.curStart > 0)
            out.push([root.curApp, root.curStart, root.now])
        return out
    }

    function keyFor(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function closeCurrent(at) {
        if (root.curApp !== "" && root.curStart > 0 && at - root.curStart >= 1000) {
            const list = root.closed.slice()
            const last = list.length ? list[list.length - 1] : null
            if (last && last[0] === root.curApp && root.curStart - last[2] < 5000)
                last[2] = at
            else
                list.push([root.curApp, root.curStart, at])
            root.closed = list
        }
        root.curApp = ""
        root.curStart = 0
    }

    function follow() {
        if (!root.loaded)
            return
        const t = Date.now()
        const key = root.keyFor(new Date(t))
        if (key !== root.dayKey) {
            const mid = new Date(new Date(t).setHours(0, 0, 0, 0)).getTime()
            const app = root.curApp
            root.closeCurrent(mid)
            root.save()
            root.closed = []
            root.dayKey = key
            if (app !== "") {
                root.curApp = app
                root.curStart = mid
            }
        }
        if (root.liveApp === root.curApp)
            return
        root.closeCurrent(t)
        if (root.liveApp !== "") {
            root.curApp = root.liveApp
            root.curStart = t
        }
        root.now = t
    }

    function save() {
        if (!root.loaded)
            return
        const segs = root.closed.slice()
        if (root.curApp !== "" && root.curStart > 0)
            segs.push([root.curApp, root.curStart, Date.now()])
        store.setText(JSON.stringify({ day: root.dayKey, segs: segs }))
    }

    onLiveAppChanged: root.follow()

    IdleMonitor {
        id: idle
        enabled: root.enabled
        timeout: 180
        respectInhibitors: true
    }

    Process {
        id: mk
        running: root.enabled
        command: ["mkdir", "-p", root.dir]
    }

    FileView {
        id: store
        path: root.enabled ? root.dir + "/" + root.dayKey + ".json" : ""
        blockLoading: false
        onLoaded: {
            if (root.loaded)
                return
            try {
                const d = JSON.parse(text())
                root.closed = Array.isArray(d.segs) ? d.segs.filter(s => s[2] < Date.now() - 1000) : []
            } catch (e) {
                root.closed = []
            }
            root.loaded = true
            root.follow()
        }
        onLoadFailed: {
            if (root.loaded)
                return
            root.closed = []
            root.loaded = true
            root.follow()
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.enabled
        onTriggered: {
            root.now = Date.now()
            root.follow()
        }
    }

    Timer {
        interval: 120000
        repeat: true
        running: root.enabled && root.loaded
        onTriggered: root.save()
    }

    Component.onDestruction: root.save()
}
