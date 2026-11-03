import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.services

Item {
    id: root

    visible: false

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    readonly property string source: Quickshell.shellDir + "/config/hypr/nebula/keybinds.lua"
    readonly property string target: ServiceKeybinds.hyprDir + "/nebula/keybinds.lua"

    property bool checked: false
    property bool active: false
    property bool adding: false
    property bool want: false
    property bool wantTouched: false
    property string error: ""

    property var defaults: []

    property var userBinds: []
    property bool scanned: false

    readonly property var conflicts: {
        const out = []
        for (const d of root.defaults) {
            const k = ServiceKeybinds.normalize(d.key)
            const o = root.userBinds.find(e => ServiceKeybinds.normalize(e.origKey) === k)
            if (o)
                out.push({ key: d.key, action: d.action, takenBy: o.name, same: o.action === d.action })
        }
        return out
    }

    readonly property var unbound: root.defaults.filter(d => !root.userBinds.some(e => e.action === d.action))

    readonly property bool ready: root.checked && root.scanned
    readonly property bool coveredByUser: root.ready && !root.active && root.defaults.length > 0 && root.unbound.length === 0
    readonly property bool shouldOffer: root.ready && !root.active && !root.coveredByUser

    function entryFor(action) {
        return root.userBinds.find(e => e.action === action)
            ?? ServiceKeybinds.entries.find(e => e.action === action && !e.unset)
            ?? null
    }

    onShouldOfferChanged: {
        if (root.shouldOffer && !root.wantTouched)
            root.want = root.conflicts.length === 0
    }

    function setWant(on) {
        root.wantTouched = true
        root.want = on
    }

    function apply() {
        if (!root.shouldOffer || !root.want || adder.running)
            return
        root.adding = true
        root.error = ""
        adder.running = true
    }

    function _status(text) {
        try {
            const s = JSON.parse(text.trim().split("\n").pop())
            root.active = !!(s.exists && s.required)
        } catch (e) {
            root.active = false
        }
        root.checked = true
    }

    FileView {
        id: repoFile
        path: root.source
        onLoaded: {
            const out = []
            const re = /hl\.bind\(\s*mod\s*\.\.\s*"\s*\+\s*([^"]+)"\s*,\s*hl\.dsp\.global\("quickshell:(\w+)"\)/g
            let m
            const text = repoFile.text()
            while ((m = re.exec(text)) !== null)
                out.push({ key: "SUPER + " + m[1].trim(), action: m[2] })
            root.defaults = out
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'find -L "$1" -name "*.lua" ! -path "$1/nebula/keybinds.lua" -exec sh -c \'for f; do printf "\\n@@FILE %s\\n" "$f"; cat "$f"; done\' sh {} + 2>/dev/null',
                  "sh", ServiceKeybinds.hyprDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const chunk of text.split("\n@@FILE ").slice(1)) {
                    const nl = chunk.indexOf("\n")
                    for (const e of ServiceKeybinds.parse(chunk.slice(nl + 1), "scan"))
                        out.push(e)
                }
                root.userBinds = out
                root.scanned = true
            }
        }
    }

    Process {
        running: true
        command: [root.cli, "hypr", "status", root.target]
        stdout: StdioCollector {
            onStreamFinished: root._status(text)
        }
    }

    Process {
        id: adder
        command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && { [ -f "$2" ] || cp "$1" "$2"; } && "$3" hypr require "$2"',
                  "sh", root.source, root.target, root.cli]
        stdout: StdioCollector {
            onStreamFinished: root._status(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.error = text.trim().split("\n").pop()
        }
        onExited: code => {
            root.adding = false
            if (code !== 0 && root.error === "")
                root.error = "nebula hypr require exited with " + code
            ServiceKeybinds.reload()
        }
    }
}
