pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings

Singleton {
    id: root

    // ── Site selection ───────────────────────────────────────────────────────
    // "weebcentral" → port 5150  |  "comix" → port 5151
    property string currentSite: SettingsConfig.manga.defaultSite

    readonly property var _sites: ({
        "weebcentral": { label: "WEEBCentral", port: 5150, script: "manga_server.py"  },
        "comix":       { label: "Comix.to",    port: 5151, script: "comix_server.py" },
    })

    readonly property string apiUrl: "http://127.0.0.1:" + _sites[currentSite].port

    function switchSite(siteKey) {
        if (siteKey === currentSite) return
        currentSite = siteKey
        // Reset browse/detail state only — favs & downloads are shared
        mangaList         = []
        currentOffset     = 0
        latestPage        = 1
        currentSearchText = ""
        currentOrigin     = ""
        currentManga      = null
        chapterPages      = []
        serverReady       = false
        healthPoller.start()
    }

    // ── Manga list ──────────────────────────────────────────────────────────
    property list<var> mangaList: []
    property bool isFetchingManga: false
    property string mangaError: ""
    property bool hasMoreManga: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentOrigin: ""

    // ── Manga detail ────────────────────────────────────────────────────────
    property var currentManga: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter pages ───────────────────────────────────────────────────────
    property list<var> chapterPages: []
    property bool isFetchingPages: false
    property string pagesError: ""
    property string currentChapterId: ""
    property bool dataSaverMode: false  // kept for UI compatibility

    // ── Favorites ────────────────────────────────────────────────────────────
    property list<var> favoritesList: []
    property bool isFetchingFavs: false
    property int favNewCount: 0   // total series with new chapters

    // ── Downloads ────────────────────────────────────────────────────────────
    property list<var> downloadsList: []
    property var downloadProgress: ({})  // chapterId -> {status, total, done}

    // ── Bulk (whole-manga) download ───────────────────────────────────────────
    property var bulkDownload: ({ mangaId: "", total: 0, chapterIds: [] })
    // 0.0–1.0 while active, -1 when idle
    readonly property real bulkDownloadValue: {
        const job = bulkDownload
        if (!job.mangaId || job.total === 0) return -1
        var done = 0
        for (var i = 0; i < job.chapterIds.length; i++) {
            const p = downloadProgress[job.chapterIds[i]]
            if (p && p.status === "done") done++
        }
        const v = done / job.total
        return v >= 1.0 ? 1.0 : v
    }

    // ── Backend servers (both run always, active one is selected by apiUrl) ──
    property bool serverReady: false

    Process {
        id: serverProcess
        command: ["bash", "-c", "fuser -k 5150/tcp 2>/dev/null; sleep 0.3; exec python3 " + Quickshell.env("HOME") + "/.config/quickshell/scripts/manga_server.py"]
        running: true
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[ServiceManga] weebcentral server exited:", code)
                if (root.currentSite === "weebcentral") { root.serverReady = false; healthPoller.start() }
                weebRestartTimer.start()
            }
        }
    }

    Timer {
        id: weebRestartTimer
        interval: 3000
        repeat: false
        onTriggered: serverProcess.running = true
    }

    Process {
        id: comixProcess
        command: ["bash", "-c", "fuser -k 5151/tcp 2>/dev/null; sleep 0.3; exec python3 " + Quickshell.env("HOME") + "/.config/quickshell/scripts/comix_server.py"]
        running: true
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[ServiceManga] comix server exited:", code)
                if (root.currentSite === "comix") { root.serverReady = false; healthPoller.start() }
                comixRestartTimer.start()
            }
        }
    }

    Timer {
        id: comixRestartTimer
        interval: 3000
        repeat: false
        onTriggered: comixProcess.running = true
    }

    // Poll /health every 150ms until the active backend is ready
    Timer {
        id: healthPoller
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    healthPoller.stop()
                    root.serverReady = true
                    console.log("[ServiceManga] Backend ready at", root.apiUrl)
                    fetchByOrigin("", true)
                    fetchFavorites()
                    fetchDownloads()
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
        }
    }

    // Auto-check favorites for new chapters every 15 minutes
    Timer {
        id: favChecker
        interval: 900000
        repeat: true
        running: root.serverReady && root.favoritesList.length > 0
        onTriggered: checkFavoritesForUpdates()
    }

    // Poll active downloads every 500 ms
    Timer {
        id: dlPoller
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            var hasActive = false
            var ids = Object.keys(root.downloadProgress)
            for (var i = 0; i < ids.length; i++) {
                var st = root.downloadProgress[ids[i]].status
                if (st === "downloading" || st === "pending") { hasActive = true; break }
            }
            if (!hasActive) { dlPoller.stop(); return }
            for (var j = 0; j < ids.length; j++) {
                var s = root.downloadProgress[ids[j]].status
                if (s === "downloading" || s === "pending")
                    _pollOne(ids[j])
            }
        }
    }

    // ── HTTP helpers ─────────────────────────────────────────────────────────
    function _get(url, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200)
                onDone(null, xhr.responseText)
            else
                onDone("HTTP " + xhr.status, null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _post(url, data, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200)
                onDone(null, xhr.responseText)
            else
                onDone("HTTP " + xhr.status, null)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }

    // ── Origin → type mapping ────────────────────────────────────────────────
    function _originType(origin) {
        if (origin === "ko") return "Manhwa"
        if (origin === "ja") return "Manga"
        if (origin === "zh") return "Manhua"
        return ""
    }

    // ── Browse / Search ──────────────────────────────────────────────────────
    function fetchByOrigin(origin, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0; latestPage = 1 }
        currentOrigin = origin
        currentSearchText = ""

        if (origin === "") {
            isFetchingManga = true
            mangaError = ""
            let url = root.apiUrl + "/hot"
            if (SettingsConfig.manga.filterAdult) url += "?filter_adult=1"
            console.log("[ServiceManga] GET", url)
            _get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else if (origin === "latest") {
            if (reset) latestPage = 1
            isFetchingManga = true
            mangaError = ""
            let url = root.apiUrl + "/latest?page=" + latestPage
            if (SettingsConfig.manga.filterAdult) url += "&filter_adult=1"
            console.log("[ServiceManga] GET", url)
            _get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else {
            _doSearch("a", _originType(origin), currentOffset, "Popularity")
        }
    }

    function searchManga(query, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0 }
        currentSearchText = query
        _doSearch(query, _originType(currentOrigin), currentOffset, "Best Match")
    }

    function fetchNextMangaPage() {
        if (!hasMoreManga || isFetchingManga) return
        if (currentSearchText.length > 0) {
            _doSearch(currentSearchText, _originType(currentOrigin), currentOffset, "Best Match")
        } else if (currentOrigin === "latest") {
            latestPage++
            fetchByOrigin("latest", false)
        } else {
            _doSearch("a", _originType(currentOrigin), currentOffset, "Popularity")
        }
    }

    function _doSearch(query, type, offset, sort) {
        isFetchingManga = true
        mangaError = ""
        let url = root.apiUrl + "/search?q=" + encodeURIComponent(query)
                + "&offset=" + offset
                + "&sort=" + encodeURIComponent(sort)
        if (type) url += "&type=" + encodeURIComponent(type)
        if (SettingsConfig.manga.filterAdult) url += "&filter_adult=1"
        console.log("[ServiceManga] GET", url)
        _get(url, function(err, body) {
            if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
            _parseMangaResults(body)
        })
    }

    // Exact tag names used by WeebCentral (case-insensitive match)
    readonly property var _adultTags: ["adult", "smut", "ecchi"]

    function _isAdult(item) {
        if (!item.tags || !Array.isArray(item.tags)) return false
        const lower = item.tags.map(t => t.toLowerCase())
        return root._adultTags.some(tag => lower.indexOf(tag) !== -1)
    }

    function _parseMangaResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { mangaError = data.error; isFetchingManga = false; return }

            // /hot → plain array  |  /latest → {results, hasMore, nextPage}  |  /search → {results, hasMore, nextOffset}
            const isHot    = Array.isArray(data)
            const isLatest = !isHot && data.nextPage !== undefined
            const items    = isHot ? data : (data.results || [])

            const filtered = SettingsConfig.manga.filterAdult
                ? items.filter(item => !root._isAdult(item))
                : items

            mangaList = [...mangaList, ...filtered.map(item => ({
                id:       item.id     || "",
                title:    item.title  || "",
                thumbUrl: item.image  || "",
                status:   item.status || "",
                type:     item.type   || "",
                author:   ""
            }))]

            hasMoreManga = isHot ? false : (data.hasMore || false)
            if (!isHot && !isLatest)
                currentOffset = data.nextOffset || (currentOffset + items.length)

            mangaError = ""
            console.log("[ServiceManga] Got", items.length, "results, hasMore:", hasMoreManga)
        } catch (e) {
            mangaError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingManga = false
    }

    // ── Manga detail ─────────────────────────────────────────────────────────
    function fetchMangaDetail(mangaId) {
        if (isFetchingDetail) return
        isFetchingDetail = true
        currentManga = null
        detailError = ""

        const url = root.apiUrl + "/info?id=" + encodeURIComponent(mangaId)
        console.log("[ServiceManga] GET", url)
        _get(url, function(err, body) {
            if (err) { detailError = "Request failed: " + err; isFetchingDetail = false; return }
            _parseMangaDetail(body)
        })
    }

    function _parseMangaDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { detailError = data.error; isFetchingDetail = false; return }

            currentManga = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                year:        0,
                coverUrl:    data.image       || "",
                authors:     data.authors     || [],
                tags:        data.tags        || [],
                chapters:    (data.chapters   || []).map(ch => ({
                    id:        ch.id        || "",
                    chapter:   ch.chapter   || "",
                    title:     ch.title     || "",
                    pages:     0,
                    group:     "",
                    publishAt: ch.publishAt || ""
                }))
            }
            detailError = ""
            console.log("[ServiceManga] Detail:", currentManga.title,
                "—", currentManga.chapters.length, "chapters")
        } catch (e) {
            detailError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingDetail = false
    }

    // ── Chapter pages ─────────────────────────────────────────────────────────
    function fetchChapterPages(chapterId, mangaId) {
        if (isFetchingPages) return
        isFetchingPages = true
        currentChapterId = chapterId
        chapterPages = []
        pagesError = ""

        var url = root.apiUrl + "/pages?chapterId=" + encodeURIComponent(chapterId)
        if (mangaId) url += "&mangaId=" + encodeURIComponent(mangaId)
        console.log("[ServiceManga] GET", url)
        _get(url, function(err, body) {
            if (err) { pagesError = "Request failed: " + err; isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function fetchOfflineChapterPages(chapterId) {
        if (isFetchingPages) return
        isFetchingPages = true
        currentChapterId = chapterId
        chapterPages = []
        pagesError = ""

        const url = root.apiUrl + "/dl/pages?chapterId=" + encodeURIComponent(chapterId)
        console.log("[ServiceManga] GET offline", url)
        _get(url, function(err, body) {
            if (err) { pagesError = "Request failed: " + err; isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function _parseChapterPages(json) {
        try {
            const data = JSON.parse(json)
            if (data.error || !Array.isArray(data)) {
                pagesError = data.error || "Invalid response"
                isFetchingPages = false
                return
            }
            if (data.length === 0) {
                pagesError = "No pages found for this chapter"
                isFetchingPages = false
                return
            }
            chapterPages = data.map((p, idx) => ({
                index:     idx,
                url:       p.img || "",
                localPath: p.img || "",
                ready:     true
            }))
            pagesError = ""
            isFetchingPages = false
            console.log("[ServiceManga] Got", chapterPages.length, "pages")
        } catch (e) {
            pagesError = "Parse error: " + e
            isFetchingPages = false
        }
    }

    // ── Favorites ─────────────────────────────────────────────────────────────
    function fetchFavorites() {
        if (isFetchingFavs) return
        isFetchingFavs = true
        _get(root.apiUrl + "/favorites", function(err, body) {
            isFetchingFavs = false
            if (err) { console.warn("[ServiceManga] favorites fetch failed:", err); return }
            try {
                const data = JSON.parse(body)
                favoritesList = data
                favNewCount = data.filter(f => f.hasNewChapters).length
            } catch (e) {
                console.error("[ServiceManga] favorites parse error:", e)
            }
        })
    }

    function addFavorite(manga) {
        // manga must have: id, title, coverUrl (proxy URL)
        // Extract raw CDN URL from proxy URL for storage
        const rawUrl = _extractRawUrl(manga.coverUrl)
        _post(root.apiUrl + "/favorites/add",
              { id: manga.id, title: manga.title, imageUrl: rawUrl },
              function(err, body) {
                  if (!err) fetchFavorites()
              })
    }

    function removeFavorite(mangaId) {
        _post(root.apiUrl + "/favorites/remove", { id: mangaId }, function(err, body) {
            if (!err) fetchFavorites()
        })
    }

    function isFavorite(mangaId) {
        return favoritesList.some(f => f.id === mangaId)
    }

    function markChapterSeen(mangaId, chapterId) {
        _post(root.apiUrl + "/favorites/mark-seen",
              { id: mangaId, chapterId: chapterId },
              function(err, body) {
                  if (!err) fetchFavorites()
              })
    }

    function checkFavoritesForUpdates() {
        _get(root.apiUrl + "/favorites/check", function(err, body) {
            if (err) { console.warn("[ServiceManga] fav check failed:", err); return }
            try {
                const data = JSON.parse(body)
                if (data.updated && data.updated.length > 0) {
                    console.log("[ServiceManga] New chapters in", data.updated.length, "series")
                    fetchFavorites()
                }
            } catch (e) {}
        })
    }

    // ── Downloads ─────────────────────────────────────────────────────────────
    function fetchDownloads() {
        _get(root.apiUrl + "/dl/list", function(err, body) {
            if (err) { console.warn("[ServiceManga] dl/list failed:", err); return }
            try {
                downloadsList = JSON.parse(body)
            } catch (e) {
                console.error("[ServiceManga] dl/list parse error:", e)
            }
        })
    }

    function startDownload(chapter, manga) {
        // chapter: {id, chapter, title}; manga: {id, title, image}
        const rawCover = _extractRawUrl(manga.image || "")
        // Optimistically mark as pending
        var dp = Object.assign({}, downloadProgress)
        dp[chapter.id] = { status: "pending", total: 0, done: 0 }
        downloadProgress = dp
        dlPoller.start()
        _post(root.apiUrl + "/dl/start", {
            mangaId:      manga.id,
            chapterId:    chapter.id,
            chapterNum:   chapter.chapter,
            chapterTitle: chapter.title,
            mangaTitle:   manga.title,
            rawCoverUrl:  rawCover
        }, function(err, body) {
            if (err) {
                console.warn("[ServiceManga] dl/start failed:", err)
                var dp2 = Object.assign({}, downloadProgress)
                dp2[chapter.id] = { status: "error", total: 0, done: 0 }
                downloadProgress = dp2
            }
        })
    }

    function _pollOne(chapterId) {
        _get(root.apiUrl + "/dl/progress?chapterId=" + encodeURIComponent(chapterId),
             function(err, body) {
                 if (err) return
                 try {
                     const prog = JSON.parse(body)
                     var dp = Object.assign({}, downloadProgress)
                     dp[chapterId] = prog
                     downloadProgress = dp
                     if (prog.status === "done") {
                         fetchDownloads()
                         // Clear bulk job once all chapters are done
                         if (bulkDownload.mangaId && bulkDownloadValue >= 1.0)
                             bulkDownload = { mangaId: "", total: 0, chapterIds: [] }
                     }
                 } catch(e) {}
             })
    }

    function getDownloadProgress(chapterId) {
        return downloadProgress[chapterId] || { status: "not_started", total: 0, done: 0 }
    }

    function downloadAllChapters(manga) {
        const chapters = manga.chapters || []
        if (chapters.length === 0) return

        const allIds = chapters.map(function(c) { return c.id })
        const rawCover = _extractRawUrl(manga.image || "")

        // Mark not-started chapters as pending
        var dp = Object.assign({}, downloadProgress)
        chapters.forEach(function(ch) {
            const s = dp[ch.id] ? dp[ch.id].status : "not_started"
            if (s !== "done" && s !== "downloading" && s !== "pending")
                dp[ch.id] = { status: "pending", total: 0, done: 0 }
        })
        downloadProgress = dp

        bulkDownload = { mangaId: manga.id, total: chapters.length, chapterIds: allIds }
        dlPoller.start()

        chapters.forEach(function(ch) {
            const s = downloadProgress[ch.id] ? downloadProgress[ch.id].status : "not_started"
            if (s !== "done" && s !== "downloading")
                _post(root.apiUrl + "/dl/start", {
                    mangaId:      manga.id,
                    chapterId:    ch.id,
                    chapterNum:   ch.chapter,
                    chapterTitle: ch.title,
                    mangaTitle:   manga.title,
                    rawCoverUrl:  rawCover
                }, function(err) {
                    if (err) console.warn("[ServiceManga] bulk dl/start failed:", ch.id)
                })
        })
    }

    function deleteDownload(chapterId) {
        _post(root.apiUrl + "/dl/delete", { chapterId: chapterId }, function(err, body) {
            if (!err) fetchDownloads()
        })
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function _extractRawUrl(proxyUrl) {
        // proxy URL is http://127.0.0.1:5150/image?url=<encoded>
        // extract the encoded url param
        const match = proxyUrl.match(/[?&]url=([^&]+)/)
        return match ? decodeURIComponent(match[1]) : proxyUrl
    }

    function downloadMorePages(upTo) {}   // no-op, kept for compatibility

    function refreshChapterPages() {
        if (currentChapterId.length === 0) return
        chapterPages = []
        fetchChapterPages(currentChapterId)
    }

    function clearChapterList() {
        if (currentManga)
            currentManga = Object.assign({}, currentManga, { chapters: [] })
    }

    function clearChapterPages() {
        chapterPages = []
        currentChapterId = ""
        pagesError = ""
    }

    function clearMangaList() {
        mangaList = []
        hasMoreManga = false
        currentOffset = 0
        latestPage = 1
        mangaError = ""
    }
}
