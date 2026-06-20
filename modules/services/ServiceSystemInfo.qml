pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuUsage: 0.0     // 0.0 – 1.0
    property real memUsage: 0.0     // 0.0 – 1.0
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property real cpuTemp: 0.0      // °C
    property real diskUsage: 0.0    // 0.0 – 1.0
    property real diskUsedGb: 0.0
    property real diskTotalGb: 0.0
    property real gpuUsage: 0.0     // 0.0 – 1.0
    property bool gpuUsageAvailable: false
    property real gpuTemp: 0.0      // °C
    property real gpuVramUsage: 0.0 // 0.0 – 1.0
    property real gpuVramUsedGb: 0.0
    property real gpuVramTotalGb: 0.0
    property real gpuClockMhz: 0.0
    property real gpuClockMaxMhz: 0.0
    property string gpuName: ""
    property string cpuName: ""
    property string netInterface: ""
    property real netDownloadBps: 0.0   // bytes/sec
    property real netUploadBps: 0.0     // bytes/sec
    property real netTotalRxBytes: 0.0  // cumulative
    property real netTotalTxBytes: 0.0  // cumulative
    property var uptime

    property string cpuTempPath: ""
    property string gpuBusyPath: ""
    property string gpuRc6Path: ""
    property string gpuTempPath: ""
    property string gpuVramUsedPath: ""
    property string gpuVramTotalPath: ""
    property string gpuClockPath: ""
    property string gpuClockMaxPath: ""
    property bool nvidiaSmiAvailable: false

    property var _prevCpu: null
    property var _prevNet: null
    property real _lastNetTime: 0
    property real _prevGpuRc6: -1
    property real _lastGpuRc6Time: 0

    function formatNetSpeed(bps) {
        if (bps >= 1024 * 1024)
            return (bps / (1024 * 1024)).toFixed(1) + " MB/s";
        if (bps >= 1024)
            return (bps / 1024).toFixed(1) + " KB/s";
        return bps.toFixed(1) + " B/s";
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KB";
        return bytes.toFixed(0) + " B";
    }

    function _parseSysValue(data) {
        const n = parseFloat(String(data).trim());
        return Number.isFinite(n) ? n : 0;
    }

    function _readTemp(data) {
        const raw = _parseSysValue(data);
        return raw > 1000 ? raw / 1000 : raw;
    }

    function _readClockMhz(data) {
        const raw = _parseSysValue(data);
        // AMD hwmon freq*_input is Hz; Intel gt rps_*_freq_mhz is already MHz.
        return raw > 100000 ? raw / 1000000 : raw;
    }

    // --- Static hardware detection ---
    Process {
        id: staticInfoProc
        running: true
        command: ["bash", "-c", "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//'); gpu=$(lspci | awk -F': ' '/VGA|3D|Display/{print $2; exit}'); echo cpu:$cpu; echo gpu:$gpu; command -v nvidia-smi >/dev/null 2>&1 && echo nvidiaSmi:1; for card in /sys/class/drm/card*; do base=$(basename \"$card\"); case \"$base\" in card[0-9]) ;; *) continue ;; esac; [ -f \"$card/device/gpu_busy_percent\" ] && echo gpuBusy:$card/device/gpu_busy_percent; [ -f \"$card/device/mem_info_vram_total\" ] && echo vramTotal:$card/device/mem_info_vram_total; [ -f \"$card/device/mem_info_vram_used\" ] && echo vramUsed:$card/device/mem_info_vram_used; [ -f \"$card/gt/gt0/rc6_residency_ms\" ] && echo gpuRc6:$card/gt/gt0/rc6_residency_ms; [ -f \"$card/gt/gt0/rps_cur_freq_mhz\" ] && echo gpuClock:$card/gt/gt0/rps_cur_freq_mhz; [ -f \"$card/gt/gt0/rps_max_freq_mhz\" ] && echo gpuClockMax:$card/gt/gt0/rps_max_freq_mhz; done; for hw in /sys/class/hwmon/hwmon*; do name=$(cat \"$hw/name\" 2>/dev/null); case \"$name\" in amdgpu|i915) [ -f \"$hw/temp1_input\" ] && echo gpuTemp:$hw/temp1_input ;; coretemp|k10temp) [ -z \"$cpuTempSet\" ] && [ -f \"$hw/temp1_input\" ] && echo cpuTemp:$hw/temp1_input && cpuTempSet=1 ;; esac; done"]

        stdout: SplitParser {
            onRead: data => {
                const sep = data.indexOf(":");
                if (sep < 0)
                    return;
                const key = data.slice(0, sep);
                const val = data.slice(sep + 1);
                if (key === "cpu")
                    root.cpuName = val;
                else if (key === "gpu")
                    root.gpuName = val;
                else if (key === "cpuTemp")
                    root.cpuTempPath = val;
                else if (key === "gpuBusy")
                    root.gpuBusyPath = val;
                else if (key === "gpuRc6")
                    root.gpuRc6Path = val;
                else if (key === "gpuTemp")
                    root.gpuTempPath = val;
                else if (key === "vramUsed")
                    root.gpuVramUsedPath = val;
                else if (key === "vramTotal")
                    root.gpuVramTotalPath = val;
                else if (key === "gpuClock")
                    root.gpuClockPath = val;
                else if (key === "gpuClockMax")
                    root.gpuClockMaxPath = val;
                else if (key === "nvidiaSmi")
                    root.nvidiaSmiAvailable = val === "1";
            }
        }
    }

    // --- CPU usage (needs two /proc/stat snapshots to diff) ---
    FileView {
        id: cpuFile
        path: "/proc/stat"

        onLoaded: {
            const line = text().split("\n")[0];
            const p = line.trim().split(/\s+/);
            const user = parseInt(p[1]);
            const nice = parseInt(p[2]);
            const system = parseInt(p[3]);
            const idle = parseInt(p[4]);
            const iowait = parseInt(p[5]);
            const irq = parseInt(p[6]);
            const softirq = parseInt(p[7]);

            const total = user + nice + system + idle + iowait + irq + softirq;
            const idleSum = idle + iowait;

            if (root._prevCpu) {
                const dt = total - root._prevCpu.total;
                const di = idleSum - root._prevCpu.idle;
                root.cpuUsage = dt > 0 ? (dt - di) / dt : 0;
            }

            root._prevCpu = {
                total: total,
                idle: idleSum
            };
        }
    }

    // --- Memory ---
    FileView {
        id: memFile
        path: "/proc/meminfo"

        onLoaded: {
            const lines = text().split("\n");
            let total = 0, available = 0;
            for (const line of lines) {
                if (line.startsWith("MemTotal:"))
                    total = parseInt(line.split(/\s+/)[1]);
                else if (line.startsWith("MemAvailable:"))
                    available = parseInt(line.split(/\s+/)[1]);
            }
            root.memTotalGb = total / (1024 * 1024);
            root.memUsedGb = (total - available) / (1024 * 1024);
            root.memUsage = total > 0 ? (total - available) / total : 0;
        }
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        onLoaded: root.cpuTemp = root._readTemp(text())
    }

    // AMD exposes a direct busy percent. Intel iGPU usage is approximated from RC6 idle residency.
    FileView {
        id: gpuBusyFile
        path: root.gpuBusyPath
        onLoaded: {
            root.gpuUsage = Math.max(0, Math.min(1, root._parseSysValue(text()) / 100));
            root.gpuUsageAvailable = true;
        }
    }

    FileView {
        id: gpuRc6File
        path: root.gpuRc6Path
        onLoaded: {
            const rc6 = root._parseSysValue(text());
            const now = Date.now();
            if (root._prevGpuRc6 >= 0 && root._lastGpuRc6Time > 0) {
                const dt = now - root._lastGpuRc6Time;
                const idleDt = rc6 - root._prevGpuRc6;
                if (dt > 0 && idleDt >= 0) {
                    root.gpuUsage = Math.max(0, Math.min(1, 1 - (idleDt / dt)));
                    root.gpuUsageAvailable = true;
                }
            }
            root._prevGpuRc6 = rc6;
            root._lastGpuRc6Time = now;
        }
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        onLoaded: root.gpuTemp = root._readTemp(text())
    }

    FileView {
        id: gpuVramTotalFile
        path: root.gpuVramTotalPath
        onLoaded: root.gpuVramTotalGb = root._parseSysValue(text()) / (1024 * 1024 * 1024)
    }

    FileView {
        id: gpuVramUsedFile
        path: root.gpuVramUsedPath
        onLoaded: {
            const used = root._parseSysValue(text());
            root.gpuVramUsedGb = used / (1024 * 1024 * 1024);
            root.gpuVramUsage = root.gpuVramTotalGb > 0 ? used / (root.gpuVramTotalGb * 1024 * 1024 * 1024) : 0;
        }
    }

    FileView {
        id: gpuClockFile
        path: root.gpuClockPath
        onLoaded: root.gpuClockMhz = root._readClockMhz(text())
    }

    FileView {
        id: gpuClockMaxFile
        path: root.gpuClockMaxPath
        onLoaded: root.gpuClockMaxMhz = root._readClockMhz(text())
    }

    Process {
        id: nvidiaSmiProc
        command: ["bash", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics,clocks.max.graphics,name --format=csv,noheader,nounits | head -n1"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => nvidiaSmiProc.buffer += data
        }

        onExited: {
            const line = nvidiaSmiProc.buffer.trim();
            nvidiaSmiProc.buffer = "";
            if (!line)
                return;

            const parts = line.split(/\s*,\s*/);
            if (parts.length < 6)
                return;

            root.gpuUsage = Math.max(0, Math.min(1, root._parseSysValue(parts[0]) / 100));
            root.gpuUsageAvailable = true;
            root.gpuTemp = root._parseSysValue(parts[1]);
            root.gpuVramUsedGb = root._parseSysValue(parts[2]) / 1024;
            root.gpuVramTotalGb = root._parseSysValue(parts[3]) / 1024;
            root.gpuVramUsage = root.gpuVramTotalGb > 0 ? root.gpuVramUsedGb / root.gpuVramTotalGb : 0;
            root.gpuClockMhz = root._parseSysValue(parts[4]);
            root.gpuClockMaxMhz = root._parseSysValue(parts[5]);
            if (parts.length >= 7)
                root.gpuName = parts.slice(6).join(", ");
        }
    }

    // --- Network speed from first non-loopback interface in /proc/net/dev ---
    FileView {
        id: netFile
        path: "/proc/net/dev"

        onLoaded: {
            const lines = text().split("\n");
            let selectedIface = "";
            let selectedStats = null;

            for (const line of lines) {
                const colon = line.indexOf(":");
                if (colon < 0)
                    continue;
                const iface = line.slice(0, colon).trim();
                if (iface === "lo")
                    continue;
                const stats = line.slice(colon + 1).trim().split(/\s+/);
                if (stats.length < 16)
                    continue;
                if (root.netInterface !== "" && iface === root.netInterface) {
                    selectedIface = iface;
                    selectedStats = stats;
                    break;
                }

                if (!selectedStats) {
                    selectedIface = iface;
                    selectedStats = stats;
                }
            }

            if (!selectedStats)
                return;
            const rx = parseFloat(selectedStats[0]);
            const tx = parseFloat(selectedStats[8]);
            const now = Date.now();

            if (root._prevNet) {
                const dt = (now - root._lastNetTime) / 1000;
                if (dt > 0) {
                    root.netDownloadBps = Math.max(0, (rx - root._prevNet.rx) / dt);
                    root.netUploadBps = Math.max(0, (tx - root._prevNet.tx) / dt);
                }
            }

            root.netInterface = selectedIface;
            root.netTotalRxBytes = rx;
            root.netTotalTxBytes = tx;
            root._prevNet = {
                rx: rx,
                tx: tx
            };
            root._lastNetTime = now;
        }
    }

    // inotify doesn't work on /proc or /sys, so poll manually
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memFile.reload();
            netFile.reload();
            if (root.cpuTempPath !== "")
                cpuTempFile.reload();
            if (root.gpuBusyPath !== "")
                gpuBusyFile.reload();
            if (root.gpuRc6Path !== "")
                gpuRc6File.reload();
            if (root.gpuTempPath !== "")
                gpuTempFile.reload();
            if (root.gpuVramTotalPath !== "")
                gpuVramTotalFile.reload();
            if (root.gpuVramUsedPath !== "")
                gpuVramUsedFile.reload();
            if (root.gpuClockPath !== "")
                gpuClockFile.reload();
            if (root.gpuClockMaxPath !== "")
                gpuClockMaxFile.reload();
            if (root.gpuBusyPath === "" && root.gpuRc6Path === "" && root.nvidiaSmiAvailable && !nvidiaSmiProc.running)
                nvidiaSmiProc.running = true;
        }
    }

    // --- Disk (df, polls slower since it changes rarely) ---
    Process {
        id: diskProc
        command: ["df", "-B1", "--output=used,size", "/"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => diskProc.buffer += data + "\n"
        }

        onExited: {
            const lines = diskProc.buffer.trim().split("\n");
            if (lines.length >= 2) {
                const parts = lines[1].trim().split(/\s+/);
                const used = parseInt(parts[0]);
                const total = parseInt(parts[1]);
                root.diskUsedGb = used / (1024 * 1024 * 1024);
                root.diskTotalGb = total / (1024 * 1024 * 1024);
                root.diskUsage = total > 0 ? used / total : 0;
            }
            diskProc.buffer = "";
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // --- Uptime ---
    function getUptime() {
        uptimeProc.running = true;
        return uptime;
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
