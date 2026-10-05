import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: pie

    property bool open: false
    property bool holding: false
    property string monitorName: ""
    property real cx: 0
    property real cy: 0
    property int hot: -1
    property int pending: -1

    readonly property real inner: 54
    readonly property real outer: 124
    readonly property real deadzone: 34

    readonly property var actions: [
        { icon: "screenshot_region", label: "Screenshot", hint: "drag a region" },
        { icon: "colorize", label: "Colour picker", hint: "copies hex" },
        { icon: "content_paste", label: "Clipboard", hint: "history" },
        { icon: ServiceTools.isRecording ? "stop_circle" : "screen_record",
          label: ServiceTools.isRecording ? "Stop recording" : "Record", hint: ServiceTools.isRecording ? "save the clip" : "drag a region" },
        { icon: "document_scanner", label: "Live Text", hint: "copy text on screen" },
        { icon: "lock", label: "Lock", hint: "lock the screen" }
    ]

    function show() {
        if (pie.open)
            return
        const mon = Hyprland.focusedMonitor
        pie.monitorName = mon ? mon.name : (Quickshell.screens[0]?.name ?? "")
        pie.hot = -1
        cursorProc.running = true
    }

    function close() {
        pie.open = false
        pie.holding = false
        pie.hot = -1
    }

    function run(i) {
        if (i < 0)
            return
        pie.pending = i
        pie.close()
        settle.restart()
    }

    function perform(i) {
        switch (i) {
        case 0:
            GlobalStates.areaSelectMode = "screenshot"
            GlobalStates.areaSelectOpen = true
            break
        case 1:
            ServiceTools.pickColor()
            break
        case 2:
            GlobalStates.clipboardOpen = true
            GlobalStates.wallpaperOpen = false
            GlobalStates.phoneOpen = false
            break
        case 3:
            if (ServiceTools.isRecording) {
                ServiceTools.stopRecording()
            } else {
                GlobalStates.areaSelectMode = "recording"
                GlobalStates.areaSelectOpen = true
            }
            break
        case 4:
            if (!GlobalStates.liveTextOpen)
                ServiceTools.startLiveText(pie.monitorName)
            break
        case 5:
            Quickshell.execDetached(["loginctl", "lock-session"])
            break
        }
    }

    function sliceAt(x, y) {
        const dx = x - pie.cx
        const dy = y - pie.cy
        if (Math.hypot(dx, dy) < pie.deadzone)
            return -1
        let a = Math.atan2(dx, -dy)
        if (a < 0)
            a += Math.PI * 2
        const n = pie.actions.length
        return Math.round(a / (Math.PI * 2) * n) % n
    }

    function sectorPath(i) {
        const n = pie.actions.length
        const gap = 0.035
        const a0 = (i - 0.5) / n * Math.PI * 2 + gap
        const a1 = (i + 0.5) / n * Math.PI * 2 - gap
        const c = pie.outer
        const pt = (r, a) => (c + r * Math.sin(a)).toFixed(2) + " " + (c - r * Math.cos(a)).toFixed(2)
        return "M" + pt(pie.outer, a0)
             + " A" + pie.outer + " " + pie.outer + " 0 0 1 " + pt(pie.outer, a1)
             + " L" + pt(pie.inner, a1)
             + " A" + pie.inner + " " + pie.inner + " 0 0 0 " + pt(pie.inner, a0) + " Z"
    }

    Timer {
        id: settle
        interval: 120
        onTriggered: {
            const i = pie.pending
            pie.pending = -1
            pie.perform(i)
        }
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const scr = Quickshell.screens.find(s => s.name === pie.monitorName) ?? Quickshell.screens[0]
                const mon = Hyprland.monitors.values.find(m => m.name === pie.monitorName)
                const mx = mon?.lastIpcObject?.x ?? 0
                const my = mon?.lastIpcObject?.y ?? 0
                let x = (scr?.width ?? 1920) / 2
                let y = (scr?.height ?? 1080) / 2
                try {
                    const p = JSON.parse(text)
                    x = p.x - mx
                    y = p.y - my
                } catch (e) {}
                const w = scr?.width ?? 1920
                const h = scr?.height ?? 1080
                pie.cx = Math.max(pie.outer + 8, Math.min(w - pie.outer - 8, x))
                pie.cy = Math.max(pie.outer + 8, Math.min(h - pie.outer - 8, y))
                pie.open = true
            }
        }
    }

    GlobalShortcut {
        name: "pie"
        description: "Pie menu of quick actions at the pointer (hold, flick, release)"
        onPressed: {
            if (pie.open) {
                pie.close()
                return
            }
            pie.holding = true
            pie.show()
        }
        onReleased: {
            if (!pie.holding)
                return
            pie.holding = false
            if (pie.open && pie.hot >= 0)
                pie.run(pie.hot)
        }
    }

    Connections {
        target: GlobalStates
        function onPieRequested() { pie.show() }
    }

    IpcHandler {
        target: "pie"
        function open(): void { pie.show() }
        function close(): void { pie.close() }
        function toggle(): void { if (pie.open) pie.close(); else pie.show() }
    }

    Loader {
        active: pie.open
        visible: active

        sourceComponent: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === pie.monitorName) ?? Quickshell.screens[0]
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:pie"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.scrim, 0.12)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: mouse => pie.hot = pie.sliceAt(mouse.x, mouse.y)
                onClicked: mouse => {
                    const i = pie.sliceAt(mouse.x, mouse.y)
                    if (i >= 0 && mouse.button === Qt.LeftButton)
                        pie.run(i)
                    else
                        pie.close()
                }
            }

            Item {
                focus: true
                Keys.onEscapePressed: pie.close()
                Keys.onPressed: event => {
                    const k = event.key - Qt.Key_1
                    if (k >= 0 && k < pie.actions.length) {
                        pie.run(k)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (pie.hot >= 0)
                            pie.run(pie.hot)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        pie.hot = (pie.hot + 1 + pie.actions.length) % pie.actions.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        pie.hot = (pie.hot - 1 + pie.actions.length) % pie.actions.length
                        event.accepted = true
                    }
                }
            }

            Item {
                id: ring
                x: pie.cx - pie.outer
                y: pie.cy - pie.outer
                width: pie.outer * 2
                height: pie.outer * 2
                scale: 0.6
                opacity: 0
                Component.onCompleted: {
                    ring.scale = 1
                    ring.opacity = 1
                }
                Behavior on scale { SpatialAnim { speed: "fast" } }
                Behavior on opacity { EffectsAnim { speed: "fast" } }

                Repeater {
                    model: pie.actions.length
                    Shape {
                        required property int index
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillColor: pie.hot === index ? Colors.primary : Colors.surfaceContainer
                            Behavior on fillColor { EffectsColorAnim {} }
                            PathSvg { path: pie.sectorPath(index) }
                        }
                    }
                }

                Repeater {
                    model: pie.actions.length
                    MaterialIconSymbol {
                        required property int index
                        readonly property real ang: index / pie.actions.length * Math.PI * 2
                        readonly property real mid: (pie.inner + pie.outer) / 2
                        x: pie.outer + mid * Math.sin(ang) - width / 2
                        y: pie.outer - mid * Math.cos(ang) - height / 2
                        content: pie.actions[index].icon
                        iconSize: pie.hot === index ? 29 : 24
                        Behavior on iconSize { SpatialAnim { speed: "fast" } }
                        fill: 1
                        customColor: pie.hot === index ? Colors.primaryText : Colors.surfaceVariantText
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: pie.inner * 2 - 12
                    height: width
                    radius: width / 2
                    color: Colors.surfaceContainerHigh

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 2
                        CustomText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            content: pie.hot >= 0 ? pie.actions[pie.hot].label : "Pick one"
                            size: 12
                            weight: 600
                            wrapMode: Text.WordWrap
                        }
                        CustomText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            content: pie.hot >= 0 ? pie.actions[pie.hot].hint : (pie.holding ? "flick, then release" : "click or 1–6")
                            size: 10
                            customColor: Colors.outline
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
