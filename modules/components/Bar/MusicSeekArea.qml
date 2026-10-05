import QtQuick
import qs.modules.services

MouseArea {
    id: root

    readonly property real elapsed: ServiceMusic.activePlayer?.position ?? 0
    readonly property real total: ServiceMusic.trackLength
    readonly property real progress: root.total > 0
        ? Math.max(0, Math.min(1, root.elapsed / root.total)) : 0
    readonly property bool canSeek: ServiceMusic.activePlayer?.canSeek ?? false

    property bool dragging: false
    property real dragVal: 0
    readonly property real shown: root.dragging ? root.dragVal : root.progress
    readonly property bool active: root.containsMouse || root.dragging

    hoverEnabled: true
    enabled: root.canSeek
    cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
    preventStealing: true

    function frac(mx) {
        return root.width > 0 ? Math.max(0, Math.min(1, mx / root.width)) : 0
    }

    onPressed: e => {
        root.dragging = true
        root.dragVal = root.frac(e.x)
    }
    onPositionChanged: e => {
        if (root.pressed)
            root.dragVal = root.frac(e.x)
    }
    onReleased: e => {
        root.dragging = false
        if (root.total > 0 && ServiceMusic.activePlayer)
            ServiceMusic.activePlayer.position = root.frac(e.x) * root.total
    }
    onCanceled: root.dragging = false
}
