pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    // Full bar array matching SettingsConfig.general.musicVisBars, values 0.0–1.0
    property var cavaData: []

    // Averaged down to exactly 12 groups — one per cookie12 star tip
    property var cavaData12: []

    readonly property real smoothFactor: 0.3

    // Reference counting for cava subprocess activation.
    // Multiple consumers (Vis, Bar/MusicPlayer, CircularMusicPlayer) each
    // call retain() when visible and release() when hidden.
    // Cava only stops when ALL consumers have released.
    property int _activeCount: 0
    readonly property bool active: _activeCount > 0

    onActiveChanged: {
        if (active) {
            cavaProc.running = false
            cavaProc.running = true
        } else {
            cavaProc.running = false
        }
    }

    function retain() { _activeCount++ }
    function release() { if (_activeCount > 0) _activeCount-- }

    Process {
        id: cavaProc
        running: false  // Started manually via active property
        command: ["sh", "-c", `
cava -p /dev/stdin <<'CAVAEOF'
[general]
bars = ${SettingsConfig.general.musicVisBars ?? 60}
framerate = 60
autosens = 1

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = 1.5
waves = 0
gravity = 100
noise_reduction = 0.20

[eq]
1 = 1
2 = 1
3 = 1
4 = 1
5 = 1
CAVAEOF
        `]

        stdout: SplitParser {
            onRead: data => {
                const newPoints = data.split(";")
                    .map(p => parseFloat(p.trim()) / 1000)
                    .filter(p => !isNaN(p))

                if (newPoints.length === 0) return

                // Smooth or initialise the full array
                let smoothed
                if (root.cavaData.length !== newPoints.length) {
                    smoothed = newPoints
                } else {
                    smoothed = []
                    for (let i = 0; i < newPoints.length; i++) {
                        smoothed.push(root.cavaData[i] + (newPoints[i] - root.cavaData[i]) * root.smoothFactor)
                    }
                }
                root.cavaData = smoothed

                // Average into 12 groups for the cookie12 star tips
                const n = smoothed.length
                const grouped = []
                for (let g = 0; g < 12; g++) {
                    const start = Math.floor(g * n / 12)
                    const end   = Math.floor((g + 1) * n / 12)
                    let sum = 0
                    for (let j = start; j < end; j++) sum += smoothed[j]
                    grouped.push(end > start ? sum / (end - start) : 0)
                }
                root.cavaData12 = grouped
            }
        }
    }
}
