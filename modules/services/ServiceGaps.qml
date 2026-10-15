pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.utils
import qs.modules.settings
import "../components/Bar/BarOps.js" as BarOps

Singleton {
    id: root

    // ── Derived gap values ──────────────────────────────────────────────
    readonly property real   pillMargin: SettingsConfig.general.pillMargin ?? 6

    // Game mode hides the bar, so the gap reserved for it has to go too —
    // otherwise a fullscreen game keeps a dead strip along the top.
    readonly property bool zeroed: ServiceGameMode.hideBar

    readonly property var edgeReserves: ({
        top: BarOps.edgeReserve(SettingsConfig.bar, SettingsConfig.general, "top", ServiceGameMode.hideWidgets),
        right: BarOps.edgeReserve(SettingsConfig.bar, SettingsConfig.general, "right", ServiceGameMode.hideWidgets),
        bottom: BarOps.edgeReserve(SettingsConfig.bar, SettingsConfig.general, "bottom", ServiceGameMode.hideWidgets),
        left: BarOps.edgeReserve(SettingsConfig.bar, SettingsConfig.general, "left", ServiceGameMode.hideWidgets)
    })

    function edgeReserve(side) {
        return root.zeroed ? 0 : (root.edgeReserves[side] ?? 0)
    }

    property var occupied: ({})


    readonly property var screenBorder: SettingsConfig.bar?.border ?? ({})
    readonly property bool borderOn: !root.zeroed && root.screenBorder.on === true
    readonly property int borderSize: Math.max(0, Math.round(Number(root.screenBorder.size ?? 8)))
    readonly property int borderRadius: Math.max(0, Math.round(Number(root.screenBorder.radius ?? 20)))
    readonly property var windowGaps: SettingsConfig.general.windowGaps ?? ({})

    function gapFor(side) {
        const legacy = "gap" + side.charAt(0).toUpperCase() + side.slice(1)
        const v = root.windowGaps[side] ?? SettingsConfig.general[legacy]
        return v === undefined || v === null ? root.borderSize : Math.max(0, Math.round(Number(v)))
    }

    function borderFor(side) {
        return root.borderOn && root.screenBorder[side] !== false ? root.borderSize : 0
    }

    function reserveFor(side) {
        if (root.zeroed)
            return 0
        const live = root.occupied[side]
        const shell = live !== undefined ? Math.max(live, root.borderFor(side))
            : root.edgeReserve(side) + root.borderFor(side)
        return Math.round(shell) + root.gapFor(side)
    }

    readonly property string primaryName: {
        const pm = SettingsConfig.general.primaryMonitor ?? ""
        if (pm === "")
            return ""
        const screens = Quickshell.screens
        return screens.some(s => s.name === pm) ? pm : (screens.length ? screens[0].name : "")
    }
    readonly property bool split: root.primaryName !== "" && Quickshell.screens.length > 1
    readonly property string secondaryEdge: !BarOps.edgePresent(SettingsConfig.bar, "top")
        && BarOps.edgePresent(SettingsConfig.bar, "bottom") ? "bottom" : "top"

    function secondaryFor(side) {
        if (root.zeroed)
            return 0
        const onBar = side === root.secondaryEdge
        return Math.max(onBar ? Appearance.size.barHeight : 0, root.borderFor(side)) + root.gapFor(side)
    }
    readonly property string secondaryKey: ["top", "right", "bottom", "left"].map(s => root.secondaryFor(s)).join(",")

    function gapTable(f) {
        return "{ top = " + f("top") + ", right = " + f("right") + ", bottom = " + f("bottom") + ", left = " + f("left") + " }"
    }

    readonly property int topFinal: root.reserveFor("top")
    readonly property int rightGap: root.reserveFor("right")
    readonly property int bottomGap: root.reserveFor("bottom")
    readonly property int leftGap: root.reserveFor("left")

    // ── Apply ───────────────────────────────────────────────────────────
    function exec() {
        if (!SettingsConfig.settingsReady)
            return
        const primary = root.gapTable(s => root.reserveFor(s))
        const reset = "if NebulaGapsRule then NebulaGapsRule:set_enabled(false) end NebulaGapsRule = nil "
        const lua = root.split
            ? reset + "hl.config({ general = { gaps_out = " + root.gapTable(s => root.secondaryFor(s)) + " } }) "
              + "NebulaGapsRule = hl.workspace_rule({ workspace = \"m[" + root.primaryName + "] s[false]\", gaps_out = " + primary + " })"
            : reset + "hl.config({ general = { gaps_out = " + primary + " } })"
        Quickshell.execDetached(["hyprctl", "eval", lua])
    }

    // ── Debounce: merge rapid setting changes into one call ─────────────
    Timer {
        id: debounce
        interval: 150
        repeat: false
        onTriggered: root.exec()
    }

    // ── Startup retries: Hyprland may not be ready immediately ───────────
    // Fires at +500ms, +1000ms, +1500ms after launch
    Timer {
        id: startupRetry
        interval: 500
        repeat: true
        property int count: 0
        onTriggered: {
            root.exec()
            count++
            if (count >= 3) stop()
        }
    }

    Component.onCompleted: {
        if (!SettingsConfig.settingsReady)
            return
        root.exec()
        startupRetry.start()
    }

    Connections {
        target: SettingsConfig
        function onSettingsReadyChanged() {
            if (!SettingsConfig.settingsReady)
                return
            root.exec()
            startupRetry.start()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.exec()
        }
    }

    // ── Reactive triggers ────────────────────────────────────────────────
    onTopFinalChanged:  debounce.restart()
    onRightGapChanged:  debounce.restart()
    onBottomGapChanged: debounce.restart()
    onLeftGapChanged:   debounce.restart()
    onSplitChanged:     debounce.restart()
    onPrimaryNameChanged: debounce.restart()
    onSecondaryKeyChanged: debounce.restart()
}
