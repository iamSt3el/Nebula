pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property var channels: [
        { key: "rain",   name: "Rain",          icon: "rainy" },
        { key: "window", name: "Rain on glass", icon: "water_drop" },
        { key: "fire",   name: "Fireplace",     icon: "fireplace" },
        { key: "cat",    name: "Purring cat",   icon: "pets" },
        { key: "cafe",   name: "Café",          icon: "local_cafe" },
        { key: "stream", name: "Stream",        icon: "water" },
        { key: "waves",  name: "Waves",         icon: "waves" },
        { key: "night",  name: "Night forest",  icon: "forest" },
        { key: "chimes", name: "Wind chimes",   icon: "air" }
    ]

    readonly property var saved: SettingsConfig.general?.soundscape ?? ({})
    property bool playing: false
    property real master: root.saved.master ?? 70
    property var levels: root.saved.levels ?? ({ rain: 55, fire: 30 })
    property bool duckWithMusic: root.saved.duck ?? true

    property real fade: 0
    readonly property real fadeTarget: root.playing ? 1 : 0
    readonly property real duckGain: root.duckWithMusic && ServiceMusic.isPlaying ? 0.35 : 1

    readonly property var active: root.channels.filter(c => (root.levels[c.key] ?? 0) > 0)
    readonly property string summary: root.active.length === 0 ? "Silent"
        : root.active.length <= 2 ? root.active.map(c => c.name).join(" + ")
        : root.active[0].name + " + " + (root.active.length - 1) + " more"
    readonly property string leadIcon: root.active.length ? root.active[0].icon : "graphic_eq"

    function level(k) { return root.levels[k] ?? 0 }

    function setLevel(k, v) {
        const l = Object.assign({}, root.levels)
        l[k] = Math.round(v)
        root.levels = l
        save.restart()
    }

    function setMaster(v) {
        root.master = Math.round(v)
        save.restart()
    }

    function setDuck(on) {
        root.duckWithMusic = on
        save.restart()
    }

    function toggle() {
        if (!root.playing && root.active.length === 0)
            root.levels = ({ rain: 55, fire: 30 })
        root.playing = !root.playing
    }

    function preset(p) {
        root.levels = p
        save.restart()
        if (!root.playing)
            root.playing = true
    }

    function gainFor(k) {
        return root.level(k) / 100 * root.master / 100 * root.fade * root.duckGain
    }

    Timer {
        id: save
        interval: 800
        onTriggered: SettingsConfig.general = Object.assign({}, SettingsConfig.general,
            { soundscape: { master: root.master, levels: root.levels, duck: root.duckWithMusic } })
    }

    Timer {
        interval: 80
        repeat: true
        running: Math.abs(root.fade - root.fadeTarget) > 0.001
        onTriggered: {
            const step = root.playing ? 0.05 : 0.08
            root.fade = root.playing ? Math.min(1, root.fade + step) : Math.max(0, root.fade - step)
        }
    }

    Instantiator {
        model: root.channels

        delegate: Process {
            id: player
            required property var modelData
            readonly property real gain: root.gainFor(player.modelData.key)
            readonly property bool wanted: root.fade > 0.001 && root.level(player.modelData.key) > 0

            function push() {
                if (player.running)
                    player.write('{"command":["set_property","volume",' + (player.gain * 100).toFixed(1) + ']}\n')
            }

            running: player.wanted
            stdinEnabled: true
            command: ["mpv", "--no-video", "--no-terminal", "--really-quiet", "--loop-file=inf",
                      "--audio-client-name=Nebula Soundscape", "--input-ipc-client=fd://0", "--volume=0",
                      Quickshell.shellPath("assets/soundscape/" + player.modelData.key + ".opus")]
            onGainChanged: player.push()
            onRunningChanged: if (player.running) Qt.callLater(player.push)
        }
    }
}
