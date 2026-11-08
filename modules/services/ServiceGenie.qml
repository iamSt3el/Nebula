pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.utils

Singleton {
    id: root

    readonly property string pluginPath: Quickshell.env("HOME") + "/.local/lib/hyprland/genie.so"
    readonly property string ctlPath: Quickshell.shellDir + "/plugins/HyprGenie/genie-ctl.sh"
    property bool loaded: false
    property bool missing: false
    property bool _triedLoad: false
    readonly property bool ready: true

    function keysFor(appId, entry) {
        const out = []
        const add = k => {
            const v = String(k ?? "").toLowerCase().trim()
            if (v !== "" && !/\s/.test(v) && v.indexOf("/") < 0 && out.indexOf(v) < 0)
                out.push(v)
        }
        add(appId)
        if (String(appId).toLowerCase() === "nebula-settings")
            add("org.quickshell")
        if (entry) {
            add(entry.id)
            add(entry.startupClass)
            const cmd = entry.command ?? []
            if (cmd.length > 0) {
                const bin = String(cmd[0]).split("/").pop()
                if (bin !== "env" && bin !== "flatpak" && bin !== "sh")
                    add(bin)
            }
        }
        return out
    }

    function rectOf(item) {
        if (!item || !item.visible)
            return null
        const att = item.QsWindow
        const win = att ? att.window : null
        if (!win || !win.screen)
            return null
        const r = att.itemRect(item)
        if (r.width <= 0 || r.height <= 0)
            return null
        return [Math.round(r.x + win.screen.x), Math.round(r.y + win.screen.y), Math.round(r.width), Math.round(r.height)]
    }

    function launch(appId, item) {
        if (root.loaded) {
            const entry = ServiceApps.entryFor(appId)
            const r = root.rectOf(item)
            const keys = root.keysFor(appId, entry)
            if (r && keys.length > 0)
                Quickshell.execDetached(["hyprctl", "genie", "launch"].concat(r.map(String), keys))
        }
        return ServiceApps.launch(appId)
    }

    function armFrom(from, fallback, appId, entry) {
        if (!root.loaded)
            return
        const r = root.rectOf(from) ?? root.rectOf(fallback)
        const keys = root.keysFor(appId, entry ?? ServiceApps.entryFor(appId))
        if (r && keys.length > 0)
            Quickshell.execDetached(["hyprctl", "genie", "from"].concat(r.map(String), keys))
    }

    function armNotif(item, n) {
        const no = n?.notification ?? n
        const app = String(no?.desktopEntry || no?.appName || "")
        if (app !== "")
            root.armFrom(item, null, app, ServiceApps.entryFor(app))
    }

    readonly property bool overviewOn: root.loaded && ((SettingsConfig.general ?? {}).genieOverview ?? true)
    readonly property bool recedeOn: root.loaded && ((SettingsConfig.general ?? {}).genieRecede ?? true)
    readonly property int flyMs: 560
    readonly property int flyStagger: 45

    function addr(a) {
        const s = String(a ?? "")
        return s === "" ? "" : (s.startsWith("0x") ? s : "0x" + s)
    }

    function flyTo(items) {
        if (!root.overviewOn || items.length === 0)
            return
        const cmds = items.map((it, i) => ["genie flyto", root.addr(it.address)].concat(it.rect.map(String), [String(i * root.flyStagger)]).join(" "))
        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
    }

    function flyFrom(items, releaseFirst) {
        if (!root.loaded)
            return
        const cmds = releaseFirst ? ["genie release"] : []
        for (const it of items)
            cmds.push(["genie flyfrom", root.addr(it.address)].concat(it.rect.map(String), ["0"]).join(" "))
        if (cmds.length > 0)
            Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
        releaseTimer.restart()
    }

    function release() {
        if (root.loaded)
            Quickshell.execDetached(["hyprctl", "genie", "release"])
    }

    Timer {
        id: releaseTimer
        interval: 900
        onTriggered: root.release()
    }

    readonly property bool editing: GlobalStates.editMode
    onEditingChanged: root.applyRecede()
    onRecedeOnChanged: root.applyRecede()
    property bool _receded: false

    function applyRecede() {
        if (!root.loaded)
            return
        const want = root.editing && root.recedeOn
        if (want === root._receded)
            return
        root._receded = want
        Quickshell.execDetached(["hyprctl", "genie", want ? "recede" : "unrecede"])
    }

    readonly property string minimizedWorkspace: "special:minimized"

    function hyprFor(toplevel) {
        return Hyprland.toplevels.values.find(h => h.wayland === toplevel) ?? null
    }

    function isMinimized(toplevel) {
        const h = root.hyprFor(toplevel)
        return !!h && (h.workspace?.name ?? "") === root.minimizedWorkspace
    }

    function addressOf(toplevel) {
        const a = root.hyprFor(toplevel)?.address ?? ""
        return a === "" ? "" : (a.startsWith("0x") ? a : "0x" + a)
    }

    function minimize(toplevel) {
        const a = root.addressOf(toplevel)
        if (root.loaded && a !== "")
            Quickshell.execDetached(["hyprctl", "genie", "minimize", a])
    }

    function restore(toplevel) {
        const a = root.addressOf(toplevel)
        if (root.loaded && a !== "")
            Quickshell.execDetached(["hyprctl", "genie", "restore", a])
    }

    function minimizeFocused() {
        if (root.loaded)
            Quickshell.execDetached(["hyprctl", "genie", "minimize"])
    }

    IpcHandler {
        target: "genie"
        function refresh(): void { root._triedLoad = false; root.refresh() }
        function minimize(): void { root.minimizeFocused() }
    }

    GlobalShortcut {
        name: "minimize"
        description: "Minimize the focused window into the dock"
        onPressed: root.minimizeFocused()
    }

    function pushIcons() {
        if (!root.loaded)
            return
        const map = GlobalStates.dockIconItems
        const cmds = ["genie icons clear", "genie wsbars clear"]
        for (const ws of GlobalStates.wsItems) {
            const r = root.rectOf(ws)
            if (r)
                cmds.push(["genie", "wsbar"].concat(r.map(String), [String(ws.wsCount ?? 5)]).join(" "))
        }
        for (const key in map) {
            const item = (map[key] ?? []).find(i => i && i.visible)
            const r = root.rectOf(item)
            if (!r)
                continue
            const keys = root.keysFor(key, ServiceApps.entryFor(key))
            if (keys.length > 0)
                cmds.push(["genie", "icon"].concat(r.map(String), keys).join(" "))
        }
        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
    }

    readonly property string settingsBatch: {
        const g = SettingsConfig.general ?? {}
        return ["genie set open " + ((g.genieOpen ?? true) ? 1 : 0),
                "genie set close " + ((g.genieClose ?? true) ? 1 : 0),
                "genie set minimize " + ((g.genieMinimize ?? true) ? 1 : 0),
                "genie set tiled " + ((g.genieTiled ?? true) ? 1 : 0),
                "genie set style " + (g.genieStyle === "shape" ? "shape" : "genie"),
                "genie set workspace " + ((g.genieWorkspace ?? true) ? 1 : 0),
                "genie set ws_ms " + Math.round(g.genieWorkspaceMs ?? 500),
                "genie set ws_style " + (["glide", "carousel"].includes(g.genieWorkspaceStyle) ? g.genieWorkspaceStyle : "dot"),
                "genie set glide_lean " + ((g.genieGlideLean ?? true) ? 1 : 0),
                "genie set carousel_zoom " + ((g.genieCarouselZoom ?? 27) / 100).toFixed(2),
                "genie set carousel_cards " + ((g.genieCarouselCards ?? true) ? 1 : 0),
                "genie set card " + String(Colors.surfaceContainer).replace("#", "").slice(-6),
                "genie set label " + String(Colors.surfaceText).replace("#", "").slice(-6),
                "genie set move " + ((g.genieMove ?? true) ? 1 : 0),
                "genie set move_ms " + Math.round(g.genieMoveMs ?? 450),
                "genie set container " + String(Colors.surface).replace("#", "").slice(-6),
                "genie set accent " + String(Colors.surface).replace("#", "").slice(-6),
                "genie set open_ms " + Math.round(g.genieOpenMs ?? 600),
                "genie set close_ms " + Math.round(g.genieCloseMs ?? 520)].join(" ; ")
    }
    onSettingsBatchChanged: root.applySettings()
    onLoadedChanged: root.applySettings()

    function applySettings() {
        if (root.loaded)
            Quickshell.execDetached(["hyprctl", "--batch", root.settingsBatch])
    }

    function refresh() {
        if (!probe.running)
            probe.running = true
    }

    Process {
        id: probe
        command: ["hyprctl", "genie", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.startsWith("open ")
                root.loaded = ok
                if (ok) {
                    root.applySettings()
                    root.release()
                    root._receded = false
                    root.applyRecede()
                    pushTimer.restart()
                } else if (!root._triedLoad) {
                    root._triedLoad = true
                    loader.running = true
                }
            }
        }
    }

    Process {
        id: loader
        command: [root.ctlPath, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.missing = text.trim() !== "ok"
                if (root.missing)
                    console.warn("ServiceGenie: plugin did not load:", text.trim())
                else
                    root.refresh()
            }
        }
    }

    Timer {
        id: pushTimer
        interval: 350
        onTriggered: root.pushIcons()
    }

    Connections {
        target: GlobalStates
        function onDockIconsVersionChanged() {
            if (root.loaded)
                pushTimer.restart()
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            if (root.loaded)
                pushTimer.restart()
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.loaded)
                pushTimer.restart()
        }
    }

    Component.onCompleted: root.refresh()
}
