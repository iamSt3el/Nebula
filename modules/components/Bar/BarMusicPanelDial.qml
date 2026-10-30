import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property real elapsed: ServiceMusic.activePlayer?.position ?? 0
    readonly property real total: ServiceMusic.trackLength
    readonly property real progress: root.total > 0 ? Math.max(0, Math.min(1, root.elapsed / root.total)) : 0
    readonly property bool canSeek: ServiceMusic.activePlayer?.canSeek ?? false

    property bool dragging: false
    property real dragVal: 0
    readonly property real shown: root.dragging ? root.dragVal : root.progress

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 56
        spacing: 2
        visible: root.hasTrack

        CustomText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            content: ServiceMusic.activeTrack?.title ?? ""
            size: 19
            weight: 600
        }
        CustomText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            content: ServiceMusic.activeTrack?.artist ?? ""
            size: 13
            customColor: Colors.surfaceVariantText
        }
    }

    CustomText {
        x: 22
        y: 74
        visible: root.hasTrack
        content: ServiceMusic.formatTime(root.shown * root.total)
        size: 12
        weight: 600
        customColor: Colors.primary
    }
    CustomText {
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: 74
        visible: root.hasTrack
        content: ServiceMusic.formatTime(root.total)
        size: 12
        weight: 500
        customColor: Colors.outline
    }

    Item {
        id: dial
        width: 280
        height: 280
        x: Math.round((parent.width - width) / 2)
        y: 68
        visible: root.hasTrack

        readonly property real r: 128
        readonly property real cx: dial.width / 2
        readonly property real cy: dial.height / 2
        readonly property real start: -Math.PI / 2
        readonly property real end: dial.start + root.shown * Math.PI * 2
        readonly property real gap: 0.16
        property real amp: ServiceMusic.isPlaying && !root.dragging ? 3 : 0
        Behavior on amp { EffectsAnim {} }

        function points(from, to, wave) {
            const out = []
            if (to <= from)
                return out
            const steps = Math.max(2, Math.round((to - from) / 0.025))
            for (let i = 0; i <= steps; i++) {
                const t = from + (to - from) * i / steps
                const rr = dial.r + wave * Math.sin((t - dial.start) * 34)
                out.push(Qt.point(dial.cx + rr * Math.cos(t), dial.cy + rr * Math.sin(t)))
            }
            return out
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Colors.surfaceContainerHighest
                strokeWidth: 6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathPolyline {
                    path: dial.points(dial.end + dial.gap, dial.start + Math.PI * 2 - dial.gap, 0)
                }
            }
            ShapePath {
                strokeColor: Colors.primary
                strokeWidth: 6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: dial.points(dial.start, dial.end, dial.amp)
                }
            }
        }

        Rectangle {
            width: root.dragging ? 22 : 18
            height: width
            radius: width / 2
            x: dial.cx + dial.r * Math.cos(dial.end) - width / 2
            y: dial.cy + dial.r * Math.sin(dial.end) - height / 2
            color: Colors.primary
            visible: root.canSeek
            Behavior on width { SpatialAnim { speed: "fast" } }
        }

        MusicShapeArt {
            anchors.centerIn: parent
            width: 208
            height: 208
            decode: 420
            round: true
            dim: ServiceMusic.isPlaying ? 0 : 1
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            property bool onRing: false

            function ringAt(mx, my) {
                const d = Math.hypot(mx - dial.cx, my - dial.cy)
                return d > 108
            }
            function frac(mx, my) {
                let a = Math.atan2(my - dial.cy, mx - dial.cx) - dial.start
                while (a < 0) a += Math.PI * 2
                return Math.max(0, Math.min(1, a / (Math.PI * 2)))
            }

            cursorShape: containsMouse && (ringAt(mouseX, mouseY) ? root.canSeek : ServiceMusic.canTogglePlaying)
                ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: e => {
                onRing = ringAt(e.x, e.y)
                if (onRing && root.canSeek) {
                    root.dragging = true
                    root.dragVal = frac(e.x, e.y)
                }
            }
            onPositionChanged: e => {
                if (pressed && root.dragging)
                    root.dragVal = frac(e.x, e.y)
            }
            onReleased: e => {
                if (root.dragging) {
                    root.dragging = false
                    if (root.total > 0 && ServiceMusic.activePlayer)
                        ServiceMusic.activePlayer.position = frac(e.x, e.y) * root.total
                } else if (!onRing) {
                    ServiceMusic.togglePlaying()
                }
            }
            onCanceled: root.dragging = false
        }
    }

    MusicIconToggle {
        x: 18
        y: parent.height - 52
        side: 36
        kind: "shuffle"
        visible: root.hasTrack
    }
    MusicIconToggle {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: parent.height - 52
        side: 36
        kind: "repeat"
        visible: root.hasTrack
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.y + dial.height - 50
        spacing: 12
        visible: root.hasTrack

        MusicShapeButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "skip_previous"
            shape: "cookie4"
            side: 54
            usable: ServiceMusic.canGoPrevious
            onTapped: ServiceMusic.previous()
        }
        MusicShapeButton {
            icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
            shape: "clover8"
            pressShape: "cookie9"
            side: 92
            iconSize: 34
            tone: Colors.primary
            iconColor: Colors.primaryText
            ringWidth: 6
            ringColor: Settings.layoutColor
            usable: ServiceMusic.canTogglePlaying
            onTapped: ServiceMusic.togglePlaying()
        }
        MusicShapeButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "skip_next"
            shape: "cookie4"
            side: 54
            usable: ServiceMusic.canGoNext
            onTapped: ServiceMusic.next()
        }
    }
}
