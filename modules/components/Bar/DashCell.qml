pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: cell

    required property string itemId
    property Item dash: null
    property Component content: null

    readonly property var base: DashLayout.items.find(i => i.id === cell.itemId) ?? ({ x: 0, y: 0, w: 1, h: 1, kind: "" })
    readonly property var live: cell.dash ? (cell.dash.specOf(cell.itemId) ?? cell.base) : cell.base
    readonly property var entry: DashLayout.kindEntry(cell.base.kind)
    readonly property bool legacy: cell.entry ? cell.entry.legacy === true : false

    readonly property real pitchX: cell.dash ? cell.dash.cellW + DashLayout.gap : 0
    readonly property real rowH: cell.dash ? cell.dash.rowH : DashLayout.rowHeight
    readonly property real pitchY: cell.rowH + DashLayout.gap

    readonly property bool editing: cell.dash ? cell.dash.editing : false
    readonly property bool selected: cell.editing && cell.dash.selectedKey === cell.itemId
    readonly property bool mine: cell.dash ? cell.dash.dragId === cell.itemId : false
    readonly property bool moving: cell.mine && cell.dash.dragMode === "move"
    readonly property bool resizing: cell.mine && cell.dash.dragMode === "resize"
    readonly property bool busy: cell.dash ? cell.dash.dragId !== "" : false
    readonly property bool binned: cell.moving && cell.dash.overBin
    readonly property bool chromeShown: cell.editing && !cell.busy && (hover.hovered || cell.selected)

    property real dragX: 0
    property real dragY: 0
    property real growW: 0
    property real growH: 0
    property bool settled: true

    readonly property var anchorSpec: cell.moving || cell.resizing ? cell.base : cell.live

    x: cell.anchorSpec.x * cell.pitchX + cell.dragX
    y: cell.anchorSpec.y * cell.pitchY + cell.dragY
    width: Math.max(cell.dash ? cell.dash.cellW : 0, cell.anchorSpec.w * cell.pitchX - DashLayout.gap + cell.growW)
    height: Math.max(cell.rowH * 0.6, cell.anchorSpec.h * cell.pitchY - DashLayout.gap + cell.growH)
    z: cell.moving ? 30 : cell.resizing ? 25 : cell.selected ? 5 : 0
    scale: cell.binned ? 0.82 : cell.moving ? 1.03 : 1
    opacity: cell.binned ? 0.55 : cell.moving ? 0.94 : 1

    Behavior on x { enabled: cell.settled; SpatialAnim { speed: "fast" } }
    Behavior on y { enabled: cell.settled; SpatialAnim { speed: "fast" } }
    Behavior on width { enabled: cell.settled; SpatialAnim { speed: "fast" } }
    Behavior on height { enabled: cell.settled; SpatialAnim { speed: "fast" } }
    Behavior on scale { SpatialAnim { speed: "fast" } }
    Behavior on opacity { EffectsAnim { speed: "fast" } }

    readonly property bool carded: cell.legacy && DashLayout.cards && cell.base.kind !== "profile"
    readonly property bool ownsHeader: loader.item ? loader.item.ownsHeader === true : false
    readonly property bool framed: !cell.legacy && DashLayout.opt(cell.itemId, "background") !== false
    readonly property bool selfCarded: loader.item ? loader.item.card === true : false
    readonly property real pad: cell.legacy ? (cell.carded ? 10 : 0) : cell.framed && !cell.selfCarded ? 10 : 0
    readonly property real head: cell.legacy && cell.carded && !cell.ownsHeader ? 24 : 0
    readonly property real innerH: cell.height - cell.pad * 2 - cell.head
    readonly property bool fills: cell.base.kind === "notifications"

    HoverHandler { id: hover; enabled: cell.editing }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        z: -1
        radius: 22
        visible: cell.moving
        color: "transparent"
        border.width: 6
        border.color: Qt.alpha(Colors.shadow, 0.25)
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: cell.editing && !cell.carded ? Qt.alpha(Colors.surfaceContainer, 0.6) : Colors.surfaceContainer
        visible: (cell.carded || cell.editing) && !cell.framed
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        visible: cell.framed
        color: cell.selfCarded && loader.item.cardColor !== undefined ? loader.item.cardColor : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }
    }

    CustomText {
        x: cell.pad + 4
        y: cell.pad
        visible: cell.legacy && cell.carded && !cell.ownsHeader
        content: cell.entry ? cell.entry.label : ""
        size: 11
        weight: 700
        customColor: Colors.outline
    }

    Item {
        anchors.fill: parent
        // Slider value pills intentionally float above their cell, like the
        // Material 3 slider. Other dashboard content remains cell-clipped.
        clip: cell.base.kind !== "slider"

        Loader {
            id: loader
            x: cell.pad
            y: cell.pad + cell.head
            width: cell.width - cell.pad * 2
            height: !cell.legacy || cell.fills || !item ? cell.innerH
                : Math.min(cell.innerH, item.implicitHeight)
            enabled: !cell.editing
            sourceComponent: cell.content
            onLoaded: {
                if ("instanceId" in item)
                    item.instanceId = cell.itemId
            if ("framed" in item)
                item.framed = Qt.binding(() => cell.framed)
            if ("outerW" in item) {
                item.outerW = Qt.binding(() => cell.width)
                item.outerH = Qt.binding(() => cell.height)
            }
            }
        }
    }

    Shape {
        anchors.fill: parent
        z: 40
        visible: cell.editing && (cell.selected || cell.mine || hover.hovered)
        layer.enabled: visible
        layer.samples: 4

        ShapePath {
            strokeColor: cell.binned ? Colors.error : Colors.primary
            strokeWidth: 2
            strokeStyle: cell.mine ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: Qt.alpha(cell.binned ? Colors.error : Colors.primary, cell.mine ? 0.08 : cell.selected ? 0.1 : 0.05)

            PathRectangle {
                x: 1
                y: 1
                width: Math.max(0, cell.width - 2)
                height: Math.max(0, cell.height - 2)
                radius: 19
            }
        }
    }

    MouseArea {
        id: moveArea
        anchors.fill: parent
        z: 50
        enabled: cell.editing
        visible: cell.editing
        hoverEnabled: true
        cursorShape: cell.moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true

        property point press: Qt.point(0, 0)
        property bool moved: false

        onPressed: mouse => {
            moveArea.press = moveArea.mapToItem(cell.dash, mouse.x, mouse.y)
            moveArea.moved = false
        }
        onPositionChanged: mouse => {
            if (!moveArea.pressed)
                return
            const p = moveArea.mapToItem(cell.dash, mouse.x, mouse.y)
            const dx = p.x - moveArea.press.x
            const dy = p.y - moveArea.press.y
            if (!moveArea.moved && Math.abs(dx) + Math.abs(dy) > 6) {
                moveArea.moved = true
                cell.settled = false
                cell.dash.beginDrag(cell.itemId, "move")
            }
            if (!moveArea.moved || !cell.moving)
                return
            cell.dragX = dx
            cell.dragY = dy
            cell.dash.updateBin(moveArea, mouse.x, mouse.y)
            cell.dash.trackMove(cell.itemId,
                                Math.round((cell.base.x * cell.pitchX + dx) / cell.pitchX),
                                Math.max(0, Math.round((cell.base.y * cell.pitchY + dy) / cell.pitchY)))
        }
        onReleased: {
            if (moveArea.moved)
                cell.finish(cell.moving)
            else
                cell.dash.selectItem(cell.itemId)
            moveArea.moved = false
        }
        onCanceled: {
            if (moveArea.moved)
                cell.finish(false)
            moveArea.moved = false
        }
    }

    Connections {
        target: cell.dash
        function onDragIdChanged() {
            if (cell.dash.dragId === "" && !cell.settled)
                cell.finish(false)
        }
    }

    property bool finishing: false

    function finish(commit) {
        if (cell.finishing)
            return
        cell.finishing = true
        const wasBinned = cell.binned
        const ax = cell.x
        const ay = cell.y
        const aw = cell.width
        const ah = cell.height
        if (cell.dash.dragId === cell.itemId)
            cell.dash.endDrag(commit)
        cell.finishing = false
        if (wasBinned && commit)
            return
        const s = cell.live
        cell.dragX = ax - s.x * cell.pitchX
        cell.dragY = ay - s.y * cell.pitchY
        cell.growW = aw - (s.w * cell.pitchX - DashLayout.gap)
        cell.growH = ah - (s.h * cell.pitchY - DashLayout.gap)
        Qt.callLater(() => {
            cell.settled = true
            cell.dragX = 0
            cell.dragY = 0
            cell.growW = 0
            cell.growH = 0
        })
    }

    Rectangle {
        z: 60
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.topMargin: 6
        visible: cell.chromeShown && !cell.selected
        width: label.implicitWidth + 16
        height: 22
        radius: 11
        color: cell.selected ? Colors.primary : Colors.surfaceContainerHighest

        CustomText {
            id: label
            anchors.centerIn: parent
            content: cell.entry ? cell.entry.label : cell.itemId
            size: 11
            weight: 700
            customColor: cell.selected ? Colors.primaryText : Colors.surfaceText
        }
    }

    Rectangle {
        z: 60
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 6
        visible: cell.chromeShown && !cell.selected
        width: 24
        height: 24
        radius: 12
        color: removeArea.containsMouse ? Colors.errorContainer : Colors.surfaceContainerHighest

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "close"
            iconSize: 15
            customColor: removeArea.containsMouse ? Colors.errorContainerText : Colors.surfaceText
        }

        MouseArea {
            id: removeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const id = cell.itemId
                const d = cell.dash
                Qt.callLater(() => d.removeItem(id))
            }
        }

        CustomToolTip { content: "Remove from the dashboard"; visible: removeArea.containsMouse }
    }

    component Grip: MouseArea {
        id: g
        required property bool horiz
        required property bool vert
        property point press: Qt.point(0, 0)
        z: 61
        enabled: cell.editing
        visible: cell.editing && (cell.chromeShown || g.pressed || g.containsMouse)
        hoverEnabled: true
        preventStealing: true
        cursorShape: g.horiz && g.vert ? Qt.SizeFDiagCursor : g.horiz ? Qt.SizeHorCursor : Qt.SizeVerCursor

        onPressed: mouse => {
            g.press = g.mapToItem(cell.dash, mouse.x, mouse.y)
            cell.settled = false
            cell.dash.beginDrag(cell.itemId, "resize")
        }
        onPositionChanged: mouse => {
            if (!g.pressed)
                return
            const p = g.mapToItem(cell.dash, mouse.x, mouse.y)
            const bw = cell.base.w * cell.pitchX - DashLayout.gap
            const bh = cell.base.h * cell.pitchY - DashLayout.gap
            if (g.horiz)
                cell.growW = Math.max(cell.dash.cellW - bw, Math.min(cell.dash.width, p.x - g.press.x))
            if (g.vert)
                cell.growH = Math.max(cell.rowH - bh, p.y - g.press.y)
            cell.dash.trackResize(cell.itemId,
                                  Math.max(1, Math.round((bw + cell.growW + DashLayout.gap) / cell.pitchX)),
                                  Math.max(1, Math.round((bh + cell.growH + DashLayout.gap) / cell.pitchY)))
        }
        onReleased: cell.finish(true)
        onCanceled: cell.finish(false)
    }

    Grip {
        horiz: true
        vert: false
        anchors.right: parent.right
        anchors.rightMargin: -6
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: Math.min(56, parent.height - 36)

        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: Math.min(40, parent.height)
            radius: 2.5
            color: parent.pressed || parent.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.6)
        }
    }

    Grip {
        horiz: false
        vert: true
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -6
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(72, parent.width - 36)
        height: 14

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(44, parent.width)
            height: 5
            radius: 2.5
            color: parent.pressed || parent.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.6)
        }
    }

    Grip {
        id: corner
        horiz: true
        vert: true
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -8
        anchors.bottomMargin: -8
        width: 26
        height: 26

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 10
            color: corner.pressed || corner.containsMouse ? Colors.primary : Colors.surfaceContainerHighest
            border.width: 2
            border.color: Colors.primary

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "open_in_full"
                rotation: 90
                iconSize: 11
                customColor: corner.pressed || corner.containsMouse ? Colors.primaryText : Colors.primary
            }
        }
    }

    Rectangle {
        z: 62
        visible: cell.resizing && cell.dash.ghost !== null
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 22
        anchors.bottomMargin: 20
        width: sizeText.implicitWidth + 16
        height: 24
        radius: 12
        color: Colors.primary

        CustomText {
            id: sizeText
            anchors.centerIn: parent
            content: cell.dash && cell.dash.ghost ? cell.dash.ghost.w + " × " + cell.dash.ghost.h : ""
            size: 12
            weight: 700
            customColor: Colors.primaryText
        }
    }
}
