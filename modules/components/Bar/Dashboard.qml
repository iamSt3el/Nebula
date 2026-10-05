import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import qs.modules.components.Bar.DashboardSections
import "DashGrid.js" as DashGrid
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item{
    id: root
    anchors.fill: parent

    implicitHeight: root.shownRows * (DashLayout.rowHeight + DashLayout.gap) - DashLayout.gap + root.pad * 2
    readonly property real pad: root.compact ? 7 : 10
    readonly property bool short: root.height > 0 && root.height < 380
    readonly property bool dense: root.compact || root.short

    property string panelMode: ""   // "" | "wifi" | "bluetooth" | "modes"
    property bool   compact:   false

    property var parentPos
    property var wifiPos
    property var bluetoothPos
    property var pos
    property var srcSize: null
    property real srcRadius: 20


    readonly property bool isPill: BarLayout.edgeShapes("top").indexOf("pill") >= 0

    readonly property int morphOpen: M3Motion.spatial.slowDuration
    readonly property int morphClose: M3Motion.spatial.defaultDuration

    property string activeMode: ""
    property bool panelVisible: false

    onPanelModeChanged: {
        closeTimer.stop()
        contentTimer.stop()
        if (root.panelMode !== "") {
            root.activeMode = root.panelMode
            root.panelVisible = true
            contentTimer.restart()
        } else {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: root.morphClose
        onTriggered: {
            panelLoader.active = false
            root.panelVisible = false
            root.activeMode = ""
        }
    }

    opacity: 0
    scale: 1

    NumberAnimation on opacity {
        from: 0; to: 1; duration: 400; running: true
    }

    NumberAnimation on scale {
        from: root.isPill ? 1 : 0.8
        to: 1
        duration: 400
        running: true
    }


    Connections {
        target: ServiceNetwork
        function onWifiEnabledChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { airplaneMode: !ServiceNetwork.wifiEnabled })
        }
    }

    Connections {
        target: ServicePipewire
        function onMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { speakerMuted: ServicePipewire.muted })
        }
        function onMicMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { micMuted: ServicePipewire.micMuted })
        }
    }




    // Overlay backdrop — fades in/out independently
    Rectangle {
        id: overlayBackdrop
        anchors.fill: parent
        z: 1
        radius: 20
        color: Qt.alpha(Colors.surface, 0.7)
        opacity: root.panelMode !== "" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: root.panelMode !== "" ? root.morphOpen : root.morphClose
                easing.type: Easing.BezierSpline
                easing.bezierCurve: M3Motion.effects.curve
            }
        }
    }

    // Panel container — persistent so states/transitions actually animate
    Rectangle {
        id: container
        z: 2
        enabled: root.panelMode !== ""

        x: root.pos ? root.pos.x : 0
        y: root.pos ? root.pos.y : 0
        width:  root.srcSize ? root.srcSize.width  : root.overlayW
        height: root.srcSize ? root.srcSize.height : 60
        radius: root.srcRadius
        opacity: {
            if (!root.panelVisible) return 0
            if (root.panelMode !== "") return 1
            const srcH = root.srcSize ? root.srcSize.height : 60
            const band = Math.max(40, srcH)
            return Math.max(0, Math.min(1, (container.height - srcH) / band))
        }
        visible: opacity > 0.01

        color: Colors.surfaceContainerHigh
        clip: true

        states: [
            State {
                name: "wifi"
                when: root.panelMode === "wifi"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: root.overlayW
                    height: root.overlayH
                    radius: 20
                }
            },
            State {
                name: "modes"
                when: root.panelMode === "modes"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: root.overlayW
                    height: 310
                    radius: 20
                }
            },
            State {
                name: "bluetooth"
                when: root.panelMode === "bluetooth"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: root.overlayW
                    height: root.overlayH
                    radius: 20
                }
            }
        ]

        transitions: [
            Transition {
                to: ""
                SpatialAnim {
                    properties: "x,y,width,height,radius"
                    speed: "default"
                }
            },
            Transition {
                SpatialAnim {
                    properties: "x,y,width,height,radius"
                    speed: "slow"
                }
            }
        ]

        Timer {
            id: contentTimer
            interval: root.morphOpen * 0.6
            onTriggered: if (root.panelMode !== "") panelLoader.active = true
        }

        Loader {
            id: panelLoader
            active: false
            anchors.fill: parent
            opacity: (root.panelMode !== "" && active) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { EffectsAnim { speed: "default" } }
            sourceComponent: root.activeMode === "wifi" ? wifiComponent
                : root.activeMode === "bluetooth" ? bluetoothComponent
                : root.activeMode === "modes" ? modesComponent
                : null
        }

        Component {
            id: wifiComponent
            Wifi { onBackClicked: root.panelMode = "" }
        }

        Component {
            id: modesComponent
            ModesPanel { onBackClicked: root.panelMode = "" }
        }

        Component {
            id: bluetoothComponent
            Bluetooth { onBackClicked: root.panelMode = "" }
        }
    }

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }


    signal toggleDashboard
    property bool active: false//hoverHandler.hovered

    onActiveChanged:{
        if(!active) root.toggleDashboard()
    }


    // HoverHandler{
    //     id: hoverHandler
    // }

    property bool editing: false

    readonly property string selectedKey: {
        const sel = BarLayout.editor ? BarLayout.editor.selectedItem : ""
        return sel.indexOf("dash:") === 0 ? sel.slice(5) : ""
    }

    readonly property real cellW: Math.max(24, (grid.width - DashLayout.gap * (DashLayout.columns - 1)) / DashLayout.columns)
    readonly property bool fitRows: DashLayout.fitRows && BarLayout.panelH("dashboard") >= 0 && root.height > 0
    readonly property real rowH: root.fitRows
        ? Math.max(28, ((root.height - root.pad * 2 + DashLayout.gap) / Math.max(1, DashLayout.rowsUsed)) - DashLayout.gap)
        : DashLayout.rowHeight
    readonly property real pitchY: root.rowH + DashLayout.gap
    readonly property var shownItems: root.preview ?? DashLayout.items
    readonly property int shownRows: Math.max(1, DashGrid.rowsUsed(root.shownItems) + (root.editing ? 2 : 0))
    readonly property real gridH: root.shownRows * root.pitchY - DashLayout.gap
    readonly property bool anyFills: false
    readonly property var occupied: {
        const o = {}
        for (const it of root.shownItems)
            for (let yy = it.y; yy < it.y + it.h; yy++)
                for (let xx = it.x; xx < it.x + it.w; xx++)
                    o[xx + "," + yy] = true
        return o
    }

    property string dragId: ""
    property string dragMode: ""
    property string dragKind: ""
    property var preview: null
    property bool overBin: false
    readonly property var ghost: {
        if (!root.preview || root.overBin)
            return null
        return root.preview.find(i => i.id === (root.dragMode === "new" ? "__new" : root.dragId)) ?? null
    }

    function specOf(id) {
        if (root.preview) {
            const p = root.preview.find(i => i.id === id)
            if (p)
                return p
            if (root.overBin && id === root.dragId)
                return null
        }
        return DashLayout.items.find(i => i.id === id) ?? null
    }

    onEditingChanged: {
        if (root.editing)
            DashLayout.activeDash = root
        else if (DashLayout.activeDash === root)
            DashLayout.activeDash = null
        root.cancelDrag()
    }
    Component.onDestruction: if (DashLayout.activeDash === root) DashLayout.activeDash = null

    function cellItem(id) {
        for (let i = 0; i < cellRepeater.count; i++) {
            const c = cellRepeater.itemAt(i)
            if (c && c.itemId === id)
                return c
        }
        return null
    }

    function selectItem(id) {
        if (BarLayout.editor)
            BarLayout.editor.selectedItem = "dash:" + id
    }

    function removeItem(id) {
        if (BarLayout.editor && BarLayout.editor.selectedItem === "dash:" + id)
            BarLayout.editor.selectedItem = "dashboard"
        DashLayout.dropItem(id)
    }

    function beginDrag(id, mode) {
        root.dragId = id
        root.dragMode = mode
        root.dragKind = ""
        root.overBin = false
        root.preview = DashLayout.items.map(i => Object.assign({}, i))
    }

    function trackMove(id, x, y) {
        const it = DashLayout.items.find(i => i.id === id)
        if (it && !root.overBin)
            root.preview = DashLayout.previewPush(id, x, y, it.w, it.h)
    }

    function trackResize(id, w, h) {
        const it = DashLayout.items.find(i => i.id === id)
        if (it)
            root.preview = DashLayout.previewPush(id, it.x, it.y, w, h)
    }

    function updateBin(item, px, py) {
        const p = item.mapToItem(bin, px, py)
        const over = bin.visible && p.x >= -12 && p.y >= -12 && p.x <= bin.width + 12 && p.y <= bin.height + 12
        if (over === root.overBin)
            return
        root.overBin = over
        if (over)
            root.preview = DashGrid.settle(DashLayout.items.filter(i => i.id !== root.dragId))
    }

    function beginExternal(kind) {
        root.dragId = "__new"
        root.dragMode = "new"
        root.dragKind = kind
        root.overBin = false
        root.preview = null
    }

    function trackExternal(item, px, py) {
        if (root.dragMode !== "new")
            return
        const e = DashLayout.kindEntry(root.dragKind)
        const w = Math.min(DashLayout.columns, e ? (e.defW ?? 2) : 2)
        const h = e ? (e.defH ?? 2) : 2
        const p = item.mapToItem(grid, px, py)
        const inside = p.x >= -20 && p.y >= -20 && p.x <= grid.width + 20 && p.y <= Math.max(grid.height, dashScroll.height) + 20
        if (!inside) {
            root.preview = null
            return
        }
        const cx = Math.round(p.x / (root.cellW + DashLayout.gap) - w / 2)
        const cy = Math.max(0, Math.round(p.y / root.pitchY - h / 2))
        root.preview = DashLayout.previewPush("__new", cx, cy, w, h, root.dragKind)
    }

    function endExternal(commit) {
        const g = root.ghost
        const kind = root.dragKind
        root.cancelDrag()
        if (!commit || !g)
            return ""
        const id = DashLayout.dropNew(kind, g.x, g.y)
        if (id !== "")
            root.selectItem(id)
        return id
    }

    function endDrag(commit) {
        const id = root.dragId
        const mode = root.dragMode
        const list = root.preview
        const bin = root.overBin
        root.cancelDrag()
        if (!commit)
            return
        if (bin) {
            root.removeItem(id)
            return
        }
        if (list)
            DashLayout.commitPreview(list, id, mode === "resize" ? "resized" : "moved")
    }

    function cancelDrag() {
        root.dragId = ""
        root.dragMode = ""
        root.dragKind = ""
        root.overBin = false
        root.preview = null
    }


    Component { id: cProfile
        DashProfile { compact: root.dense; onToggleDashboard: root.toggleDashboard() } }

    Component { id: cNotifications; DashNotifications { compact: root.dense } }
    Component { id: cTiles
        DashTiles {
            coordSpace: root
            panelMode: root.panelMode
            onOpenPanel: function(mode, pPos, p, sz, r) { root.openOverlay(mode, pPos, p, sz, r, 340, 460) }
        } }
    Component { id: cBubbles;       DashBubbles       {} }
    Component { id: cSlider;        DashSlider        {} }
    Component { id: cPower
        DashPower {
            coordSpace: root
            panelMode: root.panelMode
            onOpenPanel: function(mode, pPos, p, sz, r) { root.openOverlay(mode, pPos, p, sz, r, 340, 420) }
        } }
    Component { id: cToggle
        DashToggle {
            coordSpace: root
            panelMode: root.panelMode
            onOpenPanel: function(mode, pPos, p, sz, r) { root.openOverlay(mode, pPos, p, sz, r, 340, 460) }
        } }
    Component { id: cTimeline;      DashTimeline      {} }
    Component { id: cNextUp;        DashNextUp        {} }
    Component { id: cProcesses;     DashProcesses     {} }
    Component { id: cStorage;       DashStorage       {} }
    Component { id: cClock;         DashClock         {} }
    Component { id: cMonth;         DashMonth         {} }
    Component { id: cPlayer;        DashPlayer        {} }
    Component { id: cWeather;       DashWeather       {} }
    Component { id: cInbox;         DashInbox         {} }
    Component { id: cLevels;        DashLevels        {} }
    Component { id: cGauges;        DashGauges        {} }
    Component { id: cStat;          DashStat          {} }
    Component { id: cNetwork;       DashNetwork       {} }
    Component { id: cBattery;       DashBattery       {} }
    Component { id: cDevices;       DashDevices       {} }
    Component { id: cClaude;        DashClaude        {} }

    property real overlayW: 300
    property real overlayH: 460

    function openOverlay(mode, pPos, p, sz, r, w, h) {
        const ow = Math.min(Math.max(300, w), root.width - root.pad * 2)
        const oh = Math.min(h, root.height - root.pad * 2)
        root.overlayW = ow
        root.overlayH = oh
        root.parentPos = Qt.point(Math.max(root.pad, Math.min(root.width - root.pad - ow, pPos.x)),
                                  Math.max(root.pad, Math.min(root.height - root.pad - oh, pPos.y)))
        root.pos = p
        root.srcSize = sz
        root.srcRadius = r
        root.panelMode = mode
    }

    function componentFor(kind) {
        switch (kind) {
            case "profile":       return cProfile
            case "notifications": return cNotifications
            case "tiles":         return cTiles
            case "bubbles":       return cBubbles
            case "slider":        return cSlider
            case "power":         return cPower
            case "toggle":        return cToggle
            case "timeline":      return cTimeline
            case "nextUp":        return cNextUp
            case "processes":     return cProcesses
            case "storage":       return cStorage
            case "clock":         return cClock
            case "month":         return cMonth
            case "player":        return cPlayer
            case "weather":       return cWeather
            case "inbox":         return cInbox
            case "levels":        return cLevels
            case "gauges":        return cGauges
            case "stat":          return cStat
            case "network":       return cNetwork
            case "battery":       return cBattery
            case "devices":       return cDevices
            case "claude":        return cClaude
        }
        return null
    }

    ListModel { id: cellModel }

    function syncCells() {
        BarLayout.syncModel(cellModel, DashLayout.itemIds, "key", null)
    }

    Component.onCompleted: {
        root.syncCells()
        if (root.editing)
            DashLayout.activeDash = root
    }

    Connections {
        target: DashLayout
        function onItemIdsChanged() { root.syncCells() }
    }

    Flickable {
        id: dashScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(dashScroll.height, root.gridH + root.pad * 2)
        interactive: dashScroll.contentHeight > dashScroll.height + 1 && root.dragId === ""
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        Item {
            id: grid
            x: root.pad
            y: root.pad
            width: dashScroll.width - root.pad * 2
            height: root.gridH

            Repeater {
                model: root.editing ? DashLayout.columns * root.shownRows : 0
                delegate: Rectangle {
                    required property int index
                    visible: !root.occupied[(index % DashLayout.columns) + "," + Math.floor(index / DashLayout.columns)]
                    x: (index % DashLayout.columns) * (root.cellW + DashLayout.gap)
                    y: Math.floor(index / DashLayout.columns) * root.pitchY
                    width: root.cellW
                    height: root.rowH
                    radius: 14
                    color: Qt.alpha(Colors.primary, 0.035)
                    border.width: 1
                    border.color: Qt.alpha(Colors.outline, 0.12)
                }
            }

            Rectangle {
                visible: root.ghost !== null && root.dragMode !== ""
                x: root.ghost ? root.ghost.x * (root.cellW + DashLayout.gap) : 0
                y: root.ghost ? root.ghost.y * root.pitchY : 0
                width: root.ghost ? root.ghost.w * (root.cellW + DashLayout.gap) - DashLayout.gap : 0
                height: root.ghost ? root.ghost.h * root.pitchY - DashLayout.gap : 0
                radius: 20
                color: root.dragMode === "new" ? Colors.primaryContainer : Qt.alpha(Colors.primary, 0.14)
                border.width: 2
                border.color: Colors.primary

                Column {
                    anchors.centerIn: parent
                    visible: root.dragMode === "new"
                    spacing: 4
                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: DashLayout.kindEntry(root.dragKind)?.icon ?? "widgets"
                        iconSize: 26
                        customColor: Colors.primaryContainerText
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: DashLayout.kindEntry(root.dragKind)?.label ?? ""
                        size: 12
                        weight: 700
                        customColor: Colors.primaryContainerText
                    }
                }
                Behavior on x { SpatialAnim { speed: "fast" } }
                Behavior on y { SpatialAnim { speed: "fast" } }
                Behavior on width { SpatialAnim { speed: "fast" } }
                Behavior on height { SpatialAnim { speed: "fast" } }
            }

            Repeater {
                id: cellRepeater
                model: cellModel
                delegate: DashCell {
                    required property string key
                    itemId: key
                    dash: root
                    content: root.componentFor(DashLayout.kindOf(key))
                }
            }
        }
    }

    Rectangle {
        id: bin
        z: 20
        visible: root.editing && root.dragMode === "move"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        width: Math.min(300, root.width - 40) + (root.overBin ? 18 : 0)
        height: root.overBin ? 56 : 52
        radius: height / 2
        color: root.overBin ? Colors.errorContainer : Colors.surfaceContainerHighest
        border.width: 2
        border.color: root.overBin ? Colors.error : Qt.alpha(Colors.outline, 0.4)
        Behavior on width { SpatialAnim { speed: "fast" } }
        Behavior on height { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        Row {
            anchors.centerIn: parent
            spacing: 8
            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: "delete"
                iconSize: 20
                customColor: root.overBin ? Colors.errorContainerText : Colors.surfaceVariantText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.overBin ? "Release to remove" : "Drop here to remove"
                size: 13
                weight: 600
                customColor: root.overBin ? Colors.errorContainerText : Colors.surfaceVariantText
            }
        }
    }

    Rectangle {
        id: undoPill
        z: 20
        readonly property bool wanted: root.editing && root.dragId === "" && DashLayout.undoItems !== null && undoTimer.running
        visible: opacity > 0.01
        opacity: undoPill.wanted ? 1 : 0
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: undoRow.implicitWidth + 16
        height: 44
        radius: 22
        color: Colors.inverseSurface

        Row {
            id: undoRow
            anchors.centerIn: parent
            spacing: 6
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 8
                content: DashLayout.undoLabel
                size: 13
                customColor: Colors.inverseSurfaceText
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: undoText.implicitWidth + 24
                height: 32
                radius: 16
                color: undoArea.containsMouse ? Qt.alpha(Colors.inversePrimary, 0.18) : "transparent"
                CustomText {
                    id: undoText
                    anchors.centerIn: parent
                    content: "Undo"
                    size: 13
                    weight: 700
                    customColor: Colors.inversePrimary
                }
                MouseArea {
                    id: undoArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DashLayout.undo()
                }
            }
        }
    }

    Timer {
        id: undoTimer
        interval: 8000
    }

    Connections {
        target: DashLayout
        function onUndoLabelChanged() {
            if (DashLayout.undoLabel !== "")
                undoTimer.restart()
        }
    }
}
