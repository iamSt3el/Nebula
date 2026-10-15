import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    required property Item host

    readonly property Item dock: root.host.appsSurface
    readonly property bool dockOn: !!root.dock && root.dock.visible
    readonly property bool dockUp: root.dockOn && (root.dock.reveal ?? 1) > 0.9
    readonly property bool ready: root.host.active && (!root.dockOn || root.dockUp)
    readonly property string key: root.host.appKeyFor(root.host.shown)
    readonly property string dockSide: root.dockOn ? root.dock.side : "bottom"
    readonly property Item anchorItem: {
        GlobalStates.dockIconsVersion
        return root.dockUp && root.key !== "" ? GlobalStates.dockIconIn(root.key, root) : null
    }
    readonly property real w: 380
    readonly property real tailH: 12

    property point p: Qt.point(root.host.width - 40, root.host.height - 90)
    property bool hasTail: false
    property string dir: "bottom"
    readonly property bool across: root.dir === "left" || root.dir === "right"

    function innerPoint(rc, side, pad) {
        switch (side) {
        case "top":   return Qt.point(rc.x + rc.width / 2, rc.y + rc.height + pad)
        case "left":  return Qt.point(rc.x + rc.width + pad, rc.y + rc.height / 2)
        case "right": return Qt.point(rc.x - pad, rc.y + rc.height / 2)
        }
        return Qt.point(rc.x + rc.width / 2, rc.y - pad)
    }

    function place() {
        if (root.anchorItem) {
            const rc = root.anchorItem.mapToItem(root, 0, 0, root.anchorItem.width, root.anchorItem.height)
            root.p = root.innerPoint(rc, root.dockSide, -4)
            root.dir = root.dockSide
            root.hasTail = true
        } else if (root.dockUp) {
            const d = root.dock
            const g = d.toScreen(d.rowItem.x + d.centerGroupItem.x, d.rowItem.y + d.centerGroupItem.y,
                                 d.centerGroupItem.width, d.centerGroupItem.height)
            const b = d.bandRect
            const across = root.dockSide === "left" || root.dockSide === "right"
            root.p = root.innerPoint(across ? Qt.rect(b.x, g.y, b.width, g.height) : Qt.rect(g.x, b.y, g.width, b.height),
                                     root.dockSide, 6)
            root.dir = root.dockSide
            root.hasTail = false
        } else {
            const right = root.host.surfaces.find(x => x && x.visible && x.present && x.side === "right")
            const bottom = root.host.surfaces.find(x => x && x.visible && x.present && x.side === "bottom" && !x.autoHide)
            root.p = Qt.point(root.host.width - root.w / 2 - 16 - (right ? right.bandRect.width : 0),
                              root.host.height - 16 - (bottom ? bottom.bandRect.height : 0))
            root.dir = "bottom"
            root.hasTail = false
        }
    }

    onAnchorItemChanged: root.place()
    onDockUpChanged: root.place()
    onReadyChanged: if (root.ready) root.place()
    Component.onCompleted: root.place()

    Timer {
        interval: 250
        repeat: true
        running: bubble.visible
        onTriggered: root.place()
    }

    property real t: root.ready ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.ready ? 520 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.ready ? [0.38, 1.21, 0.22, 1.0, 1, 1] : [0.3, 0.0, 0.8, 0.15, 1, 1]
        }
    }

    Binding {
        target: GlobalStates
        property: "notifLiftApp"
        value: root.ready && root.hasTail ? root.key : ""
    }

    Binding {
        target: GlobalStates
        property: "notifBadges"
        value: {
            const out = {}
            for (const n of root.host.live) {
                const k = root.host.appKeyFor(n)
                if (k !== "") out[k] = (out[k] ?? 0) + 1
            }
            return out
        }
    }

    readonly property rect hit: root.t > 0.01
        ? Qt.rect(bubble.x - (root.dir === "left" ? root.tailH : 0), bubble.y - (root.dir === "top" ? root.tailH : 0),
                  bubble.width + (root.across ? root.tailH : 0), bubble.height + (root.across ? 0 : root.tailH))
        : Qt.rect(0, 0, 0, 0)

    property real fade: 1
    Connections {
        target: root.host
        function onShownChanged() {
            root.place()
            if (root.t < 0.5) return
            swapAnim.restart()
        }
    }
    NumberAnimation { id: swapAnim; target: root; property: "fade"; from: 0; to: 1; duration: M3Motion.effectsDuration("default") }

    Item {
        id: bubble
        visible: root.t > 0.001
        width: root.w
        height: body.implicitHeight + 28
        readonly property real off: root.tailH + (root.hasTail ? 6 : 0)
        x: {
            switch (root.dir) {
            case "left":  return root.p.x + bubble.off
            case "right": return root.p.x - bubble.off - width
            }
            return Math.max(12, Math.min(root.host.width - width - 12, root.p.x - width * 0.5))
        }
        y: {
            switch (root.dir) {
            case "top": return root.p.y + bubble.off
            case "left":
            case "right": return Math.max(12, Math.min(root.host.height - height - 12, root.p.y - height * 0.5))
            }
            return root.p.y - bubble.off - height
        }
        opacity: Math.min(1, root.t * 2)

        Behavior on x { enabled: bubble.visible && root.t > 0.9; SpatialAnim {} }
        Behavior on y { enabled: bubble.visible && root.t > 0.9; SpatialAnim {} }

        readonly property real tailX: root.across ? (root.dir === "left" ? 0 : width)
            : Math.max(28, Math.min(width - 28, root.p.x - bubble.x))
        readonly property real tailY: !root.across ? (root.dir === "top" ? 0 : height)
            : Math.max(28, Math.min(height - 28, root.p.y - bubble.y))

        transform: Scale {
            origin.x: bubble.tailX + (root.dir === "left" ? -root.tailH : root.dir === "right" ? root.tailH : 0)
            origin.y: bubble.tailY + (root.dir === "top" ? -root.tailH : root.dir === "bottom" ? root.tailH : 0)
            xScale: 0.2 + 0.8 * root.t
            yScale: 0.2 + 0.8 * root.t
        }

        Rectangle {
            visible: root.hasTail
            x: bubble.tailX - width / 2 + (root.dir === "left" ? 2 : root.dir === "right" ? -2 : 0)
            y: bubble.tailY - height / 2 + (root.dir === "top" ? 2 : root.dir === "bottom" ? -2 : 0)
            width: 22
            height: 22
            radius: 4
            rotation: 45
            color: Colors.surfaceContainerHigh
        }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colors.outlineVariant, 0.5)
        }

        Rectangle {
            visible: root.hasTail
            width: root.across ? 3 : 32
            height: root.across ? 32 : 3
            x: root.across ? (root.dir === "left" ? -1 : bubble.width - 2) : bubble.tailX - 16
            y: root.across ? bubble.tailY - 16 : (root.dir === "top" ? -1 : bubble.height - 2)
            color: Colors.surfaceContainerHigh
        }

        HoverHandler { onHoveredChanged: root.host.hovered = hovered }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: content.openDefault()
        }

        ColumnLayout {
            id: body
            x: 16
            y: 14
            width: bubble.width - 32
            opacity: root.fade
            spacing: 8

            NotifContent {
                id: content
                Layout.fillWidth: true
                notif: root.host.shown
                iconBox: 40
            }

            CustomText {
                visible: root.host.live.length > 1
                Layout.leftMargin: 52
                content: (root.host.live.length - 1) + " more waiting · open the shade"
                size: 11
                customColor: Colors.outline
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalStates.openPanel("notifications")
                }
            }
        }
    }
}
