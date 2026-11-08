pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property alias general: settingsAdapter.general
    property alias theme: settingsAdapter.theme
    property alias wallhaven: settingsAdapter.wallhaven
    property alias recording: settingsAdapter.recording
    property alias screenshot: settingsAdapter.screenshot
    property alias widgets: settingsAdapter.widgets
    property alias weather: settingsAdapter.weather
    property alias calendars: settingsAdapter.calendars
    property alias notifications: settingsAdapter.notifications
    property alias gameMode: settingsAdapter.gameMode
    property alias reading: settingsAdapter.reading
    property alias books: settingsAdapter.books
    property alias wiz: settingsAdapter.wiz
    property alias dashboard: settingsAdapter.dashboard
    property alias sleep: settingsAdapter.sleep
    property alias lockscreen: settingsAdapter.lockscreen
    property alias greeter: settingsAdapter.greeter
    property alias bar: settingsAdapter.bar
    property alias hypr: settingsAdapter.hypr
    property alias features: settingsAdapter.features

    property bool settingsReady: false

    property bool greeterMode: false

    readonly property string loginName: {
        const u = Quickshell.env("USER") ?? ""
        return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : "user"
    }
    readonly property string profileName: {
        const n = (root.general?.displayName ?? "").trim()
        return n !== "" ? n : root.loginName
    }

    property real lastSavedAt: 0
    property bool migrationTried: false
    property bool freshInstall: false

    function useDefaults() {
        migrateGuard.stop()
        if (!root.greeterMode) {
            root.freshInstall = true
            settingsAdapter.features = Features.freshDefaults()
            settingsAdapter.general = Features.freshGeneral(settingsAdapter.general)
            settingsAdapter.hypr = Object.assign({}, settingsAdapter.hypr ?? {}, { targets: {
                displays: { mode: "off", file: "" }, windows: { mode: "off", file: "" },
                input: { mode: "off", file: "" }, binds: { mode: "off", file: "" } } })
        }
        root.settingsReady = true
        writeTimer.restart()
    }

    Process {
        id: migrateProc
        command: [Paths.cli, "migrate", "--quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                migrateGuard.stop()
                if (text.trim() !== "")
                    Quickshell.reload(false)
                else
                    settingsFile.reload()
            }
        }
    }

    Timer {
        id: migrateGuard
        interval: 5000
        onTriggered: root.useDefaults()
    }

    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: {
            reloadTimer.stop()
            root.lastSavedAt = Date.now()
            settingsFile.writeAdapter()
        }
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (writeTimer.running)
                return
            settingsFile.reload()
        }
    }

    FileView {
        id: settingsFile
        path: Paths.configDir + "/settings.json"
        watchChanges: true
        blockWrites: true
        onFileChanged: {
            if (writeTimer.running || Date.now() - root.lastSavedAt < 300)
                return
            reloadTimer.restart()
        }
        onSaved: root.lastSavedAt = Date.now()
        onAdapterUpdated: {
            reloadTimer.stop()
            writeTimer.restart()
        }
        onLoaded: root.settingsReady = true
        onLoadFailed: error => {
            if (error != FileViewError.FileNotFound)
                return
            if (root.migrationTried || root.greeterMode) {
                root.useDefaults()
                return
            }
            root.migrationTried = true
            migrateGuard.restart()
            migrateProc.running = true
        }

        adapter: JsonAdapter {
            id: settingsAdapter

            readonly property var _generalDefaults: ({
                dock: true,
                dockAutoHide: true,
                wallpaperGlide: true,
                wallpaperFill: "crop",
                wallpaperPanelMode: "dock",
                clipboardPanelMode: "dock",
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "",
                displayName: "",
                greetingStyle: "time",
                greetingText: "",
                settingsSections: true,
                settingsRailWide: false,
                defaultFont: "Rubik",
                displayFont: "Titan One",
                notesSide: "L",
                notesLayout: "stack",
                notesAnchor: "top",
                notesOffset: 200,
                notesGap: 12,
                notesCardWidth: 340,
                fontScale: "normal",
                fontWeight: "medium",
                musicVisBars: 60,
                musicVisStyle: "Wave",
                musicVisFps: "30 fps",
                musicVisColor: "Primary",
                musicVisBeat: true,
                musicVisFreqColors: true,
                musicVisFade: true,
                musicVisEdge: "bottom",
                musicVisHeight: 200,
                musicVisBrightness: 75,
                musicVisMirror: false,
                musicVisStringGap: 12,
                musicVisLayer: "behind",
                soundFxOn: false,
                soundFxStyle: "boost",
                soundFxBass: 0,
                soundFxTreble: 0,
                soundFxTarget: "auto",
                wallpaperDir: Quickshell.env("HOME") + "/wallpaper",
                workspaceCount: 10,
                workspaceNames: ({}),
                showWorkspaceNumbers: false,
                flatBarMode: true,
                primaryMonitor: "",
                perMonitorWorkspaces: false,
                barCenter: "clock",
                barWeather: true,
                barWeatherPanel: true,
                motionScheme: "expressive",
                holidayCountry: "",
                editTipSeen: false,
            })

            property var general: ({
                dock: true,
                dockAutoHide: true,
                wallpaperGlide: true,
                wallpaperFill: "crop",
                wallpaperPanelMode: "dock",
                clipboardPanelMode: "dock",
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "",
                displayName: "",
                greetingStyle: "time",
                greetingText: "",
                settingsSections: true,
                settingsRailWide: false,
                defaultFont: "Rubik",
                displayFont: "Titan One",
                notesSide: "L",
                notesLayout: "stack",
                notesAnchor: "top",
                notesOffset: 200,
                notesGap: 12,
                notesCardWidth: 340,
                fontScale: "normal",
                fontWeight: "medium",
                musicVisBars: 60,
                musicVisStyle: "Wave",
                musicVisFps: "30 fps",
                musicVisColor: "Primary",
                musicVisBeat: true,
                musicVisFreqColors: true,
                musicVisFade: true,
                musicVisEdge: "bottom",
                musicVisHeight: 200,
                musicVisBrightness: 75,
                musicVisMirror: false,
                musicVisStringGap: 12,
                musicVisLayer: "behind",
                soundFxOn: false,
                soundFxStyle: "boost",
                soundFxBass: 0,
                soundFxTreble: 0,
                soundFxTarget: "auto",
                wallpaperDir: Quickshell.env("HOME") + "/wallpaper",
                workspaceCount: 10,
                workspaceNames: ({}),
                showWorkspaceNumbers: false,
                flatBarMode: true,
                primaryMonitor: "",
                perMonitorWorkspaces: false,
                barCenter: "clock",
                barWeather: true,
                barWeatherPanel: true,
                motionScheme: "expressive",
                holidayCountry: "",
                editTipSeen: false,
            })

            onGeneralChanged: {
                const d = _generalDefaults
                const cur = general || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    general = Object.assign({}, d, cur)
            }

            readonly property var _themeDefaults: ({
                matugenScheme: "scheme-content",
                matugenTheme: "dark",
                firstColor: "#ffffff",
                secondColor: "#ffffff",
                thirdColor: "#ffffff",
                transitionType: "ink",
                gowallTheme: "off",
                gowallIcons: false,
                gowallInvert: false,
                gowallShell: false,
                kindleOutlines: true,
                kindleWallpaper: "blank",
                kindleGreyIcons: true,
                kindleGreyAnsi: false
            })

            property var theme: ({
                matugenScheme: "scheme-content",
                matugenTheme: "dark",
                firstColor: "#ffffff",
                secondColor: "#ffffff",
                thirdColor: "#ffffff",
                transitionType: "ink",
                gowallTheme: "off",
                gowallIcons: false,
                gowallInvert: false,
                gowallShell: false,
                kindleOutlines: true,
                kindleWallpaper: "blank",
                kindleGreyIcons: true,
                kindleGreyAnsi: false
            })

            onThemeChanged: {
                const d = _themeDefaults
                let cur = theme || {}
                let dirty = false

                // fill in any missing keys from defaults
                for (const k in d) {
                    if (cur[k] === undefined) { dirty = true; break }
                }
                if (dirty) cur = Object.assign({}, d, cur)

                // normalize legacy capitalized mode values ("Light" → "light")
                const mode = cur.matugenTheme
                if (mode && mode !== mode.toLowerCase()) {
                    cur = Object.assign({}, cur, { matugenTheme: mode.toLowerCase() })
                    dirty = true
                }

                // strip legacy keys
                const legacy = ["colorEngine"]
                for (const k of legacy) {
                    if (k in cur) { delete cur[k]; dirty = true }
                }

                if (dirty) theme = cur
            }

            property var wallhaven: ({
                apiKey: "",
                categories: "111",
                purity: "100",
                sorting: "toplist",
                order: "desc",
                topRange: "1M",
                atleast: "",
                ratios: ""
            })


            property var recording: ({
                outputPath: "~/Videos",
                codec: "libx264",
                muxer: "mp4",
                framerate: "30",
                pixelFormat: "yuv420p",
                audioEnabled: true,
                audioSource: "mic",
                audioCodec: "aac",
                audioBitrate: "128k",
                audioSampleRate: "48000"
            })

            property var screenshot: ({
                outputPath: "~/Pictures",
                soundEnabled: true,
                soundPath: "",
                freeze: false
            })

            property var widgets: ({
                showWidgets: true,
                cardStyle: "flat",
                cardOpacity: 0.60,
                clockX: 100,
                clockY: 100,
                analogClockX: 400,
                analogClockY: 200,
                showClock: false,
                showAnalogClock: false,
                analogClockStyle: "classic",
                digitalClockStyle: "veil",
                showProfileBadge: false,
                profileBadgeX: 100,
                profileBadgeY: 400,
                showProfileDay: false,
                profileDayX: 365,
                profileDayY: 165,
                showProfileStatus: false,
                profileStatusX: 915,
                profileStatusY: 165,
                showProfileMachine: false,
                profileMachineX: 915,
                profileMachineY: 400,
                showProfileShape: false,
                profileShapeX: 1135,
                profileShapeY: 620,
                showProfileRings: false,
                profileRingsX: 585,
                profileRingsY: 620,
                showSunArc: false,
                sunArcX: 100,
                sunArcY: 620,
                showClaudeCode: false,
                claudeCodeX: 620,
                claudeCodeY: 100,
                showCalendarMini: false,
                calendarMiniX: 420,
                calendarMiniY: 300,
                calendarMiniMonday: true,
                calendarMiniDimOther: true,
                showCalendarYarn: false,
                calendarYarnX: 660,
                calendarYarnY: 300,
                calendarYarnMonday: true,
                calendarYarnFooter: true,
                showCalendarAlmanac: false,
                calendarAlmanacX: 880,
                calendarAlmanacY: 300,
                calendarAlmanacMonday: true,
                calendarAlmanacDimOther: true,
                showCalendarWindows: false,
                calendarWindowsX: 420,
                calendarWindowsY: 440,
                calendarWindowsMonday: true,
                calendarWindowsFooter: true,
                showCalendarYear: false,
                calendarYearX: 760,
                calendarYearY: 440,
                calendarYearHolidays: true,
                showCalendarMoon: false,
                calendarMoonX: 760,
                calendarMoonY: 100,
                calendarMoonMonday: true,
                showStickyNote: false,
                stickyNoteText: "",
                stickyNoteX: 620,
                stickyNoteY: 660,
                showHeadlines: false,
                headlinesX: 620,
                headlinesY: 900,
                newsFeedUrl: "https://feeds.bbci.co.uk/news/world/rss.xml",
                newsRefreshMinutes: 30,
                showYearAgo: false,
                yearAgoX: 145,
                yearAgoY: 385,
                showPhone: false,
                phoneX: 365,
                phoneY: 385,
                showCountdowns: false,
                countdownsX: 365,
                countdownsY: 605,
                networkGraphInterval: "2 s",
                showMusicExpressive: false,
                musicExpressiveX: 145,
                musicExpressiveY: 605,
                showMusicTicket: false,
                musicTicketX: 585,
                musicTicketY: 605,
                showMusicDisc: false,
                musicDiscX: 475,
                musicDiscY: 165,
                showMusicDeck: false,
                musicDeckX: 585,
                musicDeckY: 825,
                showMusicRail: false,
                musicRailX: 35,
                musicRailY: 165,
                showMusicPulse: false,
                musicPulseX: 145,
                musicPulseY: 935,
                showSysCores: false,
                sysCoresX: 1685,
                sysCoresY: 55,
                showSysQuad: false,
                sysQuadX: 1245,
                sysQuadY: 385,
                showSysChrono: false,
                sysChronoX: 1355,
                sysChronoY: 605,
                showSysSilhouette: false,
                sysSilhouetteX: 1245,
                sysSilhouetteY: 605,
                sysSilhouetteThreads: false,
                showSysMemory: false,
                sysMemoryX: 1245,
                sysMemoryY: 495,
                showSysBattery: false,
                sysBatteryX: 1575,
                sysBatteryY: 495,
                showSysThermals: false,
                sysThermalsX: 1685,
                sysThermalsY: 275,
                showSysNet: false,
                sysNetX: 1245,
                sysNetY: 605,
                showSysOrbit: false,
                sysOrbitX: 1355,
                sysOrbitY: 55,
                showWeatherHourly: false,
                weatherHourlyX: 420,
                weatherHourlyY: 200,
                showWeatherPoster: false,
                weatherPosterX: 145,
                weatherPosterY: 165,
                showWeatherHours: false,
                weatherHoursX: 365,
                weatherHoursY: 165,
                showWeatherDayClock: false,
                weatherDayClockX: 805,
                weatherDayClockY: 165,
                showWeatherWind: false,
                weatherWindX: 1025,
                weatherWindY: 165,
                showWeatherTileHourly: false,
                weatherTileHourlyX: 475,
                weatherTileHourlyY: 165,
                showWeatherTileThermo: false,
                weatherTileThermoX: 475,
                weatherTileThermoY: 330,
                showWeatherTileDays: false,
                weatherTileDaysX: 805,
                weatherTileDaysY: 165,
                showWeatherTileWeek: false,
                weatherTileWeekX: 805,
                weatherTileWeekY: 330,
                showWeatherTileStats: false,
                weatherTileStatsX: 1245,
                weatherTileStatsY: 165,
                showWeatherTileMini: false,
                weatherTileMiniX: 1245,
                weatherTileMiniY: 385,
                showWeatherTileSky: false,
                weatherTileSkyX: 475,
                weatherTileSkyY: 495,
                showWeatherTileList: false,
                weatherTileListX: 1245,
                weatherTileListY: 495,
                showWorldClock: false,
                worldClockX: 880,
                worldClockY: 440,
                worldClockZones: [
                    { label: "Local", tz: "" },
                    { label: "Tokyo", tz: "Asia/Tokyo" },
                    { label: "London", tz: "Europe/London" }
                ],
                showPhotoFrame: false,
                photoFrameX: 440,
                photoFrameY: 440,
                photoFrameImage: "",
                photoFrameShapeLock: "",
                analogShapeLock: "",
                dateShapeLock: "",
                clockShapeLock: "",
                worldClockShapeLock: "",
                clockUse24: false,
                clockShowDate: true,
                clockStatus: true,
                clockSpin: true,
                clockSeconds: true,
                clockMusicRim: true,
                clockTilt: true,
                clockAlignLeft: false,
                clockLabel: true
            })

            property var weather: ({
                location: "",
                useMetric: true,
                refreshInterval: 15
            })

            property var calendars: ({
                feeds: []
            })

            property var notifications: ({
                doNotDisturb: false,
                showBanners: true,
                popupTimeout: 5,
                popupLook: "cards",
                maxVisible: 3,
                groupPopups: true,
                urgentSticky: true,
                showInCenter: true,
                playSound: false,
                soundPath: "",
                edgeLight: "important",
                edgeLightApps: [],
                edgeLightTune: ({ thick: 5, glow: 70, glowA: 45, dur: 2.4, turns: 2, tail: 23 })
            })

            readonly property var _dashboardDefaults: ({
                profile: true,
                controls: true,
                quickActions: true,
                notifications: true,
                calendar: true,
                order: ["profile", "controls", "quickActions", "notifications", "calendar"],
                gridColumns: 4,
                rowHeight: 48,
                fitRows: true,
                options: ({
                    "profile": { showClose: false, showReload: true, showSettings: true },
                    "slider": { background: false },
                    "slider-2": { background: false, color: "primary", target: "brightness" },
                    "toggle": { which: "network" },
                    "toggle-2": { which: "bluetooth" },
                    "toggle-3": { which: "dnd" },
                    "toggle-4": { which: "gameMode" },
                    "toggle-5": { which: "awake" },
                    "toggle-6": { which: "recording" },
                    "power": { background: false, style: "button" }
                })
            })

            property var dashboard: ({
                profile: true,
                controls: true,
                quickActions: true,
                notifications: true,
                calendar: true,
                order: ["profile", "controls", "quickActions", "notifications", "calendar"],
                gridColumns: 4,
                rowHeight: 48,
                fitRows: true,
                options: ({
                    "profile": { showClose: false, showReload: true, showSettings: true },
                    "slider": { background: false },
                    "slider-2": { background: false, color: "primary", target: "brightness" },
                    "toggle": { which: "network" },
                    "toggle-2": { which: "bluetooth" },
                    "toggle-3": { which: "dnd" },
                    "toggle-4": { which: "gameMode" },
                    "toggle-5": { which: "awake" },
                    "toggle-6": { which: "recording" },
                    "power": { background: false, style: "button" }
                })
            })

            onDashboardChanged: {
                const d = _dashboardDefaults
                const cur = dashboard || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch) {
                    const merged = Object.assign({}, d)
                    for (const k in cur) {
                        if (cur[k] !== undefined)
                            merged[k] = cur[k]
                    }
                    dashboard = merged
                }
            }

            readonly property var _sleepDefaults: ({
                dimEnabled: true,
                dimMinutes: 8,
                dimLevel: 10,
                lockEnabled: true,
                lockMinutes: 10,
                screenOffEnabled: false,
                screenOffMinutes: 11,
                suspendEnabled: true,
                suspendMinutes: 30
            })

            property var sleep: ({
                dimEnabled: true,
                dimMinutes: 8,
                dimLevel: 10,
                lockEnabled: true,
                lockMinutes: 10,
                screenOffEnabled: false,
                screenOffMinutes: 11,
                suspendEnabled: true,
                suspendMinutes: 30
            })

            onSleepChanged: {
                const d = _sleepDefaults
                const cur = sleep || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    sleep = Object.assign({}, d, cur)
            }




            readonly property var _lockscreenDefaults: ({
                layout: "veil",
                clockScreen: "display",
                field: "split",
                showDate: true,
                showStatus: true,
                showMusic: true,
                showPower: true,
                showAvatar: true,
                greeterAvatar: true
            })

            property var lockscreen: ({
                layout: "veil",
                clockScreen: "display",
                field: "split",
                showDate: true,
                showStatus: true,
                showMusic: true,
                showPower: true,
                showAvatar: true,
                greeterAvatar: true
            })

            onLockscreenChanged: {
                const d = _lockscreenDefaults
                const cur = lockscreen || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    lockscreen = Object.assign({}, d, cur)
            }

            readonly property var _greeterDefaults: ({
                layout: "veil"
            })

            property var greeter: ({
                layout: "veil"
            })

            onGreeterChanged: {
                const d = _greeterDefaults
                const cur = greeter || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    greeter = Object.assign({}, d, cur)
            }




            readonly property var _gameModeDefaults: ({
                hideBar: true,
                hideWidgets: true,
                dnd: true,
                hyprPerf: true
            })

            property var gameMode: ({
                hideBar: true,
                hideWidgets: true,
                dnd: true,
                hyprPerf: true
            })

            onGameModeChanged: {
                const d = _gameModeDefaults
                const cur = gameMode || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    gameMode = Object.assign({}, d, cur)
            }

            readonly property var _readingDefaults: ({
                enabled: false,
                filter: "warm",
                warmTemp: 4600,
                warmCap: 0.88,
                sepiaTone: 0.35,
                sepiaKeep: 0.15,
                einkContrast: 1.2,
                einkLevels: 16,
                einkGrain: 0.025
            })

            property var reading: ({
                enabled: false,
                filter: "warm",
                warmTemp: 4600,
                warmCap: 0.88,
                sepiaTone: 0.35,
                sepiaKeep: 0.15,
                einkContrast: 1.2,
                einkLevels: 16,
                einkGrain: 0.025
            })

            onReadingChanged: {
                const d = _readingDefaults
                const cur = reading || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    reading = Object.assign({}, d, cur)
            }

            readonly property var _booksDefaults: ({
                layout: "spread",
                page: "warm",
                dark: "off",
                font: "Literata",
                size: 17,
                spacing: "normal",
                justify: true,
                eyeComfort: true
            })

            property var books: ({
                layout: "spread",
                page: "warm",
                dark: "off",
                font: "Literata",
                size: 17,
                spacing: "normal",
                justify: true,
                eyeComfort: true
            })

            onBooksChanged: {
                const d = _booksDefaults
                const cur = books || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    books = Object.assign({}, d, cur)
            }

            readonly property var _wizDefaults: ({
                ip: "",
                mode: "white",
                themeRole: "primary",
                boost: true,
                follow: true,
                musicStyle: "pulse",
                sensitivity: 0.6,
                speed: 100,
                recent: []
            })

            property var features: ({})

            property var wiz: ({
                ip: "",
                mode: "white",
                themeRole: "primary",
                boost: true,
                follow: true,
                musicStyle: "pulse",
                sensitivity: 0.6,
                speed: 100,
                recent: []
            })

            onWizChanged: {
                const d = _wizDefaults
                const cur = wiz || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    wiz = Object.assign({}, d, cur)
            }

            property var bar: ({
                blocks: [],
                margins: {},
                options: {},
                height: 40,
                itemGap: 6,
                blockGap: -1,
                radius: 18
            })

            property var hypr: ({
                options: {},
                monitors: {},
                workspaces: {},
                binds: {},
                addedBinds: [],
                cursor: {}
            })

            property var toggles: ({
                airplaneMode: false,
                notificationMuted: false,
                speakerMuted: false,
                micMuted: false
            })
        }
    }
}
