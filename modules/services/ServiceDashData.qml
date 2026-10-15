pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var processes: []

    property int _procUsers: 0

    readonly property int historyPoints: 40
    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    property var tempHist: []
    property var netDownHist: []
    property var netUpHist: []
    property int _sysUsers: 0

    function retainSystem() {
        if (root._sysUsers++ === 0)
            ServiceSystemInfo.retain()
    }

    function releaseSystem() {
        if (root._sysUsers > 0 && --root._sysUsers === 0)
            ServiceSystemInfo.release()
    }

    function _push(list, v) {
        const out = list.length >= root.historyPoints ? list.slice(list.length - root.historyPoints + 1) : list.slice()
        out.push(v)
        return out
    }

    Timer {
        interval: 4000
        repeat: true
        running: root._sysUsers > 0
        triggeredOnStart: true
        onTriggered: {
            root.cpuHist = root._push(root.cpuHist, ServiceSystemInfo.cpuUsage)
            root.memHist = root._push(root.memHist, ServiceSystemInfo.memUsage)
            root.gpuHist = root._push(root.gpuHist, ServiceSystemInfo.gpuUsage)
            root.tempHist = root._push(root.tempHist, ServiceSystemInfo.cpuTemp)
        }
    }

    Connections {
        target: ServiceSystemInfo
        enabled: root._sysUsers > 0
        function onNetSampled() {
            root.netDownHist = root._push(root.netDownHist, ServiceSystemInfo.netDownloadBps)
            root.netUpHist = root._push(root.netUpHist, ServiceSystemInfo.netUploadBps)
        }
    }

    function retainProcesses() {
        root._procUsers++
        if (!psProc.running)
            psProc.running = true
    }

    function releaseProcesses() {
        if (root._procUsers > 0)
            root._procUsers--
    }

    property int cores: 1

    Process {
        running: true
        command: ["nproc"]
        stdout: StdioCollector {
            onStreamFinished: root.cores = Math.max(1, parseInt(text.trim()) || 1)
        }
    }

    Process {
        id: psProc
        command: ["top", "-b", "-n", "2", "-d", "0.8", "-w", "512", "-o", "%CPU"]
        stdout: StdioCollector {
            onStreamFinished: {
                const byName = {}
                const blocks = text.split(/^top - /m)
                const last = blocks[blocks.length - 1] ?? ""
                const lines = last.split("\n")
                let seen = false
                for (const line of lines) {
                    if (!seen) {
                        seen = /^\s*PID\s+USER/.test(line)
                        continue
                    }
                    const f = line.trim().split(/\s+/)
                    if (f.length < 12)
                        continue
                    const name = f.slice(11).join(" ")
                    const e = byName[name] ?? (byName[name] = { name: name, cpu: 0, mem: 0 })
                    e.cpu += parseFloat(f[8].replace(",", ".")) || 0
                    e.mem += parseFloat(f[9].replace(",", ".")) || 0
                }
                root.processes = Object.values(byName).filter(e => e.name !== "top")
                    .map(e => Object.assign(e, { cpu: e.cpu / root.cores }))
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root._procUsers > 0
        onTriggered: if (!psProc.running) psProc.running = true
    }
}
