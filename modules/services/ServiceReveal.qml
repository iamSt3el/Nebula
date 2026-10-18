pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.utils

Singleton {
    id: root

    property bool available: false
    property int phase: 0
    property var point: null
    readonly property bool busy: root.phase > 0
    property bool idleWait: false

    function idle() {
        if (!root.idleWait)
            return
        root.idleWait = false
        idleMax.stop()
        if (root.phase === 2)
            root.phase = 3
    }

    property var _start: null
    property int _settle: 180
    property bool _themeSeen: false
    property bool _waiting: false

    function run(start, settle) {
        if (!root.available || root.phase !== 0) {
            start(() => {})
            return false
        }
        root._start = start
        root._settle = settle ?? 180
        root.point = null
        cursorProc.running = true
        return true
    }

    function captured() {
        if (root.phase !== 1)
            return
        root.phase = 2
        root._themeSeen = false
        root._waiting = false
        guard.restart()
        const start = root._start
        root._start = null
        start(waitTheme => root._ready(waitTheme === true))
    }

    function _ready(waitTheme) {
        if (root.phase !== 2)
            return
        if (waitTheme && !root._themeSeen) {
            root._waiting = true
            themeWait.restart()
            return
        }
        settleTimer.interval = root._settle
        settleTimer.restart()
    }

    function done() {
        root.idleWait = false
        idleMax.stop()
        guard.stop()
        themeWait.stop()
        settleTimer.stop()
        root.phase = 0
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector { id: cursorOut }
        onExited: {
            try {
                const c = JSON.parse(cursorOut.text)
                root.point = Qt.point(c.x, c.y)
            } catch (e) {
                root.point = null
            }
            root.phase = 1
        }
    }

    Connections {
        target: WallpaperTheme
        function onApplied() {
            if (root.phase !== 2)
                return
            root._themeSeen = true
            if (root._waiting) {
                root._waiting = false
                themeWait.stop()
                settleTimer.interval = root._settle
                settleTimer.restart()
            }
        }
    }

    Timer {
        id: settleTimer
        interval: 180
        onTriggered: {
            if (root.phase !== 2)
                return
            root.idleWait = true
            idleMax.restart()
        }
    }

    Timer {
        id: idleMax
        interval: 1500
        onTriggered: root.idle()
    }

    Timer {
        id: themeWait
        interval: 6000
        onTriggered: if (root.phase === 2) root.phase = 3
    }

    Timer {
        id: guard
        interval: 12000
        onTriggered: if (root.phase === 2) root.phase = 3
    }
}
