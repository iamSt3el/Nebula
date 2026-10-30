pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    readonly property string dir: Quickshell.env("HOME") + "/.cache/quickshell/books"
    readonly property var cfg: SettingsConfig.books ?? ({})

    property var popular: []
    property int popularPage: 0
    property bool popularMore: true
    property bool popularLoading: false

    property var asura: []
    property int asuraPage: 0
    property bool asuraMore: true
    property bool asuraLoading: false

    property string query: ""
    property string searchSource: "gutenberg"
    property var results: []
    property bool searching: false

    property var local: []
    property bool localLoading: false
    property bool localScanned: false

    property var shelf: []
    property bool shelfLoaded: false

    property var book: null
    property var openItem: null
    property bool opening: false
    property string error: ""

    signal bookReady

    function setCfg(patch) {
        SettingsConfig.books = Object.assign({}, SettingsConfig.books, patch)
    }

    function keyOf(item) {
        if (!item)
            return ""
        if (item.key)
            return item.key
        if (item.source === "asura")
            return "asura-" + item.id
        return item.source === "gutenberg" ? "gb-" + item.id : ""
    }

    function entry(key) {
        return root.shelf.find(e => e.key === key) ?? null
    }

    readonly property var recent: root.shelf.slice().sort((a, b) => (b.opened ?? 0) - (a.opened ?? 0))
    readonly property var reading: root.recent.filter(e => (e.progress ?? 0) < 0.995)

    function loadMorePopular() {
        if (root.popularLoading || !root.popularMore)
            return
        root.popularLoading = true
        popularProc.command = [root.cli, "books", "popular", String(root.popularPage + 1)]
        popularProc.running = true
    }

    function loadMoreAsura() {
        if (root.asuraLoading || !root.asuraMore)
            return
        root.asuraLoading = true
        asuraProc.command = [root.cli, "books", "asura", String(root.asuraPage + 1)]
        asuraProc.running = true
    }

    function search(q, source) {
        root.searchSource = source ?? "gutenberg"
        root.query = q.trim()
        if (root.query === "") {
            root.results = []
            searchProc.running = false
            return
        }
        searchDebounce.restart()
    }

    function scanLocal() {
        if (root.localLoading)
            return
        root.localLoading = true
        localProc.running = true
    }

    function open(item) {
        if (!item || root.opening)
            return
        root.error = ""
        root.openItem = item
        root.opening = true
        openProc.command = [root.cli, "books", "open", item.source, String(item.id)]
        openProc.running = true
    }

    function closeBook() {
        root.book = null
        bookFile.path = ""
    }

    function remember(patch) {
        const list = root.shelf.slice()
        const i = list.findIndex(e => e.key === patch.key)
        if (i >= 0)
            list[i] = Object.assign({}, list[i], patch)
        else
            list.push(patch)
        root.shelf = list
        saveTimer.restart()
    }

    function forget(key) {
        root.shelf = root.shelf.filter(e => e.key !== key)
        saveTimer.restart()
    }

    function saveProgress(chapter, frac, progress) {
        if (!root.book)
            return
        root.remember({ key: root.book.key, chapter: chapter, frac: frac, progress: progress, opened: Date.now() })
    }

    function parse(text) {
        try {
            return JSON.parse(text)
        } catch (e) {
            return { ok: false, error: "Bad reply from the books helper" }
        }
    }

    Timer {
        id: searchDebounce
        interval: 380
        onTriggered: {
            if (root.query === "")
                return
            root.searching = true
            searchProc.command = [root.cli, "books", root.searchSource === "asura" ? "asura-search" : "search", root.query]
            searchProc.running = true
        }
    }

    Process {
        id: popularProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.popularLoading = false
                const d = root.parse(text)
                if (!d.ok) {
                    root.error = d.error ?? ""
                    return
                }
                const seen = new Set(root.popular.map(b => b.id))
                root.popular = root.popular.concat(d.items.filter(b => !seen.has(b.id)))
                root.popularPage += 1
                root.popularMore = d.next === true
            }
        }
    }

    Process {
        id: asuraProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.asuraLoading = false
                const d = root.parse(text)
                if (!d.ok) {
                    root.error = d.error ?? ""
                    return
                }
                const seen = new Set(root.asura.map(b => b.id))
                root.asura = root.asura.concat(d.items.filter(b => !seen.has(b.id)))
                root.asuraPage += 1
                root.asuraMore = d.next === true
            }
        }
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false
                const d = root.parse(text)
                root.results = d.ok ? d.items : []
                if (!d.ok)
                    root.error = d.error ?? ""
            }
        }
    }

    Process {
        id: localProc
        command: [root.cli, "books", "local"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localLoading = false
                root.localScanned = true
                const d = root.parse(text)
                root.local = d.ok ? d.items : []
            }
        }
    }

    Process {
        id: openProc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text)
                if (!d.ok) {
                    root.opening = false
                    root.error = d.error ?? "Could not open this book"
                    return
                }
                bookFile.path = ""
                bookFile.path = d.path
            }
        }
    }

    FileView {
        id: bookFile
        blockLoading: false
        onLoaded: {
            let b = null
            try {
                b = JSON.parse(text())
            } catch (e) {
                root.opening = false
                root.error = "This book's cache is damaged"
                return
            }
            const it = root.openItem ?? {}
            const known = root.entry(b.key)
            root.remember({
                key: b.key, source: b.source, id: b.id,
                title: b.title || it.title || "", author: b.author || it.author || "",
                cover: b.cover !== "" ? "file://" + b.cover : (it.cover ?? ""),
                chapters: b.chapters.length,
                chapter: known ? known.chapter : (b.start ?? 0),
                frac: known ? known.frac : 0,
                progress: known ? (known.progress ?? 0) : 0,
                opened: Date.now()
            })
            root.book = b
            root.opening = false
            root.bookReady()
        }
        onLoadFailed: {
            root.opening = false
            root.error = "Could not load the book file"
        }
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: store.setText(JSON.stringify({ v: 1, shelf: root.shelf }, null, 1))
    }

    FileView {
        id: store
        path: root.dir + "/shelf.json"
        blockLoading: false
        printErrors: false
        onLoaded: {
            if (root.shelfLoaded)
                return
            try {
                const d = JSON.parse(text())
                root.shelf = Array.isArray(d.shelf) ? d.shelf : []
            } catch (e) {
                root.shelf = []
            }
            root.shelfLoaded = true
        }
        onLoadFailed: root.shelfLoaded = true
    }
}
