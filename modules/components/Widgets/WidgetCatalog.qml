pragma Singleton

import Quickshell
import QtQuick
import qs.modules.settings
import qs.modules.utils

Singleton {
    id: root

    Component.onCompleted: {
        EditSession.namers.widget = key => {
            const f = root.familyFor(key)
            return f ? (f.items.length > 1 ? f.section : f.items[0].label) : key
        }
        EditSession.namers.widgetShow = show => {
            for (const sec of root.catalog) {
                const it = sec.items.find(i => i.show === show)
                if (it)
                    return sec.items.filter(i => i.show === show).length > 1 ? sec.section : it.label
            }
            return show.replace(/^show/, "")
        }
        EditSession.searchers.widgets = q => {
            let n = 0
            for (const sec of root.catalog)
                for (const it of sec.items)
                    if (it.label.toLowerCase().indexOf(q) >= 0 || sec.section.toLowerCase().indexOf(q) >= 0)
                        n++
            return n
        }
    }

    readonly property Component cProfileBadge:   Component { ProfileBadgeWidget   { preview: true } }
    readonly property Component cProfileDay:     Component { ProfileDayWidget     { preview: true } }
    readonly property Component cProfileStatus:  Component { ProfileStatusWidget  { preview: true } }
    readonly property Component cProfileMachine: Component { ProfileMachineWidget { preview: true } }
    readonly property Component cProfileShape:   Component { ProfileShapeWidget   { preview: true } }
    readonly property Component cProfileRings:   Component { ProfileRingsWidget   { preview: true } }
    readonly property Component cPhotoFrame:    Component { PhotoFrameWidget       { preview: true } }
    readonly property Component cClockVeil:      Component { ClockVeil      { preview: true } }
    readonly property Component cClockBloom:     Component { ClockBloom     { preview: true } }
    readonly property Component cClockOrbit:     Component { ClockOrbit     { preview: true } }
    readonly property Component cClockScript:    Component { ClockScript    { preview: true } }
    readonly property Component cClockStack:     Component { ClockStack     { preview: true } }
    readonly property Component cClockCondensed: Component { ClockCondensed { preview: true } }
    readonly property Component cClockDisplay:   Component { ClockDisplay   { preview: true } }
    readonly property Component cAnalogClassic: Component { AnalogClockClassic     { preview: true } }
    readonly property Component cAnalogMinimal: Component { AnalogClockMinimal     { preview: true } }
    readonly property Component cAnalogShape:   Component { AnalogClockShape       { preview: true } }
    readonly property Component cWeatherHourly: Component { WeatherHourlyWidget    { preview: true } }
    readonly property Component cWeatherPoster:   Component { WeatherPosterWidget   { preview: true } }
    readonly property Component cWeatherHours:    Component { WeatherHoursWidget    { preview: true } }
    readonly property Component cWeatherDayClock: Component { WeatherDayClockWidget { preview: true } }
    readonly property Component cWeatherWind:     Component { WeatherWindWidget     { preview: true } }
    readonly property Component cSunArc:        Component { SunArcWidget           { preview: true } }
    readonly property Component cClaudeCode:    Component { ClaudeCodeWidget       { preview: true } }
    readonly property Component cYearAgo: Component { YearAgoWidget { preview: true } }
    readonly property Component cPhone: Component { PhoneWidget { preview: true } }
    readonly property Component cCountdowns: Component { CountdownsWidget { preview: true } }
    readonly property Component cMusicExpressive: Component { MusicExpressiveWidget { preview: true } }
    readonly property Component cMusicTicket: Component { MusicTicketWidget { preview: true } }
    readonly property Component cMusicDisc: Component { MusicDiscWidget { preview: true } }
    readonly property Component cMusicDeck: Component { MusicDeckWidget { preview: true } }
    readonly property Component cMusicRail: Component { MusicRailWidget { preview: true } }
    readonly property Component cMusicPulse: Component { MusicPulseWidget { preview: true } }
    readonly property Component cStickyNote:    Component { StickyNoteWidget       { preview: true } }
    readonly property Component cCalendarMini:  Component { CalendarMiniWidget    { preview: true } }
    readonly property Component cCalendarYarn:  Component { CalendarYarnWidget    { preview: true } }
    readonly property Component cCalendarAlm:   Component { CalendarAlmanacWidget { preview: true } }
    readonly property Component cCalendarWindows: Component { CalendarWindowsWidget { preview: true } }
    readonly property Component cCalendarYear: Component { CalendarYearWidget { preview: true } }
    readonly property Component cCalendarMoon: Component { CalendarMoonWidget { preview: true } }
    readonly property Component cPomodoro:      Component { PomodoroWidget         { preview: true } }
    readonly property Component cWorldClock:    Component { WorldClockWidget       { preview: true } }
    readonly property Component cHeadlines:     Component { HeadlinesWidget        { preview: true } }
    readonly property Component cSysPulse:      Component { SystemMonitorPulse     { preview: true } }
    readonly property Component cSysCores: Component { SysCoresWidget { preview: true } }
    readonly property Component cSysQuad: Component { SysQuadWidget { preview: true } }
    readonly property Component cSysChrono: Component { SysChronoWidget { preview: true } }
    readonly property Component cSysSilhouette: Component { SysSilhouetteWidget { preview: true } }
    readonly property Component cSysMemory: Component { SysMemoryWidget { preview: true } }
    readonly property Component cSysBattery: Component { SysBatteryWidget { preview: true } }
    readonly property Component cSysThermals: Component { SysThermalsWidget { preview: true } }
    readonly property Component cSysNet: Component { SysNetWidget { preview: true } }
    readonly property Component cSysOrbit: Component { SysOrbitWidget { preview: true } }

    // show      — the SettingsConfig.widgets key that turns the family on
    // styleKey  — the key holding which variant is active (omitted if only one)
    // style     — this card's variant value
    // def       — the family's default variant, for the ?? fallback
    readonly property var catalog: [
        { section: "Personal", icon: "person", items: [
            { label: "Badge", key: "profileBadge", comp: root.cProfileBadge, show: "showProfileBadge" },
            { label: "Your day", key: "profileDay", comp: root.cProfileDay, show: "showProfileDay" },
            { label: "Status", key: "profileStatus", comp: root.cProfileStatus, show: "showProfileStatus" },
            { label: "Machine", key: "profileMachine", comp: root.cProfileMachine, show: "showProfileMachine" },
            { label: "Shape", key: "profileShape", comp: root.cProfileShape, show: "showProfileShape" },
            { label: "Rings", key: "profileRings", comp: root.cProfileRings, show: "showProfileRings" },
            { label: "Photo Frame", key: "photoFrame", comp: root.cPhotoFrame, show: "showPhotoFrame" },
            { label: "A year ago", key: "yearAgo", comp: root.cYearAgo, show: "showYearAgo" },
            { label: "Phone", key: "phone", comp: root.cPhone, show: "showPhone" },
            { label: "Countdowns", key: "countdowns", comp: root.cCountdowns, show: "showCountdowns" }
        ]},
        { section: "Music", icon: "music_note", items: [
            { label: "Expressive", key: "musicExpressive", comp: root.cMusicExpressive, show: "showMusicExpressive" },
            { label: "Ticket", key: "musicTicket", comp: root.cMusicTicket, show: "showMusicTicket" },
            { label: "Morph Disc", key: "musicDisc", comp: root.cMusicDisc, show: "showMusicDisc" },
            { label: "Button Deck", key: "musicDeck", comp: root.cMusicDeck, show: "showMusicDeck" },
            { label: "Rail", key: "musicRail", comp: root.cMusicRail, show: "showMusicRail" },
            { label: "Pulse", key: "musicPulse", comp: root.cMusicPulse, show: "showMusicPulse" }
        ]},
        { section: "Digital Clock", icon: "schedule", items: [
            { label: "Veil",      key: "clock", comp: root.cClockVeil,      show: "showClock", styleKey: "digitalClockStyle", style: "veil",      def: "veil" },
            { label: "Bloom",     key: "clock", comp: root.cClockBloom,     show: "showClock", styleKey: "digitalClockStyle", style: "bloom",     def: "veil" },
            { label: "Orbit",     key: "clock", comp: root.cClockOrbit,     show: "showClock", styleKey: "digitalClockStyle", style: "orbit",     def: "veil" },
            { label: "Script",    key: "clock", comp: root.cClockScript,    show: "showClock", styleKey: "digitalClockStyle", style: "script",    def: "veil" },
            { label: "Stack",     key: "clock", comp: root.cClockStack,     show: "showClock", styleKey: "digitalClockStyle", style: "stack",     def: "veil" },
            { label: "Condensed", key: "clock", comp: root.cClockCondensed, show: "showClock", styleKey: "digitalClockStyle", style: "condensed", def: "veil" },
            { label: "Display",   key: "clock", comp: root.cClockDisplay,   show: "showClock", styleKey: "digitalClockStyle", style: "display",   def: "veil" }
        ]},
        { section: "Analog Clock", icon: "watch", items: [
            { label: "Classic", key: "analogClock", comp: root.cAnalogClassic, show: "showAnalogClock", styleKey: "analogClockStyle", style: "classic", def: "classic" },
            { label: "Minimal", key: "analogClock", comp: root.cAnalogMinimal, show: "showAnalogClock", styleKey: "analogClockStyle", style: "minimal", def: "classic" },
            { label: "Shape",   key: "analogClock", comp: root.cAnalogShape,   show: "showAnalogClock", styleKey: "analogClockStyle", style: "shape",   def: "classic" }
        ]},
        { section: "Weather", icon: "partly_cloudy_day", items: [
            { label: "Hourly",   key: "weatherHourly",    comp: root.cWeatherHourly, show: "showWeatherHourly" },
            { label: "Sun Arc",  key: "sunArc",           comp: root.cSunArc,        show: "showSunArc" },
            { label: "Poster",   key: "weatherPoster",    comp: root.cWeatherPoster, show: "showWeatherPoster" },
            { label: "Hours",    key: "weatherHours",     comp: root.cWeatherHours,  show: "showWeatherHours" },
            { label: "Day Clock", key: "weatherDayClock", comp: root.cWeatherDayClock, show: "showWeatherDayClock" },
            { label: "Wind",     key: "weatherWind",      comp: root.cWeatherWind,   show: "showWeatherWind" }
        ]},
        { section: "Calendar", icon: "calendar_month", items: [
            { label: "Mini",    key: "calendarMini",    comp: root.cCalendarMini, show: "showCalendarMini" },
            { label: "Yarn",    key: "calendarYarn",    comp: root.cCalendarYarn, show: "showCalendarYarn" },
            { label: "Almanac", key: "calendarAlmanac", comp: root.cCalendarAlm,  show: "showCalendarAlmanac" },
            { label: "Windows", key: "calendarWindows", comp: root.cCalendarWindows, show: "showCalendarWindows" },
            { label: "Year", key: "calendarYear", comp: root.cCalendarYear, show: "showCalendarYear" },
            { label: "Moon", key: "calendarMoon", comp: root.cCalendarMoon, show: "showCalendarMoon" }
        ]},
        { section: "Productivity", icon: "task_alt", items: [
            { label: "Claude Code", key: "claudeCode", comp: root.cClaudeCode, show: "showClaudeCode" },
            { label: "Note",        key: "stickyNote", comp: root.cStickyNote, show: "showStickyNote" },
            { label: "Pomodoro",    key: "pomodoro",   comp: root.cPomodoro,   show: "showPomodoro" },
            { label: "World Clock", key: "worldClock", comp: root.cWorldClock, show: "showWorldClock" }
        ]},
        { section: "News", icon: "newspaper", items: [
            { label: "Headlines", key: "headlines", comp: root.cHeadlines, show: "showHeadlines" }
        ]},
        { section: "System", icon: "memory", items: [
            { label: "Pulse", key: "sysMonitor", comp: root.cSysPulse, show: "showSystemMonitor" },
            { label: "Core Garden", key: "sysCores", comp: root.cSysCores, show: "showSysCores" },
            { label: "Quad Shapes", key: "sysQuad", comp: root.cSysQuad, show: "showSysQuad" },
            { label: "Memory Pill", key: "sysMemory", comp: root.cSysMemory, show: "showSysMemory" },
            { label: "Battery Capsule", key: "sysBattery", comp: root.cSysBattery, show: "showSysBattery" },
            { label: "Thermals", key: "sysThermals", comp: root.cSysThermals, show: "showSysThermals" },
            { label: "Net Tide", key: "sysNet", comp: root.cSysNet, show: "showSysNet" },
            { label: "Orbit", key: "sysOrbit", comp: root.cSysOrbit, show: "showSysOrbit" },
            { label: "Chrono", key: "sysChrono", comp: root.cSysChrono, show: "showSysChrono" },
            { label: "Silhouette", key: "sysSilhouette", comp: root.cSysSilhouette, show: "showSysSilhouette" }
        ]}
    ]

    function tileSize(item) {
        let probe = null
        try {
            probe = item.comp.createObject(null)
            if (probe && probe.implicitWidth > 0 && probe.implicitHeight > 0)
                return Qt.size(probe.implicitWidth, probe.implicitHeight)
        } catch (e) {
        } finally {
            if (probe) probe.destroy()
        }
        return WidgetSizes.small
    }

    function place(item, w, h) {
        root._land(item, WidgetLayout.firstFree(w, h))
    }

    function placeAt(item, col, halfRow, w, h) {
        root._land(item, WidgetLayout.spotAt(col, halfRow, w, h))
    }

    function _land(item, p) {
        const patch = {}
        patch[item.show] = true
        if (item.styleKey) patch[item.styleKey] = item.style
        patch[item.key + "X"] = p.x
        patch[item.key + "Y"] = p.y
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function familyOn(item) {
        return SettingsConfig.widgets[item.show] ?? false
    }

    function familyFor(key) {
        for (let s = 0; s < root.catalog.length; s++) {
            const items = root.catalog[s].items.filter(i => i.key === key)
            if (items.length > 0) return { section: root.catalog[s].section, items: items }
        }
        return null
    }

    readonly property var _legacyStyles: ({
        "digitalClockStyle": { "shapes": "bloom", "stacked": "stack" }
    })

    function styleValue(item) {
        const raw = SettingsConfig.widgets[item.styleKey] ?? item.def
        const map = root._legacyStyles[item.styleKey]
        if (!map)
            return raw
        if (map[raw] !== undefined)
            return map[raw]
        const known = root.catalog.some(sec => sec.items.some(i => i.styleKey === item.styleKey && i.style === raw))
        return known ? raw : item.def
    }

    function isActive(item) {
        if (!(SettingsConfig.widgets[item.show] ?? false)) return false
        if (!item.styleKey) return true
        return root.styleValue(item) === item.style
    }

    function selectStyle(item) {
        const patch = {}
        patch[item.show] = true
        if (item.styleKey) patch[item.styleKey] = item.style
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function remove(key) {
        const family = root.familyFor(key)
        if (!family) return
        const patch = {}
        patch[family.items[0].show] = false
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function resetLayout(key) {
        const next = Object.assign({}, SettingsConfig.widgets)
        delete next[key + "X"]
        delete next[key + "Y"]
        delete next[key + "W"]
        delete next[key + "H"]
        delete next[key + "Turned"]
        SettingsConfig.widgets = next
    }
}
