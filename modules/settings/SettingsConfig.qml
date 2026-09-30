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
    property alias notifications: settingsAdapter.notifications
    property alias gameMode: settingsAdapter.gameMode
    property alias dashboard: settingsAdapter.dashboard
    property alias sleep: settingsAdapter.sleep
    property alias lockscreen: settingsAdapter.lockscreen
    property alias greeter: settingsAdapter.greeter
    property alias bar: settingsAdapter.bar

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

    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.settingsReady = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.settingsReady = true
                writeTimer.restart()
            }
        }

        adapter: JsonAdapter {
            id: settingsAdapter

            readonly property var _generalDefaults: ({
                dock: true,
                dockAutoHide: true,
                desktopRipple: false,
                wallpaperGlide: true,
                wallpaperPanelMode: "dock",
                clipboardPanelMode: "dock",
                desktopRippleStrength: "normal",
                desktopRippleDrag: true,
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "",
                displayName: "",
                settingsSections: true,
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
                fileDropDir: ""
            })

            property var general: ({
                dock: true,
                dockAutoHide: true,
                desktopRipple: false,
                wallpaperGlide: true,
                wallpaperPanelMode: "dock",
                clipboardPanelMode: "dock",
                desktopRippleStrength: "normal",
                desktopRippleDrag: true,
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "",
                displayName: "",
                settingsSections: true,
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
                fileDropDir: ""
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
                wallpaperFill: "crop"
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
                wallpaperFill: "crop"
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

                // normalize wallpaperFill to a known mode
                const fillModes = ["crop", "fit", "stretch", "tile"]
                const fill = cur.wallpaperFill ?? "crop"
                if (!fillModes.includes(fill)) {
                    cur = Object.assign({}, cur, { wallpaperFill: "crop" })
                    dirty = true
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
                soundPath: ""
            })

            property var widgets: ({
                showWidgets: true,
                cardStyle: "flat",
                cardOpacity: 0.60,
                clockX: 100,
                clockY: 100,
                dateWidgetX: 300,
                dateWidgetY: 300,
                analogClockX: 400,
                analogClockY: 200,
                showClock: false,
                showDateWidget: false,
                showAnalogClock: false,
                analogClockStyle: "classic",
                dateWidgetStyle: "bold",
                digitalClockStyle: "veil",
                showProfileCard: false,
                profileCardStyle: "card",
                profileCardX: 100,
                profileCardY: 400,
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
                showCalendarTorn: false,
                calendarTornX: 1120,
                calendarTornY: 300,
                calendarTornMonday: true,
                calendarTornStrip: true,
                showCalendarWindows: false,
                calendarWindowsX: 420,
                calendarWindowsY: 440,
                calendarWindowsMonday: true,
                calendarWindowsFooter: true,
                showCalendarDaylight: false,
                calendarDaylightX: 420,
                calendarDaylightY: 100,
                calendarDaylightPlace: true,
                showCalendarYear: false,
                calendarYearX: 760,
                calendarYearY: 440,
                calendarYearHolidays: true,
                showCalendarStamp: false,
                calendarStampX: 1100,
                calendarStampY: 440,
                calendarStampPostmark: true,
                showCalendarMoon: false,
                calendarMoonX: 760,
                calendarMoonY: 100,
                calendarMoonMonday: true,
                showMoonPhase: false,
                moonPhaseX: 620,
                moonPhaseY: 440,
                showStickyNote: false,
                stickyNoteText: "",
                stickyNoteX: 620,
                stickyNoteY: 660,
                showHeadlines: false,
                headlinesX: 620,
                headlinesY: 900,
                newsFeedUrl: "https://feeds.bbci.co.uk/news/world/rss.xml",
                newsRefreshMinutes: 30,
                showTaskList: false,
                taskListX: 960,
                taskListY: 200,
                showCommitGarden: false,
                commitGardenX: 145,
                commitGardenY: 165,
                showNotebook: false,
                notebookX: 585,
                notebookY: 165,
                showTerminalStats: false,
                terminalStatsX: 915,
                terminalStatsY: 165,
                showMostOpened: false,
                mostOpenedX: 1135,
                mostOpenedY: 165,
                showYearAgo: false,
                yearAgoX: 145,
                yearAgoY: 385,
                showPhone: false,
                phoneX: 365,
                phoneY: 385,
                showHabits: false,
                habitsX: 585,
                habitsY: 385,
                showCountdowns: false,
                countdownsX: 365,
                countdownsY: 605,
                showMood: false,
                moodX: 695,
                moodY: 605,
                showNetworkGraph: false,
                networkGraphX: 100,
                networkGraphY: 780,
                networkGraphWindow: "3 min",
                networkGraphInterval: "2 s",
                showSysCockpit: false,
                sysCockpitX: 145,
                sysCockpitY: 165,
                showSysBlueprint: false,
                sysBlueprintX: 695,
                sysBlueprintY: 165,
                showSysVitals: false,
                sysVitalsX: 145,
                sysVitalsY: 495,
                showSysForecast: false,
                sysForecastX: 695,
                sysForecastY: 495,
                showSysFlask: false,
                sysFlaskX: 145,
                sysFlaskY: 165,
                showSysThermo: false,
                sysThermoX: 365,
                sysThermoY: 165,
                showSysCreature: false,
                sysCreatureX: 540,
                sysCreatureY: 300,
                showDayRibbon: false,
                dayRibbonX: 365,
                dayRibbonY: 420,
                showSysCells: false,
                sysCellsX: 585,
                sysCellsY: 165,
                showSysShape: false,
                sysShapeX: 805,
                sysShapeY: 165,
                showSysHourglass: false,
                sysHourglassX: 1025,
                sysHourglassY: 165,
                showSysFillNumber: false,
                sysFillNumberX: 1245,
                sysFillNumberY: 165,
                showMusicExpressive: false,
                musicExpressiveX: 145,
                musicExpressiveY: 605,
                showMusicTicket: false,
                musicTicketX: 585,
                musicTicketY: 605,
                showMusicPoster: false,
                musicPosterX: 475,
                musicPosterY: 165,
                showMusicTuner: false,
                musicTunerX: 585,
                musicTunerY: 825,
                showMusicWaveform: false,
                musicWaveformX: 1025,
                musicWaveformY: 605,
                showMusicSpectrum: false,
                musicSpectrumX: 145,
                musicSpectrumY: 825,
                showMusicLyrics: false,
                musicLyricsX: 1025,
                musicLyricsY: 385,
                showMusicCapsule: false,
                musicCapsuleX: 145,
                musicCapsuleY: 935,
                showMusicGlance: false,
                musicGlanceX: 695,
                musicGlanceY: 935,
                showMusicFlap: false,
                musicFlapX: 1025,
                musicFlapY: 825,
                showMusicBento: false,
                musicBentoX: 1245,
                musicBentoY: 385,
                showMusicRibbon: false,
                musicRibbonX: 35,
                musicRibbonY: 165,
                showMusicNeon: false,
                musicNeonX: 585,
                musicNeonY: 385,
                showMusicTerminal: false,
                musicTerminalX: 145,
                musicTerminalY: 385,
                showWeatherHourly: false,
                weatherHourlyX: 420,
                weatherHourlyY: 200,
                showWeatherShape: false,
                weatherShapeX: 660,
                weatherShapeY: 200,
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
                weatherShapeLock: "",
                dateShapeLock: "",
                batteryShapeLock: "",
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

            property var notifications: ({
                doNotDisturb: false,
                showBanners: true,
                popupTimeout: 5,
                maxVisible: 3,
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
                showDate: true,
                showStatus: true,
                showMusic: true,
                showPower: true
            })

            property var lockscreen: ({
                layout: "veil",
                showDate: true,
                showStatus: true,
                showMusic: true,
                showPower: true
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

            property var bar: ({
                blocks: [],
                margins: {},
                options: {},
                height: 40,
                itemGap: 6,
                blockGap: -1,
                radius: 18
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
