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
    property int bars: -1
    property string netType: ""
    property var notifications: []
    property var peek: null
    property var unreadIds: ({})
    readonly property int unread: root.notifications.filter(n => root.unreadIds[n.id] === true).length
    property real muteUntil: 0
    property var _firstSeen: ({})
    property bool _notifsLoaded: false
    property var _chargeMark: null
    property int minutesToFull: -1
    property bool looking: false
    property string error: ""
    property string downloads: Quickshell.env("HOME") + "/Downloads"
    property var transfers: []

    readonly property bool found: root.deviceId !== ""
    readonly property bool paired: root.pairState === 3
    readonly property bool ready: root.paired && root.reachable
    readonly property string label: root.name || "Phone"
    property bool muted: false
    readonly property bool low: root.battery >= 0 && root.battery < 15 && !root.charging
    readonly property string signalText: root.bars < 0 ? ""
        : (root.netType !== "" ? root.netType + ", " : "") + root.bars + " of 4 bars"

    signal received(string path)

    function refresh() {
        if (!stateProc.running)
            stateProc.running = true
        root.refreshNotifications()
    }

    function refreshNotifications() {
        if (!root.ready) {
            root.notifications = []
            return
        }
        if (notifProc.running) {
            notifProc.again = true
            return
        }
        notifProc.command = ["bash", Quickshell.shellDir + "/scripts/kdeconnect_notifs.sh", root.deviceId]
        notifProc.running = true
    }

    function _notif(id, method, args) {
        if (root.deviceId === "") return
        Quickshell.execDetached(["busctl", "--user", "call", "org.kde.kdeconnect",
                                 "/modules/kdeconnect/devices/" + root.deviceId + "/notifications/" + id,
                                 "org.kde.kdeconnect.device.notifications.notification", method].concat(args ?? []))
    }

    function dismiss(id) {
        root._notif(id, "dismiss")
        root.notifications = root.notifications.filter(n => n.id !== id)
        if (root.peek && root.peek.id === id)
            root.peek = null
        settle.restart()
    }

    function dismissAll() {
        for (const n of root.notifications)
            if (n.dismissable)
                root._notif(n.id, "dismiss")
        root.notifications = root.notifications.filter(n => !n.dismissable)
        root.peek = null
        settle.restart()
    }

    property var call: null
    property var missedCalls: []
    property bool ringerMuted: false
    property var _callNotif: null
    property real _callSignalAt: 0
    property real _mutedAt: 0
    property var _kdcItem: null
    property real _kdcAt: 0

    function _callSignal(type, number, contact) {
        root._callSignalAt = Date.now()
        if (type === "callReceived") {
            if (!root.call || root.call.number !== number) {
                root.call = { name: contact || number, number: number, since: Date.now(), photo: "" }
                root.ringerMuted = false
            }
            ringFallback.restart()
        } else if (type === "missedCall") {
            root._endCall()
            root.missedCalls = [{ name: contact || number, number: number, at: Date.now() }]
                .concat(root.missedCalls).slice(0, 20)
        }
        if (root._kdcItem && Date.now() - root._kdcAt < 3000)
            root._linkCallItem(root._kdcItem)
    }

    function _callNotification(item) {
        const n = item.notification
        if (!/kde ?connect/i.test((n.appName ?? "") + " " + (n.desktopEntry ?? "")))
            return
        root._kdcItem = item
        root._kdcAt = Date.now()
        if (Date.now() - root._callSignalAt < 3000)
            root._linkCallItem(item)
    }

    function _linkCallItem(item) {
        root._kdcItem = null
        item.popup = false
        const n = item.notification
        if (root.call && n.actions.length > 0) {
            root._callNotif = n
            if (item.image)
                root.call = Object.assign({}, root.call, { photo: item.image })
        }
    }

    function _ringClosed() {
        root._callNotif = null
        if (root.ringerMuted && Date.now() - root._mutedAt < 1500)
            return
        root._endCall()
    }

    function _endCall() {
        root.call = null
        root.ringerMuted = false
        root._callNotif = null
        ringFallback.stop()
    }

    function silenceRinger() {
        const n = root._callNotif
        if (!n || root.ringerMuted)
            return
        root.ringerMuted = true
        root._mutedAt = Date.now()
        const a = n.actions.find(x => x.identifier !== "default") ?? n.actions[0]
        if (a)
            a.invoke()
    }

    function textBack(number, text) {
        const t = (text ?? "").trim()
        if (t === "" || (number ?? "") === "" || root.deviceId === "")
            return
        Quickshell.execDetached(["kdeconnect-cli", "-d", root.deviceId, "--send-sms", t, "--destination", number])
    }

    function clearMissed() {
        root.missedCalls = []
    }

    function forgetMissed(at) {
        root.missedCalls = root.missedCalls.filter(c => c.at !== at)
    }

    Timer {
        id: ringFallback
        interval: 60000
        onTriggered: root._endCall()
    }

    Connections {
        target: ServiceNotification
        function onArrived(item) { root._callNotification(item) }
    }

    Connections {
        target: root._callNotif
        function onClosed(reason) { root._ringClosed() }
    }

    function markRead() {
        root.unreadIds = ({})
        root.peek = null
    }

    function reply(id, text) {
        const t = (text ?? "").trim()
        if (t === "") return
        root._notif(id, "sendReply", ["s", t])
    }

    function mute(ms) {
        root.muteUntil = ms > 0 ? Date.now() + ms : 0
        root.muted = ms > 0
        if (ms > 0) {
            root.peek = null
            muteTimer.interval = ms
            muteTimer.restart()
        } else {
            muteTimer.stop()
        }
    }

    function age(id) {
        const t = root._firstSeen[id] ?? 0
        if (t <= 0) return ""
        const m = Math.floor((Date.now() - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + " min"
        const h = Math.floor(m / 60)
        return h < 24 ? h + " h" : Math.floor(h / 24) + " d"
    }

    function _noteCharge() {
        if (!root.charging || root.battery < 0) {
            root._chargeMark = null
            root.minutesToFull = -1
            return
        }
        const now = Date.now()
        const m = root._chargeMark
        if (!m || root.battery < m.level) {
            root._chargeMark = { at: now, level: root.battery }
            root.minutesToFull = -1
            return
        }
        const gained = root.battery - m.level
        if (gained >= 2) {
            const perMin = gained / ((now - m.at) / 60000)
            root.minutesToFull = perMin > 0 ? Math.round((100 - root.battery) / perMin) : -1
        }
    }

    onBatteryChanged: root._noteCharge()
    onChargingChanged: root._noteCharge()
    onReadyChanged: root.refreshNotifications()

    Timer {
        id: muteTimer
        onTriggered: root.mute(0)
    }

    Timer {
        id: peekTimer
        interval: 5000
        onTriggered: root.peek = null
    }

    Process {
        id: notifProc
        property bool again: false
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = Object.assign({}, root._firstSeen)
                const now = Date.now()
                const fresh = []
                const list = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab <= 0) continue
                    const id = line.slice(0, tab)
                    let p = {}
                    try {
                        const d = JSON.parse(line.slice(tab + 1)).data[0] ?? {}
                        for (const k in d) p[k] = d[k].data
                    } catch (e) {
                        continue
                    }
                    if (!(id in seen)) {
                        seen[id] = root._notifsLoaded ? now : 0
                        if (root._notifsLoaded && !p.silent)
                            fresh.push(id)
                    }
                    list.push({ id: id, app: p.appName ?? "", title: p.title ?? "", text: p.text ?? "",
                                ticker: p.ticker ?? "", icon: p.hasIcon && p.iconPath ? "file://" + p.iconPath : "",
                                replyId: p.replyId ?? "", dismissable: p.dismissable !== false, silent: !!p.silent })
                }
                for (const k in seen)
                    if (!list.some(n => n.id === k)) delete seen[k]
                root._firstSeen = seen
                list.sort((a, b) => (seen[b.id] ?? 0) - (seen[a.id] ?? 0))
                root.notifications = list
                root._notifsLoaded = true
                if (root.peek && !list.some(n => n.id === root.peek.id))
                    root.peek = null
                const unread = {}
                for (const k in root.unreadIds)
                    if (list.some(n => n.id === k)) unread[k] = true
                if (fresh.length > 0 && !root.muted) {
                    for (const id of fresh) unread[id] = true
                    root.peek = list.find(n => n.id === fresh[fresh.length - 1]) ?? null
                    peekTimer.restart()
                }
                root.unreadIds = unread
            }
        }
        onExited: {
            if (notifProc.again) {
                notifProc.again = false
                root.refreshNotifications()
            }
        }
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
                             ip: f[9] ?? "", bars: f[10] === undefined || f[10] === "" ? -1 : parseInt(f[10]), netType: f[11] ?? "" }
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
                root.bars = d && !isNaN(d.bars) ? d.bars : -1
                root.netType = d ? d.netType : ""
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
        property var args: []
        stdout: SplitParser {
            onRead: line => {
                const m = /member=(\w+)/.exec(line)
                if (m) {
                    monitor.pending = m[1]
                    monitor.args = []
                    if (m[1] !== "shareReceived" && m[1] !== "textShareReceived" && m[1] !== "callReceived")
                        settle.restart()
                    return
                }
                const s = /^\s*string "(.*)"$/.exec(line)
                if (!s || monitor.pending === "")
                    return
                if (monitor.pending === "callReceived") {
                    monitor.args.push(s[1])
                    if (monitor.args.length === 3) {
                        monitor.pending = ""
                        root._callSignal(monitor.args[0], monitor.args[1], monitor.args[2])
                    }
                    return
                }
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
