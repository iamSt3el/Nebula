pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.utils
import qs.modules.settings
import "WizScenes.js" as WizScenes

Singleton {
    id: root

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    readonly property var scenes: WizScenes.scenes
    readonly property var scenePicks: WizScenes.picks

    property int _refCount: 0
    property string _bootIp: ""
    property bool _booted: false

    property string status: "idle"
    property string ip: ""
    property bool on: false
    property real dimming: 1
    property int temp: 2700
    property color rgb: "#ff5c8a"
    property int sceneId: 0
    property int speed: SettingsConfig.wiz?.speed ?? 100
    property int rssi: 0
    property string mac: ""
    property string firmware: ""
    property string moduleName: ""
    property string region: ""
    property int cctMin: 2200
    property int cctMax: 6500
    property bool locked: false

    property real _holdUntil: 0
    property string _seenSig: ""
    property string _sentSig: ""

    readonly property string mode: SettingsConfig.wiz?.mode ?? "white"
    readonly property bool ready: root.status === "ready"
    readonly property var scene: WizScenes.byId(root.sceneId)
    readonly property string themeRole: SettingsConfig.wiz?.themeRole ?? "primary"
    readonly property bool boost: SettingsConfig.wiz?.boost ?? true
    readonly property bool follow: SettingsConfig.wiz?.follow ?? true
    readonly property string musicStyle: SettingsConfig.wiz?.musicStyle ?? "pulse"
    readonly property real sensitivity: SettingsConfig.wiz?.sensitivity ?? 0.6
    readonly property var recent: SettingsConfig.wiz?.recent ?? []

    property int cycleIndex: 0
    readonly property var themeRoles: ["primary", "secondary", "tertiary"]
    readonly property string liveRole: root.themeRole === "cycle" ? root.themeRoles[root.cycleIndex % 3] : root.themeRole
    readonly property color themeColor: root.roleColor(root.liveRole)

    property color musicColor: root.themeColor
    property real musicLevel: 0
    property real _bassAvg: 0
    property real _lastBeat: 0
    property int _beatIndex: 0

    readonly property color lightColor: {
        if (!root.on)
            return Colors.surfaceContainerHighest
        switch (root.mode) {
        case "colour": return root.rgb
        case "scenes": return root.scene ? root.scene.a : WizScenes.kelvin(root.temp)
        case "theme":  return root.themeColor
        case "music":  return root.musicColor
        }
        return WizScenes.kelvin(root.temp)
    }

    property int sleepMinutes: 0
    property real sleepEnd: 0
    property real _now: Date.now()
    readonly property int sleepLeft: root.sleepEnd > 0 ? Math.max(0, Math.ceil((root.sleepEnd - root._now) / 60000)) : 0

    function retain() { root._refCount++ }
    function release() { if (root._refCount > 0) root._refCount-- }

    function kelvin(k) { return WizScenes.kelvin(k) }
    function sceneById(id) { return WizScenes.byId(id) }

    function roleColor(role) {
        const c = Qt.color(Colors[role] ?? Colors.primary)
        if (!root.boost)
            return c
        const h = c.hslHue >= 0 ? c.hslHue : 0.08
        return Qt.hsla(h, 0.95, 0.6, 1)
    }

    function saveWiz(patch) {
        SettingsConfig.wiz = Object.assign({}, SettingsConfig.wiz, patch)
    }

    function _send(params) {
        if (!proc.running)
            return
        root._holdUntil = Date.now() + 1500
        root._sentSig = root._sig(params)
        proc.write(JSON.stringify({ op: "pilot", params: params }) + "\n")
    }

    function _dim() { return Math.max(1, Math.min(100, Math.round(root.dimming * 100))) }

    function _rgbParams(c, dim) {
        return { state: true, r: Math.round(c.r * 255), g: Math.round(c.g * 255), b: Math.round(c.b * 255), dimming: dim }
    }

    function _sig(p) {
        if (p.state === false)
            return "off"
        if ((p.sceneId ?? 0) > 0)
            return "s" + p.sceneId + ":" + p.dimming
        if (p.r !== undefined)
            return "c" + p.r + "," + p.g + "," + p.b + ":" + p.dimming
        return "t" + p.temp + ":" + p.dimming
    }

    function setPower(v) {
        root.on = v
        if (!v)
            root.cancelSleep()
        root._send(v ? root._modeParams() : { state: false })
    }

    function setBrightness(v) {
        root.dimming = Math.max(0.01, Math.min(1, v))
        root.on = true
        if (root.mode !== "music")
            root._send(root._modeParams())
    }

    function setTemp(k) {
        root.temp = Math.round(Math.max(root.cctMin, Math.min(root.cctMax, k)))
        root.on = true
        root.saveWiz({ mode: "white" })
        root._send({ state: true, temp: root.temp, dimming: root._dim() })
    }

    function setColor(c) {
        root.rgb = c
        root.on = true
        root.saveWiz({ mode: "colour" })
        root._send(root._rgbParams(c, root._dim()))
    }

    function rememberColor(c) {
        const hex = Qt.color(c).toString()
        const list = [hex].concat((root.recent ?? []).filter(h => h !== hex)).slice(0, 5)
        root.saveWiz({ recent: list })
    }

    function setScene(id) {
        root.sceneId = id
        root.on = true
        root.saveWiz({ mode: "scenes" })
        root._send(root._sceneParams())
    }

    function setSpeed(v) {
        root.speed = Math.round(Math.max(10, Math.min(200, v)))
        if (root.mode === "scenes" && root.scene && root.scene.moving)
            root._send(root._sceneParams())
    }

    function _sceneParams() {
        const p = { state: true, sceneId: root.sceneId > 0 ? root.sceneId : 11, dimming: root._dim() }
        const s = WizScenes.byId(p.sceneId)
        if (s && s.moving)
            p.speed = root.speed
        return p
    }

    function _modeParams() {
        switch (root.mode) {
        case "colour": return root._rgbParams(root.rgb, root._dim())
        case "scenes": return root._sceneParams()
        case "theme":  return root._rgbParams(root.themeColor, root._dim())
        case "music":  return root._rgbParams(root.musicColor, root._dim())
        }
        return { state: true, temp: root.temp, dimming: root._dim() }
    }

    function setMode(m) {
        root.saveWiz({ mode: m })
        if (m === "scenes" && root.sceneId <= 0)
            root.sceneId = 11
        if (m === "music")
            root.musicLevel = 0
        root.on = true
        root._send(root._modeParams())
    }

    function setThemeRole(r) {
        root.saveWiz({ themeRole: r, mode: "theme" })
        root.cycleIndex = 0
        root.on = true
        root._send(root._rgbParams(root.roleColor(r === "cycle" ? "primary" : r), root._dim()))
    }

    function cycleSleep() {
        const steps = [0, 15, 30, 60]
        const next = steps[(steps.indexOf(root.sleepMinutes) + 1) % steps.length]
        root.sleepMinutes = next
        root.sleepEnd = next > 0 ? Date.now() + next * 60000 : 0
        root._now = Date.now()
    }

    function cancelSleep() {
        root.sleepMinutes = 0
        root.sleepEnd = 0
    }

    function rescan() {
        if (proc.running)
            proc.write(JSON.stringify({ op: "scan" }) + "\n")
    }

    function refresh() {
        if (proc.running)
            proc.write(JSON.stringify({ op: "refresh" }) + "\n")
    }

    function _pilot(p) {
        if (p.rssi !== undefined)
            root.rssi = p.rssi
        const norm = { state: p.state, sceneId: p.sceneId ?? 0, dimming: p.dimming, temp: p.temp, r: p.r, g: p.g, b: p.b }
        const sig = root._sig(norm)
        if (Date.now() < root._holdUntil) {
            root._seenSig = sig
            return
        }
        const external = sig !== root._seenSig && sig !== root._sentSig && root._seenSig !== ""
        const first = root._seenSig === ""
        root._seenSig = sig
        root.on = p.state === true
        if (p.dimming !== undefined)
            root.dimming = Math.max(0.01, p.dimming / 100)
        if (p.temp !== undefined && p.temp > 0)
            root.temp = p.temp
        if (p.speed !== undefined)
            root.speed = p.speed
        root.sceneId = p.sceneId ?? 0
        if (p.r !== undefined && (p.sceneId ?? 0) === 0)
            root.rgb = Qt.rgba(p.r / 255, p.g / 255, p.b / 255, 1)
        if (!root.on || !(first || external))
            return
        if (first && (root.mode === "theme" || root.mode === "music"))
            return
        const inferred = root.sceneId > 0 ? "scenes" : p.r !== undefined ? "colour" : "white"
        if (inferred !== root.mode)
            root.saveWiz({ mode: inferred })
    }

    function _handle(line) {
        let msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            return
        }
        switch (msg.type) {
        case "host":
            root.ip = msg.ip
            root.status = "ready"
            if ((SettingsConfig.wiz?.ip ?? "") !== msg.ip)
                root.saveWiz({ ip: msg.ip })
            break
        case "scanning":
            if (root.status !== "ready")
                root.status = "scanning"
            break
        case "notfound":
            root.status = "notfound"
            break
        case "lost":
            root.status = "lost"
            break
        case "state":
            root.ip = msg.ip
            root.status = "ready"
            root._pilot(msg.pilot ?? {})
            break
        case "system": {
            const c = msg.config ?? {}
            root.mac = c.mac ?? ""
            root.firmware = c.fwVersion ?? ""
            root.moduleName = c.moduleName ?? ""
            root.region = c.rgn ?? ""
            break
        }
        case "model": {
            const r = msg.config?.cctRange ?? []
            if (r.length >= 2) {
                root.cctMin = r[0]
                root.cctMax = r[r.length - 1]
            }
            break
        }
        case "ok":
            root.locked = false
            break
        case "error":
            if (msg.op === "setPilot" && (msg.code === -32602 || msg.code === -32605))
                root.locked = true
            break
        }
    }

    onThemeColorChanged: {
        if (root.mode === "theme" && root.on && root.ready && root.follow)
            root._send(root._rgbParams(root.themeColor, root._dim()))
    }

    Connections {
        target: SettingsConfig
        function onSettingsReadyChanged() {
            if (SettingsConfig.settingsReady && !root._booted) {
                root._bootIp = SettingsConfig.wiz?.ip ?? ""
                root._booted = true
            }
        }
    }

    Component.onCompleted: {
        if (SettingsConfig.settingsReady) {
            root._bootIp = SettingsConfig.wiz?.ip ?? ""
            root._booted = true
        }
    }

    Process {
        id: proc
        running: root._refCount > 0 && root._booted
        command: [root.cli, "wiz", "serve", "--ip", root._bootIp]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root._handle(line)
        }
        onRunningChanged: if (!running) root.status = "idle"
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.mode === "theme" && root.themeRole === "cycle" && root.on && root.ready
        onTriggered: {
            root.cycleIndex = (root.cycleIndex + 1) % 3
            root._send(root._rgbParams(root.themeColor, root._dim()))
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.sleepEnd > 0
        onTriggered: {
            root._now = Date.now()
            if (root._now >= root.sleepEnd) {
                root.cancelSleep()
                root.setPower(false)
            }
        }
    }

    readonly property bool musicLive: root.mode === "music" && root.on && root.ready && root._refCount > 0
    onMusicLiveChanged: {
        if (root.musicLive)
            ServiceCava.retain()
        else
            ServiceCava.release()
    }

    Timer {
        interval: 66
        repeat: true
        running: root.musicLive
        onTriggered: root._musicTick()
    }

    function _musicTick() {
        const data = ServiceCava.cavaData ?? []
        const n = data.length
        if (n === 0)
            return
        let sum = 0
        let weighted = 0
        for (let i = 0; i < n; i++) {
            sum += data[i]
            weighted += data[i] * i
        }
        const bassN = Math.max(1, Math.floor(n * 0.15))
        let bass = 0
        for (let i = 0; i < bassN; i++)
            bass += data[i]
        bass /= bassN
        const energy = sum / n
        const gain = 0.8 + root.sensitivity * 3.2
        const level = Math.max(0, Math.min(1, energy * gain))
        root.musicLevel = level
        const now = Date.now()
        root._bassAvg = root._bassAvg * 0.92 + bass * 0.08
        const beat = bass > 0.12 && bass > root._bassAvg * 1.35 && now - root._lastBeat > 260
        if (beat)
            root._lastBeat = now
        let c = root.themeColor
        if (root.musicStyle === "spectrum") {
            const centre = sum > 0 ? weighted / sum / Math.max(1, n - 1) : 0
            c = Qt.hsva(Math.max(0, Math.min(0.83, centre * 1.6)), 1, 1, 1)
        } else if (root.musicStyle === "theme") {
            if (beat)
                root._beatIndex = (root._beatIndex + 1) % 3
            c = root.roleColor(root.themeRoles[root._beatIndex])
        }
        root.musicColor = c
        const ceiling = root._dim()
        const floor = Math.max(1, Math.round(ceiling * 0.12))
        const dim = Math.round(floor + (ceiling - floor) * (root.musicStyle === "pulse" ? Math.max(level, beat ? 1 : 0) : level))
        const params = root._rgbParams(c, dim)
        const sig = root._sig(params)
        if (sig === root._sentSig)
            return
        root._send(params)
    }
}
