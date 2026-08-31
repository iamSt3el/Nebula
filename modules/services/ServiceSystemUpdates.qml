pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string checkScript:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/updates_check.sh"
    readonly property string maintScript:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/updates_maint.sh"
    readonly property string blockedScript:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/updates_blocked.sh"

    readonly property var cfg: SettingsConfig.updates ?? ({})
    readonly property bool includeAur: root.cfg.includeAur ?? true

    property var repoUpdates: []
    property var aurUpdates: []
    property int downloadCount: 0
    property real downloadBytes: 0

    property bool checking: false
    property string checkError: ""
    property double lastChecked: 0

    readonly property int repoCount: root.repoUpdates.length
    readonly property int aurCount: root.aurUpdates.length
    readonly property int totalCount: root.repoCount + root.aurCount

    property bool upgrading: false
    property bool aurRunning: false
    property string phase: ""
    property string currentPackage: ""
    property int doneCount: 0
    property int stepTotal: 0
    property var logLines: []
    property string errorText: ""
    property int lastExitCode: 0
    property int stage: 1
    property string missingKeyId: ""
    property string missingKeyOwner: ""
    property var blockedPackages: []
    property bool repairingKeyring: false

    readonly property bool busy: root.upgrading || root.aurRunning

    readonly property real progress: {
        if (!root.upgrading) return 0
        switch (root.phase) {
        case "keyring":
            return 0.01
        case "sync":
            return 0.02
        case "download": {
            const tot = root.downloadCount > 0 ? root.downloadCount : Math.max(1, root.doneCount)
            return 0.03 + 0.52 * Math.min(1, root.doneCount / tot)
        }
        case "install": {
            const tot = root.stepTotal > 0 ? root.stepTotal : Math.max(1, root.doneCount)
            return 0.55 + 0.40 * Math.min(1, root.doneCount / tot)
        }
        case "hooks": {
            const tot = root.stepTotal > 0 ? root.stepTotal : Math.max(1, root.doneCount)
            return 0.95 + 0.05 * Math.min(1, root.doneCount / tot)
        }
        case "done":
            return 1
        }
        return 0
    }

    readonly property string phaseLabel: {
        switch (root.phase) {
        case "keyring":   return "Refreshing keyring"
        case "sync":      return "Synchronising databases"
        case "download":  return "Downloading packages"
        case "install":   return "Installing"
        case "hooks":     return "Running hooks"
        case "done":      return "Up to date"
        case "cancelled": return "Cancelled"
        case "error":     return "Failed"
        }
        return ""
    }

    property var orphans: []
    property int orphanCascade: 0
    property int prunableCount: 0
    property string prunableSize: ""
    property int uninstalledCount: 0
    property string uninstalledSize: ""
    property real cacheBytes: 0
    property int cacheFiles: 0
    property string cacheDir: "/var/cache/pacman/pkg"
    property var pacnewFiles: []
    property string lastUpgrade: ""
    property bool maintScanning: false
    property string maintBusy: ""
    property string maintResult: ""

    readonly property int orphanCount: root.orphans.length
    readonly property int pacnewCount: root.pacnewFiles.length

    property var news: []
    property bool newsLoading: false

    readonly property double lastUpgradeMs: {
        if (root.lastUpgrade === "") return 0
        const t = Date.parse(root.lastUpgrade)
        return isNaN(t) ? 0 : t
    }

    readonly property var criticalNews: {
        if (root.lastUpgradeMs <= 0) return []
        const out = []
        for (const n of root.news)
            if (n.ts > root.lastUpgradeMs) out.push(n)
        return out
    }

    readonly property bool hasCriticalNews: root.criticalNews.length > 0

    property string bootId: ""

    function formatBytes(bytes) {
        const b = Number(bytes) || 0
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GiB"
        if (b >= 1048576)    return (b / 1048576).toFixed(1) + " MiB"
        if (b >= 1024)       return (b / 1024).toFixed(0) + " KiB"
        return b + " B"
    }

    function relativeTime(ms) {
        if (!ms) return "never"
        const diff = Math.max(0, Date.now() - ms)
        const mins = Math.floor(diff / 60000)
        if (mins < 1)   return "just now"
        if (mins < 60)  return mins + " min ago"
        const hrs = Math.floor(mins / 60)
        if (hrs < 24)   return hrs + (hrs === 1 ? " hour ago" : " hours ago")
        const days = Math.floor(hrs / 24)
        return days + (days === 1 ? " day ago" : " days ago")
    }

    function check() {
        if (root.checking || root.upgrading) return
        root.checking = true
        root.checkError = ""
        checkProc.repo = []
        checkProc.aur = []
        checkProc.sawEof = false
        checkProc.command = ["bash", root.checkScript, root.includeAur ? "all" : "repo"]
        checkProc.running = true
    }

    function upgradeRepo(ignore) {
        if (root.busy || root.repoCount === 0) return

        const safe = []
        const list = ignore || []
        for (const name of list)
            if (/^[A-Za-z0-9@._+-]+$/.test(name)) safe.push(name)

        root.upgrading = true
        root.missingKeyId = ""
        root.missingKeyOwner = ""
        root.blockedPackages = []
        root.stage = 1
        root.phase = "keyring"
        root.currentPackage = ""
        root.doneCount = 0
        root.stepTotal = 0
        root.errorText = ""
        root.logLines = []

        upgradeProc.command = ["pkexec", "/usr/bin/bash", "-c",
            "pacman -Sy --noconfirm --noprogressbar --color never archlinux-keyring; " +
            "echo '@@nebula-stage2@@'; " +
            "pacman -Su --noconfirm --noprogressbar --color never" +
            (safe.length > 0 ? " --ignore " + safe.join(",") : "")]
        upgradeProc.running = true
    }

    function findBlocked() {
        if (root.missingKeyOwner === "" || root.repoCount === 0) return
        blockedProc.found = []
        blockedProc.command = ["bash", root.blockedScript, root.missingKeyOwner]
            .concat(root.repoUpdates.map(u => u.name))
        blockedProc.running = true
    }

    function upgradeAur() {
        if (root.busy || root.aurCount === 0) return
        const helper = root.aurHelper
        if (helper === "") return
        root.aurRunning = true
        aurProc.command = ["kitty", "--title", "Nebula AUR upgrade", "bash", "-c",
            helper + " -Sua; printf '\\n\\033[1mFinished. Press enter to close.\\033[0m '; read _"]
        aurProc.running = true
    }

    property string aurHelper: ""

    function repairKeyring() {
        if (root.repairingKeyring || root.busy) return
        root.repairingKeyring = true
        keyProc.command = ["pkexec", "/usr/bin/bash", "-c",
            "lock=/etc/pacman.d/gnupg/pubring.gpg.lock; " +
            "if [ -f \"$lock\" ] && [ ! -s \"$lock\" ]; then rm -f \"$lock\"; fi; " +
            "pacman-key --populate archlinux && pacman-key --updatedb"]
        keyProc.running = true
    }

    function scanMaintenance() {
        if (root.maintScanning) return
        root.maintScanning = true
        maintProc.orphans = []
        maintProc.pacnew = []
        maintProc.command = ["bash", root.maintScript,
                             String(Math.max(0, root.cfg.cacheKeep ?? 2))]
        maintProc.running = true
    }

    function removeOrphans() {
        if (root.busy || root.maintBusy !== "" || root.orphanCount === 0) return
        root.maintBusy = "orphans"
        maintActionProc.command = ["pkexec", "/usr/bin/bash", "-c",
            "list=$(pacman -Qtdq) || exit 0; [ -z \"$list\" ] && exit 0; " +
            "pacman -Rns --noconfirm $list"]
        maintActionProc.running = true
    }

    function cleanCache() {
        if (root.busy || root.maintBusy !== "" || root.prunableCount === 0) return
        const keep = Math.max(0, root.cfg.cacheKeep ?? 2)
        root.maintBusy = "cache"
        root.maintResult = ""
        maintActionProc.command = ["pkexec", "/usr/bin/paccache", "-r", "-k", String(keep)]
        maintActionProc.running = true
    }

    function cleanUninstalled() {
        if (root.busy || root.maintBusy !== "" || root.uninstalledCount === 0) return
        root.maintBusy = "uninstalled"
        root.maintResult = ""
        maintActionProc.command = ["pkexec", "/usr/bin/paccache", "-r", "-u", "-k", "0"]
        maintActionProc.running = true
    }

    function openPacdiff() {
        Quickshell.execDetached(["kitty", "--title", "pacdiff", "bash", "-c",
            "sudo DIFFPROG=${DIFFPROG:-vimdiff} pacdiff; " +
            "printf '\\nFinished. Press enter to close. '; read _"])
    }

    function openNews(link) {
        if (link) Quickshell.execDetached(["xdg-open", link])
    }

    function refreshNews() {
        if (root.newsLoading) return
        root.newsLoading = true
        newsProc.buffer = ""
        newsProc.running = true
    }

    function refreshAll() {
        root.check()
        root.scanMaintenance()
        root.refreshNews()
    }

    function _pushLog(line) {
        const l = root.logLines.slice()
        l.push(line)
        if (l.length > 200) l.splice(0, l.length - 200)
        root.logLines = l
    }

    function _stripPkg(file) {
        let s = String(file).replace(/\.sig$/, "").replace(/\.pkg\.tar\..*$/, "")
        const parts = s.split("-")
        if (parts.length > 3) return parts.slice(0, parts.length - 3).join("-")
        return s
    }

    function _handleUpgradeLine(raw) {
        const t = String(raw).replace(/\r/g, "").replace(/\[[0-9;]*[A-Za-z]/g, "").trim()
        if (t === "") return
        root._pushLog(t)

        if (t === "@@nebula-stage2@@") {
            root.stage = 2
            root.phase = "sync"
            root.errorText = ""
            root.doneCount = 0
            root.stepTotal = 0
            root.currentPackage = ""
            return
        }

        const keyAsk = t.match(/Import PGP key ([0-9A-Fa-fx]{8,}),\s*"([^"]+)"/)
        if (keyAsk) {
            root.missingKeyId = keyAsk[1]
            root.missingKeyOwner = keyAsk[2].replace(/\s*<.*$/, "").trim()
        }

        const keyMiss = t.match(/key "?([0-9A-Fa-fx]{8,})"? could not be imported/)
        if (keyMiss) root.missingKeyId = keyMiss[1]

        if (/^error:/.test(t) && root.errorText === "") root.errorText = t.replace(/^error:\s*/, "")
        if (root.stage < 2) return

        if (t.indexOf(":: Synchronizing package databases") === 0) {
            root.phase = "sync"; root.doneCount = 0; root.stepTotal = 0; root.currentPackage = ""; return
        }
        if (t.indexOf(":: Retrieving packages") === 0) {
            root.phase = "download"; root.doneCount = 0; root.stepTotal = 0; root.currentPackage = ""; return
        }
        if (t.indexOf(":: Processing package changes") === 0) {
            root.phase = "install"; root.doneCount = 0; root.stepTotal = 0; root.currentPackage = ""; return
        }
        if (t.indexOf(":: Running post-transaction hooks") === 0) {
            root.phase = "hooks"; root.doneCount = 0; root.stepTotal = 0; root.currentPackage = ""; return
        }

        let m = t.match(/^(\S+) downloading\.\.\.$/)
        if (!m) m = t.match(/^downloading (\S+?)\.\.\.$/)
        if (m) {
            const file = m[1]
            if (/\.sig$/.test(file)) return
            if (file.indexOf(".pkg.tar") < 0) {
                if (root.phase !== "download") { root.phase = "sync"; root.currentPackage = file }
                return
            }
            if (root.phase !== "download") { root.phase = "download"; root.doneCount = 0 }
            root.doneCount += 1
            root.currentPackage = root._stripPkg(file)
            return
        }

        const step = t.match(/^\(\s*(\d+)\/\s*(\d+)\)\s*(.*)$/)
        if (step) {
            root.doneCount = parseInt(step[1])
            root.stepTotal = parseInt(step[2])
            root.currentPackage = step[3]
            return
        }
    }

    Component.onCompleted: {
        bootProc.running = true
        helperProc.running = true
    }

    Timer {
        interval: 45000
        running: SettingsConfig.settingsReady && (root.cfg.autoCheck ?? true)
        repeat: false
        onTriggered: {
            root.check()
            root.scanMaintenance()
            root.refreshNews()
        }
    }

    Timer {
        interval: Math.max(1, root.cfg.checkIntervalHours ?? 3) * 3600000
        running: SettingsConfig.settingsReady && (root.cfg.autoCheck ?? true)
        repeat: true
        onTriggered: root.check()
    }

    Timer {
        id: notifyTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.totalCount === 0) return
            if (!(root.cfg.notifyOnStart ?? true)) return
            if (root.bootId === "") return
            if (root.cfg.lastNotifiedBoot === root.bootId) return

            SettingsConfig.updates = Object.assign({}, SettingsConfig.updates,
                { lastNotifiedBoot: root.bootId })

            const body = root.repoCount + " repo" +
                (root.aurCount > 0 ? " · " + root.aurCount + " AUR" : "") +
                (root.downloadBytes > 0 ? " · " + root.formatBytes(root.downloadBytes) : "")
            ServiceNotification.sendNotification(
                root.totalCount + (root.totalCount === 1 ? " update available" : " updates available"),
                body, "Updates", "system-software-update")
        }
    }

    Process {
        id: bootProc
        command: ["cat", "/proc/sys/kernel/random/boot_id"]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "") root.bootId = t
            }
        }
    }

    Process {
        id: helperProc
        command: ["bash", "-c",
            "for h in yay paru; do command -v $h >/dev/null 2>&1 && { echo $h; exit 0; }; done; echo"]
        stdout: SplitParser {
            onRead: line => root.aurHelper = line.trim()
        }
    }

    Process {
        id: checkProc
        property var repo: []
        property var aur: []
        property bool sawEof: false

        stdout: SplitParser {
            onRead: line => {
                const t = String(line).replace(/\n$/, "")
                if (t.trim() === "") return
                if (t === "eof") { checkProc.sawEof = true; return }
                const p = t.split("\t")
                if (p[0] === "totals") {
                    root.downloadCount = parseInt(p[1]) || 0
                    root.downloadBytes = parseFloat(p[2]) || 0
                    return
                }
                if (p.length < 4) return
                const entry = { name: p[1], oldVersion: p[2], newVersion: p[3], source: p[0] }
                if (p[0] === "repo") checkProc.repo.push(entry)
                else if (p[0] === "aur") checkProc.aur.push(entry)
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "" && root.checkError === "") root.checkError = t
            }
        }

        onExited: exitCode => {
            const sortByName = (a, b) => a.name.localeCompare(b.name)
            root.repoUpdates = checkProc.repo.slice().sort(sortByName)
            root.aurUpdates = checkProc.aur.slice().sort(sortByName)
            if (!root.includeAur) root.aurUpdates = []
            root.lastChecked = Date.now()
            root.checking = false
            if (!checkProc.sawEof && root.checkError === "")
                root.checkError = "Check did not complete (exit " + exitCode + ")"
            if (checkProc.sawEof) root.checkError = ""
            notifyTimer.restart()
        }
    }

    Process {
        id: upgradeProc
        stdout: SplitParser { onRead: line => root._handleUpgradeLine(line) }
        stderr: SplitParser { onRead: line => root._handleUpgradeLine(line) }

        onExited: exitCode => {
            root.lastExitCode = exitCode
            root.upgrading = false
            root.currentPackage = ""
            if (exitCode === 0) {
                root.phase = "done"
                root.repoUpdates = []
                root.downloadCount = 0
                root.downloadBytes = 0
                ServiceNotification.sendNotification("System updated",
                    "Repository packages are up to date", "Updates", "system-software-update")
                doneCooldown.restart()
                root.check()
                root.scanMaintenance()
            } else if (exitCode === 126) {
                root.phase = "cancelled"
                if (root.errorText === "") root.errorText = "Authentication dismissed"
                doneCooldown.restart()
            } else if (exitCode === 127) {
                root.phase = "error"
                root.errorText = "pkexec could not run pacman — no polkit agent, or not authorised"
            } else {
                root.phase = "error"
                if (root.errorText === "") root.errorText = "pacman exited with code " + exitCode
                if (root.missingKeyOwner !== "") root.findBlocked()
                ServiceNotification.sendNotification("Update failed",
                    root.errorText, "Updates", "dialog-error")
            }
        }
    }

    Timer {
        id: doneCooldown
        interval: 6000
        repeat: false
        onTriggered: if (!root.upgrading && (root.phase === "done" || root.phase === "cancelled")) root.phase = ""
    }

    Process {
        id: aurProc
        onExited: {
            root.aurRunning = false
            root.check()
            root.scanMaintenance()
        }
    }

    Process {
        id: blockedProc
        property var found: []

        stdout: SplitParser {
            onRead: line => {
                const p = String(line).replace(/\n$/, "").split("\t")
                if (p[0] === "blocked" && p[1]) blockedProc.found.push(p[1])
            }
        }

        onExited: root.blockedPackages = blockedProc.found.slice()
    }

    Process {
        id: keyProc
        property string tail: ""

        stdout: SplitParser { onRead: line => { if (line.trim() !== "") keyProc.tail = line.trim() } }
        stderr: SplitParser { onRead: line => { if (line.trim() !== "") keyProc.tail = line.trim() } }

        onExited: exitCode => {
            root.repairingKeyring = false
            if (exitCode === 0) {
                root.missingKeyId = ""
                root.missingKeyOwner = ""
                root.blockedPackages = []
                root.errorText = ""
                root.phase = ""
                ServiceNotification.sendNotification("Keyring repaired",
                    "Retry the upgrade", "Updates", "system-software-update")
            } else {
                root.errorText = keyProc.tail !== "" ? keyProc.tail
                                                     : "Keyring repair failed (exit " + exitCode + ")"
            }
        }
    }

    Process {
        id: maintProc
        property var orphans: []
        property var pacnew: []

        stdout: SplitParser {
            onRead: line => {
                const t = String(line).replace(/\n$/, "")
                if (t.trim() === "" || t === "eof") return
                const p = t.split("\t")
                switch (p[0]) {
                case "orphan":
                    maintProc.orphans.push(p[1]); break
                case "pacnew":
                    maintProc.pacnew.push(p[1]); break
                case "prune":
                    root.prunableCount = parseInt(p[1]) || 0
                    root.prunableSize = p[2] || ""
                    break
                case "uninstalled":
                    root.uninstalledCount = parseInt(p[1]) || 0
                    root.uninstalledSize = p[2] || ""
                    break
                case "cascade":
                    root.orphanCascade = parseInt(p[1]) || 0
                    break
                case "cache":
                    root.cacheBytes = parseFloat(p[1]) || 0
                    root.cacheFiles = parseInt(p[2]) || 0
                    if (p[3]) root.cacheDir = p[3]
                    break
                case "lastupgrade":
                    root.lastUpgrade = p[1]; break
                }
            }
        }

        onExited: {
            root.orphans = maintProc.orphans.slice()
            root.pacnewFiles = maintProc.pacnew.slice()
            root.maintScanning = false
        }
    }

    Process {
        id: maintActionProc
        property string tail: ""

        stdout: SplitParser { onRead: line => { if (line.trim() !== "") maintActionProc.tail = line.trim() } }
        stderr: SplitParser { onRead: line => { if (line.trim() !== "") maintActionProc.tail = line.trim() } }

        onExited: exitCode => {
            root.maintResult = exitCode === 0
                ? (maintActionProc.tail !== "" ? maintActionProc.tail : "Done")
                : (exitCode === 126 ? "Authentication dismissed"
                                    : "Failed (exit " + exitCode + ")")
            maintActionProc.tail = ""
            root.maintBusy = ""
            root.scanMaintenance()
        }
    }

    Process {
        id: newsProc
        property string buffer: ""
        command: ["curl", "-sL", "--max-time", "15", "https://archlinux.org/feeds/news/"]

        stdout: SplitParser { onRead: data => newsProc.buffer += data + "\n" }

        onExited: {
            const xml = newsProc.buffer
            newsProc.buffer = ""
            root.newsLoading = false
            const items = []
            const re = /<item>([\s\S]*?)<\/item>/g
            let m
            while ((m = re.exec(xml)) !== null && items.length < 12) {
                const block = m[1]
                const grab = tag => {
                    const r = new RegExp("<" + tag + ">([\\s\\S]*?)</" + tag + ">")
                    const g = block.match(r)
                    if (!g) return ""
                    return g[1]
                        .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/, "$1")
                        .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                        .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
                        .replace(/&amp;/g, "&")
                        .replace(/<[^>]+>/g, "")
                        .trim()
                }
                const pub = grab("pubDate")
                const ts = Date.parse(pub)
                items.push({
                    title: grab("title"),
                    link: grab("link"),
                    date: pub,
                    ts: isNaN(ts) ? 0 : ts
                })
            }
            root.news = items
        }
    }
}
