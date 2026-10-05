import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    required property Item host

    readonly property Item dock: root.host.bottomSurface && root.host.bottomSurface.visible ? root.host.bottomSurface : null
    readonly property string side: root.dock ? root.dock.side : "bottom"
    readonly property bool across: root.side === "left" || root.side === "right"
    readonly property real floor: root.host.topSurface && root.host.topSurface.side === "bottom"
        ? root.host.height - root.host.topSurface.bandRect.height : root.host.height
    readonly property real reveal: root.dock ? (root.dock.reveal ?? 1) : 0
    readonly property real slide: root.dock ? root.dock.slide : 0
    readonly property real edge: {
        if (!root.dock) return root.floor
        const b = root.dock.bandRect
        switch (root.side) {
        case "top":   return b.y + b.height - root.slide
        case "left":  return b.x + b.width - root.slide
        case "right": return b.x + root.slide
        }
        return b.y + root.slide
    }
    readonly property rect group: root.dock
        ? root.dock.toScreen(root.dock.rowItem.x + root.dock.centerGroupItem.x, root.dock.rowItem.y + root.dock.centerGroupItem.y,
                             root.dock.centerGroupItem.width, root.dock.centerGroupItem.height)
        : Qt.rect(0, 0, 0, 0)
    readonly property real groupLen: root.across ? root.group.height : root.group.width
    readonly property real r: 22
    readonly property bool joined: root.reveal > 0.9
        && root.groupLen - 2 * root.r >= (root.across ? toast.height : 360)
    readonly property real w: root.across ? Math.min(420, root.host.width - 40)
        : root.joined ? Math.min(480, root.groupLen - 2 * root.r) : Math.min(480, root.host.width - 40)
    readonly property real mid: root.groupLen > 0
        ? (root.across ? root.group.y + root.group.height / 2 : root.group.x + root.group.width / 2)
        : (root.across ? root.host.height / 2 : root.host.width / 2)
    readonly property var queue: root.host.live.slice(1, 4)

    readonly property bool ready: root.host.active && (!root.dock || root.reveal > 0.9)
    property real t: root.ready ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.ready ? M3Motion.spatialDuration("default") : 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.ready ? [0.05, 0.7, 0.1, 1.0, 1, 1] : [0.3, 0.0, 0.8, 0.15, 1, 1]
        }
    }

    readonly property real gap: root.joined ? 0 : 12
    readonly property real push: (1 - root.t) * (root.joined ? (root.across ? toast.width : toast.height) + 4 : 36)
    readonly property real restX: {
        switch (root.side) {
        case "left":  return root.edge + root.gap - root.push
        case "right": return root.edge - root.gap - toast.width + root.push
        }
        return Math.max(12, Math.min(root.host.width - toast.width - 12, root.mid - toast.width / 2))
    }
    readonly property real restY: {
        switch (root.side) {
        case "top":  return root.edge + root.gap - root.push
        case "left":
        case "right": return Math.max(12, Math.min(root.host.height - toast.height - 12, root.mid - toast.height / 2))
        }
        return root.edge - root.gap - toast.height + root.push
    }
    readonly property rect clipRect: {
        if (!root.joined) return Qt.rect(0, 0, root.host.width, root.host.height)
        switch (root.side) {
        case "top":   return Qt.rect(0, root.edge, root.host.width, root.host.height - root.edge)
        case "left":  return Qt.rect(root.edge, 0, root.host.width - root.edge, root.host.height)
        case "right": return Qt.rect(0, 0, root.edge, root.host.height)
        }
        return Qt.rect(0, 0, root.host.width, root.edge)
    }
    readonly property rect hit: root.t > 0.01
        ? (root.across
           ? Qt.rect(root.restX, root.restY - (root.joined ? root.r : 0), toast.width, toast.height + (root.joined ? 2 * root.r : 0))
           : Qt.rect(root.restX - (root.joined ? root.r : 0), root.restY, toast.width + (root.joined ? 2 * root.r : 0), toast.height))
        : Qt.rect(0, 0, 0, 0)

    property real fade: 1
    Connections {
        target: root.host
        function onShownChanged() {
            if (root.t < 0.5) return
            swapAnim.restart()
        }
    }
    NumberAnimation { id: swapAnim; target: root; property: "fade"; from: 0; to: 1; duration: M3Motion.effectsDuration("default") }

    Item {
        id: clipper
        x: root.clipRect.x
        y: root.clipRect.y
        width: root.clipRect.width
        height: root.clipRect.height
        clip: root.joined

        Item {
            id: toast
            visible: root.t > 0.001
            width: root.w
            height: body.implicitHeight + 30
            x: root.restX - clipper.x
            y: root.restY - clipper.y
            opacity: root.joined ? 1 : root.t

            Rectangle {
                anchors.fill: parent
                color: Colors.surface
                topLeftRadius: root.joined && (root.side === "top" || root.side === "left") ? 0 : 28
                topRightRadius: root.joined && (root.side === "top" || root.side === "right") ? 0 : 28
                bottomLeftRadius: root.joined && (root.side === "bottom" || root.side === "left") ? 0 : 28
                bottomRightRadius: root.joined && (root.side === "bottom" || root.side === "right") ? 0 : 28
            }

            NotifJoin {
                anchors.fill: parent
                visible: root.joined
                side: root.side
                r: root.r
                color: Colors.surface
            }

            HoverHandler { onHoveredChanged: root.host.hovered = hovered }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: content.openDefault()
            }

            ColumnLayout {
                id: body
                x: 18
                y: 16
                width: toast.width - 36
                opacity: root.fade
                spacing: 10

                NotifContent {
                    id: content
                    Layout.fillWidth: true
                    notif: root.host.shown
                    bodyLines: 1
                    iconBox: 48
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.queue.length > 0

                    Repeater {
                        model: root.queue
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            implicitWidth: Math.min(170, chipRow.implicitWidth + 18)
                            implicitHeight: 28
                            radius: 14
                            color: Colors.surfaceContainerHigh
                            clip: true

                            Row {
                                id: chipRow
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    source: IconUtil.getIconPath(chip.modelData?.appIcon ?? "")
                                    sourceSize.width: 32
                                    sourceSize.height: 32
                                }
                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 130)
                                    content: chip.modelData?.summary || chip.modelData?.appName || ""
                                    size: 12
                                    elide: Text.ElideRight
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.openDashboard()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: 1.5
                    color: Colors.surfaceContainerHighest
                    Rectangle {
                        width: parent.width * Math.max(0, 1 - (root.host.shown?.progress ?? 0))
                        height: parent.height
                        radius: 1.5
                        color: Colors.primary
                    }
                }
            }
        }
    }
}
