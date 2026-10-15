pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import Nebula
import qs.modules.settings

Singleton {
    id: root

    readonly property real cpuUsage: stats.cpuUsage
    readonly property real memUsage: stats.memUsage
    readonly property real memUsedGb: stats.memUsedGb
    readonly property real memTotalGb: stats.memTotalGb
    readonly property real memCacheFrac: stats.memCacheFrac
    readonly property real memBuffersFrac: stats.memBuffersFrac
    readonly property var cpuCores: stats.cpuCores
    readonly property real cpuTemp: stats.cpuTemp
    readonly property real diskUsage: stats.diskUsage
    readonly property real diskUsedGb: stats.diskUsedGb
    readonly property real diskTotalGb: stats.diskTotalGb
    readonly property real gpuUsage: stats.gpuUsage
    readonly property real gpuTemp: stats.gpuTemp
    readonly property real gpuVramUsage: stats.gpuVramUsage
    readonly property real gpuVramUsedGb: stats.gpuVramUsedGb
    readonly property real gpuVramTotalGb: stats.gpuVramTotalGb
    readonly property real gpuClockMhz: stats.gpuClockMhz
    property string gpuName: ""
    readonly property string cpuName: stats.cpuName
    readonly property real netDownloadBps: stats.netDownloadBps
    readonly property real netUploadBps: stats.netUploadBps
    readonly property real netTotalRxBytes: stats.netTotalRxBytes
    readonly property real netTotalTxBytes: stats.netTotalTxBytes
    property var uptime
    property var fanRpms: []

    property int _refCount: 0

    function retain() {
        _refCount++
    }

    function release() {
        if (_refCount > 0) _refCount--
    }

    function formatNetSpeed(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bps >= 1024)        return (bps / 1024).toFixed(1) + " KB/s"
        return bps.toFixed(1) + " B/s"
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024 * 1024) return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (bytes >= 1024 * 1024)        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        if (bytes >= 1024)               return (bytes / 1024).toFixed(1) + " KB"
        return bytes.toFixed(0) + " B"
    }

    readonly property string netInterface: ServiceNetwork.activeInterface

    readonly property int netWindowMinutes: {
        const n = parseInt(SettingsConfig.widgets?.networkGraphWindow ?? "3")
        return (isNaN(n) || n <= 0) ? 3 : n
    }

    readonly property int netSampleIntervalMs: {
        const n = parseInt(SettingsConfig.widgets?.networkGraphInterval ?? "2")
        return Math.max(1000, Math.min(60000, (isNaN(n) || n <= 0 ? 2 : n) * 1000))
    }

    readonly property int _netRawPoints:
        Math.max(1, Math.round(root.netWindowMinutes * 60000 / root.netSampleIntervalMs))

    readonly property int netSamplesPerPoint: Math.max(1, Math.ceil(root._netRawPoints / 240))

    readonly property int netHistoryPoints:
        Math.max(2, Math.round(root._netRawPoints / root.netSamplesPerPoint))

    signal netSampled()

    SystemStats {
        id: stats
        running: root._refCount > 0
        interval: 4000
        netInterval: root.netSampleIntervalMs
        diskInterval: 30000
        netInterface: root.netInterface
        onNetSampled: root.netSampled()
    }

    Process {
        running: true
        command: ["bash", "-c", "echo gpu:$(lspci | grep -i vga | sed 's/.*: //')"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("gpu:"))
                    root.gpuName = data.slice(4)
            }
        }
    }

    Timer {
        interval: root.fanRpms.length > 0 ? 2000 : 30000
        repeat: true
        triggeredOnStart: true
        running: root._refCount > 0
        onTriggered: fanProc.running = true
    }

    Process {
        id: fanProc
        command: ["cat", "/run/nebula-fans"]
        property var next: []
        stdout: SplitParser {
            onRead: data => fanProc.next = data.trim().split(/\s+/).map(v => parseInt(v)).filter(v => !isNaN(v))
        }
        onExited: {
            root.fanRpms = fanProc.next
            fanProc.next = []
        }
    }

    function getUptime() {
        uptimeProc.running = true
        return uptime
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //' | sed 's/ hours*/h/' | sed 's/ minutes*/m/' | sed 's/,//g'"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => uptimeProc.buffer = data
        }

        onExited: root.uptime = uptimeProc.buffer
    }
}
