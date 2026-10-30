pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string path: Paths.configDir + "/notes.json"
    readonly property var colors: ({ butter: "#f1d99a", sage: "#c9d6a3", blush: "#efb9ad", sky: "#b7cfe6", lilac: "#d3c5ea", sand: "#e4d3bd" })
    readonly property var colorKeys: ["butter", "sage", "blush", "sky", "lilac", "sand"]
    readonly property string defaultSide: SettingsConfig.general.notesSide ?? "L"

    property var notes: []
    property bool loaded: false
    property string openId: ""

    signal requestOpen(string id)

    function uid() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)
    }

    function find(id) {
        return root.notes.find(n => n.id === id) ?? null
    }

    function copy(n) {
        return Object.assign({}, n, { todo: n.todo.map(t => t.slice()) })
    }

    function mutate(id, fn) {
        let hit = false
        root.notes = root.notes.map(n => {
            if (n.id !== id)
                return n
            hit = true
            const c = root.copy(n)
            fn(c)
            return c
        })
        if (hit)
            save.restart()
    }

    function add(side, y) {
        side = side ?? root.defaultSide
        const onSide = root.notes.filter(n => n.side === side).map(n => n.y)
        const n = {
            id: root.uid(),
            c: root.colorKeys[root.notes.length % root.colorKeys.length],
            title: "New note",
            body: "",
            todo: [],
            at: Date.now(),
            side: side,
            y: y ?? (onSide.length ? Math.min(0.88, Math.max(...onSide) + 0.09) : 0.22)
        }
        root.notes = root.notes.concat([n])
        save.restart()
        return n.id
    }

    function update(id, patch) {
        root.mutate(id, n => {
            Object.assign(n, patch)
            if (!("side" in patch) && !("y" in patch))
                n.at = Date.now()
        })
    }

    function relayout(next, side) {
        const row = next.filter(o => o.side === side).sort((a, b) => a.y - b.y)
        row.forEach((o, i) => o.y = (i + 1) / (row.length + 1))
        root.notes = next
        save.restart()
    }

    function place(id, side, y) {
        if (!root.find(id))
            return
        root.relayout(root.notes.map(n => n.id === id ? Object.assign(root.copy(n), { side: side, y: y }) : root.copy(n)), side)
    }

    function moveAll(side) {
        root.relayout(root.notes.map(n => Object.assign(root.copy(n), { side: side })), side)
    }

    function remove(id) {
        root.notes = root.notes.filter(n => n.id !== id)
        if (root.openId === id)
            root.openId = ""
        save.restart()
    }

    function setTodo(id, index, done) {
        root.mutate(id, n => {
            if (!n.todo[index])
                return
            n.todo[index][1] = done
            n.at = Date.now()
        })
    }

    function addTodo(id, text) {
        if (text.trim() === "")
            return
        root.mutate(id, n => {
            n.todo = n.todo.concat([[text.trim(), false]])
            n.at = Date.now()
        })
    }

    function removeTodo(id, index) {
        root.mutate(id, n => n.todo = n.todo.filter((_, i) => i !== index))
    }

    function ago(ms) {
        const m = Math.round((Date.now() - ms) / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + " min ago"
        const d = new Date(ms), now = new Date()
        if (d.toDateString() === now.toDateString()) return "today " + Qt.formatTime(d, "hh:mm")
        const y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)
        if (d.toDateString() === y.toDateString()) return "yesterday"
        return Qt.formatDate(d, "d MMM")
    }

    Timer {
        id: save
        interval: 600
        onTriggered: store.setText(JSON.stringify({ v: 1, notes: root.notes }, null, 1))
    }

    FileView {
        id: store
        path: root.path
        blockLoading: false
        onLoaded: {
            if (root.loaded)
                return
            try {
                const d = JSON.parse(text())
                root.notes = Array.isArray(d.notes) ? d.notes : []
            } catch (e) {
                root.notes = []
            }
            root.loaded = true
        }
        onLoadFailed: {
            root.notes = []
            root.loaded = true
        }
    }

    IpcHandler {
        target: "notes"
        function add(): void { root.requestOpen(root.add()) }
        function close(): void { root.openId = "" }
    }

    GlobalShortcut {
        name: "note"
        description: "Add a sticky note on the screen edge"
        onPressed: root.requestOpen(root.add())
    }
}
