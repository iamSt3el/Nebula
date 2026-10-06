pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property var sources: [
        { file: "nebula", path: root.hyprDir + "/nebula/keybinds.lua" },
        { file: "lua", path: root.hyprDir + "/lua/keybinds.lua" }
    ]

    property var parsed: ({ nebula: [], lua: [] })

    readonly property var overrides: SettingsConfig.hypr?.binds ?? ({})
    readonly property var added: SettingsConfig.hypr?.addedBinds ?? []

    readonly property var groupOrder: ["Nebula", "Windows", "Workspaces", "Apps", "Media"]

    readonly property var actions: ({
        "appLauncher":        { name: "App launcher",      desc: "Search apps, maths, commands, emoji and windows", icon: "apps" },
        "overview":           { name: "Overview",          desc: "Every workspace and window at once",            icon: "grid_view" },
        "clipboard":          { name: "Clipboard",         desc: "History with previews and pins",                icon: "content_paste" },
        "clipboardPocket":    { name: "Clipboard pocket",  desc: "Small history at the pointer, pastes in place", icon: "ads_click" },
        "wallpaperLauncher":  { name: "Wallpapers",        desc: "Browse and apply wallpapers",                   icon: "wallpaper" },
        "toolsWidget":        { name: "Tools",             desc: "Screenshots, recording and colour picker",      icon: "construction" },
        "settingOpen":        { name: "Settings",          desc: "Open this window",                              icon: "settings" },
        "cheatsheet":         { name: "Cheat sheet",       desc: "Every shortcut on one screen",                  icon: "keyboard" },
        "filedrop":           { name: "Phone panel",       desc: "Files, links and clipboard over KDE Connect",   icon: "send_to_mobile" },
        "ocr":                { name: "Live Text",         desc: "Select text straight off the screen",           icon: "document_scanner" },
        "pie":                { name: "Pie menu",          desc: "Hold, flick toward an action, release",         icon: "donut_large" },
        "tuck":               { name: "Tuck window",       desc: "Park the focused window on the screen edge",    icon: "vertical_align_bottom" },
        "untuck":             { name: "Untuck window",     desc: "Bring back the last tucked window",             icon: "vertical_align_top" },
        "spotlight":          { name: "Spotlight",         desc: "Dim everything except the focused window",      icon: "highlight" },
        "note":               { name: "New note",          desc: "Sticky note on the screen edge",                icon: "sticky_note_2" },
        "lock":               { name: "Lock",              desc: "Lock the session",                              icon: "lock" },
        "shutdown":           { name: "Session menu",      desc: "Lock, sleep, log out, restart, power off",      icon: "power_settings_new" },
        "barEdit":            { name: "Bar edit mode",     desc: "Move and restyle bar items in place",           icon: "edit_square" },
        "brightnessIncrease": { name: "Brightness up",     desc: "Raise the screen brightness with the OSD",      icon: "brightness_high" },
        "brightnessDecrease": { name: "Brightness down",   desc: "Lower the screen brightness with the OSD",      icon: "brightness_low" }
    })

    readonly property var entries: {
        const out = []
        const seen = {}
        for (const src of root.sources) {
            for (const e of (root.parsed[src.file] ?? [])) {
                const ov = root.overrides[e.id]
                const key = ov ? (ov.key ?? e.origKey) : e.origKey
                const r = Object.assign({}, e, {
                    key: key,
                    locked: ov?.locked ?? e.locked,
                    repeating: ov?.repeating ?? e.repeating,
                    release: ov?.release ?? e.release,
                    changed: !!ov,
                    unset: key === ""
                })
                if (e.action) seen[e.action] = true
                out.push(r)
            }
        }
        for (const a of root.added) {
            const meta = a.action?.startsWith("global:") ? root.actions[a.action.slice(7)] : null
            if (a.action?.startsWith("global:")) seen[a.action.slice(7)] = true
            out.push({
                id: a.id, file: "settings", origKey: "", key: a.key, group: meta ? "Nebula" : "Apps",
                name: a.name ?? meta?.name ?? "Command", desc: meta?.desc ?? (a.command ?? ""),
                icon: meta?.icon ?? "terminal", dispatchers: [], action: a.action?.startsWith("global:") ? a.action.slice(7) : "",
                locked: a.locked ?? false, repeating: a.repeating ?? false, release: a.release ?? false,
                editable: true, loop: false, mouse: false, changed: true, unset: a.key === "", addedBind: true
            })
        }
        for (const id in root.actions) {
            if (seen[id]) continue
            const m = root.actions[id]
            out.push({
                id: "unbound|" + id, file: "settings", origKey: "", key: "", group: "Nebula",
                name: m.name, desc: m.desc, icon: m.icon, dispatchers: [], action: id,
                locked: false, repeating: false, release: false, editable: true, loop: false, mouse: false,
                changed: false, unset: true, placeholder: true
            })
        }
        return out
    }

    readonly property var groups: {
        const by = {}
        for (const e of root.entries) {
            if (e.unset) continue
            if (!by[e.group]) by[e.group] = []
            by[e.group].push({ shortcut: root.pretty(e.key), description: e.name })
        }
        return root.groupOrder.filter(g => by[g]).map(g => ({ name: g, binds: by[g] }))
    }

    readonly property int bindCount: root.entries.filter(e => !e.unset).length

    function reload() {
        for (var i = 0; i < readers.count; i++)
            readers.objectAt(i)?.reload()
    }

    function filtered(query) {
        const q = (query ?? "").trim().toLowerCase()
        if (q === "") return root.groups
        const out = []
        for (const g of root.groups) {
            const hits = g.binds.filter(b =>
                b.shortcut.toLowerCase().indexOf(q) !== -1 ||
                b.description.toLowerCase().indexOf(q) !== -1)
            if (hits.length > 0) out.push({ name: g.name, binds: hits })
        }
        return out
    }

    function entriesIn(group) {
        return root.entries.filter(e => e.group === group)
    }

    function owner(key, exceptId) {
        const k = root.normalize(key)
        if (k === "") return null
        return root.entries.find(e => e.id !== exceptId && !e.unset && root.normalize(e.key) === k) ?? null
    }

    readonly property var keyNames: ({
        "SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt",
        "RETURN": "Enter", "ENTER": "Enter", "grave": "`", "slash": "/", "TAB": "Tab", "Tab": "Tab",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "SPACE": "Space", "space": "Space",
        "mouse:272": "Left drag", "mouse:273": "Right drag", "mouse_down": "Scroll down", "mouse_up": "Scroll up",
        "PRINT": "Print", "ESCAPE": "Esc", "BACKSPACE": "Backspace", "DELETE": "Delete",
        "XF86AudioRaiseVolume": "Volume up", "XF86AudioLowerVolume": "Volume down", "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic mute", "XF86MonBrightnessUp": "Brightness up", "XF86MonBrightnessDown": "Brightness down",
        "XF86AudioNext": "Next", "XF86AudioPrev": "Previous", "XF86AudioPlay": "Play", "XF86AudioPause": "Pause"
    })

    function keyParts(key) {
        return String(key ?? "").split("+").map(s => s.trim()).filter(s => s !== "")
            .map(s => root.keyNames[s] ?? root.keyNames[s.toUpperCase()] ?? (s.length === 1 ? s.toUpperCase() : s))
    }

    function pretty(key) {
        return root.keyParts(key).join(" + ")
    }

    function normalize(key) {
        const order = ["SUPER", "SHIFT", "CTRL", "ALT"]
        const parts = String(key ?? "").split("+").map(s => s.trim().toUpperCase()).filter(s => s !== "")
            .map(s => s === "CONTROL" ? "CTRL" : s === "ENTER" ? "RETURN" : s === "MOD4" ? "SUPER" : s)
        const mods = parts.filter(s => order.indexOf(s) >= 0).sort((x, y) => order.indexOf(x) - order.indexOf(y))
        return mods.concat(parts.filter(s => order.indexOf(s) < 0)).join(" + ")
    }

    function _humanize(s) {
        if (!s) return ""
        var out = String(s).replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_\-.]+/g, " ").trim().toLowerCase()
        return out.charAt(0).toUpperCase() + out.slice(1)
    }

    function _splitTop(s, delim) {
        var parts = [], depth = 0, inStr = false, start = 0
        for (var i = 0; i < s.length; i++) {
            const ch = s[i]
            if (inStr) {
                if (ch === "\\") { i++; continue }
                if (ch === '"') inStr = false
                continue
            }
            if (ch === '"') { inStr = true; continue }
            if (ch === "(" || ch === "{") { depth++; continue }
            if (ch === ")" || ch === "}") { depth--; continue }
            if (depth === 0 && s.substr(i, delim.length) === delim) {
                parts.push(s.substring(start, i))
                i += delim.length - 1
                start = i + 1
            }
        }
        parts.push(s.substring(start))
        return parts
    }

    function _commentAt(s) {
        var inStr = false
        for (var i = 0; i < s.length; i++) {
            const ch = s[i]
            if (inStr) {
                if (ch === "\\") { i++; continue }
                if (ch === '"') inStr = false
                continue
            }
            if (ch === '"') { inStr = true; continue }
            if (ch === "-" && s[i + 1] === "-") return i
        }
        return -1
    }

    function _resolveExpr(expr, locals, loopLabel) {
        const parts = root._splitTop(String(expr), "..")
        var out = ""
        for (var p of parts) {
            p = p.trim()
            if (p === "") continue
            const q = p.match(/^"([\s\S]*)"$/)
            if (q) { out += q[1].replace(/\\"/g, '"'); continue }
            if (locals.hasOwnProperty(p)) { out += locals[p]; continue }
            out += loopLabel !== "" ? loopLabel : p
        }
        return out.trim()
    }

    function _inline(text, locals) {
        var out = "", i = 0
        while (i < text.length) {
            const ch = text[i]
            if (ch === '"') {
                var j = i + 1
                while (j < text.length && text[j] !== '"') { if (text[j] === "\\") j++; j++ }
                out += text.substring(i, j + 1)
                i = j + 1
                continue
            }
            if (/[A-Za-z_]/.test(ch)) {
                var k = i
                while (k < text.length && /[A-Za-z0-9_]/.test(text[k])) k++
                const w = text.substring(i, k)
                const prev = out.replace(/\s+$/, "").slice(-1)
                const field = prev === "." || prev === ":"
                const tableKey = /^\s*=(?!=)/.test(text.substring(k))
                out += (!field && !tableKey && locals.hasOwnProperty(w)) ? JSON.stringify(locals[w]) : w
                i = k
                continue
            }
            out += ch
            i++
        }
        return out
    }

    function _flags(opts) {
        const s = String(opts ?? "")
        const on = name => new RegExp("\\b" + name + "\\s*=\\s*true").test(s)
        return { locked: on("locked"), repeating: on("repeating"), release: on("release"), mouse: on("mouse") }
    }

    readonly property var windowNames: [
        [/window\.close\(/, "Close window", "close", "Ask the focused window to close"],
        [/kill/, "Force quit", "dangerous", "Kill the focused app"],
        [/fullscreen\(/, "Fullscreen", "fullscreen", "Toggle fullscreen for the focused window"],
        [/window\.float\(/, "Float", "picture_in_picture", "Toggle floating for the focused window"],
        [/window\.center\(/, "Center", "filter_center_focus", "Center the floating window"],
        [/window\.pin\(/, "Pin", "push_pin", "Keep the window on every workspace"],
        [/window\.pseudo\(/, "Pseudo-tile", "crop_free", "Keep the window's own size inside its tile"],
        [/togglesplit/, "Toggle split", "splitscreen_right", "Flip the split direction"],
        [/swapsplit/, "Swap split", "swap_horiz", "Swap the two halves"],
        [/group\.toggle\(/, "Group", "tab_group", "Turn the window into a tab group"],
        [/group\.next\(/, "Next in group", "tab", "Switch to the next tab in the group"],
        [/focus\(\{\s*direction/, "Move focus", "open_with", "Focus the window in that direction"],
        [/window\.swap\(/, "Swap windows", "swap_vert", "Swap with the window in that direction"],
        [/window\.resize\(\{/, "Resize", "aspect_ratio", "Grow or shrink the focused window"],
        [/window\.drag\(/, "Move with mouse", "drag_pan", "Drag a window with the modifier held"],
        [/window\.resize\(\)/, "Resize with mouse", "open_in_full", "Resize a window with the modifier held"],
        [/cycle_next|bring_to_top/, "Cycle windows", "tab", "Switch between windows on this workspace"],
        [/toggle_special/, "Scratchpad", "inventory_2", "Show or hide the scratchpad"],
        [/special:/, "Send to scratchpad", "move_to_inbox", "Move the window to the scratchpad"],
        [/window\.move\(\{\s*workspace/, "Move to workspace", "drive_file_move", "Send the window to a workspace"],
        [/focus\(\{\s*workspace\s*=\s*"empty"/, "Empty workspace", "add_box", "Go to the first empty workspace"],
        [/focus\(\{\s*workspace\s*=\s*"[me]\+1"/, "Next workspace", "arrow_forward", "Go to the next workspace"],
        [/focus\(\{\s*workspace\s*=\s*"[me]-1"/, "Previous workspace", "arrow_back", "Go to the previous workspace"],
        [/focus\(\{\s*workspace/, "Go to workspace", "counter_1", "Switch to a workspace"],
        [/hl\.dsp\.exit|dispatch 'hl\.dsp\.exit/, "Exit Hyprland", "logout", "End the Hyprland session"]
    ]

    function _classify(key, disp, locals) {
        const g = disp.match(/global\s*\(\s*"quickshell:([^"]+)"/)
        if (g) {
            const m = root.actions[g[1]]
            return { group: "Nebula", action: g[1], name: m?.name ?? root._humanize(g[1]), icon: m?.icon ?? "bolt", desc: m?.desc ?? "" }
        }
        if (/^XF86/.test(key.split("+").pop().trim())) {
            return { group: "Media", action: "", name: root.keyNames[key.trim()] ?? root._humanize(key.replace("XF86", "")), icon: "music_note", desc: root._describe(disp, locals) }
        }
        for (const w of root.windowNames) {
            if (w[0].test(disp)) {
                const ws = /workspace|special|scratch/i.test(w[1])
                return { group: ws ? "Workspaces" : (w[1] === "Exit Hyprland" ? "Apps" : "Windows"), action: "", name: w[1], icon: w[2], desc: w[3] }
            }
        }
        const e = disp.match(/exec_cmd\s*\(([\s\S]*)\)\s*$/)
        if (e) {
            const cmd = root._resolveExpr(e[1], locals, "")
            const h = cmd.match(/^hyprctl\s+(?:dispatch\s+)?(\S+)/)
            const app = cmd.split(/\s+/)[0].split("/").pop().replace(/\.(sh|py)$/, "")
            const name = h ? (h[1] === "reload" ? "Reload Hyprland" : root._humanize(h[1])) : root._humanize(app)
            return { group: "Apps", action: "", name: name, icon: h ? "tune" : "terminal", desc: cmd }
        }
        return { group: "Windows", action: "", name: root._describe(disp, locals), icon: "keyboard", desc: "" }
    }

    function _describe(disp, locals) {
        const d = String(disp).trim()
        const e = d.match(/exec_cmd\s*\(([\s\S]*)\)\s*$/)
        if (e) return root._resolveExpr(e[1], locals, "")
        const m = d.match(/hl\.dsp\.([A-Za-z_.]+)\s*\(/)
        return m ? root._humanize(m[1]) : d
    }

    function parse(text, file) {
        const lines = String(text).split("\n")
        const locals = {}
        const byKey = {}
        const order = []
        var loopLabel = ""
        var loopStart = 0, loopEnd = 0

        for (var n = 0; n < lines.length; n++) {
            const line = lines[n].trim()
            if (line === "") continue

            const loc = line.match(/^local\s+([A-Za-z_]\w*)\s*=\s*"([^"]*)"/)
            if (loc) { locals[loc[1]] = loc[2]; continue }

            const forM = line.match(/^for\s+\w+\s*=\s*(\d+)\s*,\s*(\d+)\s*do/)
            if (forM) {
                loopStart = parseInt(forM[1]); loopEnd = parseInt(forM[2])
                loopLabel = loopEnd === 10 && loopStart === 1 ? "1–0" : loopStart + "–" + loopEnd
                continue
            }
            if (line === "end") { loopLabel = ""; continue }

            if (line.indexOf("hl.bind(") !== 0) continue
            var body = line
            const cIdx = root._commentAt(body)
            if (cIdx !== -1) body = body.substring(0, cIdx).trim()

            const open = body.indexOf("(")
            var depth = 0, inStr = false, close = -1
            for (var c = open; c < body.length; c++) {
                const ch = body[c]
                if (inStr) {
                    if (ch === "\\") { c++; continue }
                    if (ch === '"') inStr = false
                    continue
                }
                if (ch === '"') { inStr = true; continue }
                if (ch === "(") depth++
                else if (ch === ")") { depth--; if (depth === 0) { close = c; break } }
            }
            if (close === -1) continue

            const args = root._splitTop(body.substring(open + 1, close), ",")
            if (args.length < 2) continue

            const key = root._resolveExpr(args[0], locals, loopLabel).replace(/\s*\+\s*/g, " + ").trim()
            const disp = root._inline(args[1].trim(), locals)
            const fl = root._flags(args.slice(2).join(","))
            const cls = root._classify(key, disp, locals)
            const id = file + "|" + key

            if (byKey[id]) {
                byKey[id].dispatchers.push(disp)
                continue
            }
            const e = {
                id: id, file: file, origKey: key, group: cls.group, action: cls.action,
                name: cls.name, desc: cls.desc, icon: cls.icon, dispatchers: [disp],
                locked: fl.locked, repeating: fl.repeating, release: fl.release, mouse: fl.mouse,
                loop: loopLabel !== "", editable: loopLabel === "" && !fl.mouse
            }
            byKey[id] = e
            order.push(e)
        }
        return order
    }

    Instantiator {
        id: readers
        model: root.sources
        delegate: FileView {
            required property var modelData
            path: modelData.path
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                const p = Object.assign({}, root.parsed)
                p[modelData.file] = root.parse(text(), modelData.file)
                root.parsed = p
            }
            onLoadFailed: {
                const p = Object.assign({}, root.parsed)
                p[modelData.file] = []
                root.parsed = p
            }
        }
    }
}
