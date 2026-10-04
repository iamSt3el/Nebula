pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.modules.utils
import qs.modules.settings

// Parses the launcher query into a mode + term and produces the results for
// every non-app mode. App mode stays in ServiceApps and keeps its own
// DesktopEntry-shaped model, because the app list needs pinning, categories
// and the context menu that a normalised result object can't carry.
//
// Results here are normalised to:
//   { key, title, subtitle, glyph, symbol, iconName, payload, action }
// where `action` is one of "copy" | "run" | "run-term" | "focus", and `payload`
// is what that action consumes. The views stay dumb; activate() does the work.
Singleton {
    id: root

    // ── Mode table ────────────────────────────────────────────────────────────
    readonly property var modes: [
        { id: "calc", key: "launcherCalc",    prefix: "=", label: "Calc",    icon: "calculate",     hint: "1920*0.15 · 100 usd to inr" },
        { id: "run", key: "launcherRun",     prefix: ">", label: "Run",     icon: "terminal",      hint: "shell command" },
        { id: "emoji", key: "launcherEmoji",   prefix: ":", label: "Emoji",   icon: "mood",          hint: "fire · rocket · thumbsup" },
        { id: "windows", key: "launcherWindows", prefix: "w", label: "Windows", icon: "select_window", hint: "open windows" }
    ]

    readonly property var _g: SettingsConfig.general ?? ({})
    readonly property string position: root._g.launcherPosition ?? "edge"
    readonly property var styles: [
        { value: "spotlight",  label: "Spotlight",  icon: "search",            w: 680, h: 560 },
        { value: "rail",       label: "Rail",       icon: "view_sidebar",      w: 560, h: 720 },
        { value: "bento",      label: "Bento",      icon: "dashboard",         w: 900, h: 660 },
        { value: "folders",    label: "Folders",    icon: "folder",            w: 460, h: 720 },
        { value: "list",       label: "List",       icon: "lists",             w: 440, h: 720 },
        { value: "expressive", label: "Expressive", icon: "interests",         w: 460, h: 760 },
        { value: "hearth",     label: "Hearth",     icon: "fireplace",         w: 660, h: 720 }
    ]

    readonly property string style: {
        const s = root._g.launcherStyle ?? "list"
        return root.styles.some(x => x.value === s) ? s : "list"
    }
    readonly property var styleSpec: root.styles.find(x => x.value === root.style)
    readonly property int defaultWidth: root.styleSpec.w
    readonly property int defaultHeight: root.styleSpec.h
    readonly property int minWidth: 320
    readonly property int maxWidth: 1200
    readonly property int minHeight: 360
    readonly property int maxHeight: 1200
    readonly property var savedSize: (root._g.launcherSizes ?? {})[root.style] ?? null
    property var draft: null
    readonly property int panelWidth: root.draft ? root.draft.w
        : root.savedSize && typeof root.savedSize.w === "number" ? root.clampW(root.savedSize.w) : root.defaultWidth
    readonly property int panelHeight: root.draft ? root.draft.h
        : root.savedSize && typeof root.savedSize.h === "number" ? root.clampH(root.savedSize.h) : root.defaultHeight
    readonly property bool customSize: root.savedSize !== null

    function clampW(w) {
        return Math.round(Math.max(root.minWidth, Math.min(root.maxWidth, w)))
    }

    function clampH(h) {
        return Math.round(Math.max(root.minHeight, Math.min(root.maxHeight, h)))
    }

    function setSize(w, h) {
        const all = Object.assign({}, root._g.launcherSizes ?? {})
        const cw = root.clampW(w)
        const ch = root.clampH(h)
        if (cw === root.defaultWidth && ch === root.defaultHeight) delete all[root.style]
        else all[root.style] = { w: cw, h: ch }
        root.draft = null
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { launcherSizes: all })
    }

    function clearSize() {
        root.draft = null
        if (!root.customSize) return
        const all = Object.assign({}, root._g.launcherSizes ?? {})
        delete all[root.style]
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { launcherSizes: all })
    }
    readonly property real radius: (root._g.launcherRadius ?? -1) < 0
        ? ((SettingsConfig.bar ?? {}).radius ?? 18) : root._g.launcherRadius
    readonly property int iconSize: root._g.launcherIconSize ?? 30

    readonly property var _styleIconSizes: ({
        spotlight: [60, 32], rail: [root.iconSize + 12, 28], bento: [40, 32, 28], folders: [34],
        list: [root.iconSize], expressive: [48, root.iconSize + 10], hearth: [root.iconSize + 2, 42]
    })
    property var _iconSizes: []
    property var _iconQueue: []
    property var _iconKept: ({})

    function noteIconSize(size) {
        const s = Math.round(size)
        if (s <= 0 || root._iconSizes.indexOf(s) >= 0)
            return
        root._iconSizes.push(s)
        root._queueIcons(s)
    }

    function _queueIcons(size) {
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; i++) {
            const icon = apps[i].icon ?? ""
            if (icon !== "" && !root._iconKept[icon + "@" + size])
                root._iconQueue.push({ icon: icon, size: size })
        }
        if (root._iconQueue.length > 0)
            iconTimer.start()
    }

    Item { id: iconShelf }

    Component {
        id: iconKeeper
        Image { visible: false }
    }

    Timer {
        id: iconTimer
        interval: 40
        repeat: true
        onTriggered: {
            const job = root._iconQueue.shift()
            if (!job) {
                iconTimer.stop()
                return
            }
            const key = job.icon + "@" + job.size
            if (root._iconKept[key])
                return
            root._iconKept[key] = iconKeeper.createObject(iconShelf, {
                source: IconUtil.getDesktopIconPath(job.icon),
                sourceSize: Qt.size(job.size, job.size)
            })
        }
    }

    Timer {
        id: iconWarmup
        interval: 4000
        running: true
        onTriggered: {
            const sizes = (root._styleIconSizes[root.style] ?? [root.iconSize + 8]).concat(root._iconSizes)
            root._iconSizes = []
            for (let i = 0; i < sizes.length; i++)
                root.noteIconSize(sizes[i])
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { iconWarmup.restart() }
    }
    readonly property string sortMode: root._g.launcherSort ?? "az"
    readonly property var enabledModes: root.modes.filter(m => root._g[m.key] ?? true)
    readonly property string hint: "Search apps" + root.enabledModes.map(m => "   " + m.prefix + "\u2009" + m.label.toLowerCase()).join("")

    // `w` is a bare letter, so it only counts as a prefix when followed by a
    // space — otherwise "wezterm" would never reach app search.
    function _prefixOf(q) {
        if (q.length === 0) return null
        for (const m of root.enabledModes) {
            if (m.prefix === "w") {
                if (q === "w " || q.startsWith("w ")) return m
            } else if (q.startsWith(m.prefix)) {
                return m
            }
        }
        return null
    }

    property string query: ""

    readonly property var activeMode: _prefixOf(query)
    readonly property string mode: activeMode ? activeMode.id : "apps"
    readonly property string term: {
        if (!activeMode) return query
        return query.slice(activeMode.prefix.length).trim()
    }

    property var results: []

    onQueryChanged: _recompute()

    function _recompute() {
        switch (root.mode) {
        case "calc":    calcDebounce.restart();     break
        case "run":     results = _runResults();    break
        case "emoji":   results = _emojiResults();  break
        case "windows": results = _windowResults(); break
        default:        results = []
        }
    }

    // ── Calculator (qalc) ─────────────────────────────────────────────────────
    // qalc always exits 0 and always prints something, so there is no error
    // channel to test — a nonsense expression just yields a nonsense result.
    // The view shows whatever came back and lets the user judge it.
    property string calcResult: ""

    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            if (root.term.length === 0) {
                root.calcResult = ""
                root.results = []
                return
            }
            calcProc.running = false
            calcProc.command = ["qalc", "-t", "-e", root.term]
            calcProc.running = true
        }
    }

    Process {
        id: calcProc

        stdout: StdioCollector {
            onStreamFinished: {
                // A stale result can land after the user has switched modes.
                if (root.mode !== "calc") return

                root.calcResult = text.trim()
                root.results = root.calcResult.length > 0
                    ? [{
                        key: "calc",
                        title: root.calcResult,
                        subtitle: root.term,
                        glyph: "",
                        symbol: "calculate",
                        iconName: "",
                        payload: root.calcResult,
                        action: "copy"
                    }]
                    : []
            }
        }
    }

    // ── Run ───────────────────────────────────────────────────────────────────
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    function _runResults() {
        if (root.term.length === 0) return []
        return [
            {
                key: "run",
                title: root.term,
                subtitle: "Run command",
                glyph: "", symbol: "terminal", iconName: "",
                payload: root.term,
                action: "run"
            },
            {
                key: "run-term",
                title: root.term,
                subtitle: "Run in " + root.terminal + ", keep output open",
                glyph: "", symbol: "dock_to_bottom", iconName: "",
                payload: root.term,
                action: "run-term"
            }
        ]
    }

    // ── Emoji ─────────────────────────────────────────────────────────────────
    // Data from assets/emoji.json. The JSON parse is cheap, but
    // Fuzzy.prepare over ~1500 entries is not, so that part stays lazy — same
    // approach as ServiceApps._ensurePrepared().
    property var _emoji: []
    property var _emojiPrepped: null

    FileView {
        id: emojiFile
        path: Quickshell.env("HOME") + "/.config/quickshell/assets/emoji.json"
        onLoaded: {
            try {
                root._emoji = JSON.parse(text())
            } catch (e) {
                console.warn("[ServiceLauncher] could not parse emoji.json:", e)
                root._emoji = []
            }
            root._emojiPrepped = null
        }
        onLoadFailed: {
            console.warn("[ServiceLauncher] emoji.json missing")
            root._emoji = []
        }
    }

    function _ensureEmojiPrepared() {
        if (!root._emojiPrepped)
            root._emojiPrepped = root._emoji.map(e => ({ kw: Fuzzy.prepare(e.kw), item: e }))
        return root._emojiPrepped
    }

    function _emojiPick(list) {
        return list.map(e => ({
            key: "emoji-" + e.ch,
            title: e.ch,
            subtitle: e.name,
            glyph: e.ch,
            symbol: "", iconName: "",
            payload: e.ch,
            action: "copy"
        }))
    }

    function _emojiResults() {
        if (root._emoji.length === 0) return []
        if (root.term.length === 0) return _emojiPick(root._emoji.slice(0, 200))

        return _emojiPick(
            Fuzzy.go(root.term, _ensureEmojiPrepared(), { all: true, key: "kw", limit: 200 })
                .map(r => r.obj.item)
        )
    }

    // ── Windows ───────────────────────────────────────────────────────────────
    function _windowResults() {
        const wins = Array.from(ToplevelManager.toplevels.values)
            .filter(t => (t.appId ?? "").length > 0)

        const needle = root.term.toLowerCase()
        const matched = needle.length === 0 ? wins : wins.filter(t => {
            return ((t.appId ?? "") + " " + (t.title ?? "")).toLowerCase().includes(needle)
        })

        return matched.map((t, i) => ({
            key: "win-" + i + "-" + (t.appId ?? ""),
            title: (t.title && t.title.length > 0) ? t.title : t.appId,
            subtitle: t.appId,
            glyph: "", symbol: "select_window",
            iconName: t.appId,
            payload: t,
            action: "focus"
        }))
    }

    // ── Activation ────────────────────────────────────────────────────────────
    // Returns true when the launcher should close.
    function activate(result): bool {
        if (!result) return false

        switch (result.action) {
        case "copy":
            Quickshell.clipboardText = result.payload
            return true

        case "run":
            ServiceApps.spawn(["bash", "-lc", result.payload], "")
            return true

        case "run-term":
            ServiceApps.spawn([
                root.terminal, "-e", "bash", "-lc",
                result.payload + "; echo; read -n1 -r -p 'press any key…'"
            ], "")
            return true

        case "focus":
            if (result.payload) result.payload.activate()
            return true
        }
        return false
    }

    function reset() {
        root.query = ""
        root.results = []
        root.calcResult = ""
    }
}
