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
    property alias ai: settingsAdapter.ai
    property alias manga: settingsAdapter.manga
    property alias recording: settingsAdapter.recording
    property alias screenshot: settingsAdapter.screenshot
    property alias widgets: settingsAdapter.widgets
    property alias weather: settingsAdapter.weather
    property alias notifications: settingsAdapter.notifications

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
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeTimer.restart()
            }
        }

        adapter: JsonAdapter {
            id: settingsAdapter

            readonly property var _generalDefaults: ({
                dock: true,
                dockAutoHide: true,
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "/home/steel/Downloads/DANDADAN.jpg",
                defaultFont: "Rubik",
                displayFont: "Titan One",
                fontScale: "normal",
                fontWeight: "extrabold",
                musicVisBars: 60,
                wallpaperDir: "/home/steel/wallpaper",
                workspaceCount: 10,
                showWorkspaceNumbers: false
            })

            property var general: ({
                dock: true,
                dockAutoHide: true,
                dockMusicPlayer: true,
                appGrid: false,
                pinnedApps: [],
                musicVisOn: true,
                profile: "/home/steel/Downloads/DANDADAN.jpg",
                defaultFont: "Rubik",
                displayFont: "Titan One",
                fontScale: "normal",
                fontWeight: "extrabold",
                musicVisBars: 60,
                wallpaperDir: "/home/steel/wallpaper",
                workspaceCount: 10,
                showWorkspaceNumbers: false
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
                transitionType: "fade"
            })

            property var theme: ({
                matugenScheme: "scheme-content",
                matugenTheme: "dark",
                firstColor: "#ffffff",
                secondColor: "#ffffff",
                thirdColor: "#ffffff",
                transitionType: "fade"
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

                // strip legacy gowall keys
                const legacy = ["colorEngine", "gowallTheme"]
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

            property var ai: ({
                googleApiKey: "",
                backend: "ollama",
                ollamaModel: "deepseek-r1:1.5b"
            })

            property var manga: ({
                scrollSpeed: 5,
                pageSpacing: 4,
                defaultSite: "comix",
                preloadPages: 1500,
                filterAdult: true
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
                clockX: 100,
                clockY: 100,
                musicPlayerX: 200,
                musicPlayerY: 200,
                dateWidgetX: 300,
                dateWidgetY: 300,
                analogClockX: 400,
                analogClockY: 200,
                showCircularMusicPlayer: true,
                showClock: false,
                showDateWidget: false,
                showAnalogClock: false,
                analogClockStyle: "classic",
                dateWidgetStyle: "default"
            })

            property var weather: ({
                location: "Chirawa",
                useMetric: true,
                refreshInterval: 15
            })

            property var notifications: ({
                doNotDisturb: false,
                showBanners: true,
                popupTimeout: 5,
                maxVisible: 3,
                showInCenter: true,
                playSound: false
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
