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
    property alias widgets: settingsAdapter.widgets
    property alias weather: settingsAdapter.weather

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
                musicVisBars: 60,
                wallpaperDir: "/home/steel/wallpaper"
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
                musicVisBars: 60,
                wallpaperDir: "/home/steel/wallpaper"
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
                matugenTheme: "Light",
                firstColor: "#ffffff",
                secondColor: "#ffffff",
                thirdColor: "#ffffff",
                transitionType: "fade"
            })

            property var theme: ({
                matugenScheme: "scheme-content",
                matugenTheme: "Light",
                firstColor: "#ffffff",
                secondColor: "#ffffff",
                thirdColor: "#ffffff",
                transitionType: "fade"
            })

            onThemeChanged: {
                const d = _themeDefaults
                const cur = theme || {}
                let needsPatch = false
                for (const k in d) {
                    if (cur[k] === undefined) { needsPatch = true; break }
                }
                if (needsPatch)
                    theme = Object.assign({}, d, cur)
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
                audioCodec: "aac",
                audioBitrate: "128k",
                audioSampleRate: "48000"
            })

            property var widgets: ({
                clockX: 100,
                clockY: 100,
                temperatureX: 600,
                temperatureY: 100
            })

            property var weather: ({
                location: "Chirawa",
                useMetric: true,
                refreshInterval: 15
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
