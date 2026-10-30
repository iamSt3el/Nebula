import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: edits

    required property Item block
    readonly property bool gripHovered: gripHover.hovered
    readonly property bool gripShown: gripPill.shown
    readonly property bool holdsSelection: !!edits.block.editor && edits.block.editor.selectedItem !== ""
        && edits.block.hasItem(edits.block.editor.selectedItem)
    readonly property bool engaged: edits.block.hovering || gripHover.hovered || gripArea.pressed || edits.block.blockSelected
        || edits.holdsSelection || edits.block.emptyInEdit
    property bool lingering: false
    onEngagedChanged: {
        if (edits.engaged)
            linger.stop()
        else {
            edits.lingering = true
            linger.restart()
        }
    }

    Timer {
        id: linger
        interval: 450
        onTriggered: edits.lingering = false
    }

    MouseArea {
        id: editArea
        x: 0
        y: 0
        width: edits.block.width
        height: edits.block.barH
        enabled: edits.block.editing
        visible: edits.block.editing
        cursorShape: edits.block.editor && edits.block.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property string pressId: ""
        property int pressList: -1
        property Item pressGrab: null
        property string pressGrabId: ""
        property real pressW: 28
        property real pressX: 0
        property real pressY: 0
        property string pressApp: ""
        property bool pressAppPinned: false
        property real pressAppW: 0

        function clearPress() {
            editArea.pressId = ""
            editArea.pressList = -1
            editArea.pressApp = ""
            editArea.pressAppPinned = false
            editArea.pressGrab = null
            editArea.pressGrabId = ""
        }

        onPressed: mouse => {
            const s = edits.block.slotUnder(mouse.x)
            editArea.pressId = s ? s.itemId : ""
            editArea.pressList = s ? s.listIndex : -1
            editArea.pressW = s ? s.width : 28
            editArea.pressApp = ""
            editArea.pressAppPinned = false
            if (s && BarLayout.baseId(s.itemId) === "dockApps" && s.loaderItem) {
                const lx = mouse.x - (edits.block.pad + s.x + s.contentStart)
                const r = s.loaderItem.appRects.find(a => lx >= a.x && lx <= a.x + a.w)
                if (r) {
                    editArea.pressApp = r.appId
                    editArea.pressAppPinned = r.pinned
                    editArea.pressAppW = r.w
                }
            }
            editArea.pressX = mouse.x
            editArea.pressY = mouse.y
            const ed = edits.block.editor
            if (ed) {
                ed.liftUrl = ""
                ed.liftFor = ""
                const it = s && editArea.pressApp === "" ? s.loaderItem : null
                if (it && it.width > 0 && it.height > 0) {
                    const lp = editArea.mapToItem(it, mouse.x, mouse.y)
                    ed.liftDX = lp.x
                    ed.liftDY = lp.y
                    ed.liftW = it.width
                    ed.liftH = it.height
                    editArea.pressGrab = it
                    editArea.pressGrabId = s.itemId
                } else {
                    editArea.pressGrab = null
                    editArea.pressGrabId = ""
                }
            }
        }
        onPositionChanged: mouse => {
            if (!editArea.pressed)
                return
            const e = edits.block.editor
            if (e.mode === "" && Math.hypot(mouse.x - editArea.pressX, mouse.y - editArea.pressY) > 4) {
                if (editArea.pressApp !== "")
                    e.beginApp(editArea.pressApp, editArea.pressAppPinned, editArea.pressAppW)
                else if (editArea.pressList >= 0) {
                    const it = editArea.pressGrab
                    const want = editArea.pressGrabId
                    if (it && it.width > 0 && it.height > 0)
                        it.grabToImage(r => {
                            e.liftUrl = r.url
                            e.liftFor = want
                        })
                    e.beginItem(editArea.pressId, edits.block.blockId, editArea.pressList, editArea.pressW)
                }
            }
            if (e.mode !== "") {
                const p = editArea.mapToItem(null, mouse.x, mouse.y)
                e.update(p.x, p.y)
            }
        }
        onReleased: {
            const id = editArea.pressId
            const app = editArea.pressApp
            const pinned = editArea.pressAppPinned
            editArea.clearPress()
            if (edits.block.editor.mode !== "")
                edits.block.editor.finish()
            else if (app !== "" && !pinned)
                Qt.callLater(() => ServiceApps.pinById(app))
            else if (BarLayout.isMore(edits.block.blockId)) {
                if (edits.block.frame && edits.block.frame.toggleEditPage)
                    edits.block.frame.toggleEditPage()
            } else if (id === "")
                edits.block.editor.selectedBlock = edits.block.blockSelected ? "" : edits.block.blockId
            else
                edits.block.editor.selectedItem = id
        }
        onCanceled: {
            editArea.clearPress()
            edits.block.editor.cancel()
        }
    }

    MouseArea {
        x: 0
        y: 0
        z: 2
        width: edits.block.width
        height: edits.block.barH
        enabled: edits.block.editing && BarLayout.gapModel
        visible: edits.block.editing && BarLayout.gapModel
        acceptedButtons: Qt.RightButton
        onClicked: {
            const e = edits.block.editor
            if (!e)
                return
            const id = edits.block.blockId
            e.selectedItem = ""
            e.selectedBlock = e.selectedBlock === id ? "" : id
        }
    }

    Item {
        id: gripClip
        z: 1
        readonly property real across: edits.block.vertical ? gripPill.width : gripPill.height
        x: -120
        width: edits.block.width + 240
        y: edits.block.far ? -(gripClip.across + 12) : edits.block.barH
        height: gripClip.across + 12
        clip: true
        visible: edits.block.revealT > 0.001 && gripPill.slide > 0.01

        Rectangle {
            id: gripPill
            readonly property bool shown: edits.block.handlesIn && !edits.block.tabOpen && !BarLayout.isMore(edits.block.blockId)
                && GlobalStates.panelPreview === "" && !GlobalStates.launcherPreview
                && !edits.block.blockSelected && !edits.holdsSelection
                && (edits.engaged || edits.lingering || gripArea.pressed)
            HoverHandler { id: gripHover }
            property real slide: gripPill.shown ? 1 : 0
            Behavior on slide { SpatialAnim { speed: "fast" } }
            opacity: Math.max(0, Math.min(1, gripPill.slide * 2))
            readonly property real across: edits.block.vertical ? width : height
            readonly property real off: (1 - gripPill.slide) * (gripPill.across + 8) * (edits.block.far ? 1 : -1)
            y: (edits.block.far ? gripClip.height - 6 - across : 6) + (across - height) / 2 + gripPill.off
            readonly property real along: edits.block.vertical ? height : width
            x: 120 - width / 2 + Math.max(6 - edits.block.absX + gripPill.along / 2,
                                          Math.min(edits.block.frameW - edits.block.absX - 6 - gripPill.along / 2, edits.block.width / 2))
            width: handleRow.implicitWidth + 8
            height: 28
            transform: edits.block.vertical ? [gripFlip] : []

            Matrix4x4 { id: gripFlip; matrix: edits.block.flipAbout(gripPill.width, gripPill.height) }
            radius: 14
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colors.outline, 0.25)

            Row {
                id: handleRow
                anchors.centerIn: parent
                spacing: 2

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: gripArea.containsMouse || gripArea.pressed ? Qt.alpha(Colors.primary, 0.16) : "transparent"

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "drag_indicator"
                        iconSize: 16
                        customColor: Colors.surfaceText
                    }

                    MouseArea {
                        id: gripArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: gripArea.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        property point pressAt: Qt.point(0, 0)
                        property bool dragging: false
                        onPressed: mouse => {
                            gripArea.pressAt = gripArea.mapToItem(null, mouse.x, mouse.y)
                            gripArea.dragging = false
                        }
                        onPositionChanged: mouse => {
                            if (!gripArea.pressed)
                                return
                            const p = gripArea.mapToItem(null, mouse.x, mouse.y)
                            if (!gripArea.dragging) {
                                if (Math.hypot(p.x - gripArea.pressAt.x, p.y - gripArea.pressAt.y) <= 4)
                                    return
                                gripArea.dragging = true
                                edits.block.editor.beginBlock(edits.block.blockId)
                            }
                            edits.block.editor.update(p.x, p.y)
                        }
                        onReleased: {
                            if (gripArea.dragging) {
                                gripArea.dragging = false
                                edits.block.editor.finish()
                                return
                            }
                            edits.block.editor.selectedBlock = edits.block.blockSelected ? "" : edits.block.blockId
                        }
                        onCanceled: {
                            if (gripArea.dragging)
                                edits.block.editor.cancel()
                            gripArea.dragging = false
                        }
                    }

                    CustomToolTip { content: "Click to select · drag to move"; visible: gripArea.containsMouse && !gripArea.pressed }
                }
            }
        }
    }
}
