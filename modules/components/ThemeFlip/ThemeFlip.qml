import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.services
import qs.modules.settings

Scope {
    id: root

    property int held: 0
    readonly property bool active: ServiceReveal.phase > 0

    Component.onCompleted: ServiceReveal.available = true

    onActiveChanged: {
        if (!root.active)
            return
        root.held = 0
        captureFallback.restart()
    }

    function frameHeld() {
        root.held++
        if (root.held >= Quickshell.screens.length && ServiceReveal.phase === 1) {
            captureFallback.stop()
            ServiceReveal.captured()
        }
    }

    Timer {
        id: captureFallback
        interval: 600
        onTriggered: if (ServiceReveal.phase === 1) ServiceReveal.captured()
    }

    Timer {
        running: ServiceReveal.phase === 3
        interval: 800
        onTriggered: ServiceReveal.done()
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:themeflip"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property point center: {
                const p = ServiceReveal.point
                return p ? Qt.point(p.x - win.modelData.x, p.y - win.modelData.y)
                         : Qt.point(win.width / 2, win.height / 2)
            }
            readonly property real far: Math.max(
                Math.hypot(win.center.x, win.center.y),
                Math.hypot(win.width - win.center.x, win.center.y),
                Math.hypot(win.center.x, win.height - win.center.y),
                Math.hypot(win.width - win.center.x, win.height - win.center.y))
            readonly property real feather: Math.max(24, Math.min(64, win.far * 0.05))
            property real radius: -win.feather
            readonly property bool sampler: win.modelData === Quickshell.screens[0]
            property int calm: 0

            FrameAnimation {
                running: win.sampler && ServiceReveal.idleWait
                onRunningChanged: win.calm = 0
                onTriggered: {
                    win.calm = frameTime < 0.022 ? win.calm + 1 : 0
                    if (win.calm >= 8)
                        ServiceReveal.idle()
                }
            }

            ScreencopyView {
                anchors.fill: parent
                captureSource: win.modelData
                live: false
                paintCursor: false
                onHasContentChanged: if (hasContent) heldTimer.start()
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property vector2d itemSize: Qt.vector2d(width, height)
                    property vector2d center: Qt.vector2d(win.center.x, win.center.y)
                    property real radius: win.radius
                    property real feather: win.feather
                    fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/reveal.frag.qsb")
                }
            }

            Timer {
                id: heldTimer
                interval: 34
                onTriggered: root.frameHeld()
            }

            NumberAnimation {
                target: win
                property: "radius"
                from: -win.feather
                to: win.far + win.feather + 2
                duration: 750
                easing.type: Easing.BezierSpline
                easing.bezierCurve: M3Motion.emphasizedCurve
                running: ServiceReveal.phase === 3
            }
        }
    }
}
