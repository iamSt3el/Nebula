pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import "ReadingShaders.js" as Shaders

Singleton {
    id: root

    readonly property var cfg: SettingsConfig.reading ?? ({})
    readonly property bool active: root.cfg.enabled ?? false
    readonly property var filters: Shaders.filters
    readonly property string filter: Shaders.byId(root.cfg.filter) ? root.cfg.filter : "warm"
    readonly property string filterName: Shaders.byId(root.filter).name
    readonly property string source: Shaders.source(root.filter, root.cfg)
    readonly property string dir: Quickshell.env("HOME") + "/.cache/quickshell/reading"

    property int _slot: 0
    property bool _dirty: false

    function _set(patch) {
        SettingsConfig.reading = Object.assign({}, SettingsConfig.reading, patch)
    }

    function toggle() { root._set({ enabled: !root.active }) }
    function setEnabled(on) { root._set({ enabled: on }) }
    function choose(id) { root._set({ filter: id, enabled: true }) }

    function value(key) {
        return Shaders.valueOf(Shaders.param(key), root.cfg)
    }

    function format(key, v) {
        return Shaders.format(Shaders.param(key), v)
    }

    function setParam(key, v) {
        const p = Shaders.param(key)
        if (!p) return
        const s = Shaders.snap(p, v)
        if (s === root.value(key)) return
        const patch = {}
        patch[key] = s
        root._set(patch)
    }

    function _lua(path) {
        return "hl.config({ decoration = { screen_shader = " + JSON.stringify(path) + " } })"
    }

    function apply() {
        if (writer.running) {
            root._dirty = true
            return
        }
        if (!root.active) {
            writer.command = ["hyprctl", "eval", root._lua("")]
        } else {
            root._slot = 1 - root._slot
            const path = root.dir + "/reading-" + root._slot + ".frag"
            writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\" && hyprctl eval \"$4\"",
                "sh", root.dir, root.source, path, root._lua(path)]
        }
        writer.running = true
    }

    Component.onCompleted: if (root.active) applyTimer.restart()
    onActiveChanged: applyTimer.restart()
    onSourceChanged: if (root.active) applyTimer.restart()

    Timer {
        id: applyTimer
        interval: 60
        onTriggered: root.apply()
    }

    Process {
        id: writer
        onExited: {
            if (root._dirty) {
                root._dirty = false
                root.apply()
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && root.active)
                applyTimer.restart()
        }
    }
}
