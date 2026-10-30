import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import qs.modules.settings
import qs.modules.utils
import qs.modules.services

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property string wallpaperDir: SettingsConfig.general.wallpaperDir ?? (Quickshell.env("HOME") + "/wallpaper")

    onWallpaperDirChanged: {
        if (folderModel.folder.toString() !== "") {
            processedFiles = {}
            wallpaperMap = {}
            wallpapers = []
            folderModel.folder = "file://" + wallpaperDir
        }
    }
    property string cacheDir: StandardPaths.writableLocation(StandardPaths.CacheLocation).toString().replace("file://", "") + "/wallpaper-thumbs"
    property int thumbSize: 256
    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    property string scheme: SettingsConfig.theme.matugenScheme
    property string theme: SettingsConfig.theme.matugenTheme
    property string gowallTheme: SettingsConfig.theme.gowallTheme ?? "off"
    property bool gowallIcons: SettingsConfig.theme.gowallIcons ?? false
    property bool gowallInvert: SettingsConfig.theme.gowallInvert ?? false
    property bool gowallShell: SettingsConfig.theme.gowallShell ?? false
    readonly property bool gowallActive: {
        const t = (root.gowallTheme ?? "").toLowerCase()
        return t !== "" && t !== "off"
    }

    // `gowall list` reports the built-ins plus anything in ~/.config/gowall/config.yml,
    // so the picker never goes stale against the installed binary. Queried lazily —
    // nothing spawns until a settings page actually asks.
    property var gowallThemes: []
    property bool gowallAvailable: false
    property bool gowallChecked: false

    // CustomListNew renders modelData.name, so the picker needs objects.
    readonly property var gowallOptions: [{ name: "off" }, { name: "match" }]
        .concat(root.gowallThemes.map(t => ({ name: t })))

    // ── Icon theme recoloring ──────────────────────────────────────────────
    // The whole icon theme is copied and recolored (~80k files, ~10s), so this
    // runs as a tracked Process rather than fire-and-forget — the settings page
    // shows its progress.
    readonly property bool iconBusy: iconProc.running
    property real iconProgress: 0
    property string iconThemeName: ""
    property string iconStatus: ""

    function buildGowallIcons(force) {
        if (iconProc.running) return
        if (!root.gowallActive) {
            console.warn("[ServiceWallpaper] buildGowallIcons: no palette selected")
            return
        }
        root.iconProgress = 0
        root.iconStatus = "Recoloring icons…"
        iconProc.command = force
            ? [root.cli, "gowall-icons", root.gowallTheme, "--apply", "--force"]
            : [root.cli, "gowall-icons", root.gowallTheme, "--apply"]
        iconProc.running = true
    }

    function restoreIconTheme() {
        if (iconProc.running) return
        root.iconProgress = 0
        root.iconStatus = "Restoring icon theme…"
        iconProc.command = [root.cli, "gowall-icons", "--restore"]
        iconProc.running = true
    }

    readonly property bool kindleIcons: KindleMode.recolorIcons
    readonly property string kindleIconTheme: KindleMode.iconTheme
    onKindleIconThemeChanged: if (root.kindleIcons) root.syncKindleIcons()
    property bool iconPending: false
    onKindleIconsChanged: root.syncKindleIcons()
    Component.onCompleted: if (root.kindleIcons) root.syncKindleIcons()

    function syncKindleIcons() {
        if (iconProc.running) {
            root.iconPending = true
            return
        }
        if (root.kindleIcons) {
            root.iconProgress = 0
            root.iconStatus = "Making grey icons…"
            iconProc.command = [root.cli, "gowall-icons", KindleMode.iconTheme, "--apply"]
            iconProc.running = true
        } else if (root.gowallIcons && root.gowallActive) {
            root.buildGowallIcons(false)
        } else {
            root.restoreIconTheme()
        }
    }

    Process {
        id: iconProc

        stdout: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t.startsWith("progress=")) {
                    const parts = t.substring(9).split("/")
                    const done = parseInt(parts[0]), total = parseInt(parts[1])
                    if (total > 0) root.iconProgress = done / total
                } else if (t.startsWith("theme=")) {
                    root.iconThemeName = t.substring(6)
                } else if (t.startsWith("assets=")) {
                    KindleMode.iconAssets = KindleMode.iconTheme !== "" && t.endsWith("/assets-" + KindleMode.iconTheme) ? t.substring(7) : ""
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t === "") return
                root.iconStatus = t.replace("[gowall_icons] ", "")
                console.log("[ServiceWallpaper]", t)
            }
        }

        onExited: code => {
            root.iconProgress = code === 0 ? 1 : 0
            if (code !== 0) root.iconStatus = "Icon recolor failed"
            if (root.iconPending) {
                root.iconPending = false
                root.syncKindleIcons()
            }
        }
    }

    // A six-icon before/after sample, so a palette can be judged without
    // committing to a full rebuild. ~0.2s.
    property var iconPreview: []
    property string iconPreviewTheme: ""

    function refreshIconPreview(theme) {
        const t = (theme ?? "").toLowerCase()
        if (t === "" || t === "off") {
            root.iconPreview = []
            root.iconPreviewTheme = ""
            return
        }
        if (previewProc.running) return
        if (root.iconPreviewTheme === theme && root.iconPreview.length > 0) return
        previewProc.found = []
        previewProc.wanted = theme
        previewProc.command = [root.cli, "gowall-icons", theme, "--preview"]
        previewProc.running = true
    }

    Process {
        id: previewProc
        property var found: []
        property string wanted: ""

        stdout: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (!t.startsWith("preview=")) return
                const parts = t.substring(8).split("|")
                if (parts.length === 2)
                    previewProc.found.push({ before: parts[0], after: parts[1] })
            }
        }

        onExited: code => {
            if (code === 0 && previewProc.found.length > 0) {
                root.iconPreview = previewProc.found
                root.iconPreviewTheme = previewProc.wanted
            } else {
                root.iconPreview = []
            }
        }
    }

    function refreshGowallThemes(force) {
        if (gowallListProc.running) return
        if (root.gowallChecked && !force) return
        gowallListProc.found = []
        gowallListProc.running = true
    }

    Process {
        id: gowallListProc
        property var found: []
        command: ["gowall", "list"]

        stdout: SplitParser {
            onRead: line => {
                const t = line.replace(/\x1b\[[0-9;]*m/g, "").trim()
                if (t.length > 0) gowallListProc.found.push(t)
            }
        }

        onExited: code => {
            root.gowallChecked = true
            root.gowallAvailable = code === 0 && gowallListProc.found.length > 0
            root.gowallThemes = root.gowallAvailable ? gowallListProc.found : []
            console.log("[ServiceWallpaper] gowall list →", root.gowallThemes.length, "themes (exit", code + ")")
        }
    }

    // ── Wallpaper application queue ────────────────────────────────────────
    property string _pendingPath: ""
    property bool   _applying: false
    property double _applyStartedAt: 0

    Process {
        id: applyProc
        onExited: code => {
            applyWatchdog.stop()
            const elapsed = (Date.now() - root._applyStartedAt).toFixed(0)
            console.log("[ServiceWallpaper] apply finished in", elapsed + "ms (exit", code + ")")
            WallpaperTheme.reloadColors()
            root._applying = false
            const next = root._pendingPath
            root._pendingPath = ""
            if (next) {
                console.log("[ServiceWallpaper] Dequeuing pending wallpaper:", next)
                root._startApply(next)
            }
        }
    }

    Timer {
        id: applyWatchdog
        interval: 60000
        onTriggered: {
            console.warn("[ServiceWallpaper] apply still running after 60s — stopping it")
            applyProc.running = false
        }
    }

    function _startApply(path) {
        _applying = true
        _pendingPath = ""
        _applyStartedAt = Date.now()
        console.log("[ServiceWallpaper] _startApply →", path, "| mode:", root.theme, "| t=0ms")
        if (!root.gowallActive && !root.gowallInvert)
            WallpaperTheme.showNow(path)
        applyProc.command = [root.cli, "wallpaper", "set", path,
                             "--scheme", root.scheme, "--mode", root.theme,
                             "--gowall", root.gowallTheme,
                             "--gowall-icons", root.gowallIcons && !root.kindleIcons ? "on" : "off",
                             "--invert", root.gowallInvert ? "on" : "off",
                             "--gowall-shell", root.gowallShell ? "on" : "off"]
        applyProc.running = true
        applyWatchdog.restart()
    }

    function _enqueue(path) {
        if (!path || path.length === 0) return
        if (_applying) {
            console.log("[ServiceWallpaper] Queued (busy):", path)
            _pendingPath = path
        } else {
            _startApply(path)
        }
    }

    // The untouched wallpaper — with gowall on, WallpaperTheme.wallpaper is the
    // recolored copy in the cache, and feeding that back in would convert a
    // converted image.
    readonly property string currentSource: WallpaperTheme.sourceWallpaper || WallpaperTheme.wallpaper

    // Re-runs the whole pipeline for the wallpaper that is already set. Used by
    // the settings pages after a scheme/palette change.
    function reapply() {
        const wp = root.currentSource
        if (!wp || wp.length === 0) {
            console.warn("[ServiceWallpaper] reapply: no wallpaper loaded yet")
            return
        }
        _enqueue(wp)
    }

    // Re-generates colors for the current wallpaper in the new mode.
    // gen_colors.py: ~615ms cold, ~44ms score-cached, ~2ms fully-cached.
    // A gowall palette is the exception: the recolor depends on the mode, so
    // the full pipeline has to run and repaint the desktop.
    function applyTheme() {
        const wp = root.currentSource
        if (!wp || wp.length === 0) {
            console.warn("[ServiceWallpaper] applyTheme: no wallpaper loaded yet")
            return
        }
        if (root.gowallActive) {
            console.log("[ServiceWallpaper] applyTheme → gowall", root.gowallTheme, "— full pipeline")
            _enqueue(wp)
            return
        }
        console.log("[ServiceWallpaper] applyTheme → mode:", root.theme, "wallpaper:", wp)
        const cmd = [root.cli, "scheme", "generate", wp, root.scheme, root.theme]
        if (themeProc.running) {
            themeProc.next = cmd
            return
        }
        themeProc.command = cmd
        themeProc.running = true
    }

    function flipMode(mode) {
        if (!mode || mode === root.theme) return
        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenTheme: mode })
        root.applyTheme()
    }

    Process {
        id: themeProc
        property var next: null
        onExited: {
            WallpaperTheme.reloadColors()
            if (themeProc.next) {
                themeProc.command = themeProc.next
                themeProc.next = null
                themeProc.running = true
            }
        }
    }
    // ── End queue ──────────────────────────────────────────────────────────

    property list<string> wallpapers: []
    property var filteredWallpapers: []
    property string currentSearchText: ""
    property var wallpaperMap: ({})
    property var processedFiles: ({})
    property string localSortBy: "name"

    onLocalSortByChanged: updateWallpapersList()

    // ── Favorites ──────────────────────────────────────────────────────────
    property string favoritesPath: Quickshell.env("HOME") + "/.config/quickshell/favorites.json"
    property var favorites: ({})
    property var favoritedWallpapers: []

    function isFavorite(cachePath) {
        return !!favorites[getOriginalPath(cachePath)]
    }

    function toggleFavorite(cachePath) {
        const orig = getOriginalPath(cachePath)
        if (!orig) return
        const copy = Object.assign({}, favorites)
        if (copy[orig]) delete copy[orig]
        else copy[orig] = true
        favorites = copy
        _updateFavoritedWallpapers()
        saveFavorites()
    }

    function _updateFavoritedWallpapers() {
        const favList = []
        for (let i = 0; i < wallpapers.length; i++) {
            const cp = wallpapers[i]
            if (favorites[getOriginalPath(cp)]) favList.push(cp)
        }
        favoritedWallpapers = favList
    }

    function saveFavorites() {
        const data = JSON.stringify(Object.keys(favorites))
        favSaver.command = [
            "python3", "-c",
            "import sys,json; json.dump(json.loads(sys.argv[1]),open(sys.argv[2],'w'),indent=2)",
            data, favoritesPath
        ]
        favSaver.running = true
    }

    function loadFavorites() {
        favLoader._buffer = ""
        favLoader.command = [
            "bash", "-c",
            "[ -f '" + favoritesPath + "' ] && cat '" + favoritesPath + "' || echo '[]'"
        ]
        favLoader.running = true
    }
    // ── End Favorites ──────────────────────────────────────────────────────

    // ── Online / Wallhaven ──────────────────────────────────────────────────
    property bool onlineMode: false
    property list<var> onlineWallpapers: []
    property bool isFetchingOnline: false
    property int  onlinePage: 1
    property int  onlineLastPage: 1
    property int  onlineTotal: 0
    property bool hasMorePages: false
    property int onlineRetryIn: 0
    property int _requestPage: 1
    readonly property int requestPage: _requestPage
    property bool _refetchPending: false
    readonly property string _statusMark: "@@NEBULA_HTTP@@"
    property string _fetchBuffer: ""
    property string _pendingDownloadPath: ""
    property string _partialPath: ""
    property string onlineError: ""
    property string onlineErrorKind: ""
    property string onlineColor: ""
    property string downloadingId: ""
    property int downloadedBytes: 0
    property int downloadTotalBytes: 0
    readonly property real downloadProgress: downloadTotalBytes > 0
        ? Math.min(1.0, downloadedBytes / downloadTotalBytes) : 0
    property bool _cancelingDownload: false
    property var _downloadQueue: []
    readonly property var queuedIds: _downloadQueue.map(w => w.id)
    readonly property var queuedItems: _downloadQueue
    property var failedIds: []
    property string _applyId: ""
    readonly property string applyId: _applyId
    property var _thumbQueue: []

    readonly property var wallhavenColors: [
        "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc",
        "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900",
        "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff", "424153"
    ]
    readonly property var wallhavenRatios: ["16x9", "16x10", "21x9", "32x9", "48x9", "4x3", "5x4", "3x2", "1x1"]

    readonly property var _bigScreen: {
        let best = null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++) {
            const s = list[i]
            const w = Math.round(s.width * (s.devicePixelRatio || 1))
            const h = Math.round(s.height * (s.devicePixelRatio || 1))
            if (!best || w * h > best.w * best.h) best = { w: w, h: h }
        }
        return best || { w: 1920, h: 1080 }
    }
    readonly property string fitAtleast: _bigScreen.w + "x" + _bigScreen.h
    readonly property string fitRatio: {
        const r = _bigScreen.w / _bigScreen.h
        let best = "16x9"
        let gap = 99
        for (const k of wallhavenRatios) {
            const p = k.split("x")
            const d = Math.abs(Number(p[0]) / Number(p[1]) - r)
            if (d < gap) { gap = d; best = k }
        }
        return best
    }

    function fitsScreen(wh) {
        const w = wh || SettingsConfig.wallhaven
        return w.atleast === fitAtleast && w.ratios === fitRatio
    }

    function matchThemeColor() {
        const pri = Colors.primary
        let best = "cc6633"
        let gap = 999
        for (const hex of wallhavenColors) {
            const c = Qt.color("#" + hex)
            if (c.hsvSaturation < 0.35 || c.hsvValue < 0.3) continue
            let d = Math.abs(c.hsvHue - pri.hsvHue)
            d = Math.min(d, 1 - d) + Math.abs(c.hsvSaturation - pri.hsvSaturation) * 0.05
            if (d < gap) { gap = d; best = hex }
        }
        return best
    }

    onOnlineModeChanged: {
        onlineRetry.stop()
        onlineRetryIn = 0
        if (onlineMode) {
            onlineWallpapers = []
            onlinePage = 1
            onlineError = ""
            onlineErrorKind = ""
        }
    }

    function isQueued(id) {
        return id !== "" && queuedIds.indexOf(id) >= 0
    }

    function queuePosition(id) {
        return queuedIds.indexOf(id) + 1
    }

    function buildWallhavenUrl(page, wh) {
        const w = wh || SettingsConfig.wallhaven
        const p = []
        p.push("categories=" + w.categories)
        p.push("purity="     + w.purity)
        p.push("sorting="    + w.sorting)
        p.push("order="      + w.order)
        if (w.sorting === "toplist")
            p.push("topRange=" + w.topRange)
        if ((w.atleast ?? "").length > 0)
            p.push("atleast=" + encodeURIComponent(w.atleast))
        if ((w.ratios ?? "").length > 0)
            p.push("ratios=" + encodeURIComponent(w.ratios))
        if (onlineColor.length > 0)
            p.push("colors=" + onlineColor)
        if (currentSearchText.length > 0)
            p.push("q=" + encodeURIComponent(currentSearchText))
        if ((w.apiKey ?? "").length > 0)
            p.push("apikey=" + encodeURIComponent(w.apiKey))
        p.push("page=" + page)
        return "https://wallhaven.cc/api/v1/search?" + p.join("&")
    }

    function fetchWallhaven(resetPage) {
        if (isFetchingOnline) {
            if (resetPage) _refetchPending = true
            return
        }
        onlineRetry.stop()
        onlineRetryIn = 0
        if (resetPage) {
            onlinePage = 1
            onlineWallpapers = []
            onlineTotal = 0
            onlineLastPage = 1
            hasMorePages = false
            _requestPage = 1
        }
        isFetchingOnline = true
        onlineError = ""
        onlineErrorKind = ""
        _fetchBuffer = ""
        console.log("[ServiceWallpaper] Fetching Wallhaven page", _requestPage)
        wallhavenFetcher.command = [
            "curl", "-sS", "--max-time", "20",
            "-w", "\n" + _statusMark + "%{http_code}",
            buildWallhavenUrl(_requestPage)
        ]
        wallhavenFetcher.running = true
    }

    function searchOnline(text) {
        currentSearchText = text
        fetchWallhaven(true)
    }

    function setOnlineColor(hex) {
        if (onlineColor === hex) return
        onlineColor = hex
        fetchWallhaven(true)
    }

    function patchWallhaven(p) {
        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, p)
        fetchWallhaven(true)
    }

    function retryOnlineNow() {
        onlineRetry.stop()
        onlineRetryIn = 0
        fetchWallhaven(false)
    }

    readonly property var recentSearches: SettingsConfig.wallhaven.recent ?? []

    function _rememberSearch(text) {
        const low = text.toLowerCase()
        if (low.startsWith("like:")) return
        const next = [text].concat(recentSearches.filter(t => t.toLowerCase() !== low)).slice(0, 6)
        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { recent: next })
    }

    function forgetSearch(text) {
        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven,
            { recent: recentSearches.filter(t => t !== text) })
    }

    function _rateLimited() {
        onlineRetryIn = 15
        onlineErrorKind = "rate"
        onlineError = "Wallhaven is busy — retrying in " + onlineRetryIn + "s"
        onlineRetry.restart()
    }

    function _parseWallhavenResults(raw) {
        const at = raw.lastIndexOf(_statusMark)
        const status = at >= 0 ? parseInt(raw.slice(at + _statusMark.length)) : 0
        const body = at >= 0 ? raw.slice(0, at) : raw

        if (status === 429) {
            _rateLimited()
            return
        }
        if (status === 401) {
            onlineErrorKind = "key"
            onlineError = "Wallhaven didn't accept your API key"
            return
        }
        if (status !== 200) {
            onlineErrorKind = "http"
            onlineError = "Wallhaven returned an error (HTTP " + status + ")"
            console.error("[ServiceWallpaper] Wallhaven HTTP", status, "| body:", body.trim().slice(0, 200))
            return
        }

        try {
            const data = JSON.parse(body)
            if (data.error) {
                onlineErrorKind = "http"
                onlineError = data.error
                console.error("[ServiceWallpaper] Wallhaven API error:", data.error)
                return
            }

            const items = data.data || []
            const meta  = data.meta || {}

            const seen = {}
            if (_requestPage > 1)
                for (const w of onlineWallpapers) seen[w.id] = true
            const parsed = items.filter(item => !seen[item.id]).map(item => ({
                id:         item.id,
                thumbUrl:   item.thumbs.large,
                fullUrl:    item.path,
                pageUrl:    item.url || ("https://wallhaven.cc/w/" + item.id),
                resolution: item.resolution,
                fileType:   item.file_type,
                fileSize:   item.file_size || 0,
                views:      item.views || 0,
                favorites:  item.favorites || 0,
                category:   item.category || "",
                purity:     item.purity || "sfw",
                colors:     item.colors || []
            }))

            onlinePage = _requestPage
            onlineWallpapers = (_requestPage === 1)
                ? parsed
                : [...onlineWallpapers, ...parsed]

            _queueThumbs(parsed)
            onlineTotal = meta.total || onlineWallpapers.length
            if (_requestPage === 1 && onlineTotal > 0 && currentSearchText.trim().length > 0)
                _rememberSearch(currentSearchText.trim())
            onlineLastPage = meta.last_page || 1
            hasMorePages = (meta.current_page || 1) < (meta.last_page || 1)
            onlineError = ""
            onlineErrorKind = ""
            console.log("[ServiceWallpaper] Wallhaven: got", parsed.length,
                        "wallpapers, page", meta.current_page, "/", meta.last_page)
        } catch (e) {
            onlineErrorKind = "http"
            onlineError = "Wallhaven sent something unreadable — try again"
            console.error("[ServiceWallpaper] Wallhaven parse error:", e, "| body:", body.trim().slice(0, 200))
        }
    }

    function fetchNextPage() {
        if (!hasMorePages || isFetchingOnline || onlineRetry.running) return
        _requestPage = onlinePage + 1
        fetchWallhaven(false)
    }

    property var onlineDetails: ({})
    property string _detailNext: ""

    function detailsFor(id) {
        return id ? onlineDetails[id] ?? null : null
    }

    function requestDetails(id) {
        if (!id || onlineDetails[id]) return
        if (detailProc.running) {
            _detailNext = id
            return
        }
        detailProc._id = id
        detailProc._buf = ""
        const key = SettingsConfig.wallhaven.apiKey ?? ""
        detailProc.command = ["curl", "-sS", "--max-time", "15",
            "https://wallhaven.cc/api/v1/w/" + id + (key.length > 0 ? "?apikey=" + encodeURIComponent(key) : "")]
        detailProc.running = true
    }

    property var onlineThumbs: ({})
    property var onlineThumbMiss: ({})
    property var _onlineThumbNext: null
    property var _thumbWant: []

    function onlineThumbUrl(item) {
        if (!item || typeof item !== "object" || !item.id) return ""
        const p = onlineThumbs[item.id]
        if (p) return "file://" + p
        return onlineThumbMiss[item.id] ? (item.thumbUrl || "") : ""
    }

    function _queueThumbs(items) {
        const want = _thumbWant.slice()
        for (const it of items)
            if (it && it.id && it.thumbUrl && !onlineThumbs[it.id] && !want.some(w => w.id === it.id))
                want.push(it)
        _thumbWant = want
        if (!thumbBatch.running)
            _runThumbs()
    }

    function _runThumbs() {
        const batch = _thumbWant.slice(0, 24)
        _thumbWant = _thumbWant.slice(24)
        if (batch.length === 0) return
        const args = []
        for (const it of batch)
            args.push(it.id, it.thumbUrl)
        thumbBatch._ids = batch.map(it => it.id)
        thumbBatch.command = ["sh", Quickshell.shellDir + "/scripts/wallhaven_thumbs.sh", onlineThumbDir, ...args]
        thumbBatch._got = ({})
        thumbBatch.running = true
    }
    readonly property string onlineThumbDir: StandardPaths.writableLocation(StandardPaths.CacheLocation).toString().replace("file://", "") + "/wallhaven-thumbs"

    function onlinePreviewFor(item) {
        if (!item || typeof item !== "object" || !item.id) return null
        const p = onlineThumbs[item.id]
        return p ? previewFor(p) : null
    }

    function requestOnlinePreview(item) {
        if (!item || typeof item !== "object" || !item.id || !item.thumbUrl || !previewUsable) return
        const p = onlineThumbs[item.id]
        if (p) {
            requestPreview(p)
            return
        }
        if (onlineThumbProc.running) {
            _onlineThumbNext = item
            return
        }
        onlineThumbProc._id = item.id
        onlineThumbProc._path = onlineThumbDir + "/" + item.id + ".jpg"
        onlineThumbProc.command = ["sh", "-c", "mkdir -p \"$1\" && { [ -s \"$2\" ] || { curl -sSfL --max-time 15 -o \"$2.part\" \"$3\" && mv -f \"$2.part\" \"$2\"; } || { rm -f \"$2.part\"; exit 1; }; }",
            "sh", onlineThumbDir, onlineThumbProc._path, item.thumbUrl]
        onlineThumbProc.running = true
    }

    property int draftCount: -1
    property var _countDraft: null

    function requestCount(wh) {
        _countDraft = wh
        draftCount = -1
        countDebounce.restart()
    }

    function _runCount() {
        if (!_countDraft) return
        if (countProc.running) {
            countDebounce.restart()
            return
        }
        countProc._buf = ""
        countProc.command = ["curl", "-sS", "--max-time", "15", buildWallhavenUrl(1, _countDraft)]
        countProc.running = true
    }

    function _savePathFor(wallpaper) {
        const ext = wallpaper.fullUrl.split('.').pop().split('?')[0] || "jpg"
        return root.wallpaperDir + "/" + wallpaper.id + "." + ext
    }

    function downloadAndSetWallpaper(wallpaper, apply) {
        if (!wallpaper || typeof wallpaper !== "object" || !wallpaper.fullUrl) return
        const applyIt = apply !== false
        failedIds = failedIds.filter(x => x !== wallpaper.id)
        const local = localFor(wallpaper)
        if (local !== "") {
            if (applyIt) {
                _applyId = ""
                applyFile(local)
            }
            return
        }
        if (applyIt) _applyId = wallpaper.id
        if (wallpaper.id === downloadingId) return
        if (wallhavenDownloader.running || _pendingDownloadPath.length > 0) {
            if (!_downloadQueue.some(w => w.id === wallpaper.id))
                _downloadQueue = [..._downloadQueue, wallpaper]
            return
        }
        _downloadQueue = _downloadQueue.filter(w => w.id !== wallpaper.id)
        _startDownload(wallpaper)
    }

    function saveWallpaper(wallpaper) {
        downloadAndSetWallpaper(wallpaper, false)
    }

    function _startDownload(wallpaper) {
        const savePath = _savePathFor(wallpaper)
        _pendingDownloadPath = savePath
        _partialPath = onlineThumbDir + "/" + wallpaper.id + ".part"
        downloadingId = wallpaper.id
        downloadedBytes = 0
        downloadTotalBytes = wallpaper.fileSize || 0
        downloadPoller.restart()
        console.log("[ServiceWallpaper] Downloading wallpaper", wallpaper.id, "->", savePath)
        wallhavenDownloader.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" || exit 1; curl -sSfL --max-time 300 -o \"$1\" \"$3\" & c=$!; "
            + "trap 'kill $c 2>/dev/null; exit 143' TERM INT; wait $c || exit $?; mv -f \"$1\" \"$2\"",
            "sh", _partialPath, savePath, wallpaper.fullUrl]
        wallhavenDownloader.running = true
    }

    function _nextDownload() {
        while (_downloadQueue.length > 0) {
            const next = _downloadQueue[0]
            _downloadQueue = _downloadQueue.slice(1)
            const local = localFor(next)
            if (local === "") {
                _startDownload(next)
                return
            }
            if (_applyId === next.id) {
                _applyId = ""
                applyFile(local)
            }
        }
    }

    function unqueueDownload(id) {
        _downloadQueue = _downloadQueue.filter(w => w.id !== id)
        if (_applyId === id) _applyId = ""
    }

    function cancelDownload() {
        if (!wallhavenDownloader.running) return
        _cancelingDownload = true
        wallhavenDownloader.running = false
    }

    function cancelAllDownloads() {
        _downloadQueue = []
        _applyId = ""
        cancelDownload()
    }

    function openOnWallhaven(item) {
        if (!item || !item.id) return
        ServiceApps.spawn(["xdg-open", item.pageUrl || ("https://wallhaven.cc/w/" + item.id)])
    }

    function _runThumbJob() {
        if (downloadedThumbGen.running || _thumbQueue.length === 0) return
        const job = _thumbQueue[0]
        _thumbQueue = _thumbQueue.slice(1)
        downloadedThumbGen.savePath = job.savePath
        downloadedThumbGen.thumbPath = job.thumbPath
        downloadedThumbGen.command = [
            "convert", job.savePath,
            "-resize", root.thumbSize + "x" + root.thumbSize + "^",
            "-gravity", "center",
            "-extent", root.thumbSize + "x" + root.thumbSize,
            "-quality", "85",
            job.thumbPath
        ]
        downloadedThumbGen.running = true
    }
    // ── End Online ──────────────────────────────────────────────────────────

    onWallpapersChanged: {
        updateSearch(currentSearchText)
        _updateFavoritedWallpapers()
    }

    function fuzzyQuery(search: string): var {
        const existing = new Set(wallpapers)
        const preps = []
        for (let i = 0; i < folderModel.count; i++) {
            const orig = folderModel.get(i, "filePath")
            const cachePath = root.cacheDir + "/" + Qt.md5(orig) + ".jpg"
            if (existing.has(cachePath)) {
                preps.push({
                    content: Fuzzy.prepare(orig.split("/").pop()),
                    cachePath: cachePath
                })
            }
        }
        return Fuzzy.go(search, preps, { all: true, key: "content" })
            .map(r => r.obj.cachePath)
    }

    function updateSearch(searchText) {
        currentSearchText = searchText
        filteredWallpapers = searchText.length > 0 ? fuzzyQuery(searchText) : [...wallpapers]
    }

    property alias folderModel: folderModel
    property alias cacheModel: cacheModel

    property var thumbQueue: []
    property bool isProcessing: false

    Process {
        id: createCacheDir
        command: ["sh", "-c", "mkdir -p '" + root.cacheDir + "' && ls '" + root.cacheDir + "' > /dev/null"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[ServiceWallpaper] Cache directory ready:", root.cacheDir)
                cacheModel.folder = "file://" + root.cacheDir
                folderModel.folder = "file://" + root.wallpaperDir
                root.loadFavorites()
            } else {
                console.error("[ServiceWallpaper] Failed to create cache directory:", root.cacheDir)
            }
        }
    }

    FolderListModel {
        id: folderModel
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.PNG", "*.JPG", "*.JPEG"]
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        showOnlyReadable: true

        onFolderChanged: {
            console.log("[ServiceWallpaper] Scanning wallpaper folder:", root.wallpaperDir)
        }

        onCountChanged: {
            console.log("[ServiceWallpaper] Found", count, "wallpapers in folder")
            if (count === 0) {
                console.warn("[ServiceWallpaper] No wallpapers found! Check if folder exists:", root.wallpaperDir)
            }
            if (count > 0 && !root.isProcessing) {
                generateThumbnails()
            }
        }

        onStatusChanged: {
            if (status === FolderListModel.Ready && count === 0)
                console.warn("[ServiceWallpaper] Folder is ready but empty. Path:", root.wallpaperDir)
            if (status === FolderListModel.Ready)
                root.generateThumbnails()
        }
    }

    FolderListModel {
        id: cacheModel
        nameFilters: ["*.jpg"]
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        showOnlyReadable: true

        onFolderChanged: {
            console.log("[ServiceWallpaper] Cache folder changed to:", folder)
        }

        onCountChanged: {
            console.log("[ServiceWallpaper] Cache contains", count, "thumbnails")
            updateWallpapersList()
        }

        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.generateThumbnails()
        }
    }

    function cachedThumbNames() {
        const have = ({})
        for (let i = 0; i < cacheModel.count; i++)
            have[cacheModel.get(i, "fileName")] = true
        return have
    }

    property bool _rescanPending: false

    function _pointsAt(model, dir) {
        const strip = s => s.replace(/\/+$/, "")
        return strip(decodeURIComponent(model.folder.toString())) === strip("file://" + dir)
    }

    function generateThumbnails() {
        if (!root._pointsAt(folderModel, root.wallpaperDir)) return
        if (!root._pointsAt(cacheModel, root.cacheDir)) return
        if (root.isProcessing) {
            root._rescanPending = true
            return
        }
        if (folderModel.count === 0) return
        if (folderModel.status !== FolderListModel.Ready) return
        if (cacheModel.status !== FolderListModel.Ready) return

        const have = root.cachedThumbNames()
        const queue = []

        for (let i = 0; i < folderModel.count; i++) {
            const originalPath = folderModel.get(i, "filePath")
            const hash = Qt.md5(originalPath)
            const thumbPath = root.cacheDir + "/" + hash + ".jpg"

            if (have[hash + ".jpg"]) {
                root.wallpaperMap[thumbPath] = originalPath
                root.processedFiles[originalPath] = true
                continue
            }

            if (root.processedFiles[originalPath]) continue
            queue.push({ originalPath: originalPath, thumbPath: thumbPath })
        }

        root.updateWallpapersList()

        if (queue.length === 0) return

        console.log("[ServiceWallpaper] Generating", queue.length, "missing thumbnails")
        root.thumbQueue = queue
        root.isProcessing = true
        root.processNextThumbnail()
    }

    function processNextThumbnail() {
        if (root.thumbQueue.length === 0) {
            root.isProcessing = false
            if (root._rescanPending) {
                root._rescanPending = false
                root.generateThumbnails()
            }
            root.updateWallpapersList()
            return
        }

        const job = root.thumbQueue[0]
        root.processedFiles[job.originalPath] = true
        root.wallpaperMap[job.thumbPath] = job.originalPath

        thumbGenerator.originalPath = job.originalPath
        thumbGenerator.thumbPath = job.thumbPath
        thumbGenerator.command = [
            "convert",
            job.originalPath,
            "-resize", root.thumbSize + "x" + root.thumbSize + "^",
            "-gravity", "center",
            "-extent", root.thumbSize + "x" + root.thumbSize,
            "-quality", "85",
            job.thumbPath
        ]
        thumbGenerator.running = true
    }

    Process {
        id: thumbGenerator
        property string originalPath: ""
        property string thumbPath: ""

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.error("[ServiceWallpaper] Failed to generate thumbnail for:", originalPath)
                delete root.wallpaperMap[thumbPath]
            }
            root.thumbQueue = root.thumbQueue.slice(1)
            processNextThumbnail()
        }
    }

    function updateWallpapersList() {
        const entries = []
        const names = {}
        for (let i = 0; i < folderModel.count; i++) {
            const originalPath = folderModel.get(i, "filePath")
            names[folderModel.get(i, "fileName")] = originalPath
            const cachePath = root.cacheDir + "/" + Qt.md5(originalPath) + ".jpg"
            if (root.wallpaperMap[cachePath]) {
                entries.push({
                    cachePath: cachePath,
                    modified: folderModel.get(i, "fileModified")
                })
            }
        }
        if (localSortBy === "newest") {
            entries.sort((a, b) => new Date(b.modified) - new Date(a.modified))
        } else {
            entries.sort((a, b) => {
                const nameA = root.wallpaperMap[a.cachePath].split("/").pop().toLowerCase()
                const nameB = root.wallpaperMap[b.cachePath].split("/").pop().toLowerCase()
                return nameA < nameB ? -1 : nameA > nameB ? 1 : 0
            })
        }
        console.log("[ServiceWallpaper] Total wallpapers available:", entries.length)
        root.localNames = names
        root.wallpapers = entries.map(e => e.cachePath)
    }

    function getOriginalPath(cachePath: string): string {
        return root.wallpaperMap[cachePath] || cachePath
    }

    function setWallpaper(cachePath: string) {
        const originalPath = getOriginalPath(cachePath)
        if (!originalPath) {
            console.error("[ServiceWallpaper] Cannot find original path for:", cachePath)
            return
        }
        console.log("[ServiceWallpaper] Setting wallpaper:", originalPath)
        _enqueue(originalPath)
    }

    function refresh() {
        console.log("[ServiceWallpaper] Refreshing wallpaper list")
        const folder = folderModel.folder
        folderModel.folder = ""
        folderModel.folder = folder
    }

    // ── Wallhaven processes ─────────────────────────────────────────────────
    Process {
        id: wallhavenFetcher
        stdout: SplitParser {
            onRead: line => { root._fetchBuffer += line }
        }
        onExited: (exitCode) => {
            const raw = root._fetchBuffer
            root._fetchBuffer = ""
            root.isFetchingOnline = false
            if (root._refetchPending || !root.onlineMode) {
                root._refetchPending = false
                if (root.onlineMode) root.fetchWallhaven(true)
                return
            }
            if (exitCode === 0) {
                root._parseWallhavenResults(raw)
            } else {
                root.onlineErrorKind = "network"
                root.onlineError = "Can't reach Wallhaven — check your connection"
                console.error("[ServiceWallpaper] Wallhaven curl failed, exit:", exitCode)
            }
        }
    }

    Timer {
        id: onlineRetry
        interval: 1000
        repeat: true
        onTriggered: {
            root.onlineRetryIn = Math.max(0, root.onlineRetryIn - 1)
            if (root.onlineRetryIn > 0) {
                root.onlineError = "Wallhaven is busy — retrying in " + root.onlineRetryIn + "s"
                return
            }
            stop()
            if (root.onlineMode) root.fetchWallhaven(false)
        }
    }

    Process {
        id: wallhavenDownloader
        onExited: (exitCode) => {
            downloadPoller.stop()
            const savePath = root._pendingDownloadPath
            const partial = root._partialPath
            root._partialPath = ""
            const id = root.downloadingId
            root._pendingDownloadPath = ""
            root.downloadingId = ""
            root.downloadedBytes = 0
            if (root._cancelingDownload) {
                console.log("[ServiceWallpaper] Download canceled:", savePath)
                Quickshell.execDetached(["rm", "-f", partial])
                root._cancelingDownload = false
                if (root._applyId === id) root._applyId = ""
            } else if (exitCode === 0) {
                console.log("[ServiceWallpaper] Download complete:", savePath)
                root.processedFiles[savePath] = true
                root._thumbQueue = [...root._thumbQueue, {
                    savePath: savePath,
                    thumbPath: root.cacheDir + "/" + Qt.md5(savePath) + ".jpg"
                }]
                root._runThumbJob()
                if (root._applyId === id) {
                    root._applyId = ""
                    root._enqueue(savePath)
                }
            } else {
                console.error("[ServiceWallpaper] Download failed for:", savePath, "exit", exitCode)
                Quickshell.execDetached(["rm", "-f", partial])
                if (root._applyId === id) root._applyId = ""
                root.failedIds = [...root.failedIds.filter(x => x !== id), id]
                ServiceNotification.sendNotification(
                    "Wallpaper Download Failed",
                    savePath.split("/").pop(),
                    "Wallpaper",
                    "dialog-error"
                )
            }
            root._nextDownload()
        }
    }

    Process {
        id: downloadedThumbGen
        property string savePath: ""
        property string thumbPath: ""
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[ServiceWallpaper] Download thumbnail ready:", thumbPath)
                root.wallpaperMap[thumbPath] = savePath
                const fileName = savePath.split("/").pop()
                ServiceNotification.sendNotification(
                    "Wallpaper Downloaded",
                    fileName,
                    "Wallpaper",
                    "image-x-generic",
                    thumbPath
                )
                root.refresh()
            } else {
                console.error("[ServiceWallpaper] Failed to generate thumbnail for:", savePath)
                ServiceNotification.sendNotification(
                    "Wallpaper Download Failed",
                    savePath.split("/").pop(),
                    "Wallpaper",
                    "dialog-error"
                )
            }
            root._runThumbJob()
        }
    }

    Process {
        id: detailProc
        property string _id: ""
        property string _buf: ""
        stdout: SplitParser { onRead: line => detailProc._buf += line }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const d = JSON.parse(detailProc._buf).data
                    if (d) {
                        const next = Object.assign({}, root.onlineDetails)
                        next[detailProc._id] = {
                            tags: (d.tags || []).map(t => ({ id: t.id, name: t.name })),
                            uploader: d.uploader ? d.uploader.username : "",
                            source: d.source || ""
                        }
                        root.onlineDetails = next
                    }
                } catch (e) {
                    console.warn("[ServiceWallpaper] Wallhaven details unreadable for", detailProc._id)
                }
            }
            detailProc._buf = ""
            const queued = root._detailNext
            root._detailNext = ""
            if (queued) Qt.callLater(root.requestDetails, queued)
        }
    }

    Process {
        id: thumbBatch
        property var _ids: []
        property var _got: ({})
        stdout: SplitParser {
            onRead: line => {
                const id = line.trim()
                if (id === "" || thumbBatch._ids.indexOf(id) < 0) return
                thumbBatch._got[id] = true
                const next = Object.assign({}, root.onlineThumbs)
                next[id] = root.onlineThumbDir + "/" + id + ".jpg"
                root.onlineThumbs = next
            }
        }
        onExited: {
            const miss = thumbBatch._ids.filter(id => !thumbBatch._got[id])
            if (miss.length > 0) {
                const next = Object.assign({}, root.onlineThumbMiss)
                for (const id of miss) next[id] = true
                root.onlineThumbMiss = next
            }
            Qt.callLater(root._runThumbs)
        }
    }

    Process {
        id: onlineThumbProc
        property string _id: ""
        property string _path: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                const next = Object.assign({}, root.onlineThumbs)
                next[onlineThumbProc._id] = onlineThumbProc._path
                root.onlineThumbs = next
                root.requestPreview(onlineThumbProc._path)
            }
            const queued = root._onlineThumbNext
            root._onlineThumbNext = null
            if (queued) Qt.callLater(root.requestOnlinePreview, queued)
        }
    }

    Timer {
        id: countDebounce
        interval: 450
        onTriggered: root._runCount()
    }

    Process {
        id: countProc
        property string _buf: ""
        stdout: SplitParser { onRead: line => countProc._buf += line }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const meta = JSON.parse(countProc._buf).meta
                    if (meta) root.draftCount = meta.total || 0
                } catch (e) {
                    root.draftCount = -2
                }
            } else {
                root.draftCount = -2
            }
            countProc._buf = ""
        }
    }

    Timer {
        id: downloadPoller
        interval: 300
        repeat: true
        running: false
        onTriggered: {
            if (root._partialPath.length > 0 && !fileSizeChecker.running) {
                fileSizeChecker._buf = ""
                fileSizeChecker.command = ["stat", "-c", "%s", root._partialPath]
                fileSizeChecker.running = true
            }
        }
    }

    Process {
        id: fileSizeChecker
        property string _buf: ""
        stdout: SplitParser {
            onRead: line => fileSizeChecker._buf += line
        }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                const sz = parseInt(fileSizeChecker._buf.trim())
                if (!isNaN(sz)) root.downloadedBytes = sz
            }
            fileSizeChecker._buf = ""
        }
    }
    // ── End Wallhaven processes ─────────────────────────────────────────────

    // ── Favorites processes ─────────────────────────────────────────────────
    Process {
        id: favLoader
        property string _buffer: ""
        stdout: SplitParser {
            onRead: line => { favLoader._buffer += line }
        }
        onExited: (exitCode) => {
            if (exitCode === 0 && favLoader._buffer.length > 0) {
                try {
                    const keys = JSON.parse(favLoader._buffer)
                    const set = {}
                    for (let i = 0; i < keys.length; i++) set[keys[i]] = true
                    root.favorites = set
                    root._updateFavoritedWallpapers()
                    console.log("[ServiceWallpaper] Loaded", keys.length, "favorites")
                } catch (e) {
                    console.warn("[ServiceWallpaper] Failed to parse favorites:", e)
                }
            }
            favLoader._buffer = ""
        }
    }

    Process {
        id: favSaver
        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.error("[ServiceWallpaper] Failed to save favorites, exit:", exitCode)
        }
    }
    // ── End Favorites processes ─────────────────────────────────────────────

    // ── File management ─────────────────────────────────────────────────────
    function deleteWallpaper(cachePath) {
        const orig = getOriginalPath(cachePath)
        if (!orig) return
        fileDeleter._cachePath = cachePath
        fileDeleter._origPath  = orig
        fileDeleter.command = ["rm", "-f", orig, cachePath]
        fileDeleter.running = true
        console.log("[ServiceWallpaper] Deleting wallpaper:", orig)
    }

    Process {
        id: fileDeleter
        property string _cachePath: ""
        property string _origPath: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                delete root.wallpaperMap[_cachePath]
                delete root.processedFiles[_origPath]
                root.wallpapers = root.wallpapers.filter(w => w !== _cachePath)
            } else {
                console.error("[ServiceWallpaper] Delete failed for:", _origPath)
            }
        }
    }
    // ── End File management ──────────────────────────────────────────────────

    readonly property int panelHeight: 600
    readonly property int panelWidth: 1480

    readonly property string currentCachePath: root.currentSource
        ? root.cacheDir + "/" + Qt.md5(root.currentSource) + ".jpg" : ""

    property var localNames: ({})

    function localFor(item) {
        if (!item || typeof item !== "object" || !item.fullUrl) return ""
        const ext = item.fullUrl.split('.').pop().split('?')[0] || "jpg"
        return root.localNames[item.id + "." + ext] || ""
    }

    function applyFile(path) {
        _enqueue(path)
    }

    property var seedInfo: ({})
    property string _seedNext: ""

    function _seedKey(path) {
        return path + "|" + root.scheme + "|" + root.theme
    }

    function seedsFor(path) {
        return path ? root.seedInfo[root._seedKey(path)] || null : null
    }

    function requestSeeds(path) {
        if (!path || root.seedInfo[root._seedKey(path)]) return
        if (seedProc.running) {
            root._seedNext = path
            return
        }
        seedProc.key = root._seedKey(path)
        seedProc.command = [root.cli, "scheme", "seeds", path, "--variant", root.scheme, "--mode", root.theme]
        seedProc.running = true
    }

    function chooseSeed(path, index) {
        const info = root.seedsFor(path)
        if (!info || info.chosen === index || seedSetProc.running) return
        const next = Object.assign({}, root.seedInfo)
        for (const k in next)
            if (k.startsWith(path + "|")) next[k] = Object.assign({}, next[k], { chosen: index })
        root.seedInfo = next
        seedSetProc.path = path
        seedSetProc.command = [root.cli, "scheme", "seed", path, String(index)]
        seedSetProc.running = true
    }

    Process {
        id: seedProc
        property string key: ""
        stdout: StdioCollector { id: seedOut }
        onExited: code => {
            if (code === 0) {
                try {
                    const next = Object.assign({}, root.seedInfo)
                    next[seedProc.key] = JSON.parse(seedOut.text)
                    root.seedInfo = next
                } catch (e) {
                    console.warn("[ServiceWallpaper] seeds parse failed:", e)
                }
            }
            const queued = root._seedNext
            root._seedNext = ""
            if (queued) root.requestSeeds(queued)
        }
    }

    Process {
        id: seedSetProc
        property string path: ""
        onExited: {
            const cachePath = root.cacheDir + "/" + Qt.md5(seedSetProc.path) + ".jpg"
            const next = Object.assign({}, root.previewColors)
            for (const k in next)
                if (k.startsWith(cachePath + "|")) delete next[k]
            root.previewColors = next
            root.requestPreview(cachePath)
            if (seedSetProc.path === root.currentSource) root.reapply()
        }
    }

    property var imageInfo: ({})
    property string _infoNext: ""

    function infoFor(path) {
        return path ? root.imageInfo[path] || null : null
    }

    function requestInfo(path) {
        if (!path || root.imageInfo[path]) return
        if (infoProc.running) {
            root._infoNext = path
            return
        }
        infoProc.target = path
        infoProc.command = ["sh", "-c", "magick identify -ping -format '%w %h\\n' \"$1[0]\"; stat -c %s \"$1\"", "_", path]
        infoProc.running = true
    }

    function formatBytes(n) {
        if (!n || n <= 0) return ""
        if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
        return Math.max(1, Math.round(n / 1024)) + " KB"
    }

    Process {
        id: infoProc
        property string target: ""
        stdout: StdioCollector { id: infoOut }
        onExited: {
            const lines = infoOut.text.trim().split("\n")
            const dims = (lines[0] || "").trim().split(" ")
            const w = parseInt(dims[0]), h = parseInt(dims[1])
            const bytes = parseInt(lines[lines.length - 1])
            if (w > 0 && h > 0) {
                const next = Object.assign({}, root.imageInfo)
                next[infoProc.target] = { width: w, height: h, bytes: bytes > 0 ? bytes : 0 }
                root.imageInfo = next
            }
            const queued = root._infoNext
            root._infoNext = ""
            if (queued) root.requestInfo(queued)
        }
    }

    readonly property bool previewUsable: !(root.gowallActive && root.gowallShell
                                            && (root.gowallTheme ?? "").toLowerCase() !== "match")
    property var previewColors: ({})
    property var _previewQueue: []

    function _previewKey(cachePath) {
        return cachePath + "|" + root.scheme + "|" + root.theme
    }

    function previewFor(cachePath) {
        if (!cachePath || !root.previewUsable) return null
        return root.previewColors[root._previewKey(cachePath)] ?? null
    }

    function requestPreview(cachePath) {
        if (!cachePath || !root.previewUsable) return
        if (root.previewColors[root._previewKey(cachePath)]) return
        root._previewQueue = [cachePath].concat(root._previewQueue.filter(p => p !== cachePath)).slice(0, 4)
        root._nextPreview()
    }

    function _nextPreview() {
        if (paletteProc.running || root._previewQueue.length === 0) return
        const cp = root._previewQueue[0]
        root._previewQueue = root._previewQueue.slice(1)
        if (root.previewColors[root._previewKey(cp)]) { root._nextPreview(); return }
        paletteProc._key = root._previewKey(cp)
        paletteProc._buf = ""
        paletteProc.command = [root.cli, "wallpaper", "preview", root.getOriginalPath(cp), cp, root.scheme, root.theme]
        paletteProc.running = true
    }

    Process {
        id: paletteProc
        property string _key: ""
        property string _buf: ""
        stdout: SplitParser {
            onRead: line => paletteProc._buf += line
        }
        onExited: exitCode => {
            if (exitCode === 0 && paletteProc._buf.length > 0) {
                try {
                    const next = Object.assign({}, root.previewColors)
                    next[paletteProc._key] = JSON.parse(paletteProc._buf)
                    root.previewColors = next
                } catch (e) {
                    console.warn("[ServiceWallpaper] preview parse failed:", e)
                }
            }
            paletteProc._buf = ""
            Qt.callLater(root._nextPreview)
        }
    }
}
