pragma Singleton

import Quickshell
import QtQuick
import qs.modules.settings
import qs.modules.utils

Singleton {
    id: root

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
    readonly property Component cAnalogClassic: Component { AnalogClockClassic     { preview: true } }
    readonly property Component cAnalogMinimal: Component { AnalogClockMinimal     { preview: true } }
    readonly property Component cAnalogShape:   Component { AnalogClockShape       { preview: true } }
    readonly property Component cDateBold:      Component { DateWidgetBold         { preview: true } }
    readonly property Component cDateAccent:    Component { DateWidgetAccent       { preview: true } }
    readonly property Component cDateShape:     Component { DateWidgetShape        { preview: true } }
    readonly property Component cWeatherCast:   Component { WeatherWidgetForecast  { preview: true } }
    readonly property Component cWeatherHourly: Component { WeatherHourlyWidget    { preview: true } }
    readonly property Component cSunArc:        Component { SunArcWidget           { preview: true } }
    readonly property Component cMoonPhase:     Component { MoonPhaseWidget        { preview: true } }
    readonly property Component cWeatherShape:  Component { WeatherShapeWidget     { preview: true } }
    readonly property Component cClaudeCode:    Component { ClaudeCodeWidget       { preview: true } }
    readonly property Component cTaskList:      Component { TaskListWidget         { preview: true } }
    readonly property Component cCommitGarden: Component { CommitGardenWidget { preview: true } }
    readonly property Component cNotebook: Component { NotebookWidget { preview: true } }
    readonly property Component cTerminalStats: Component { TerminalStatsWidget { preview: true } }
    readonly property Component cMostOpened: Component { MostOpenedWidget { preview: true } }
    readonly property Component cYearAgo: Component { YearAgoWidget { preview: true } }
    readonly property Component cPhone: Component { PhoneWidget { preview: true } }
    readonly property Component cHabits: Component { HabitsWidget { preview: true } }
    readonly property Component cCountdowns: Component { CountdownsWidget { preview: true } }
    readonly property Component cMood: Component { MoodWidget { preview: true } }
    readonly property Component cSysCockpit: Component { SysCockpitWidget { preview: true } }
    readonly property Component cSysBlueprint: Component { SysBlueprintWidget { preview: true } }
    readonly property Component cSysVitals: Component { SysVitalsWidget { preview: true } }
    readonly property Component cSysForecast: Component { SysForecastWidget { preview: true } }
    readonly property Component cSysFlask: Component { SysFlaskWidget { preview: true } }
    readonly property Component cLavaLamp: Component { LavaLampWidget { preview: true } }
    readonly property Component cSysThermo: Component { SysThermoWidget { preview: true } }
    readonly property Component cSysCreature: Component { SysCreatureWidget { preview: true } }
    readonly property Component cDayRibbon: Component { DayRibbonWidget { preview: true } }
    readonly property Component cSysCells: Component { SysCellsWidget { preview: true } }
    readonly property Component cSysShape: Component { SysShapeWidget { preview: true } }
    readonly property Component cSysHourglass: Component { SysHourglassWidget { preview: true } }
    readonly property Component cSysFillNumber: Component { SysFillNumberWidget { preview: true } }
    readonly property Component cMusicExpressive: Component { MusicExpressiveWidget { preview: true } }
    readonly property Component cMusicTicket: Component { MusicTicketWidget { preview: true } }
    readonly property Component cMusicPoster: Component { MusicPosterWidget { preview: true } }
    readonly property Component cMusicTuner: Component { MusicTunerWidget { preview: true } }
    readonly property Component cMusicWaveform: Component { MusicWaveformWidget { preview: true } }
    readonly property Component cMusicSpectrum: Component { MusicSpectrumWidget { preview: true } }
    readonly property Component cMusicLyrics: Component { MusicLyricsWidget { preview: true } }
    readonly property Component cMusicCapsule: Component { MusicCapsuleWidget { preview: true } }
    readonly property Component cMusicGlance: Component { MusicGlanceWidget { preview: true } }
    readonly property Component cMusicFlap: Component { MusicFlapWidget { preview: true } }
    readonly property Component cMusicBento: Component { MusicBentoWidget { preview: true } }
    readonly property Component cMusicRibbon: Component { MusicRibbonWidget { preview: true } }
    readonly property Component cMusicNeon: Component { MusicNeonWidget { preview: true } }
    readonly property Component cMusicTerminal: Component { MusicTerminalWidget { preview: true } }
    readonly property Component cStickyNote:    Component { StickyNoteWidget       { preview: true } }
    readonly property Component cCalendarMini:  Component { CalendarMiniWidget    { preview: true } }
    readonly property Component cCalendarYarn:  Component { CalendarYarnWidget    { preview: true } }
    readonly property Component cCalendarAlm:   Component { CalendarAlmanacWidget { preview: true } }
    readonly property Component cCalendarTorn:  Component { CalendarTornWidget    { preview: true } }
    readonly property Component cCalendarWindows: Component { CalendarWindowsWidget { preview: true } }
    readonly property Component cCalendarDaylight: Component { CalendarDaylightWidget { preview: true } }
    readonly property Component cCalendarYear: Component { CalendarYearWidget { preview: true } }
    readonly property Component cCalendarStamp: Component { CalendarStampWidget { preview: true } }
    readonly property Component cCalendarMoon: Component { CalendarMoonWidget { preview: true } }
    readonly property Component cPomodoro:      Component { PomodoroWidget         { preview: true } }
    readonly property Component cWorldClock:    Component { WorldClockWidget       { preview: true } }
    readonly property Component cHeadlines:     Component { HeadlinesWidget        { preview: true } }
    readonly property Component cSysDefault:    Component { SystemMonitorWidget    { preview: true } }
    readonly property Component cSysCompact:    Component { SystemMonitorCompact   { preview: true } }
    readonly property Component cSysPulse:      Component { SystemMonitorPulse     { preview: true } }
    readonly property Component cBattRing:      Component { BatteryWidgetRing      { preview: true } }
    readonly property Component cBattShape:     Component { BatteryWidgetShape     { preview: true } }
    readonly property Component cNetGraph:      Component { NetworkGraphWidget     { preview: true } }

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
            { label: "Commit garden", key: "commitGarden", comp: root.cCommitGarden, show: "showCommitGarden" },
            { label: "Notebook", key: "notebook", comp: root.cNotebook, show: "showNotebook" },
            { label: "Terminal", key: "terminalStats", comp: root.cTerminalStats, show: "showTerminalStats" },
            { label: "Most opened", key: "mostOpened", comp: root.cMostOpened, show: "showMostOpened" },
            { label: "A year ago", key: "yearAgo", comp: root.cYearAgo, show: "showYearAgo" },
            { label: "Phone", key: "phone", comp: root.cPhone, show: "showPhone" },
            { label: "Habits", key: "habits", comp: root.cHabits, show: "showHabits" },
            { label: "Countdowns", key: "countdowns", comp: root.cCountdowns, show: "showCountdowns" },
            { label: "Mood", key: "mood", comp: root.cMood, show: "showMood" }
        ]},
        { section: "Music", icon: "music_note", items: [
            { label: "Expressive", key: "musicExpressive", comp: root.cMusicExpressive, show: "showMusicExpressive" },
            { label: "Ticket", key: "musicTicket", comp: root.cMusicTicket, show: "showMusicTicket" },
            { label: "Poster", key: "musicPoster", comp: root.cMusicPoster, show: "showMusicPoster" },
            { label: "Radio Tuner", key: "musicTuner", comp: root.cMusicTuner, show: "showMusicTuner" },
            { label: "Waveform", key: "musicWaveform", comp: root.cMusicWaveform, show: "showMusicWaveform" },
            { label: "Spectrum", key: "musicSpectrum", comp: root.cMusicSpectrum, show: "showMusicSpectrum" },
            { label: "Lyrics", key: "musicLyrics", comp: root.cMusicLyrics, show: "showMusicLyrics" },
            { label: "Capsule", key: "musicCapsule", comp: root.cMusicCapsule, show: "showMusicCapsule" },
            { label: "Glance Line", key: "musicGlance", comp: root.cMusicGlance, show: "showMusicGlance" },
            { label: "Split-Flap", key: "musicFlap", comp: root.cMusicFlap, show: "showMusicFlap" },
            { label: "Bento", key: "musicBento", comp: root.cMusicBento, show: "showMusicBento" },
            { label: "Edge Ribbon", key: "musicRibbon", comp: root.cMusicRibbon, show: "showMusicRibbon" },
            { label: "Neon Sign", key: "musicNeon", comp: root.cMusicNeon, show: "showMusicNeon" },
            { label: "Terminal", key: "musicTerminal", comp: root.cMusicTerminal, show: "showMusicTerminal" }
        ]},
        { section: "Digital Clock", icon: "schedule", items: [
            { label: "Veil",      key: "clock", comp: root.cClockVeil,      show: "showClock", styleKey: "digitalClockStyle", style: "veil",      def: "veil" },
            { label: "Bloom",     key: "clock", comp: root.cClockBloom,     show: "showClock", styleKey: "digitalClockStyle", style: "bloom",     def: "veil" },
            { label: "Orbit",     key: "clock", comp: root.cClockOrbit,     show: "showClock", styleKey: "digitalClockStyle", style: "orbit",     def: "veil" },
            { label: "Script",    key: "clock", comp: root.cClockScript,    show: "showClock", styleKey: "digitalClockStyle", style: "script",    def: "veil" },
            { label: "Stack",     key: "clock", comp: root.cClockStack,     show: "showClock", styleKey: "digitalClockStyle", style: "stack",     def: "veil" },
            { label: "Condensed", key: "clock", comp: root.cClockCondensed, show: "showClock", styleKey: "digitalClockStyle", style: "condensed", def: "veil" }
        ]},
        { section: "Analog Clock", icon: "watch", items: [
            { label: "Classic", key: "analogClock", comp: root.cAnalogClassic, show: "showAnalogClock", styleKey: "analogClockStyle", style: "classic", def: "classic" },
            { label: "Minimal", key: "analogClock", comp: root.cAnalogMinimal, show: "showAnalogClock", styleKey: "analogClockStyle", style: "minimal", def: "classic" },
            { label: "Shape",   key: "analogClock", comp: root.cAnalogShape,   show: "showAnalogClock", styleKey: "analogClockStyle", style: "shape",   def: "classic" }
        ]},
        { section: "Date", icon: "today", items: [
            { label: "Bold",   key: "dateWidget", comp: root.cDateBold,   show: "showDateWidget", styleKey: "dateWidgetStyle", style: "bold",   def: "bold" },
            { label: "Accent", key: "dateWidget", comp: root.cDateAccent, show: "showDateWidget", styleKey: "dateWidgetStyle", style: "accent", def: "bold" },
            { label: "Shape",  key: "dateWidget", comp: root.cDateShape,  show: "showDateWidget", styleKey: "dateWidgetStyle", style: "shape",  def: "bold" }
        ]},
        { section: "Weather", icon: "partly_cloudy_day", items: [
            { label: "Forecast", key: "weatherForecast",  comp: root.cWeatherCast,   show: "showWeatherForecast" },
            { label: "Hourly",   key: "weatherHourly",    comp: root.cWeatherHourly, show: "showWeatherHourly" },
            { label: "Sun Arc",  key: "sunArc",           comp: root.cSunArc,        show: "showSunArc" },
            { label: "Moon",     key: "moonPhase",        comp: root.cMoonPhase,     show: "showMoonPhase" },
            { label: "Shape",    key: "weatherShape",     comp: root.cWeatherShape,  show: "showWeatherShape" }
        ]},
        { section: "Calendar", icon: "calendar_month", items: [
            { label: "Mini",    key: "calendarMini",    comp: root.cCalendarMini, show: "showCalendarMini" },
            { label: "Yarn",    key: "calendarYarn",    comp: root.cCalendarYarn, show: "showCalendarYarn" },
            { label: "Almanac", key: "calendarAlmanac", comp: root.cCalendarAlm,  show: "showCalendarAlmanac" },
            { label: "Torn",    key: "calendarTorn",    comp: root.cCalendarTorn, show: "showCalendarTorn" },
            { label: "Windows", key: "calendarWindows", comp: root.cCalendarWindows, show: "showCalendarWindows" },
            { label: "Daylight", key: "calendarDaylight", comp: root.cCalendarDaylight, show: "showCalendarDaylight" },
            { label: "Year", key: "calendarYear", comp: root.cCalendarYear, show: "showCalendarYear" },
            { label: "Stamp", key: "calendarStamp", comp: root.cCalendarStamp, show: "showCalendarStamp" },
            { label: "Moon", key: "calendarMoon", comp: root.cCalendarMoon, show: "showCalendarMoon" }
        ]},
        { section: "Productivity", icon: "task_alt", items: [
            { label: "Claude Code", key: "claudeCode", comp: root.cClaudeCode, show: "showClaudeCode" },
            { label: "Tasks",       key: "taskList",   comp: root.cTaskList,   show: "showTaskList" },
            { label: "Note",        key: "stickyNote", comp: root.cStickyNote, show: "showStickyNote" },
            { label: "Pomodoro",    key: "pomodoro",   comp: root.cPomodoro,   show: "showPomodoro" },
            { label: "World Clock", key: "worldClock", comp: root.cWorldClock, show: "showWorldClock" }
        ]},
        { section: "News", icon: "newspaper", items: [
            { label: "Headlines", key: "headlines", comp: root.cHeadlines, show: "showHeadlines" }
        ]},
        { section: "System", icon: "memory", items: [
            { label: "Monitor",    key: "sysMonitor",   comp: root.cSysDefault,  show: "showSystemMonitor", styleKey: "systemMonitorStyle", style: "default", def: "default" },
            { label: "Compact",    key: "sysMonitor",   comp: root.cSysCompact,  show: "showSystemMonitor", styleKey: "systemMonitorStyle", style: "compact", def: "default" },
            { label: "Pulse",      key: "sysMonitor",   comp: root.cSysPulse,    show: "showSystemMonitor", styleKey: "systemMonitorStyle", style: "pulse",   def: "default" },
            { label: "Ring",       key: "battery",      comp: root.cBattRing,    show: "showBattery", styleKey: "batteryStyle", style: "ring",  def: "ring" },
            { label: "Shape",      key: "battery",      comp: root.cBattShape,   show: "showBattery", styleKey: "batteryStyle", style: "shape", def: "ring" },
            { label: "Network",    key: "networkGraph", comp: root.cNetGraph,    show: "showNetworkGraph" },
            { label: "Cockpit", key: "sysCockpit", comp: root.cSysCockpit, show: "showSysCockpit" },
            { label: "Blueprint", key: "sysBlueprint", comp: root.cSysBlueprint, show: "showSysBlueprint" },
            { label: "Vitals", key: "sysVitals", comp: root.cSysVitals, show: "showSysVitals" },
            { label: "Forecast", key: "sysForecast", comp: root.cSysForecast, show: "showSysForecast" },
            { label: "Flask", key: "sysFlask", comp: root.cSysFlask, show: "showSysFlask" },
            { label: "Lava Lamp", key: "lavaLamp", comp: root.cLavaLamp, show: "showLavaLamp" },
            { label: "Thermometer", key: "sysThermo", comp: root.cSysThermo, show: "showSysThermo" },
            { label: "Creature", key: "sysCreature", comp: root.cSysCreature, show: "showSysCreature" },
            { label: "Day Ribbon", key: "dayRibbon", comp: root.cDayRibbon, show: "showDayRibbon" },
            { label: "Cell Stack", key: "sysCells", comp: root.cSysCells, show: "showSysCells" },
            { label: "Shape Shifter", key: "sysShape", comp: root.cSysShape, show: "showSysShape" },
            { label: "Hourglass", key: "sysHourglass", comp: root.cSysHourglass, show: "showSysHourglass" },
            { label: "Fill Number", key: "sysFillNumber", comp: root.cSysFillNumber, show: "showSysFillNumber" }
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
        SettingsConfig.widgets = next
    }
}
