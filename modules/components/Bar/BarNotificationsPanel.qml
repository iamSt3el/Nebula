import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root

    property real maxHeight: 640
    readonly property int count: ServiceNotification.allNotifications.length
    readonly property bool isEmpty: root.count === 0
    readonly property bool dnd: ServiceNotification.dnd
    readonly property real until: ServiceNotification.muteUntil
    readonly property string mode: !root.dnd ? "" : root.until <= 0 ? "on"
        : root.until === root.morning ? "morning" : "hour"

    property real morning: root.nextMorning()
    property bool counted: false
    property bool dndOpen: false
    property bool showAllOlder: false
    property bool ready: false
    property real now: Date.now()
    property int openSeq: 0
    property bool clearing: false
    readonly property int shownRows: root.fresh.length + root.olderShown.length
    readonly property int olderCap: 4

    readonly property var sorted: {
        ServiceNotification.allNotifications.length
        return ServiceNotification.groupedNotifications.slice()
            .sort((a, b) => (b.latest?.arrivalTimestamp ?? 0) - (a.latest?.arrivalTimestamp ?? 0))
    }
    readonly property var fresh: root.sorted.filter(g => (g.latest?.arrivalTimestamp ?? 0) > ServiceNotification.seenAt)
    readonly property var older: root.sorted.filter(g => (g.latest?.arrivalTimestamp ?? 0) <= ServiceNotification.seenAt)

    property string dragSection: ""
    property int dragIndex: -1
    property real dragDistance: 0
    property var dismissTarget: null
    readonly property real dismissThreshold: Math.max(60, body.width * 0.32)
    property Item revealItem: null

    function beginDrag(section, i) {
        if (flingAnim.running)
            return
        root.dragSection = section
        root.dragIndex = i
    }

    function updateDrag(d) {
        if (!flingAnim.running)
            root.dragDistance = d
    }

    function endDrag() {
        if (flingAnim.running)
            return
        root.dragIndex = -1
        root.dragDistance = 0
    }

    function flingAway(section, i, group, toRight) {
        root.dragSection = section
        root.dragIndex = i
        root.dismissTarget = group
        flingAnim.to = toRight ? body.width + 48 : -(body.width + 48)
        flingAnim.restart()
    }

    function reveal(item) {
        root.revealItem = item
        revealTimer.restart()
    }

    NumberAnimation {
        id: flingAnim
        target: root
        property: "dragDistance"
        duration: Appearance.motion.spatialFast
        easing.type: Easing.InCubic
        onFinished: {
            const target = root.dismissTarget
            root.dismissTarget = null
            root.dragDistance = 0
            root.dragIndex = -1
            if (target)
                ServiceNotification.removeGroup(target)
        }
    }

    Timer {
        id: revealTimer
        interval: 380
        onTriggered: {
            const it = root.revealItem
            root.revealItem = null
            if (!it)
                return
            const bottom = it.mapToItem(listCol, 0, 0).y + it.height
            const maxY = Math.max(0, body.contentHeight - body.height)
            if (bottom > body.contentY + body.height)
                body.contentY = Math.min(maxY, bottom - body.height)
        }
    }
    readonly property var olderShown: root.showAllOlder ? root.older : root.older.slice(0, root.olderCap)

    readonly property real fixedHeight: 14 + header.implicitHeight + dndWrap.height + 12 + 12
    readonly property real listHeight: root.isEmpty ? 150
        : Math.min(Math.max(80, root.maxHeight - root.fixedHeight), listCol.implicitHeight)

    implicitWidth: 400
    implicitHeight: root.fixedHeight + root.listHeight

    function nextMorning() {
        const d = new Date()
        d.setHours(8, 0, 0, 0)
        if (d.getTime() <= Date.now())
            d.setDate(d.getDate() + 1)
        return d.getTime()
    }

    function hhmm(ms) {
        const d = new Date(ms)
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }

    readonly property string status: {
        if (!root.dnd)
            return "Popups and sounds are on"
        if (root.until <= 0)
            return "Do Not Disturb is on until you turn it off"
        const sameDay = new Date(root.until).toDateString() === new Date().toDateString()
        return "Do Not Disturb until " + root.hhmm(root.until) + (sameDay ? "" : " tomorrow")
    }

    function pick(value) {
        root.morning = root.nextMorning()
        if (value === "off")
            ServiceNotification.setDnd(false)
        else if (value === "hour")
            ServiceNotification.setDnd(true, Date.now() + 3600000)
        else if (value === "morning")
            ServiceNotification.setDnd(true, root.morning)
        else
            ServiceNotification.setDnd(true, 0)
    }

    function syncCount() {
        const want = root.visible
        if (want === root.counted)
            return
        root.counted = want
        GlobalStates.notificationCenterCount += want ? 1 : -1
    }

    function clearAll() {
        if (root.clearing || root.count === 0)
            return
        clearTimer.interval = 220 + Math.max(0, root.shownRows - 1) * 35 + 40
        root.clearing = true
        clearTimer.restart()
    }

    function cascadeHead() {
        headFx.stop()
        root.headFade = 0
        root.headLift = 12
        headFx.start()
    }

    property real headFade: 1
    property real headLift: 0

    SequentialAnimation {
        id: headFx
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "headFade"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "headLift"; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
        }
    }

    Timer {
        id: clearTimer
        onTriggered: {
            ServiceNotification.clear()
            root.clearing = false
        }
    }

    onVisibleChanged: {
        root.syncCount()
        root.now = Date.now()
        if (root.visible) {
            readyTimer.restart()
            root.cascadeHead()
            root.openSeq++
        } else {
            readyTimer.stop()
            root.ready = false
            root.dndOpen = false
            root.showAllOlder = false
        }
    }
    Component.onCompleted: {
        root.morning = root.nextMorning()
        root.syncCount()
        readyTimer.restart()
        root.cascadeHead()
        Qt.callLater(() => root.openSeq++)
    }
    Component.onDestruction: if (root.counted) GlobalStates.notificationCenterCount--

    Timer {
        id: readyTimer
        interval: 450
        onTriggered: root.ready = true
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 14; leftMargin: 18; rightMargin: 12 }
        spacing: 8
        opacity: root.headFade
        transform: Translate { y: root.headLift }

        CustomText {
            content: "Notifications"
            size: 17
            weight: 700
        }

        CustomText {
            Layout.fillWidth: true
            content: root.count > 0 ? String(root.count) : ""
            size: 13
            weight: 500
            customColor: Colors.outline
        }

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: root.dnd ? Colors.primary
                 : root.dndOpen ? Colors.secondaryContainer
                 : dndMa.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: root.dnd ? "notifications_paused" : "bedtime"
                iconSize: 19
                fill: root.dnd ? 1 : 0
                customColor: root.dnd ? Colors.primaryText
                           : root.dndOpen ? Colors.secondaryContainerText : Colors.surfaceVariantText
            }

            MouseArea {
                id: dndMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton)
                        ServiceNotification.setDnd(!root.dnd, 0)
                    else
                        root.dndOpen = !root.dndOpen
                }
            }
        }

        Rectangle {
            visible: root.count > 0
            Layout.preferredWidth: clearText.implicitWidth + 28
            Layout.preferredHeight: 36
            radius: 18
            color: clearMa.containsMouse ? Qt.alpha(Colors.primary, 0.10) : Qt.alpha(Colors.primary, 0)
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            CustomText {
                id: clearText
                anchors.centerIn: parent
                content: "Clear all"
                size: 13
                weight: 600
                customColor: Colors.primary
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
            }
        }
    }

    Item {
        id: dndWrap
        anchors { left: parent.left; right: parent.right; top: header.bottom; leftMargin: 12; rightMargin: 12 }
        height: root.dndOpen || root.dnd ? dndCol.implicitHeight + 12 : 0
        clip: true
        opacity: root.headFade
        Behavior on height { SpatialAnim { speed: "fast" } }

        ColumnLayout {
            id: dndCol
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 12 }
            spacing: 8
            opacity: root.dndOpen || root.dnd ? 1 : 0
            Behavior on opacity { EffectsAnim { speed: "fast" } }

            CustomText {
                Layout.leftMargin: 6
                Layout.fillWidth: true
                content: root.status
                size: 11
                customColor: root.dnd ? Colors.primary : Colors.outline
                elide: Text.ElideRight
            }

            M3ButtonGroup {
                Layout.fillWidth: true
                fillWidth: true
                height: 34
                textSize: 12
                inactiveColor: Colors.surfaceContainerHigh
                model: [
                    { value: "off",     label: "Off" },
                    { value: "hour",    label: "1 hour" },
                    { value: "morning", label: "Until " + root.hhmm(root.morning) },
                    { value: "on",      label: "Until off" }
                ]
                activeCheck: value => value === (root.mode === "" ? "off" : root.mode)
                onSegmentClicked: value => root.pick(value)
            }
        }
    }

    Flickable {
        id: body
        anchors { left: parent.left; right: parent.right; top: dndWrap.bottom; topMargin: 12; leftMargin: 12; rightMargin: 12 }
        height: root.listHeight
        contentWidth: width
        contentHeight: listCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: body.contentHeight > body.height + 0.5
        visible: !root.isEmpty

        ColumnLayout {
            id: listCol
            width: body.width
            spacing: 8

            SectionLabel {
                visible: root.fresh.length > 0
                content: "New"
            }

            Repeater {
                model: ScriptModel { values: root.fresh }
                delegate: GroupRow {
                    section: "new"
                    order: index
                }
            }

            SectionLabel {
                visible: root.older.length > 0
                Layout.topMargin: root.fresh.length > 0 ? 10 : 0
                content: "Earlier"
            }

            Repeater {
                model: ScriptModel { values: root.olderShown }
                delegate: GroupRow {
                    section: "earlier"
                    order: root.fresh.length + index
                }
            }

            Rectangle {
                visible: root.older.length > root.olderCap
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.preferredHeight: 36
                radius: 18
                color: moreMa.containsMouse ? Colors.surfaceContainer : Qt.alpha(Colors.surfaceContainer, 0)
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        content: root.showAllOlder ? "expand_less" : "expand_more"
                        iconSize: 18
                        customColor: Colors.surfaceVariantText
                    }

                    CustomText {
                        content: root.showAllOlder ? "Show less" : (root.older.length - root.olderCap) + " more"
                        size: 12
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }
                }

                MouseArea {
                    id: moreMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showAllOlder = !root.showAllOlder
                }
            }
        }
    }

    ColumnLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: dndWrap.bottom; topMargin: 12 + (150 - implicitHeight) / 2 }
        visible: root.isEmpty
        spacing: 8

        MaterialShapes.ShapeCanvas {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            roundedPolygon: MatrialShapeFn.getSunny()
            color: Colors.surfaceContainerHigh

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: root.dnd ? "notifications_paused" : "done_all"
                iconSize: 22
                customColor: Colors.primary
            }
        }

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: "You're all caught up"
            size: 13
            weight: 600
        }

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: root.dnd ? "New ones will wait here quietly" : "New notifications will show up here"
            size: 11
            customColor: Colors.outline
        }
    }

    component SectionLabel: CustomText {
        Layout.leftMargin: 6
        Layout.bottomMargin: 4
        size: 12
        weight: 600
        customColor: Colors.outline
    }

    component GroupRow: Item {
        id: gr

        required property var modelData
        required property int index
        property string section: ""
        property int order: 0
        property bool leaving: false
        property real keep: 1
        property real lift: 0
        property real fade: 1

        Layout.fillWidth: true
        Layout.preferredHeight: groupItem.implicitHeight * gr.keep
        clip: gr.keep < 0.999

        Component.onCompleted: if (root.ready) enterAnim.start()

        Connections {
            target: root
            function onOpenSeqChanged() {
                if (gr.leaving)
                    return
                enterAnim.stop()
                cascadeFx.stop()
                gr.keep = 1
                gr.fade = 0
                gr.lift = 12
                cascadePause.duration = 120 + gr.order * 40
                cascadeFx.start()
            }
            function onClearingChanged() {
                if (!root.clearing || gr.leaving)
                    return
                gr.leaving = true
                sweepPause.duration = Math.max(0, root.shownRows - 1 - gr.order) * 35
                sweepTo.to = gr.width + 40
                sweepFx.start()
            }
        }

        SequentialAnimation {
            id: cascadeFx
            PauseAnimation { id: cascadePause }
            ParallelAnimation {
                NumberAnimation { target: gr; property: "fade"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { target: gr; property: "lift"; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
            }
        }

        SequentialAnimation {
            id: sweepFx
            PauseAnimation { id: sweepPause }
            NumberAnimation { id: sweepTo; target: mover; property: "x"; duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.closeCurve }
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: gr; property: "keep"; from: 0; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
            NumberAnimation { target: gr; property: "lift"; from: -14; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
            NumberAnimation { target: gr; property: "fade"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        }

        Item {
            id: mover
            width: gr.width
            height: groupItem.implicitHeight
            opacity: gr.fade
            transform: Translate { y: gr.lift }

            NotificationGroupItem {
                id: groupItem
                width: mover.width
                group: gr.modelData
                index: gr.index
                listDragIndex: root.dragSection === gr.section ? root.dragIndex : -1
                listDragDistance: root.dragDistance
                dismissThreshold: root.dismissThreshold
                dragSettling: root.dragIndex < 0
                dismissTarget: root.dismissTarget

                onExpandRequested: root.reveal(gr)
                onDragBegan: i => root.beginDrag(gr.section, i)
                onDragMoved: d => root.updateDrag(d)
                onDragCancelled: root.endDrag()
                onDragDismissed: toRight => root.flingAway(gr.section, gr.index, gr.modelData, toRight)
            }
        }
    }
}
