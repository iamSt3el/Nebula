pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.utils
import qs.modules.settings
import "../components/Bar/BarOps.js" as BarOps

Singleton{
    id: root
  
    property real scoreThreshold: 0.2
    property var allApplications: DesktopEntries.applications
    property real totalApps: allApplications.values.length
    property list<DesktopEntry> list: []

    // The XDG spec only counts top-level .desktop files in an applications
    // directory; subdirectories are meant for organisation and are supposed to
    // be ignored. Quickshell walks them anyway, so Wine's generated start-menu
    // entries surface next to the native ones and the same app shows up twice.
    // A Wine copy is worse than a harmless extra row: it also wins the name
    // search, so "firefox" can hand you the Windows build.
    function _isWine(entry): bool {
        const cmd = entry.command ?? []
        return cmd.some(p => p === "wine" || p.startsWith("WINEPREFIX="))
    }

    // Collapse in two passes. startupClass is the strongest identity a desktop
    // entry carries, so entries sharing one are the same app by definition.
    // Display name is only used to catch a Wine entry shadowing a native one —
    // never to merge two name-only matches, since unrelated apps legitimately
    // share a name ("Files", "Terminal") and both need to stay reachable.
    function _dedupe(entries): var {
        const byClass = new Map()
        const rest = []

        for (const e of entries) {
            const cls = (e.startupClass ?? "").toLowerCase()
            if (cls.length === 0) { rest.push(e); continue }
            const prev = byClass.get(cls)
            if (!prev || (_isWine(prev) && !_isWine(e))) byClass.set(cls, e)
        }

        const byName = new Map()
        const kept = []

        for (const e of Array.from(byClass.values()).concat(rest)) {
            const key = (e.name ?? "").trim().toLowerCase()
            if (key.length === 0) { kept.push(e); continue }

            const prev = byName.get(key)
            if (prev === undefined) { byName.set(key, e); kept.push(e); continue }

            // Two non-Wine entries (or two Wine ones) sharing a display name are
            // different apps, not duplicates. Keep both.
            if (_isWine(prev) === _isWine(e)) { kept.push(e); continue }

            // Otherwise one side is a Wine wrapper. The native entry wins the
            // name and replaces the wrapper; if the wrapper came first we have
            // already kept it, so swap it out in place.
            if (_isWine(e)) continue
            byName.set(key, e)
            const i = kept.indexOf(prev)
            if (i >= 0) kept[i] = e
        }
        return kept
    }

    function rebuildList(): void {
        root.list = root._dedupe(Array.from(DesktopEntries.applications.values))
            .sort((a, b) => a.name.localeCompare(b.name))
    }
    Component.onCompleted: root.rebuildList()
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { listRebuild.restart() }
    }
    Timer {
        id: listRebuild
        interval: 150
        onTriggered: root.rebuildList()
    }
    readonly property list<DesktopEntry> pinnedApps: {
        const pins = new Set(SettingsConfig.general.pinnedApps)
        return list.filter(app => pins.has(app.id))
    }

    readonly property var dockModel: {
        const map = new Map()

        for (const id of SettingsConfig.general.pinnedApps) {
            map.set(id.toLowerCase(), { appId: id, pinned: true, toplevels: [] })
        }

        for (const toplevel of ToplevelManager.toplevels.values) {
            const appId = toplevel.appId?.toLowerCase() ?? ""
            if (!appId) continue
            if (!map.has(appId))
                map.set(appId, { appId: toplevel.appId, pinned: false, toplevels: [] })
            map.get(appId).toplevels.push(toplevel)
        }

        return Array.from(map.values())
    }

    property var displayableApps: {
        return allApplications.values.filter(function(app) {
            return !app.runInTerminal
        })
    }

    property var filteredApps: [...list]
    property string currentSearchText: ""
    property int selectedIndex: 0


    // Computed on first fuzzy search rather than at singleton creation (229 apps × Fuzzy.prepare)
    property var _preppedNames: null

    function _ensurePrepared() {
        if (!_preppedNames)
            _preppedNames = list.map(a => ({ name: Fuzzy.prepare(`${a.name} `), entry: a }))
        return _preppedNames
    }

    // Invalidate cache when app list changes
    onListChanged: _preppedNames = null

    function reset(): void{
        filteredApps = [...list]
    }


    function fuzzyQuery(search: string): var {
        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
            .sort((a, b) => b.score - a.score)
            return results
            .map(item => item.entry)
        }

        return Fuzzy.go(search, _ensurePrepared(), {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }




    // dockModel holds plain objects, not DesktopEntry, so a launch has to
    // resolve the entry first
    function entryFor(appId: string): var {
        if (!appId) return null
        const direct = DesktopEntries.heuristicLookup(appId)
        if (direct) return direct
        const lower = appId.toLowerCase()
        return root.list.find(a => (a.id ?? "").toLowerCase() === lower) ?? null
    }

    function launch(appId: string): bool {
        const entry = root.entryFor(appId)
        if (!entry) {
            console.warn("ServiceApps.launch: no desktop entry for", appId)
            return false
        }
        root.run(entry)
        return true
    }

    function isPinned(app): bool {
        return SettingsConfig.general.pinnedApps.includes(app.id)
    }

    function pin(app): void {
        if (!SettingsConfig.general.pinnedApps.includes(app.id))
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {pinnedApps: [...SettingsConfig.general.pinnedApps, app.id]})
    }

    function unpin(app): void {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {pinnedApps: SettingsConfig.general.pinnedApps.filter(id => id !== app.id)})
    }

    function togglePin(app): void {
        if (isPinned(app)) unpin(app)
        else pin(app)
    }

    function isPinnedById(appId: string): bool {
        return SettingsConfig.general.pinnedApps.some(id => id.toLowerCase() === appId.toLowerCase())
    }

    function togglePinById(appId: string): void {
        if (isPinnedById(appId))
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {pinnedApps: SettingsConfig.general.pinnedApps.filter(id => id.toLowerCase() !== appId.toLowerCase())})
        else
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {pinnedApps: [...SettingsConfig.general.pinnedApps, appId]})
    }

    function movePin(appId: string, index: int): void {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general,
            {pinnedApps: BarOps.movePin(SettingsConfig.general.pinnedApps, appId, index)})
    }

    function pinById(appId: string): void {
        if (!isPinnedById(appId))
            togglePinById(appId)
    }

    function unpinById(appId: string): void {
        if (isPinnedById(appId))
            togglePinById(appId)
    }

    property var usage: ({})

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/app-usage.json"
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {}
            } catch (e) {
                root.usage = {}
            }
        }
    }

    Timer {
        id: usageWrite
        interval: 1000
        onTriggered: usageFile.setText(JSON.stringify(root.usage))
    }

    function run(entry): void {
        if (!entry)
            return
        const next = Object.assign({}, root.usage)
        const prev = next[entry.id] ?? { count: 0, last: 0 }
        next[entry.id] = { count: prev.count + 1, last: Date.now() }
        root.usage = next
        usageWrite.restart()
        root.spawn(entry.command, entry.workingDirectory)
    }

    function spawn(command, workingDirectory): void {
        if (!command || command.length === 0)
            return
        Quickshell.execDetached({
            command: Array.from(command),
            environment: { LD_PRELOAD: null },
            workingDirectory: workingDirectory ?? ""
        })
    }

    function byUsage(apps): var {
        const u = root.usage
        return Array.prototype.slice.call(apps).sort((a, b) =>
            ((u[b.id] ? u[b.id].count : 0) - (u[a.id] ? u[a.id].count : 0)) || a.name.localeCompare(b.name))
    }

    function recent(n: int): var {
        const u = root.usage
        return root.list.filter(a => !!u[a.id]).sort((a, b) => u[b.id].last - u[a.id].last).slice(0, n)
    }

    function updateSearch(searchText){
        currentSearchText = searchText
        selectedIndex = 0

        if (searchText.length > 0) {
            filteredApps = fuzzyQuery(searchText)
        } else {
            filteredApps = [...list]
        }
    }
}
