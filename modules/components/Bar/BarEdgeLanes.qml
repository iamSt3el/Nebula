pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: lanes

    required property Item host

    anchors.fill: parent

    readonly property var empties: lanes.host.surfaces.filter(s => s && s.visible && !s.present)
    readonly property bool active: lanes.host.editing && !lanes.host.stage && !lanes.host.shelfOpen
                                   && !lanes.host.drawerShown
    readonly property real thick: 36

    property Item popSurf: null
    property string popAnchor: ""
    property rect popFrom: Qt.rect(0, 0, 0, 0)
    property string popShape: "pill"

    function anchorName(surf, anchor) {
        if (surf && surf.vertical)
            return anchor === "left" ? "top" : anchor === "right" ? "bottom" : "middle"
        return anchor === "left" ? "left" : anchor === "right" ? "right" : "centre"
    }

    function edgeName(side) {
        return side.charAt(0).toUpperCase() + side.slice(1)
    }

    function laneRect(surf) {
        const b = ServiceGaps.borderFor(surf.side)
        if (surf.vertical) {
            const laneAt = side => lanes.empties.some(e => e.edge === side) ? ServiceGaps.borderFor(side) + 4 + lanes.thick : 0
            const y0 = Math.max(surf.crossStart, laneAt("top")) + 8
            const y1 = lanes.height - Math.max(surf.crossEnd, laneAt("bottom")) - 8
            const x = surf.far ? lanes.width - b - 4 - lanes.thick : b + 4
            return Qt.rect(x, y0, lanes.thick, Math.max(0, y1 - y0))
        }
        const x0 = surf.sideStart + 8
        const x1 = lanes.width - surf.sideEnd - 8
        const y = surf.far ? lanes.height - b - 4 - lanes.thick : b + 4
        return Qt.rect(x0, y, Math.max(0, x1 - x0), lanes.thick)
    }

    function emptyBlock(surf, anchor) {
        return BarLayout.allBlocks.find(b => b.edge === surf.edge && b.anchor === anchor && b.items.length === 0) ?? null
    }

    function openPop(surf, anchor, from) {
        const existing = lanes.emptyBlock(surf, anchor)
        if (existing) {
            lanes.pickParts(existing.id)
            return
        }
        lanes.popSurf = surf
        lanes.popAnchor = anchor
        lanes.popFrom = from
        lanes.popShape = BarLayout.gapPresetOf(surf.edge)
    }

    function closePop() {
        lanes.popSurf = null
        lanes.popAnchor = ""
    }

    function pickParts(blockId) {
        const e = lanes.host.editor
        if (!e)
            return
        e.selectedItem = ""
        e.selectedBlock = blockId
        lanes.host.shelfOpen = true
    }

    function confirmPop() {
        const surf = lanes.popSurf
        const anchor = lanes.popAnchor
        const shape = lanes.popShape
        lanes.closePop()
        if (!surf)
            return
        if (shape !== "")
            BarLayout.applyGapPreset(surf.edge, shape)
        const id = BarLayout.addBlock(anchor, surf.edge)
        Qt.callLater(() => lanes.pickParts(id))
    }

    onActiveChanged: if (!lanes.active) lanes.closePop()

    Repeater {
        model: lanes.host.editing ? lanes.empties : []

        delegate: Rectangle {
            id: lane

            required property Item modelData
            readonly property Item surf: lane.modelData
            readonly property rect r: lanes.laneRect(lane.surf)
            readonly property var ed: lanes.host.editor
            readonly property string dropEdge: {
                const e = lane.ed
                if (!e || e.mode !== "item" || e.dropBlock === "")
                    return ""
                if (e.dropBlock.indexOf("+") === 0)
                    return e.dropBlock.slice(1).split(":")[0]
                const b = BarLayout.blockById(e.dropBlock)
                return b ? b.edge : ""
            }
            readonly property string dropAnchor: {
                const e = lane.ed
                if (lane.dropEdge !== lane.surf.edge)
                    return ""
                if (e.dropBlock.indexOf("+") === 0)
                    return e.dropBlock.slice(1).split(":")[1] ?? ""
                const b = BarLayout.blockById(e.dropBlock)
                return b ? b.anchor : ""
            }
            readonly property bool hot: lane.dropAnchor !== ""
            readonly property bool dragging: !!lane.ed && lane.ed.mode === "item"
            readonly property bool open: lane.dragging || laneHover.hovered || lanes.popSurf === lane.surf
            property real openT: lane.open ? 1 : 0
            Behavior on openT { EffectsAnim { speed: "fast" } }

            x: lane.r.x
            y: lane.r.y
            width: lane.r.width
            height: lane.r.height
            radius: lanes.thick / 2
            color: Qt.alpha(Colors.primary, (lane.hot ? 0.18 : laneHover.hovered ? 0.1 : 0.06) * lane.openT)
            border.width: 2
            border.color: Qt.alpha(Colors.primary, (lane.hot ? 1 : 0.55) * lane.openT)
            opacity: lanes.active || lane.dragging ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { EffectsAnim { speed: "fast" } }

            HoverHandler { id: laneHover }

            MouseArea {
                anchors.fill: parent
                visible: lane.open
            }

            Rectangle {
                readonly property bool flat: !lane.surf.vertical
                opacity: 1 - lane.openT
                visible: opacity > 0.01
                width: flat ? 48 : 3
                height: flat ? 3 : 48
                radius: 1.5
                x: flat ? (lane.width - width) / 2 : (lane.surf.far ? lane.width - 3 : 0)
                y: flat ? (lane.surf.far ? lane.height - 3 : 0) : (lane.height - height) / 2
                color: Colors.outline
            }

            CustomText {
                opacity: lane.openT
                visible: !lane.surf.vertical && lane.openT > 0.01
                x: 120
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, lane.width / 2 - 120 - 80)
                elide: Text.ElideRight
                content: lane.dragging ? "Drop here to start the " + lane.surf.edge + " edge"
                    : lanes.edgeName(lane.surf.edge) + " edge is empty · drag an item here or add a block"
                size: 12
                weight: 500
                customColor: Colors.primary
            }

            Repeater {
                model: ["left", "center", "right"]

                delegate: Rectangle {
                    id: slotBtn

                    required property string modelData
                    readonly property string anchorKey: slotBtn.modelData
                    readonly property var waiting: lanes.emptyBlock(lane.surf, slotBtn.anchorKey)
                    readonly property bool lit: lane.dropAnchor === slotBtn.anchorKey
                        || (lanes.popSurf === lane.surf && lanes.popAnchor === slotBtn.anchorKey)
                    readonly property real along: slotBtn.anchorKey === "left" ? 4
                        : slotBtn.anchorKey === "right" ? (lane.surf.vertical ? lane.height : lane.width) - 4 - slotBtn.alongSize
                        : ((lane.surf.vertical ? lane.height : lane.width) - slotBtn.alongSize) / 2
                    readonly property real alongSize: lane.surf.vertical ? 28 : btnRow.implicitWidth + 20

                    x: lane.surf.vertical ? 4 : slotBtn.along
                    y: lane.surf.vertical ? slotBtn.along : 4
                    opacity: lane.openT
                    visible: lane.openT > 0.01
                    width: lane.surf.vertical ? 28 : slotBtn.alongSize
                    height: 28
                    radius: 14
                    color: slotBtn.lit ? Colors.primary
                        : btnArea.containsMouse ? Colors.primaryContainer
                        : slotBtn.waiting ? Colors.secondaryContainer : Colors.surfaceContainer
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    readonly property color ink: slotBtn.lit ? Colors.primaryText
                        : btnArea.containsMouse ? Colors.primaryContainerText
                        : slotBtn.waiting ? Colors.secondaryContainerText : Colors.primary

                    RowLayout {
                        id: btnRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIconSymbol {
                            content: slotBtn.waiting ? "widgets" : "add"
                            iconSize: 16
                            customColor: slotBtn.ink
                        }
                        CustomText {
                            visible: !lane.surf.vertical
                            content: slotBtn.waiting ? "Empty block · add parts" : lanes.anchorName(lane.surf, slotBtn.anchorKey).charAt(0).toUpperCase()
                                + lanes.anchorName(lane.surf, slotBtn.anchorKey).slice(1)
                            size: 12
                            weight: 600
                            customColor: slotBtn.ink
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lanes.openPop(lane.surf, slotBtn.anchorKey,
                                                 slotBtn.mapToItem(lanes, 0, 0, slotBtn.width, slotBtn.height))
                    }

                    CustomToolTip {
                        content: slotBtn.waiting ? "Empty block · add parts"
                            : "Add a block at the " + lanes.anchorName(lane.surf, slotBtn.anchorKey) + " of the " + lane.surf.edge + " edge"
                        visible: btnArea.containsMouse && lane.surf.vertical
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: lanes.popSurf !== null
        onClicked: lanes.closePop()
    }

    EditKit.Card {
        id: pop

        readonly property bool shown: lanes.popSurf !== null && lanes.active
        readonly property string side: lanes.popSurf ? lanes.popSurf.edge : "top"
        property real showT: pop.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: pop.shown ? 320 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pop.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }

        visible: pop.showT > 0.01
        opacity: Math.min(1, pop.showT * 1.5)
        width: 360
        height: popCol.implicitHeight + 36
        radius: 28
        x: Math.max(12, Math.min(lanes.width - pop.width - 12,
            pop.side === "left" ? lanes.popFrom.x + lanes.popFrom.width + 18
            : pop.side === "right" ? lanes.popFrom.x - pop.width - 18
            : lanes.popFrom.x + lanes.popFrom.width / 2 - pop.width / 2))
        y: Math.max(12, Math.min(lanes.height - pop.height - 12,
            pop.side === "top" ? lanes.popFrom.y + lanes.popFrom.height + 18
            : pop.side === "bottom" ? lanes.popFrom.y - pop.height - 18
            : lanes.popFrom.y + lanes.popFrom.height / 2 - pop.height / 2))
        transform: Scale {
            origin.x: pop.width / 2
            origin.y: pop.side === "bottom" ? pop.height : 0
            xScale: 0.85 + 0.15 * pop.showT
            yScale: 0.6 + 0.4 * pop.showT
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: popCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText {
                        content: "New block · " + lanes.edgeName(pop.side) + " " + lanes.anchorName(lanes.popSurf, lanes.popAnchor)
                        size: 16
                        weight: 600
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: "Pick its shape, then the parts to put in it"
                        size: 12
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }

                EditKit.Pill {
                    icon: "close"
                    box: 36
                    tip: "Close · Esc"
                    onClicked: lanes.closePop()
                }
            }

            EditKit.SectionLabel { content: "Shape" }

            EditTextChoice {
                Layout.fillWidth: true
                model: (lanes.popSurf && BarLayout.gapPresetOf(lanes.popSurf.edge) === ""
                    ? [{ value: "", label: "As it is", desc: "Keep this edge's own gaps" }] : []).concat(BarLayout.gapPresetInfo)
                current: lanes.popShape
                onPicked: v => lanes.popShape = v
            }

            EditKit.Pill {
                Layout.fillWidth: true
                icon: "add"
                label: "Add block and pick parts"
                filled: true
                box: 40
                onClicked: lanes.confirmPop()
            }
        }
    }
}
