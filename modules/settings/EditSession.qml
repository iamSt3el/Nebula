pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "EditDiff.js" as EditDiff

Singleton {
    id: root

    property var history: []
    property int index: -1
    property bool restoring: false
    property bool peek: false
    property bool peeked: false
    property string hint: ""

    readonly property bool canUndo: root.index > 0
    readonly property bool canRedo: root.index >= 0 && root.index < root.history.length - 1
    readonly property int changes: Math.max(0, root.index)
    readonly property string undoLabel: root.canUndo ? (root.history[root.index]?.label ?? "") : ""
    readonly property string redoLabel: root.canRedo ? (root.history[root.index + 1]?.label ?? "") : ""

    property var namers: ({})
    property var searchers: ({})

    readonly property var noisyGeneral: ["soundscape", "clipboardPins", "launcherSizes"]
    readonly property var noisyWidgets: ["habits", "countdowns", "moods", "worldClockZones"]

    onPeekChanged: if (root.peek) root.peeked = true

    function name(kind, id) {
        const f = root.namers[kind]
        if (!f)
            return String(id)
        try {
            const n = f(id)
            return n ? String(n) : String(id)
        } catch (e) {
            return String(id)
        }
    }

    function search(kind, query) {
        const f = root.searchers[kind]
        if (!f)
            return 0
        try {
            return f(query) | 0
        } catch (e) {
            return 0
        }
    }

    function stripped(obj, keys) {
        const out = Object.assign({}, obj ?? {})
        for (const k of keys)
            delete out[k]
        return out
    }

    function canonOf(v) {
        if (v === null || typeof v !== "object")
            return JSON.stringify(v)
        if (Array.isArray(v))
            return "[" + v.map(x => root.canonOf(x)).join(",") + "]"
        return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + root.canonOf(v[k])).join(",") + "}"
    }

    function current() {
        return JSON.parse(JSON.stringify({
            bar: SettingsConfig.bar ?? {},
            general: root.stripped(SettingsConfig.general, root.noisyGeneral),
            widgets: root.stripped(SettingsConfig.widgets, root.noisyWidgets),
            dashboard: SettingsConfig.dashboard ?? {}
        }))
    }

    function begin() {
        recordTimer.stop()
        root.peek = false
        root.peeked = false
        root.index = -1
        root.history = [{ s: root.canonOf(root.current()), label: "When you opened edit mode", t: Date.now() }]
        root.index = 0
    }

    function record() {
        if (root.index < 0)
            return
        const now = root.current()
        const s = root.canonOf(now)
        if (s === root.history[root.index].s)
            return
        const label = EditDiff.describe(JSON.parse(root.history[root.index].s), now, (k, id) => root.name(k, id), root.hint)
        root.hint = ""
        const next = root.history.slice(0, root.index + 1).concat([{ s: s, label: label, t: Date.now() }])
        root.history = next.length > 80 ? [next[0]].concat(next.slice(next.length - 79)) : next
        root.index = root.history.length - 1
    }

    function restoreAt(i) {
        if (i < 0 || i >= root.history.length)
            return
        recordTimer.stop()
        root.restoring = true
        root.index = i
        const s = JSON.parse(root.history[i].s)
        const keep = (live, keys) => {
            const out = {}
            for (const k of keys)
                if (live && live[k] !== undefined)
                    out[k] = live[k]
            return out
        }
        const general = Object.assign({}, s.general, keep(SettingsConfig.general, root.noisyGeneral))
        const widgets = Object.assign({}, s.widgets, keep(SettingsConfig.widgets, root.noisyWidgets))
        if (root.canonOf(JSON.parse(JSON.stringify(SettingsConfig.bar ?? {}))) !== root.canonOf(s.bar))
            SettingsConfig.bar = s.bar
        if (root.canonOf(root.stripped(SettingsConfig.general, root.noisyGeneral)) !== root.canonOf(s.general))
            SettingsConfig.general = general
        if (root.canonOf(root.stripped(SettingsConfig.widgets, root.noisyWidgets)) !== root.canonOf(s.widgets))
            SettingsConfig.widgets = widgets
        if (root.canonOf(JSON.parse(JSON.stringify(SettingsConfig.dashboard ?? {}))) !== root.canonOf(s.dashboard))
            SettingsConfig.dashboard = s.dashboard
        restoreRelease.restart()
    }

    function undo() {
        if (root.canUndo)
            root.restoreAt(root.index - 1)
    }

    function redo() {
        if (root.canRedo)
            root.restoreAt(root.index + 1)
    }

    function discard() {
        if (root.index > 0)
            root.restoreAt(0)
        GlobalStates.closeEdit()
    }

    function changed() {
        if (GlobalStates.editMode && !root.restoring)
            recordTimer.restart()
    }

    Timer {
        id: restoreRelease
        interval: 500
        onTriggered: root.restoring = false
    }

    Timer {
        id: recordTimer
        interval: 300
        onTriggered: root.record()
    }

    Connections {
        target: SettingsConfig
        function onBarChanged() { root.changed() }
        function onGeneralChanged() { root.changed() }
        function onWidgetsChanged() { root.changed() }
        function onDashboardChanged() { root.changed() }
    }

    Connections {
        target: GlobalStates
        function onEditModeChanged() {
            if (GlobalStates.editMode) {
                root.begin()
            } else {
                recordTimer.stop()
                root.peek = false
            }
        }
    }
}
