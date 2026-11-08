pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var list: [
        { id: "phone", name: "Phone", icon: "smartphone", group: "Connect", fresh: false,
          description: "Notifications, calls, files and battery from your phone over KDE Connect",
          tool: "kdeconnect-cli", pkg: "kdeconnect",
          bar: ["phoneStatus", "phoneNotifs", "phoneCall"], widgets: ["showPhone"] },
        { id: "clipboard", name: "Clipboard history", icon: "content_paste", group: "Connect", fresh: true,
          description: "Keeps what you copy so you can paste it again later",
          tool: "cliphist", pkg: "cliphist", bar: ["clipboard"], widgets: [] },
        { id: "wiz", name: "Smart light", icon: "lightbulb", group: "Connect", fresh: false,
          description: "Controls a WiZ bulb on your network and can follow your music",
          bar: ["wiz"], widgets: [] },
        { id: "kindle", name: "Kindle dashboard", icon: "tablet", group: "Connect", fresh: false,
          description: "Serves an e-ink dashboard page to a jailbroken Kindle",
          bar: ["kindle"], widgets: [] },

        { id: "weather", name: "Weather", icon: "partly_cloudy_day", group: "Information", fresh: true,
          description: "Forecast in the bar, on the lock screen and in weather widgets",
          bar: ["weather", "sun"],
          widgets: ["showWeatherHourly", "showSunArc", "showWeatherPoster", "showWeatherHours",
                    "showWeatherDayClock", "showWeatherWind",
                    "showWeatherTileHourly", "showWeatherTileThermo", "showWeatherTileDays", "showWeatherTileWeek",
                    "showWeatherTileStats", "showWeatherTileMini", "showWeatherTileSky", "showWeatherTileList"] },
        { id: "events", name: "Calendar events", icon: "event", group: "Information", fresh: true,
          description: "Events from your online calendars in the calendar and dashboard",
          bar: [], widgets: [] },
        { id: "headlines", name: "Headlines", icon: "newspaper", group: "Information", fresh: false,
          description: "Top news stories on a desktop widget",
          bar: [], widgets: ["showHeadlines"] },
        { id: "claudeCode", name: "Claude Code usage", icon: "terminal", group: "Information", fresh: false,
          description: "Token use and limits from your Claude Code sessions",
          bar: ["claudeCode"], widgets: ["showClaudeCode"] },
        { id: "countdowns", name: "Countdowns", icon: "hourglass_top", group: "Information", fresh: false,
          description: "Countdown and \"a year ago\" widgets from your own dates and photos",
          bar: [], widgets: ["showCountdowns", "showYearAgo"] },
        { id: "screenTime", name: "Screen time", icon: "hourglass", group: "Information", fresh: false,
          description: "Logs which apps you use and for how long, for your profile",
          key: ["general", "screenTimeLog"], bar: [], widgets: [] },

        { id: "books", name: "Book shelf", icon: "auto_stories", group: "Reading and sound", fresh: false,
          description: "Find, download and read books in a reader panel",
          bar: [], widgets: [] },
        { id: "reading", name: "Reading filter", icon: "eyeglasses", group: "Reading and sound", fresh: false,
          description: "Warm, sepia and e-ink screen filters for long reading",
          bar: [], widgets: [] },
        { id: "visualiser", name: "Music visualiser", icon: "graphic_eq", group: "Reading and sound", fresh: true,
          description: "Bars along the screen edge that move with your music",
          tool: "cava", pkg: "cava", key: ["general", "musicVisOn"], bar: [], widgets: [] },
        { id: "soundFx", name: "Sound effects", icon: "equalizer", group: "Reading and sound", fresh: false,
          description: "Equaliser and audio presets through EasyEffects",
          tool: "easyeffects", pkg: "easyeffects", bar: [], widgets: [] },
        { id: "soundscape", name: "Soundscape", icon: "forest", group: "Reading and sound", fresh: false,
          description: "Background loops like rain and a café to mix while you work",
          tool: "mpv", pkg: "mpv", bar: ["soundscape"], widgets: [] },

        { id: "hyprDisplays", name: "Displays", icon: "monitor", group: "Hyprland", fresh: false, hypr: "displays",
          description: "Resolution, refresh rate, scale and arrangement of your screens",
          bar: [], widgets: [] },
        { id: "hyprWindows", name: "Windows", icon: "select_window", group: "Hyprland", fresh: false, hypr: "windows",
          description: "Gaps, borders, rounding, blur and the tiling layout",
          bar: [], widgets: [] },
        { id: "hyprInput", name: "Keyboard & mouse", icon: "mouse", group: "Hyprland", fresh: false, hypr: "input",
          description: "Keyboard layouts, key repeat, pointer speed, touchpad and cursor",
          bar: [], widgets: [] },
        { id: "hyprBinds", name: "Shortcuts", icon: "keyboard", group: "Hyprland", fresh: false, hypr: "binds",
          description: "Change and add Hyprland keybinds",
          bar: [], widgets: [] },

        { id: "notes", name: "Desk notes", icon: "sticky_note_2", group: "Desktop", fresh: true,
          description: "Notes that tuck into the screen edge and slide out when you need them",
          bar: [], widgets: [] },
        { id: "tuck", name: "Window tuck", icon: "tab_unselected", group: "Desktop", fresh: false,
          description: "Tuck windows away into tabs on the screen edge",
          bar: [], widgets: [] },
        { id: "scenes", name: "Desk scenes", icon: "view_quilt", group: "Desktop", fresh: false,
          description: "Save and restore which apps are open and where they sit",
          bar: ["scenes"], widgets: [] },
        { id: "genie", name: "Dock genie", icon: "auto_awesome", group: "Desktop", fresh: false, optIn: true,
          description: "Apps pour out of their dock icon when they open and back into it when they close. Loads the genie Hyprland plugin",
          bar: [], widgets: [] }
    ]

    readonly property var groups: {
        const out = []
        for (const f of root.list)
            if (out.indexOf(f.group) < 0)
                out.push(f.group)
        return out
    }

    readonly property var byId: {
        const out = {}
        for (const f of root.list)
            out[f.id] = f
        return out
    }

    readonly property var _barOwner: {
        const out = {}
        for (const f of root.list)
            for (const b of f.bar)
                out[b] = f.id
        return out
    }

    readonly property var _widgetOwner: {
        const out = {}
        for (const f of root.list)
            for (const w of f.widgets)
                out[w] = f.id
        return out
    }

    readonly property var states: {
        const ready = SettingsConfig.settingsReady
        const saved = SettingsConfig.features ?? {}
        const out = {}
        for (const f of root.list) {
            if (!ready)
                out[f.id] = false
            else if (f.hypr) {
                const t = (SettingsConfig.hypr ?? {}).targets
                out[f.id] = t === undefined || ((t[f.hypr] ?? {}).mode ?? "off") !== "off"
            } else if (f.key)
                out[f.id] = (SettingsConfig[f.key[0]] ?? {})[f.key[1]] ?? true
            else
                out[f.id] = saved[f.id] ?? !f.optIn
        }
        return out
    }

    readonly property bool phone: root.states.phone
    readonly property bool clipboard: root.states.clipboard
    readonly property bool wiz: root.states.wiz
    readonly property bool kindle: root.states.kindle
    readonly property bool weather: root.states.weather
    readonly property bool events: root.states.events
    readonly property bool headlines: root.states.headlines
    readonly property bool claudeCode: root.states.claudeCode
    readonly property bool countdowns: root.states.countdowns
    readonly property bool screenTime: root.states.screenTime
    readonly property bool books: root.states.books
    readonly property bool reading: root.states.reading
    readonly property bool visualiser: root.states.visualiser
    readonly property bool soundFx: root.states.soundFx
    readonly property bool soundscape: root.states.soundscape
    readonly property bool notes: root.states.notes
    readonly property bool tuck: root.states.tuck
    readonly property bool scenes: root.states.scenes
    readonly property bool genie: root.states.genie
    readonly property bool hyprDisplays: root.states.hyprDisplays
    readonly property bool hyprWindows: root.states.hyprWindows
    readonly property bool hyprInput: root.states.hyprInput
    readonly property bool hyprBinds: root.states.hyprBinds

    function on(id) {
        return root.states[id] ?? true
    }

    function set(id, value) {
        const f = root.byId[id]
        if (!f)
            return
        if (f.hypr) {
            const hypr = SettingsConfig.hypr ?? {}
            const all = {}
            for (const g of root.list)
                if (g.hypr)
                    all[g.hypr] = (hypr.targets ?? {})[g.hypr] ?? { mode: hypr.targets === undefined ? "nebula" : "off", file: "" }
            const prev = all[f.hypr]
            all[f.hypr] = value
                ? { mode: prev.lastMode && prev.lastMode !== "off" ? prev.lastMode : (prev.mode !== "off" ? prev.mode : "nebula"), file: prev.file ?? "" }
                : { mode: "off", file: prev.file ?? "", lastMode: prev.mode }
            SettingsConfig.hypr = Object.assign({}, hypr, { targets: all })
            return
        }
        if (f.key) {
            const patch = {}
            patch[f.key[1]] = value
            SettingsConfig[f.key[0]] = Object.assign({}, SettingsConfig[f.key[0]] ?? {}, patch)
            return
        }
        const patch = {}
        patch[id] = value
        SettingsConfig.features = Object.assign({}, SettingsConfig.features ?? {}, patch)
    }

    function barItemOn(itemId) {
        const k = itemId.indexOf("#")
        const owner = root._barOwner[k < 0 ? itemId : itemId.slice(0, k)]
        return owner === undefined || root.on(owner)
    }

    function widgetOn(show) {
        const owner = root._widgetOwner[show]
        return owner === undefined || root.on(owner)
    }

    function freshDefaults() {
        const out = {}
        for (const f of root.list)
            if (!f.key && !f.hypr)
                out[f.id] = f.fresh
        return out
    }

    function freshGeneral(general) {
        const out = Object.assign({}, general ?? {})
        for (const f of root.list)
            if (f.key && f.key[0] === "general")
                out[f.key[1]] = f.fresh
        return out
    }

    property var _last: null
    property bool reloadPending: false
    property bool manageReload: true

    onStatesChanged: root._compare()

    readonly property bool _ready: SettingsConfig.settingsReady
    on_ReadyChanged: if (root._ready) root._last = root.states

    function _compare() {
        const prev = root._last
        if (!root._ready || !prev)
            return
        root._last = root.states
        for (const id in root.states)
            if (prev[id] && !root.states[id])
                root._turnedOff(id)
    }

    function _turnedOff(id) {
        if (!root.manageReload || root.byId[id]?.hypr)
            return
        if (id === "reading" && (SettingsConfig.reading ?? {}).enabled)
            SettingsConfig.reading = Object.assign({}, SettingsConfig.reading, { enabled: false })
        if (id === "soundFx" && (SettingsConfig.general ?? {}).soundFxOn)
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, { soundFxOn: false })
        if (id === "genie")
            Quickshell.execDetached([Quickshell.shellDir + "/plugins/HyprGenie/genie-ctl.sh", "unload"])
        root.reloadPending = true
        root._maybeReload()
    }

    readonly property bool _settingsOpen: GlobalStates.settingsOpen
    on_SettingsOpenChanged: root._maybeReload()

    function _maybeReload() {
        if (root.reloadPending && !root._settingsOpen)
            reloadTimer.restart()
    }

    Timer {
        id: reloadTimer
        interval: 2000
        onTriggered: {
            if (root._settingsOpen)
                return
            root.reloadPending = false
            Quickshell.reload(false)
        }
    }

    property var installed: ({})
    property bool toolsChecked: false

    function missingTool(id) {
        const f = root.byId[id]
        return !!(f && f.tool && root.toolsChecked && !root.installed[f.tool])
    }

    Process {
        running: true
        command: ["sh", "-c", "for t in \"$@\"; do command -v \"$t\" >/dev/null 2>&1 && echo \"$t\"; done", "sh"]
            .concat(root.list.filter(f => f.tool).map(f => f.tool))
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {}
                for (const t of text.split("\n"))
                    if (t.trim() !== "")
                        found[t.trim()] = true
                root.installed = found
                root.toolsChecked = true
                if (SettingsConfig.freshInstall)
                    for (const f of root.list)
                        if (f.tool && !found[f.tool] && root.on(f.id))
                            root.set(f.id, false)
            }
        }
    }
}
