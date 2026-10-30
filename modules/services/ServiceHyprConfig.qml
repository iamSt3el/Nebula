pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr"
    readonly property string mainPath: root.hyprDir + "/hyprland.lua"
    readonly property var areas: ["displays", "windows", "input", "binds"]
    readonly property var areaNames: ({ displays: "Displays", windows: "Windows", input: "Keyboard & mouse", binds: "Shortcuts" })

    readonly property var cfg: SettingsConfig.hypr ?? ({})
    readonly property var overrides: root.cfg.options ?? ({})

    property var live: ({})
    property bool optionsLoaded: false
    property var monitors: []
    property var workspaceRules: ({})
    property var cursorThemes: []
    property var kbLayouts: []
    property var areaStatus: ({})
    property var _dirty: ({})
    property bool hasTouchpad: false
    property string mouseName: ""
    property string keyboardName: ""
    property string touchpadName: ""

    function prettyDevice(name) {
        const words = String(name).replace(/-(keyboard|mouse|touchpad)(-\d+)?$/i, "").replace(/-\d+$/, "").split("-")
        return words.filter((w, i) => w !== "" && w !== words[i - 1] && w.toLowerCase() !== "kb")
            .map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")
    }

    readonly property string cursorTheme: root.cfg.cursor?.theme ?? (Quickshell.env("XCURSOR_THEME") || "Adwaita")
    readonly property int cursorSize: root.cfg.cursor?.size ?? (parseInt(Quickshell.env("XCURSOR_SIZE")) || 24)

    property var pendingMonitor: null
    property int revertIn: 0

    readonly property var watched: [
        "general.gaps_in", "general.gaps_out", "general.float_gaps", "general.border_size", "general.layout",
        "general.resize_on_border", "general.snap.enabled",
        "decoration.rounding", "decoration.rounding_power", "decoration.active_opacity", "decoration.inactive_opacity",
        "decoration.dim_inactive", "decoration.dim_strength",
        "decoration.blur.enabled", "decoration.blur.size", "decoration.blur.passes",
        "decoration.shadow.enabled", "decoration.glow.enabled", "decoration.motion_blur.enabled",
        "animations.enabled", "dwindle.preserve_split", "master.new_status", "master.focus_master_on_close",
        "scrolling.column_width", "scrolling.follow_focus", "misc.vrr", "misc.focus_on_activate",
        "input.kb_layout", "input.kb_options", "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default",
        "input.sensitivity", "input.accel_profile", "input.follow_mouse", "input.natural_scroll", "input.scroll_factor",
        "input.focus_on_close",
        "input.touchpad.natural_scroll", "input.touchpad.tap_to_click", "input.touchpad.disable_while_typing",
        "input.touchpad.scroll_factor", "input.touchpad.clickfinger_behavior", "input.touchpad.drag_3fg",
        "cursor.hide_on_key_press", "cursor.inactive_timeout",
        "gestures.workspace_swipe_invert", "gestures.workspace_swipe_create_new"
    ]

    property var drafts: ({})
    property var _pending: ({})

    function value(path, fallback) {
        if (root.drafts.hasOwnProperty(path)) return root.drafts[path]
        if (root.overrides.hasOwnProperty(path)) return root.overrides[path]
        if (root.live.hasOwnProperty(path)) return root.live[path]
        return fallback
    }

    function isChanged(path) {
        return root.overrides.hasOwnProperty(path)
    }

    function areaOf(path) {
        if (/^(input|cursor|gestures)\./.test(path)) return "input"
        if (path === "misc.vrr") return "displays"
        return "windows"
    }

    readonly property var targets: {
        const t = root.cfg.targets
        const out = {}
        for (const a of root.areas)
            out[a] = t === undefined ? { mode: "nebula", file: "" } : (t[a] ?? { mode: "off", file: "" })
        return out
    }

    function target(area) {
        return root.targets[area] ?? { mode: "off", file: "" }
    }

    function fileOf(area) {
        const t = root.target(area)
        return t.mode === "own" ? t.file : root.hyprDir + "/nebula/" + area + ".lua"
    }

    function prettyPath(p) {
        const home = Quickshell.env("HOME")
        return p.indexOf(home) === 0 ? "~" + p.slice(home.length) : p
    }

    function setTarget(area, mode, file) {
        const prev = root.target(area)
        if (prev.mode === "own" && prev.file !== "" && (mode !== "own" || file !== prev.file))
            root._queue(["remove", area, prev.file])
        const all = Object.assign({}, root.cfg.targets ?? root.targets)
        all[area] = { mode: mode, file: mode === "own" ? file : "", lastMode: mode === "off" ? prev.mode : undefined }
        root._patch("targets", all)
        if (mode !== "off")
            root._markDirty(area)
        root._scheduleWrite(true)
    }

    function removeBlock(area) {
        const t = root.target(area)
        if (t.mode === "own" && t.file !== "")
            root._queue(["remove", area, t.file])
        else
            root._queue(["write", area, "nebula", "", ""])
        root._scheduleWrite(true)
    }

    function requireFile(area) {
        root._queue(["require", root.fileOf(area)])
        root._scheduleWrite(true)
    }

    function _markDirty(area) {
        const d = Object.assign({}, root._dirty)
        d[area] = true
        root._dirty = d
    }

    function _patch(section, value) {
        const next = Object.assign({}, root.cfg)
        next[section] = value
        SettingsConfig.hypr = next
    }

    function preview(path, val) {
        const d = Object.assign({}, root.drafts)
        d[path] = val
        root.drafts = d
        root._pending[path] = val
        if (!previewTimer.running) previewTimer.start()
    }

    function set(path, val) {
        const o = Object.assign({}, root.overrides)
        o[path] = val
        root._patch("options", o)
        root._pending[path] = val
        if (!previewTimer.running) previewTimer.start()
        const d = Object.assign({}, root.drafts)
        delete d[path]
        root.drafts = d
        root._markDirty(root.areaOf(path))
        root._scheduleWrite(false)
    }

    function reset(path) {
        if (!root.isChanged(path)) return
        const o = Object.assign({}, root.overrides)
        delete o[path]
        root._patch("options", o)
        root._markDirty(root.areaOf(path))
        root._scheduleWrite(true)
    }

    function monitor(name) {
        return root.monitors.find(m => m.name === name) ?? null
    }

    function monitorRule(m, patch) {
        const saved = root.cfg.monitors?.[m.name] ?? {}
        const r = Object.assign({
            mode: m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
            position: m.x + "x" + m.y,
            scale: m.scale,
            transform: m.transform,
            vrr: m.vrr ? 1 : 0,
            mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "",
            disabled: !!m.disabled
        }, saved, patch ?? {})
        return r
    }

    function setMonitor(name, patch) {
        const m = root.monitor(name)
        if (!m) return
        if (root.pendingMonitor && root.pendingMonitor.name !== name) root.keepMonitor()
        const prev = root.pendingMonitor?.name === name ? root.pendingMonitor.prev : root.monitorRule(m)
        const next = root.monitorRule(m, patch)
        root.pendingMonitor = { name: name, prev: prev, next: next }
        root._eval(root._monitorLua(name, next))
        root.revertIn = 15
        revertTimer.restart()
        monitorRefresh.restart()
    }

    function keepMonitor() {
        const p = root.pendingMonitor
        if (!p) return
        revertTimer.stop()
        const all = Object.assign({}, root.cfg.monitors ?? {})
        all[p.name] = p.next
        root._patch("monitors", all)
        root.pendingMonitor = null
        root._markDirty("displays")
        root._scheduleWrite(false)
    }

    function revertMonitor() {
        const p = root.pendingMonitor
        if (!p) return
        revertTimer.stop()
        root._eval(root._monitorLua(p.name, p.prev))
        root.pendingMonitor = null
        monitorRefresh.restart()
    }

    function setWorkspaceMonitor(ws, monitorName) {
        const w = Object.assign({}, root.cfg.workspaces ?? {})
        if (monitorName === "") delete w[String(ws)]
        else w[String(ws)] = monitorName
        root._patch("workspaces", w)
        root._markDirty("displays")
        if (monitorName === "") {
            root._scheduleWrite(true)
            return
        }
        root._eval("hl.workspace_rule(" + root.toLua({ workspace: String(ws), monitor: monitorName }) + ")")
        root._scheduleWrite(false)
    }

    function workspaceMonitor(ws) {
        return root.cfg.workspaces?.[String(ws)] ?? root.workspaceRules[String(ws)] ?? ""
    }

    function setBind(entry, key, flags) {
        root._markDirty("binds")
        const b = Object.assign({}, root.cfg.binds ?? {})
        if (entry.addedBind) {
            const list = (root.cfg.addedBinds ?? []).map(a => a.id === entry.id
                ? Object.assign({}, a, { key: key }, flags ?? {}) : a)
            root._patch("addedBinds", list)
        } else if (entry.placeholder) {
            const list = (root.cfg.addedBinds ?? []).concat([Object.assign({
                id: "added|" + entry.action + "|" + Date.now(), key: key, action: "global:" + entry.action, name: entry.name
            }, flags ?? {})])
            root._patch("addedBinds", list)
        } else {
            const same = key === entry.origKey && !flags
            if (same) delete b[entry.id]
            else b[entry.id] = Object.assign({ key: key }, flags ?? {})
            root._patch("binds", b)
        }
        root._scheduleWrite(true)
    }

    function addCommand(key, command, name) {
        root._markDirty("binds")
        const list = (root.cfg.addedBinds ?? []).concat([{
            id: "added|cmd|" + Date.now(), key: key, action: "exec:" + command, command: command, name: name || command
        }])
        root._patch("addedBinds", list)
        root._scheduleWrite(true)
    }

    function removeAdded(id) {
        root._markDirty("binds")
        root._patch("addedBinds", (root.cfg.addedBinds ?? []).filter(a => a.id !== id))
        root._scheduleWrite(true)
    }

    function resetBind(entry) {
        root._markDirty("binds")
        if (entry.addedBind) { root.removeAdded(entry.id); return }
        const b = Object.assign({}, root.cfg.binds ?? {})
        delete b[entry.id]
        root._patch("binds", b)
        root._scheduleWrite(true)
    }

    function resetAllBinds() {
        root._markDirty("binds")
        const next = Object.assign({}, root.cfg, { binds: {}, addedBinds: [] })
        SettingsConfig.hypr = next
        root._scheduleWrite(true)
    }

    function setCursor(theme, size) {
        const c = { theme: theme, size: size }
        root._patch("cursor", c)
        root._markDirty("input")
        Quickshell.execDetached(["hyprctl", "setcursor", theme, String(size)])
        root._scheduleWrite(false)
    }

    readonly property string _recordMark: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nebula-record-session"

    function beginRecord() {
        const id = String(Date.now())
        root._eval("hl.define_submap(\"nebula_record\", function() "
            + "hl.bind(\"SUPER + SHIFT + CTRL + ALT + F24\", hl.dsp.submap(\"reset\")) end) "
            + "hl.dispatch(hl.dsp.submap(\"nebula_record\"))")
        Quickshell.execDetached(["sh", "-c",
            "printf %s \"$1\" > \"$2\"; sleep 20; "
            + "[ \"$(cat \"$2\" 2>/dev/null)\" = \"$1\" ] && hyprctl dispatch 'hl.dsp.submap(\"reset\")' >/dev/null 2>&1",
            "record", id, root._recordMark])
    }

    function endRecord() {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"; hyprctl dispatch 'hl.dsp.submap(\"reset\")' >/dev/null 2>&1",
            "record", root._recordMark])
    }

    function _eval(code) {
        Quickshell.execDetached(["hyprctl", "eval", code])
    }

    function _nest(flat) {
        const out = {}
        for (const path in flat) {
            const parts = path.split(".")
            var node = out
            for (var i = 0; i < parts.length - 1; i++) {
                if (typeof node[parts[i]] !== "object" || node[parts[i]] === null) node[parts[i]] = {}
                node = node[parts[i]]
            }
            node[parts[parts.length - 1]] = flat[path]
        }
        return out
    }

    function toLua(v) {
        if (v === null || v === undefined) return "nil"
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return isFinite(v) ? String(Math.round(v * 1000) / 1000) : "0"
        if (typeof v === "string") return JSON.stringify(v)
        if (Array.isArray(v)) return "{ " + v.map(x => root.toLua(x)).join(", ") + " }"
        const keys = Object.keys(v)
        return "{ " + keys.map(k => (/^[A-Za-z_]\w*$/.test(k) ? k : "[" + JSON.stringify(k) + "]") + " = " + root.toLua(v[k])).join(", ") + " }"
    }

    function _monitorLua(name, r) {
        if (r.disabled) return "hl.monitor(" + root.toLua({ output: name, disabled: true }) + ")"
        const spec = { output: name, mode: r.mode, position: r.position, scale: r.scale, transform: r.transform, vrr: r.vrr }
        if (r.mirror) spec.mirror = r.mirror
        return "hl.monitor(" + root.toLua(spec) + ")"
    }

    function _bindLua(key, disp, e) {
        const opts = {}
        if (e.locked) opts.locked = true
        if (e.repeating) opts.repeating = true
        if (e.release) opts.release = true
        const tail = Object.keys(opts).length ? ", " + root.toLua(opts) : ""
        return "hl.bind(" + JSON.stringify(key) + ", " + disp + tail + ")"
    }

    function _optionsFor(area) {
        const out = {}
        for (const k in root.overrides)
            if (root.areaOf(k) === area)
                out[k] = root.overrides[k]
        return out
    }

    function _configLua(area) {
        const o = root._optionsFor(area)
        return Object.keys(o).length ? "hl.config(" + root.toLua(root._nest(o)) + ")\n" : ""
    }

    function buildArea(area) {
        var out = root._configLua(area)
        if (area === "displays") {
            const mons = root.cfg.monitors ?? {}
            for (const n of Object.keys(mons)) out += root._monitorLua(n, mons[n]) + "\n"
            const ws = root.cfg.workspaces ?? {}
            for (const w of Object.keys(ws)) out += "hl.workspace_rule(" + root.toLua({ workspace: w, monitor: ws[w] }) + ")\n"
        } else if (area === "input") {
            const c = root.cfg.cursor
            if (c?.theme) {
                out += "hl.env(\"XCURSOR_THEME\", " + JSON.stringify(c.theme) + ")\n"
                out += "hl.env(\"XCURSOR_SIZE\", \"" + c.size + "\")\n"
                out += "hl.env(\"HYPRCURSOR_SIZE\", \"" + c.size + "\")\n"
                out += "hl.on(\"hyprland.start\", function() hl.exec_cmd(" + JSON.stringify("hyprctl setcursor " + c.theme + " " + c.size) + ") end)\n"
            }
        } else if (area === "binds") {
            const changed = ServiceKeybinds.entries.filter(e => e.changed && !e.addedBind)
            const added = ServiceKeybinds.entries.filter(e => e.addedBind && e.key !== "")
            const unbound = {}
            for (const e of changed) {
                if (e.origKey && !unbound[e.origKey]) {
                    out += "hl.unbind(" + JSON.stringify(e.origKey) + ")\n"
                    unbound[e.origKey] = true
                }
            }
            for (const e of changed) {
                if (e.key === "") continue
                for (const d of e.dispatchers) out += root._bindLua(e.key, d, e) + "\n"
            }
            for (const e of added) {
                const a = (root.cfg.addedBinds ?? []).find(x => x.id === e.id)
                if (!a) continue
                const disp = a.action.startsWith("global:")
                    ? "hl.dsp.global(" + JSON.stringify("quickshell:" + a.action.slice(7)) + ")"
                    : "hl.dsp.exec_cmd(" + JSON.stringify(a.command ?? a.action.slice(5)) + ")"
                out += root._bindLua(e.key, disp, e) + "\n"
            }
        }
        return out
    }

    property bool _reloadAfterWrite: false

    function _scheduleWrite(reload) {
        if (reload) root._reloadAfterWrite = true
        writeTimer.restart()
    }

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    property var _ops: []

    function _queue(op) {
        root._ops = root._ops.concat([op])
    }

    function writeNow() {
        if (writer.running) {
            writeTimer.restart()
            return
        }
        const ops = []
        for (const a of root.areas) {
            const t = root.target(a)
            if (root._dirty[a] && t.mode !== "off" && (t.mode === "nebula" || t.file !== ""))
                ops.push(["write", a, t.mode, t.mode === "own" ? t.file : "", root.buildArea(a)])
        }
        root._dirty = {}
        const all = root._ops.concat(ops)
        root._ops = []
        for (const a of root.areas)
            if (root.target(a).mode !== "off")
                all.push(["status", a, root.fileOf(a)])
        writer.command = ["sh", "-c", root._script, "sh", root.cli].concat([].concat(...all))
        writer.running = true
    }

    readonly property string _script: "cli=$1; shift; while [ $# -gt 0 ]; do case \"$1\" in "
        + "write) printf '%s ' \"$2\"; if [ \"$3\" = own ]; then printf '%s' \"$5\" | \"$cli\" hypr write \"$2\" own \"$4\"; "
        + "else printf '%s' \"$5\" | \"$cli\" hypr write \"$2\" nebula; fi; shift 5;; "
        + "remove) printf '%s ' \"$2\"; \"$cli\" hypr remove \"$2\" \"$3\"; shift 3;; "
        + "require) printf '%s ' \"$2\"; \"$cli\" hypr require \"$3\"; shift 3;; "
        + "status) printf '%s ' \"$2\"; \"$cli\" hypr status \"$3\"; shift 3;; "
        + "retire) printf 'legacy '; \"$cli\" hypr retire-legacy; shift 1;; "
        + "*) shift;; esac; done"

    function _afterSave(text) {
        const st = Object.assign({}, root.areaStatus)
        for (const line of text.split("\n")) {
            const k = line.indexOf(" ")
            if (k < 0) continue
            const area = line.slice(0, k)
            if (root.areas.indexOf(area) < 0) continue
            try {
                const j = JSON.parse(line.slice(k + 1))
                if (j.file === root.fileOf(area)) st[area] = j
            } catch (e) {}
        }
        root.areaStatus = st
        if (root._reloadAfterWrite) {
            root._reloadAfterWrite = false
            reloadTimer.restart()
        }
    }

    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: root._afterSave(text)
        }
    }

    function statusOf(area) {
        return root.areaStatus[area] ?? null
    }

    function _migrate() {
        if (root.cfg.targets !== undefined || SettingsConfig.greeterMode)
            return
        const all = {}
        for (const a of root.areas) {
            all[a] = { mode: "nebula", file: "" }
            root._markDirty(a)
        }
        root._patch("targets", all)
        root._queue(["retire"])
        root._scheduleWrite(false)
    }

    readonly property bool _settingsReady: SettingsConfig.settingsReady
    on_SettingsReadyChanged: if (root._settingsReady) root._migrate()

    function refreshMonitors() {
        monitorReader.running = true
        rulesReader.running = true
    }

    function refresh() {
        optionReader.running = true
        monitorReader.running = true
        rulesReader.running = true
        themesReader.running = true
        devicesReader.running = true
    }

    function _parseOption(o) {
        if (o.hasOwnProperty("bool")) return o.bool
        if (o.hasOwnProperty("int")) return o.int
        if (o.hasOwnProperty("float")) return Math.round(o.float * 1000) / 1000
        if (o.hasOwnProperty("str")) return o.str
        if (o.hasOwnProperty("css")) {
            const n = String(o.css).trim().split(/\s+/).map(Number)
            if (n.length === 4 && n.every(x => x === n[0])) return n[0]
            return { top: n[0] ?? 0, right: n[1] ?? n[0] ?? 0, bottom: n[2] ?? n[0] ?? 0, left: n[3] ?? n[1] ?? n[0] ?? 0 }
        }
        if (o.hasOwnProperty("gradient")) return o.gradient
        return null
    }

    Timer { id: writeTimer; interval: 450; onTriggered: root.writeNow() }

    Timer {
        id: previewTimer
        interval: 60
        onTriggered: {
            const p = root._pending
            root._pending = {}
            if (Object.keys(p).length)
                root._eval("hl.config(" + root.toLua(root._nest(p)) + ")")
        }
    }
    Timer { id: reloadTimer; interval: 150; onTriggered: Quickshell.execDetached(["hyprctl", "reload"]) }
    Timer { id: monitorRefresh; interval: 900; onTriggered: monitorReader.running = true }

    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.revertIn -= 1
            if (root.revertIn <= 0) root.revertMonitor()
        }
    }


    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        printErrors: false
        onLoaded: {
            const lines = text().split("\n")
            const out = []
            var inLayout = false
            for (const l of lines) {
                if (l.startsWith("! ")) { inLayout = l.trim() === "! layout"; continue }
                if (!inLayout) continue
                const m = l.match(/^\s+(\S+)\s+(.+)$/)
                if (m) out.push({ code: m[1], name: m[2].trim() })
            }
            root.kbLayouts = out.sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    Process {
        id: optionReader
        command: ["hyprctl", "-j", "--batch", root.watched.map(o => "getoption " + o).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const live = {}
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue
                    try {
                        const o = JSON.parse(line)
                        live[o.option] = root._parseOption(o)
                    } catch (e) {}
                }
                root.live = live
                root.optionsLoaded = true
            }
        }
    }

    Process {
        id: monitorReader
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = JSON.parse(text) } catch (e) {}
            }
        }
    }

    Process {
        id: rulesReader
        command: ["hyprctl", "-j", "workspacerules"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                try {
                    for (const r of JSON.parse(text))
                        if (r.monitor && /^\d+$/.test(r.workspaceString)) out[r.workspaceString] = r.monitor
                } catch (e) {}
                root.workspaceRules = out
            }
        }
    }

    Process {
        id: themesReader
        command: ["sh", "-c", "for d in /usr/share/icons/* \"$HOME\"/.local/share/icons/* \"$HOME\"/.icons/*; do [ -d \"$d/cursors\" ] && basename \"$d\"; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.cursorThemes = text.split("\n").filter(s => s.trim() !== "")
        }
    }

    Process {
        id: devicesReader
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const mice = (d.mice ?? []).map(m => m.name)
                    const pad = mice.find(n => /touchpad|trackpad/i.test(n))
                    const mouse = mice.find(n => !/touchpad|trackpad|keyboard|:|-kb-/i.test(n))
                    const kb = (d.keyboards ?? []).find(k => k.main) ?? null
                    root.hasTouchpad = pad !== undefined
                    root.touchpadName = pad === undefined ? "" : /^syna/i.test(pad) ? "Synaptics" : /^elan/i.test(pad) ? "ELAN" : root.prettyDevice(pad)
                    root.mouseName = mouse === undefined ? "" : root.prettyDevice(mouse)
                    root.keyboardName = kb ? root.prettyDevice(kb.name) : ""
                } catch (e) {}
            }
        }
    }

    property var _lastModes: ({})

    onTargetsChanged: {
        const prev = root._lastModes
        const next = {}
        for (const a of root.areas) {
            next[a] = root.target(a).mode + "|" + root.target(a).file
            if (prev[a] !== undefined && prev[a] !== next[a] && root.target(a).mode !== "off") {
                root._markDirty(a)
                root._scheduleWrite(true)
            }
        }
        root._lastModes = next
    }

    Component.onCompleted: {
        root.refresh()
        if (root._settingsReady)
            root._migrate()
        for (const a of root.areas)
            if (root.target(a).mode !== "off")
                root._markDirty(a)
        root._scheduleWrite(false)
    }
}
