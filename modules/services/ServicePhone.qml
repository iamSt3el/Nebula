pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string deviceId: ""
    property string name: ""
    property int pairState: 0
    property string verifyKey: ""
    property string ip: ""
    property var others: []
    property bool justPaired: false
    property string storageRoot: ""
    property string storageName: ""
    property string mountError: ""
    property bool mounting: false
    property real pairSince: 0
    property int _lastPair: 0
    property bool reachable: false
    property int battery: -1
    property bool charging: false
    property int notifs: 0
    property bool looking: false
    property string error: ""
    property string downloads: Quickshell.env("HOME") + "/Downloads"
    property var transfers: []

    readonly property bool found: root.deviceId !== ""
    readonly property bool paired: root.pairState === 3
    readonly property bool ready: root.paired && root.reachable
    readonly property string label: root.name || "Phone"

    signal received(string path)

    function refresh() {
        if (!stateProc.running)
            stateProc.running = true
    }

    function lookAgain() {
        root.looking = true
        Quickshell.execDetached(["kdeconnect-cli", "--refresh"])
        lookTimer.restart()
    }

    function run(args) {
        if (root.deviceId === "") return
        Quickshell.execDetached(["kdeconnect-cli", "-d", root.deviceId].concat(args))
    }

    function share(paths) {
        const list = (paths ?? []).filter(p => !!p)
        if (list.length === 0 || root.deviceId === "") return
        root._queue.push({ args: list.reduce((a, p) => a.concat(["--share", p]), []),
                           entries: list.map(p => ({ kind: "out", name: root.baseName(p), path: p })) })
        root._pump()
    }

    function shareText(text) {
        const t = (text ?? "").trim()
        if (t === "" || root.deviceId === "") return
        const isUrl = /^(https?:\/\/|www\.)\S+$/i.test(t)
        root._queue.push({ args: isUrl ? ["--share", t] : ["--share-text", t],
                           entries: [{ kind: isUrl ? "link" : "text", name: t, path: "" }] })
        root._pump()
    }

    function sendClipboard() {
        if (root.deviceId === "") return
        root._queue.push({ args: ["--send-clipboard"], entries: [{ kind: "clip", name: "Clipboard", path: "" }] })
        root._pump()
    }

    function ring() { root.run(["--ring"]) }

    function _device(method) {
        if (root.deviceId === "") return
        pairProc.command = ["busctl", "--user", "call", "org.kde.kdeconnect",
                            "/modules/kdeconnect/devices/" + root.deviceId, "org.kde.kdeconnect.device", method]
        pairProc.running = true
    }

    function requestPair() { root._device("requestPairing") }
    function acceptPair() { root._device("acceptPairing") }
    function cancelPair() { root._device("cancelPairing") }

    function forget(id) {
        pairProc.command = ["busctl", "--user", "call", "org.kde.kdeconnect",
                            "/modules/kdeconnect/devices/" + id, "org.kde.kdeconnect.device", "unpair"]
        pairProc.running = true
    }

    onPairStateChanged: {
        if (root.pairState === 1 || root.pairState === 2)
            root.pairSince = Date.now()
        if (root.pairState === 3 && (root._lastPair === 1 || root._lastPair === 2)) {
            root.justPaired = true
            pairedTimer.restart()
        }
        root._lastPair = root.pairState
    }

    Timer {
        id: pairedTimer
        interval: 4000
        onTriggered: root.justPaired = false
    }

    Process {
        id: pairProc
        onExited: settle.restart()
    }

    function browse() {
        if (root.deviceId === "") return
        Quickshell.execDetached(["bash", "-c",
            "kdeconnect-cli -d \"$1\" --mount >/dev/null 2>&1; sleep 1; p=$(kdeconnect-cli -d \"$1\" --get-mount-point 2>/dev/null); "
            + "[ -n \"$p\" ] && xdg-open \"$p\"", "browse", root.deviceId])
    }

    function mount() {
        if (root.deviceId === "" || mountProc.running) return
        root.mounting = true
        mountProc.running = true
    }

    Process {
        id: mountProc
        command: ["bash", "-c",
            "b=/modules/kdeconnect/devices/$1/sftp; i=org.kde.kdeconnect.device.sftp;"
            + "busctl --user --timeout=25 call org.kde.kdeconnect $b $i mountAndWait >/dev/null 2>&1;"
            + "busctl --user call org.kde.kdeconnect $b $i getDirectories 2>/dev/null | grep -o '\"[^\"]*\"' | head -n2 | tr -d '\"';"
            + "busctl --user call org.kde.kdeconnect $b $i getMountError 2>/dev/null | cut -d' ' -f2- | tr -d '\"'",
            "mount", root.deviceId]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                root.storageRoot = (l[0] ?? "").trim()
                root.storageName = (l[1] ?? "").trim() || "Phone storage"
                root.mountError = (l[2] ?? "").trim()
            }
        }
        onExited: root.mounting = false
    }

    function openKdeConnect() {
        Quickshell.execDetached(["kdeconnect-app"])
    }

    function humanSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        const units = ["B", "KB", "MB", "GB"]
        let v = bytes
        for (let i = 0; i < units.length; i++) {
            if (v < 1024 || i === units.length - 1)
                return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
            v /= 1024
        }
        return ""
    }

    function noteReceived(path) {
        root._push({ kind: "in", name: root.baseName(path), path: path })
    }

    function clearTransfers() {
        root.transfers = []
    }

    function baseName(path) {
        const parts = (path ?? "").split("/")
        return parts[parts.length - 1] || path
    }

    function _push(entry) {
        root.transfers = [Object.assign({ at: Date.now(), ok: true }, entry)].concat(root.transfers).slice(0, 40)
    }

    property var _queue: []
    property var _current: null

    function _pump() {
        if (sendProc.running || root._queue.length === 0)
            return
        root._current = root._queue.shift()
        sendProc.command = ["kdeconnect-cli", "-d", root.deviceId].concat(root._current.args)
        sendProc.running = true
    }

    Process {
        id: sendProc
        stderr: StdioCollector { id: sendErr }
        onExited: code => {
            const job = root._current
            root._current = null
            if (job) {
                for (const e of job.entries)
                    root._push(Object.assign({}, e, { ok: code === 0 }))
                root.error = code === 0 ? "" : (sendErr.text.trim().split("\n").pop() || "Could not reach the phone")
            }
            root._pump()
        }
    }

    function _pick(rows) {
        let best = null
        let score = -1
        for (const f of rows) {
            if (f.type !== "phone" && f.type !== "tablet")
                continue
            const sc = f.reachable && f.pair === 3 ? 4 : f.reachable && f.pair > 0 ? 3 : f.reachable ? 2 : f.pair === 3 ? 1 : 0
            if (sc > score) {
                best = f
                score = sc
            }
        }
        return best
    }

    Process {
        id: stateProc
        command: ["bash", Quickshell.shellDir + "/scripts/kdeconnect_state.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l !== "").map(l => {
                    const f = l.split("\t")
                    return { id: f[0], name: f[1], type: f[2], reachable: f[3] === "true", pair: parseInt(f[4]) || 0,
                             key: f[5] ?? "", battery: parseInt(f[6]), charging: f[7] === "true", notifs: parseInt(f[8]) || 0,
                             ip: f[9] ?? "" }
                })
                const d = root._pick(rows)
                root.deviceId = d ? d.id : ""
                root.name = d ? d.name : ""
                root.reachable = d ? d.reachable : false
                root.pairState = d ? d.pair : 0
                root.verifyKey = d ? d.key : ""
                root.ip = d ? d.ip : ""
                root.others = rows.filter(f => (!d || f.id !== d.id) && f.pair === 3 && !f.reachable
                                               && (f.type === "phone" || f.type === "tablet"))
                root.battery = d && !isNaN(d.battery) ? d.battery : -1
                root.charging = d ? d.charging : false
                root.notifs = d ? d.notifs : 0
                if (root.reachable)
                    root.looking = false
            }
        }
    }

    Process {
        id: dirProc
        running: true
        command: ["xdg-user-dir", "DOWNLOAD"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim()
                if (d !== "") root.downloads = d
            }
        }
    }

    Process {
        id: monitor
        running: true
        command: ["dbus-monitor", "--session", "type='signal',path_namespace='/modules/kdeconnect'"]
        property string pending: ""
        stdout: SplitParser {
            onRead: line => {
                const m = /member=(\w+)/.exec(line)
                if (m) {
                    monitor.pending = m[1]
                    if (m[1] !== "shareReceived" && m[1] !== "textShareReceived")
                        settle.restart()
                    return
                }
                const s = /^\s*string "(.*)"$/.exec(line)
                if (!s || monitor.pending === "")
                    return
                const kind = monitor.pending
                monitor.pending = ""
                if (kind === "shareReceived") {
                    const path = decodeURIComponent(s[1].replace(/^file:\/\//, ""))
                    root._push({ kind: "in", name: root.baseName(path), path: path })
                    root.received(path)
                } else if (kind === "textShareReceived") {
                    root._push({ kind: "textIn", name: s[1], path: "" })
                }
            }
        }
        onExited: restartMonitor.restart()
    }

    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: lookTimer
        interval: 6000
        onTriggered: {
            root.refresh()
            root.looking = false
        }
    }

    Timer {
        interval: root.reachable ? 60000 : 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
