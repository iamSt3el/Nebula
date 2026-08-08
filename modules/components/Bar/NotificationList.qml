import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

Item {
    id: root

    readonly property real contentHeight: list.contentHeight
    readonly property int shelfHeight: 34

    property int firstHidden: -1
    readonly property bool shelfVisible: root.firstHidden >= 0

    readonly property real shelfReserve:
        (list.contentHeight > list.height + 1) ? root.shelfHeight + 6 : 0
    readonly property real shelfLine: list.contentY + list.height - root.shelfReserve

    readonly property var hiddenIcons: {
        if (root.firstHidden < 0) return []
        const seen = {}
        const out = []
        const all = list.sortedGroups
        for (var i = root.firstHidden; i < all.length; i++) {
            const key = (all[i].appName ?? "") + "|" + (all[i].appIcon ?? "")
            if (seen[key]) continue
            seen[key] = true
            out.push(all[i])
            if (out.length >= 5) break
        }
        return out
    }

    function recomputeShelf() {
        if (list.count === 0 || list.height <= 0) {
            root.firstHidden = -1
            return
        }
        const bottom = root.shelfLine
        for (var i = 0; i < list.count; i++) {
            const it = list.itemAtIndex(i)
            if (!it) continue
            if (it.y + it.height > bottom) {
                root.firstHidden = i
                return
            }
        }
        root.firstHidden = -1
    }

    Connections {
        target: list
        function onContentYChanged() { root.recomputeShelf() }
        function onContentHeightChanged() { root.recomputeShelf() }
        function onCountChanged() { root.recomputeShelf() }
        function onHeightChanged() { root.recomputeShelf() }
    }

    ListView {
        id: list
        anchors.fill: parent
        spacing: 0
        clip: true
        cacheBuffer: 200
        boundsBehavior: Flickable.OvershootBounds
        flickDeceleration: 3000
        bottomMargin: root.shelfVisible ? root.shelfHeight + 6 : 0

        property bool populated: false
        Component.onCompleted: populateTimer.start()
        Timer {
            id: populateTimer
            interval: 260
            onTriggered: list.populated = true
        }

        property int dragIndex: -1
        property real dragDistance: 0
        property var dismissTarget: null
        readonly property bool dragActive: list.dragIndex >= 0
        readonly property real dismissThreshold: Math.max(60, list.width * 0.32)

        readonly property var sortedGroups: {
            var _ = ServiceNotification.allNotifications.length
            return ServiceNotification.groupedNotifications
                .slice()
                .sort((a, b) => (b.latest?.arrivalTimestamp ?? 0) - (a.latest?.arrivalTimestamp ?? 0))
        }

        model: ScriptModel { values: list.sortedGroups }

        function beginDrag(i) {
            if (flingAnim.running) return
            list.dragIndex = i
        }

        function updateDrag(d) {
            if (flingAnim.running) return
            list.dragDistance = d
        }

        function endDrag() {
            if (flingAnim.running) return
            list.dragIndex = -1
            list.dragDistance = 0
        }

        function flingAway(i, group, toRight) {
            list.dragIndex = i
            list.dismissTarget = group
            flingAnim.to = toRight ? list.width + 48 : -(list.width + 48)
            flingAnim.restart()
        }

        NumberAnimation {
            id: flingAnim
            target: list
            property: "dragDistance"
            duration: Appearance.motion.spatialFast
            easing.type: Easing.InCubic
            onFinished: {
                const target = list.dismissTarget
                list.dismissTarget = null
                list.dragDistance = 0
                list.dragIndex = -1
                if (target) ServiceNotification.removeGroup(target)
            }
        }

        add: Transition {
            enabled: list.populated
            ParallelAnimation {
                NumberAnimation {
                    property: "x"; from: list.width; to: 0
                    duration: Appearance.motion.spatialDefault
                    easing.type: Appearance.motion.spatialEasing
                    easing.overshoot: Appearance.motion.spatialOvershoot
                }
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: Appearance.motion.effectsDefault
                    easing.type: Appearance.motion.effectsEasing
                }
            }
        }

        addDisplaced: Transition {
            enabled: list.populated
            NumberAnimation {
                property: "y"
                duration: Appearance.motion.spatialDefault
                easing.type: Appearance.motion.spatialEasing
                easing.overshoot: Appearance.motion.spatialOvershoot
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Appearance.motion.spatialDefault
                easing.type: Appearance.motion.spatialEasing
                easing.overshoot: Appearance.motion.spatialOvershoot
            }
        }

        delegate: Item {
            id: slot
            required property var modelData
            required property int index

            width: list.width
            height: row.implicitHeight + 8

            onHeightChanged: root.recomputeShelf()

            // Cards shrink away into the shelf instead of being clipped by it
            readonly property real shelfProgress: {
                const h = Math.max(1, row.implicitHeight)
                const covered = (slot.y + h) - root.shelfLine
                if (covered <= 0) return 0
                return Math.min(1, covered / h)
            }

            NotificationGroupItem {
                id: row
                width: slot.width
                opacity: 1 - slot.shelfProgress
                scale: 1 - 0.08 * slot.shelfProgress
                transformOrigin: Item.Top
                group: slot.modelData
                index: slot.index

                listDragIndex: list.dragIndex
                listDragDistance: list.dragDistance
                dismissThreshold: list.dismissThreshold
                dragSettling: !list.dragActive
                dismissTarget: list.dismissTarget

                onDragBegan: i => list.beginDrag(i)
                onDragMoved: d => list.updateDrag(d)
                onDragCancelled: list.endDrag()
                onDragDismissed: toRight => list.flingAway(slot.index, slot.modelData, toRight)
            }
        }
    }

    Rectangle {
        id: shelf
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.shelfHeight
        radius: 20
        color: Colors.surfaceContainerHigh

        opacity: root.shelfVisible ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.effectsDefault
                easing.type: Appearance.motion.effectsEasing
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: root.hiddenIcons

                delegate: Rectangle {
                    id: shelfIcon
                    required property var modelData

                    readonly property string symbol:
                        shelfIcon.resolveSymbol(modelData.appIcon, modelData.appName)

                    function resolveSymbol(appIcon, appName) {
                        const ic = (appIcon || "").toLowerCase()
                        const ap = (appName || "").toLowerCase()
                        if (ic.includes("camera-photo") || ap.includes("screenshot")) return "photo_camera"
                        if (ic.includes("camera-video") || ap.includes("record"))     return "screen_record"
                        if (ic.includes("dialog-error") || ic.includes("error"))      return "error_outline"
                        if (ic.includes("bluetooth"))                                  return "bluetooth"
                        if (ic.includes("network") || ic.includes("wifi"))            return "wifi"
                        if (ic.includes("battery"))                                    return "battery_std"
                        if (ic.includes("volume") || ic.includes("audio"))            return "volume_up"
                        return ""
                    }

                    width: 22
                    height: 22
                    radius: 11
                    color: shelfIcon.symbol !== "" ? Colors.primaryContainer
                                                   : Qt.alpha(Colors.primary, 0.12)

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: shelfIcon.symbol
                        iconSize: 13
                        customColor: Colors.primaryContainerText
                        visible: shelfIcon.symbol !== ""
                    }

                    Image {
                        id: shelfImg
                        anchors.fill: parent
                        anchors.margins: 4
                        source: shelfIcon.symbol !== ""
                            ? "" : IconUtil.getIconPath(shelfIcon.modelData.appIcon ?? "")
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        visible: shelfIcon.symbol === "" && status === Image.Ready
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "notifications"
                        iconSize: 12
                        customColor: Colors.primaryContainerText
                        visible: shelfIcon.symbol === "" && shelfImg.status !== Image.Ready
                    }
                }
            }
        }

        CustomText {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.firstHidden >= 0
            content: (list.count - root.firstHidden) + " more"
            size: 11
            weight: 600
            customColor: Colors.outline
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: list.positionViewAtEnd()
        }
    }
}
