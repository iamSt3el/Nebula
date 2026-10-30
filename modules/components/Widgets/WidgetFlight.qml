import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Item {
    id: root

    property Item stageItem: null
    property var shots: []
    property int count: 0
    property int phase: 0
    property int ticks: 0

    function shownOpacity(item) {
        let o = 1
        for (let p = item; p; p = p.parent) {
            if (!p.visible)
                return 0
            o *= p.opacity
        }
        return o
    }

    function stop() {
        frames.running = false
        root.phase = 0
        root.count = 0
        root.shots = []
    }

    function capture() {
        root.stop()
        const widgets = ServiceLayouts._widgets
        if (!ServiceLayouts.animate || !root.stageItem || !root.visible || !widgets || ServiceLayouts.same(SettingsConfig.widgets, widgets))
            return
        const list = []
        for (const host of WidgetLayout.hosts) {
            if (!host || host.width < 1 || host.height < 1 || root.shownOpacity(host) < 0.05)
                continue
            list.push({
                host: host,
                crop: host.mapToItem(root.stageItem, 0, 0, host.width, host.height),
                at: host.mapToItem(root, 0, 0, host.width, host.height),
                gone: false
            })
        }
        if (!list.length)
            return
        root.shots = list
        root.count = list.length
        root.phase = 1
        root.ticks = 0
        ServiceLayouts.hold()
        frames.running = true
    }

    function applied() {
        if (root.phase !== 2)
            return
        let any = false
        for (const e of root.shots) {
            e.gone = !e.host || !e.host.parent || !e.host.visible || WidgetLayout.hosts.indexOf(e.host) < 0
            e.host = null
            any = any || e.gone
        }
        root.phase = 3
        if (any)
            clear.restart()
        else
            root.stop()
    }

    Connections {
        target: ServiceLayouts
        function onCaptureWidgets() { root.capture() }
        function onWidgetsApplied() { root.applied() }
    }

    FrameAnimation {
        id: frames
        running: false
        onTriggered: {
            if (root.phase !== 1 || ++root.ticks < 2)
                return
            frames.running = false
            root.phase = 2
            ServiceLayouts.release()
        }
    }

    Timer {
        id: clear
        interval: M3Motion.effectsDuration("default") + 60
        onTriggered: root.stop()
    }

    Timer {
        interval: 3000
        running: root.phase > 0
        onTriggered: {
            if (root.phase === 1)
                ServiceLayouts.release()
            root.stop()
        }
    }

    Repeater {
        model: root.count

        delegate: ShaderEffectSource {
            id: shot

            required property int index
            readonly property var entry: root.shots[shot.index] ?? null
            readonly property bool fading: root.phase === 3 && !!shot.entry && shot.entry.gone

            x: shot.entry ? shot.entry.at.x : 0
            y: shot.entry ? shot.entry.at.y : 0
            width: shot.entry ? shot.entry.at.width : 0
            height: shot.entry ? shot.entry.at.height : 0
            visible: root.phase < 3 || shot.fading
            live: false
            hideSource: false
            sourceItem: root.stageItem
            sourceRect: shot.entry ? shot.entry.crop : Qt.rect(0, 0, 0, 0)
            smooth: true

            opacity: shot.fading ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: M3Motion.effectsDuration("default")
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
                }
            }

            transform: Translate {
                y: shot.fading ? 10 : 0
                Behavior on y {
                    NumberAnimation {
                        duration: M3Motion.effectsDuration("default")
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
                    }
                }
            }
        }
    }
}
