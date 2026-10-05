import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    required property Item host

    readonly property Item bar: root.host.topSurface && root.host.topSurface.visible ? root.host.topSurface : null
    readonly property Item dock: root.host.bottomSurface && root.host.bottomSurface.visible ? root.host.bottomSurface : null
    readonly property string side: root.bar ? root.bar.side : "top"
    readonly property bool across: root.side === "left" || root.side === "right"
    function bandOn(s) {
        const x = [root.bar, root.dock].find(v => v && v.side === s)
        return x ? (s === "left" || s === "right" ? x.bandRect.width : x.bandRect.height) : 0
    }
    readonly property real rightInset: root.side === "right" ? 0 : root.bandOn("right")
    readonly property real topInset: root.side === "top" ? 0 : root.bandOn("top")
    readonly property bool joined: !!root.bar && !root.bar.allPill
    readonly property real edge: {
        if (!root.bar) return ServiceGaps.topFinal
        const b = root.bar.bandRect
        switch (root.side) {
        case "bottom": return b.y
        case "left":   return b.x + b.width
        case "right":  return b.x
        }
        return b.y + b.height
    }
    readonly property real r: 22
    readonly property real w: 400
    readonly property real gap: root.joined ? 0 : 8
    readonly property real restX: {
        switch (root.side) {
        case "left":  return root.edge + root.gap
        case "right": return root.edge - root.gap - root.w
        }
        return root.host.width - root.w - (root.joined ? root.r : 0) - 10 - root.rightInset
    }
    readonly property real restY: {
        switch (root.side) {
        case "bottom": return root.edge - root.gap - card.height
        case "left":
        case "right":  return root.topInset + 10 + (root.joined ? root.r : 0)
        }
        return root.edge + root.gap
    }
    readonly property real enterX: root.across
        ? (root.side === "left" ? -1 : 1) * (1 - root.t) * (root.w + 12)
        : (1 - root.t) * (root.host.width - root.restX + 12)
    readonly property rect clipRect: {
        if (!root.across || !root.joined) return Qt.rect(0, 0, root.host.width, root.host.height)
        return root.side === "left" ? Qt.rect(root.edge, 0, root.host.width - root.edge, root.host.height)
                                    : Qt.rect(0, 0, root.edge, root.host.height)
    }
    readonly property var more: root.host.live.slice(1)

    property real t: root.host.active ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.host.active ? M3Motion.spatialDuration("default") : 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.host.ease(root.host.active)
        }
    }

    readonly property rect hit: root.t > 0.01
        ? (root.across
           ? Qt.rect(root.restX, root.restY - (root.joined ? root.r : 0), card.width, card.height + (root.joined ? 2 * root.r : 0))
           : Qt.rect(root.restX - (root.joined ? root.r : 0), root.restY, card.width + (root.joined ? 2 * root.r : 0), card.height))
        : Qt.rect(0, 0, 0, 0)

    property real shift: 0
    property real fade: 1

    Connections {
        target: root.host
        function onShownChanged() {
            if (root.t < 0.5) return
            swapAnim.restart()
        }
    }

    ParallelAnimation {
        id: swapAnim
        NumberAnimation { target: root; property: "shift"; from: root.w * 0.5; to: 0; duration: M3Motion.spatialDuration("default"); easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.spatialCurve("default") }
        NumberAnimation { target: root; property: "fade"; from: 0; to: 1; duration: M3Motion.effectsDuration("default") }
    }

    Item {
        id: clipper
        x: root.clipRect.x
        y: root.clipRect.y
        width: root.clipRect.width
        height: root.clipRect.height
        clip: root.across && root.joined

        Item {
            id: card
            visible: root.t > 0.001
            x: root.restX + root.enterX - clipper.x
            y: root.restY - clipper.y
            width: root.w
            height: body.implicitHeight + 28
            opacity: Math.min(1, root.t * 1.6)

            Rectangle {
                anchors.fill: parent
                color: Colors.surface
                topLeftRadius: root.joined && (root.side === "top" || root.side === "left") ? 0 : 22
                topRightRadius: root.joined && (root.side === "top" || root.side === "right") ? 0 : 22
                bottomLeftRadius: root.joined && (root.side === "bottom" || root.side === "left") ? 0 : 24
                bottomRightRadius: root.joined && (root.side === "bottom" || root.side === "right") ? 0 : 24
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

            Item {
                anchors.fill: parent
                clip: true

                ColumnLayout {
                    id: body
                    x: 16 + root.shift
                    y: 14
                    width: card.width - 32
                    opacity: root.fade
                    spacing: 10

                    NotifContent {
                        id: content
                        Layout.fillWidth: true
                        notif: root.host.shown
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

                    RowLayout {
                        visible: root.more.length > 0
                        Layout.fillWidth: true
                        spacing: 8

                        Row {
                            spacing: -6
                            Repeater {
                                model: root.more.slice(0, 3)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: Colors.surfaceContainerHighest
                                    border.width: 2
                                    border.color: Colors.surface
                                    Image {
                                        anchors.centerIn: parent
                                        width: 14
                                        height: 14
                                        source: IconUtil.getIconPath(parent.modelData?.appIcon ?? "")
                                        sourceSize.width: 28
                                        sourceSize.height: 28
                                    }
                                }
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.more.length + " more"
                            size: 12
                            customColor: Colors.outline
                        }

                        CustomText {
                            content: "Open shade"
                            size: 12
                            weight: 600
                            customColor: Colors.primary
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.openDashboard()
                            }
                        }
                    }
                }
            }
        }
    }
}
