pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.platform as Platform
import qs.modules.settings

Singleton {
    id: root

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"

    property bool ready: false
    property string usb: "none"
    property bool hasFrame: false
    property string name: ""
    property string fit: "cover"
    property string preview: ""
    property int updated: 0
    property bool onKindle: false
    property bool serving: false
    property string message: ""
    property bool messageOk: true
    property string pending: ""
    readonly property bool busy: work.running

    property int _refCount: 0

    function retain() {
        _refCount++
        if (_refCount === 1) root.refresh()
    }

    function release() {
        if (_refCount > 0) _refCount--
    }

    function refresh() {
        if (!stat.running && !work.running) stat.running = true
    }

    function apply(text) {
        if (text.length === 0) return null
        try {
            const d = JSON.parse(text)
            root.usb = d.usb ?? "none"
            root.hasFrame = d.hasFrame ?? false
            root.name = d.name ?? ""
            root.fit = d.fit ?? "cover"
            root.preview = d.preview ?? ""
            root.updated = d.updated ?? 0
            root.onKindle = d.onKindle ?? false
            root.serving = d.serving ?? false
            root.ready = true
            return d
        } catch (e) {
            console.warn("[ServiceKindle] bad output:", e)
            return null
        }
    }

    function run(args, label) {
        if (work.running) return
        root.pending = label
        root.message = ""
        work.command = [root.cli, "kindle"].concat(args)
        work.running = true
    }

    function setImage(path) {
        if (path) root.run(["frame", path, "--fit", root.fit, "--push"], "image")
    }

    function setFit(value) {
        if (value === root.fit || work.running) return
        root.fit = value
        if (root.hasFrame) root.run(["frame", "--fit", value, "--push"], "fit")
    }

    function push() {
        root.run(["push"], "push")
    }

    function setWifi(on) {
        if (work.running) return
        root.serving = on
        root.run(["wifi", on ? "on" : "off"], "wifi")
    }

    function clear() {
        root.run(["frame", "--clear"], "clear")
    }

    function browse() {
        GlobalStates.fileDialogOpen = true
        picker.open()
    }

    Timer {
        interval: 4000
        running: root._refCount > 0
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: stat
        command: [root.cli, "kindle", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    Process {
        id: work
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.apply(text)
                const kind = root.pending
                root.pending = ""
                if (!d) {
                    root.messageOk = false
                    root.message = "Something went wrong"
                    return
                }
                if (d.message !== undefined) {
                    root.messageOk = d.ok === true
                    root.message = d.ok === true || d.usb !== "none" ? d.message : ""
                }
                if (kind === "wifi") root.message = ""
            }
        }
        stderr: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "") console.warn("[ServiceKindle]", t)
            }
        }
    }

    Platform.FileDialog {
        id: picker
        title: "Choose an image for the Kindle"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
        onAccepted: {
            GlobalStates.fileDialogOpen = false
            root.setImage(decodeURIComponent(picker.file.toString().replace(/^file:\/\//, "")))
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }
}
