pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

QtObject {
    id: root

    property var shellScreen: null
    property var source: null
    readonly property bool ready: root.source !== null
    readonly property string wallUrl: WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen : ""

    function overlaps(a, b) {
        return a.x < b.x + b.width && b.x < a.x + a.width
            && a.y < b.y + b.height && b.y < a.y + a.height
    }

    function covered(mon, box) {
        if (!mon)
            return false
        const ids = [mon.activeWorkspace?.id ?? 0]
        const special = mon.lastIpcObject?.specialWorkspace?.id ?? 0
        if (special !== 0)
            ids.push(special)
        for (const tl of Hyprland.toplevels.values) {
            const g = tl.lastIpcObject
            if (!g || !g.at || !g.size || g.hidden === true || g.mapped === false)
                continue
            const ws = tl.workspace?.id ?? g.workspace?.id ?? 0
            if (ids.indexOf(ws) < 0)
                continue
            if (root.overlaps(Qt.rect(g.at[0] - mon.x, g.at[1] - mon.y, g.size[0], g.size[1]), box))
                return true
        }
        return false
    }

    function wallFor(mon, width) {
        const fill = Settings.wallpaperFillOrDefault(SettingsConfig.general.wallpaperFill)
        const glideOn = (SettingsConfig.general.wallpaperGlide ?? true) && fill !== "full" && !ServiceGameMode.active
        const overscan = glideOn ? 0.25 : 0
        let top = 1
        for (const w of Hyprland.workspaces.values)
            if (w.id > top)
                top = w.id
        const span = Math.max(5, Math.min(10, top))
        const ws = Math.max(1, mon?.activeWorkspace?.id ?? 1)
        const glide = (Math.min(ws, span) - 1) / (span - 1)
        return {
            x: -glide * width * overscan,
            width: width * (1 + overscan),
            fillMode: fill === "full" ? Image.PreserveAspectFit : fill === "fill" ? Image.Stretch : Image.PreserveAspectCrop
        }
    }

    function find() {
        const scr = root.shellScreen
        if (!scr || root.wallUrl === "" || GlobalStates.editMode || KindleMode.wallpaper === "blank")
            return null
        if ((SettingsConfig.widgets.showWidgets ?? true) === false)
            return null
        const host = WidgetLayout.hosts.find(h => h.configKey === "clock" && h.handoffParts !== undefined)
        if (!host || !host.visible || host.opacity < 0.99)
            return null
        const win = host.QsWindow.window
        if (!win || !win.visible || !win.screen || win.screen.name !== scr.name)
            return null
        if (Math.abs(win.width - scr.width) > 1 || Math.abs(win.height - scr.height) > 1)
            return null
        const pad = 32
        const box = host.mapToItem(null, -pad, -pad, host.width + 2 * pad, host.height + 2 * pad)
        const mon = Hyprland.monitorFor(scr)
        if (root.covered(mon, box))
            return null
        const parts = host.handoffParts.filter(p => p.rect.width > 0 && p.rect.height > 0).map(p => ({
            role: p.role,
            face: p.face,
            local: p.rect,
            screen: host.mapToItem(null, p.rect.x, p.rect.y, p.rect.width, p.rect.height)
        }))
        if (parts.length === 0)
            return null
        return { parts: parts, box: box, wall: root.wallFor(mon, scr.width) }
    }

    function capture() {
        root.source = root.find()
    }

    function wall() {
        const scr = root.shellScreen
        return root.wallFor(scr ? Hyprland.monitorFor(scr) : null, scr ? scr.width : 0)
    }

    function bands(width, height) {
        if (ServiceGameMode.hideBar)
            return []
        const f = ServiceGaps.frame ?? ({ on: 0 })
        const occ = ServiceGaps.occupied ?? ({})
        const depth = side => Math.ceil(Math.max(f.on === 1 ? (f[side] ?? 0) : 0, occ[side] ?? 0))
        const t = depth("top")
        const b = depth("bottom")
        const l = depth("left")
        const r = depth("right")
        const out = []
        if (t > 0)
            out.push({ side: "top", depth: t, rect: Qt.rect(0, 0, width, t) })
        if (b > 0)
            out.push({ side: "bottom", depth: b, rect: Qt.rect(0, height - b, width, b) })
        if (l > 0)
            out.push({ side: "left", depth: l, rect: Qt.rect(0, t, l, height - t - b) })
        if (r > 0)
            out.push({ side: "right", depth: r, rect: Qt.rect(width - r, t, r, height - t - b) })
        return out
    }

    function anchors() {
        const scr = root.shellScreen
        if (!scr || KindleMode.wallpaper === "blank")
            return {}
        const mon = Hyprland.monitorFor(scr)
        const ws = mon?.activeWorkspace ?? null
        return {
            windows: ws ? (ws.toplevels?.values ?? []).length : 0
        }
    }
}
