import QtQuick
import Qt5Compat.GraphicalEffects

Flickable {
    id: root

    property real fadeSize: 72
    property bool fadeEdges: true
    property real wheelStep: 110

    readonly property real maxY: Math.max(0, root.contentHeight - root.height)
    readonly property bool scrollable: root.maxY > 1
    property real topFade: root.scrollable && root.contentY > 1 ? 1 : 0
    property real bottomFade: root.scrollable && root.contentY < root.maxY - 1 ? 1 : 0
    readonly property real fadeStop: Math.min(0.25, root.fadeSize / Math.max(1, root.height))
    Behavior on topFade { EffectsAnim { speed: "slow" } }
    Behavior on bottomFade { EffectsAnim { speed: "slow" } }

    property real glideY: 0

    function wheel(event) {
        if (!root.scrollable)
            return
        if ((event.phase ?? 0) > 0 && event.pixelDelta.y !== 0) {
            glide.stop()
            root.contentY = Math.max(0, Math.min(root.maxY, root.contentY - event.pixelDelta.y))
            return
        }
        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 * root.wheelStep : event.pixelDelta.y * 4
        if (!glide.running) {
            root.cancelFlick()
            root.glideY = root.contentY
            glide.goal = root.contentY
        }
        glide.goal = Math.max(0, Math.min(root.maxY, glide.goal - delta))
        glide.start()
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 3000
    onMovementStarted: glide.stop()

    layer.enabled: root.fadeEdges && root.scrollable && root.visible
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 1 - root.topFade) }
                GradientStop { position: root.fadeStop; color: "black" }
                GradientStop { position: 1 - root.fadeStop; color: "black" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1 - root.bottomFade) }
            }
        }
    }

    FrameAnimation {
        id: glide
        property real goal: 0
        onTriggered: {
            const d = glide.goal - root.glideY
            if (Math.abs(d) < 0.5) {
                root.contentY = Math.round(glide.goal)
                glide.stop()
                return
            }
            root.glideY += d * (1 - Math.exp(-Math.min(frameTime, 0.05) * 13))
            root.contentY = Math.round(root.glideY)
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.wheel(event)
    }
}
