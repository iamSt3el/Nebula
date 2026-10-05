pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property var cfg: SettingsConfig.general ?? ({})
    readonly property int focusMin: root.cfg.focusMinutes ?? 25
    readonly property int shortMin: root.cfg.focusShortBreak ?? 5
    readonly property int longMin: root.cfg.focusLongBreak ?? 15
    readonly property int rounds: Math.max(1, root.cfg.focusRounds ?? 4)

    property string phase: "idle"
    property bool running: false
    property int done: 0
    property int remaining: 0
    property int total: 1
    property real endsAt: 0

    readonly property bool onBreak: root.phase === "break"
    readonly property bool finished: root.phase === "focusDone" || root.phase === "breakDone"
    readonly property real progress: root.total > 0 ? 1 - root.remaining / root.total : 0
    readonly property int sessionInRound: root.done % root.rounds
    readonly property bool longBreakNext: root.done > 0 && root.done % root.rounds === 0

    readonly property string clock: {
        const s = Math.max(0, root.remaining)
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }

    function _begin(phase, minutes) {
        root.phase = phase
        root.total = Math.max(1, minutes * 60)
        root.remaining = root.total
        root.endsAt = Date.now() + root.total * 1000
        root.running = true
    }

    function startFocus() {
        root._begin("focus", root.focusMin)
    }

    function startBreak() {
        root._begin("break", root.longBreakNext ? root.longMin : root.shortMin)
    }

    function toggle() {
        switch (root.phase) {
        case "idle":
        case "breakDone":
            root.startFocus()
            return
        case "focusDone":
            root.startBreak()
            return
        }
        if (root.running) {
            root.running = false
        } else {
            root.endsAt = Date.now() + root.remaining * 1000
            root.running = true
        }
    }

    function skip() {
        if (root.phase === "focus" || root.phase === "break")
            root._finish()
        else
            root.toggle()
    }

    function stop() {
        root.running = false
        root.phase = "idle"
        root.remaining = 0
        root.total = 1
    }

    function reset() {
        root.stop()
        root.done = 0
    }

    function _finish() {
        root.running = false
        root.remaining = 0
        if (root.phase === "focus") {
            root.done += 1
            root.phase = "focusDone"
            ServiceNotification.sendNotification("Focus session done",
                (root.longBreakNext ? "Time for a long break" : "Time for a short break") + " · click the timer to start it",
                "Focus", "alarm")
        } else if (root.phase === "break") {
            root.phase = "breakDone"
            ServiceNotification.sendNotification("Break over", "Click the timer to start the next focus session",
                "Focus", "alarm")
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: {
            root.remaining = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 1000))
            if (root.remaining <= 0)
                root._finish()
        }
    }
}
