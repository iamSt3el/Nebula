pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.settings

Singleton {
    id: root

    // ── Derived gap values ──────────────────────────────────────────────
    readonly property string barMode:    SettingsConfig.general.barMode ?? "flat"
    readonly property bool   isPill:     barMode === "pill"
    readonly property real   pillMargin: SettingsConfig.general.pillMargin ?? 6

    // Game mode hides the bar, so the gap reserved for it has to go too —
    // otherwise a fullscreen game keeps a dead strip along the top.
    readonly property bool zeroed: ServiceGameMode.hideBar

    // topGap: bar height + pill floating margin + 10px breathing room (pill only)
    readonly property int topAuto:  Appearance.size.barHeight + (isPill ? Math.round(pillMargin) + 10 : 0)
    readonly property int topExtra: SettingsConfig.general.gapTop    ?? 0
    readonly property int topFinal: zeroed ? 0 : topAuto + topExtra

    readonly property int rightGap:  zeroed ? 0 : (SettingsConfig.general.gapRight  ?? 5)
    readonly property int bottomGap: zeroed ? 0 : (SettingsConfig.general.gapBottom ?? 5)
    readonly property int leftGap:   zeroed ? 0 : (SettingsConfig.general.gapLeft   ?? 5)

    // ── Apply ───────────────────────────────────────────────────────────
    function exec() {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ general = { gaps_out = { top = "    + root.topFinal  +
            ", right = "  + root.rightGap  +
            ", bottom = " + root.bottomGap +
            ", left = "   + root.leftGap   + " } } })"])
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
        root.exec()
        startupRetry.start()
    }

    // ── Reactive triggers ────────────────────────────────────────────────
    onBarModeChanged:   debounce.restart()
    onIsPillChanged:    debounce.restart()
    onTopFinalChanged:  debounce.restart()
    onRightGapChanged:  debounce.restart()
    onBottomGapChanged: debounce.restart()
    onLeftGapChanged:   debounce.restart()
}
