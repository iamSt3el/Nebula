pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: chrome
    anchors.fill: parent

    property QtObject editor: null
    property Item topSurface: null
    property Item bottomSurface: null
    property bool editing: false
    property bool previewRight: true

    readonly property string sel: chrome.editor ? chrome.editor.selectedItem : ""
    readonly property string selBlock: chrome.editor ? chrome.editor.selectedBlock : ""
    readonly property bool dragging: chrome.editor !== null && chrome.editor.mode !== ""
    readonly property bool stage: chrome.editor !== null && chrome.editor.panelStage
    readonly property bool drawerShown: chrome.editor !== null && chrome.editor.drawerMode !== ""

    property bool shelfOpen: false
    property string pop: ""
    property real t: 0

    visible: chrome.t > 0.01
    Behavior on t { SpatialAnim { speed: "default" } }

    onEditingChanged: {
        chrome.t = chrome.editing ? 1 : 0
        chrome.shelfOpen = false
        chrome.pop = ""
        if (chrome.editing) chrome.resetHistory()
    }
    onSelChanged: chrome.pop = ""
    onSelBlockChanged: chrome.pop = ""

    readonly property rect shelfRect: shelf.visible ? Qt.rect(shelf.x, shelf.y, shelf.width, shelf.height) : Qt.rect(0, 0, 0, 0)

    function closeAll() {
        if (DashLayout.activeDash && DashLayout.activeDash.dragId !== "") { DashLayout.activeDash.cancelDrag(); return true }
        if (chrome.pop !== "") { chrome.pop = ""; return true }
        if (chrome.shelfOpen) { chrome.shelfOpen = false; return true }
        if (chrome.editor && chrome.editor.drawerMode !== "") { chrome.editor.drawerMode = ""; return true }
        if (chrome.stage) { chrome.editor.panelStage = false; return true }
        return false
    }

    readonly property var panelList: [
        { item: "clock",     kind: "calendar",  label: "Calendar",  icon: "calendar_month" },
        { item: "weather",   kind: "weather",   label: "Weather",   icon: "partly_cloudy_day" },
        { item: "dashboard", kind: "dashboard", label: "Dashboard", icon: "dashboard" },
        { item: "launcher",  kind: "launcher",  label: "Apps",      icon: "apps" },
        { item: "wallpaper", kind: "wallpaper", label: "Wallpaper", icon: "wallpaper" },
        { item: "clipboard", kind: "clipboard", label: "Clipboard", icon: "content_paste" }
    ]

    function panelOf(id) {
        const k = BarLayout.panelFor(id)
        return chrome.panelList.find(p => p.kind === k) ?? null
    }

    function openStage(itemId) {
        if (!chrome.editor) return
        chrome.shelfOpen = false
        chrome.pop = ""
        chrome.editor.drawerMode = ""
        chrome.editor.selectedItem = itemId
        chrome.editor.panelStage = true
    }

    readonly property var tints: [
        { value: "none",        label: "None" },
        { value: "primary",     label: "Primary" },
        { value: "secondary",   label: "Secondary" },
        { value: "tertiary",    label: "Tertiary" },
        { value: "surfaceText", label: "Neutral" }
    ]

    property var history: []
    property int historyIndex: -1
    property bool restoring: false
    readonly property bool canUndo: chrome.historyIndex > 0
    readonly property bool canRedo: chrome.historyIndex >= 0 && chrome.historyIndex < chrome.history.length - 1

    function canonOf(v) {
        if (v === null || typeof v !== "object")
            return JSON.stringify(v)
        if (Array.isArray(v))
            return "[" + v.map(x => chrome.canonOf(x)).join(",") + "]"
        return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + chrome.canonOf(v[k])).join(",") + "}"
    }

    function snapshot() {
        return chrome.canonOf(JSON.parse(JSON.stringify({ bar: SettingsConfig.bar ?? {}, general: SettingsConfig.general ?? {} })))
    }

    function resetHistory() {
        recordTimer.stop()
        chrome.history = [chrome.snapshot()]
        chrome.historyIndex = 0
    }

    function restoreAt(i) {
        recordTimer.stop()
        chrome.restoring = true
        chrome.historyIndex = i
        const s = JSON.parse(chrome.history[i])
        SettingsConfig.bar = s.bar
        SettingsConfig.general = s.general
        restoreRelease.restart()
    }

    function undo() { if (chrome.canUndo) chrome.restoreAt(chrome.historyIndex - 1) }
    function redo() { if (chrome.canRedo) chrome.restoreAt(chrome.historyIndex + 1) }

    Timer {
        id: restoreRelease
        interval: 500
        onTriggered: chrome.restoring = false
    }

    Timer {
        id: recordTimer
        interval: 300
        onTriggered: {
            const s = chrome.snapshot()
            if (chrome.historyIndex >= 0 && s === chrome.history[chrome.historyIndex])
                return
            const next = chrome.history.slice(0, chrome.historyIndex + 1).concat([s])
            chrome.history = next.length > 80 ? next.slice(next.length - 80) : next
            chrome.historyIndex = chrome.history.length - 1
        }
    }

    Connections {
        target: SettingsConfig
        function onBarChanged() { if (chrome.editing && !chrome.restoring) recordTimer.restart() }
        function onGeneralChanged() { if (chrome.editing && !chrome.restoring) recordTimer.restart() }
    }

    property rect selRect: Qt.rect(0, 0, 0, 0)
    property string selEdge: "top"
    property bool selFound: false

    function locate() {
        const id = chrome.sel
        for (const surf of [chrome.topSurface, chrome.bottomSurface]) {
            if (!surf || !surf.visible) continue
            for (const b of surf.visibleBlocks) {
                if (!b.hasItem(id)) continue
                const it = b.itemFor(id)
                if (!it) continue
                chrome.selRect = it.mapToItem(chrome, 0, 0, it.width, it.height)
                chrome.selEdge = surf.side
                chrome.selFound = true
                return
            }
        }
        chrome.selFound = false
    }

    Timer {
        interval: 60
        repeat: true
        running: chrome.editing && chrome.sel !== ""
        triggeredOnStart: true
        onTriggered: chrome.locate()
    }

    property rect blockRect: Qt.rect(0, 0, 0, 0)
    property string blockEdge: "top"
    property bool blockFound: false

    function locateBlock() {
        for (const surf of [chrome.topSurface, chrome.bottomSurface]) {
            if (!surf || !surf.visible) continue
            const b = surf.visibleBlocks.find(v => v.blockId === chrome.selBlock)
            if (!b) continue
            chrome.blockRect = b.mapToItem(chrome, 0, 0, b.width, b.barH)
            chrome.blockEdge = surf.side
            chrome.blockFound = true
            return
        }
        chrome.blockFound = false
    }

    Timer {
        interval: 60
        repeat: true
        running: chrome.editing && chrome.selBlock !== ""
        triggeredOnStart: true
        onTriggered: chrome.locateBlock()
    }

    readonly property var shapeChoices: [
        { value: "stepped", label: "Stepped", icon: "view_agenda" },
        { value: "flat",    label: "Flat",    icon: "remove" },
        { value: "pill",    label: "Pill",    icon: "circle" }
    ]

    function addTarget(id) {
        const dockOnly = !BarLayout.allows(id, "bar")
        const edge = dockOnly ? "bottom" : "top"
        const blocks = BarLayout.allBlocks.filter(b => b.edge === edge && b.id !== "__sys")
        if (chrome.sel !== "" && !dockOnly) {
            const own = blocks.find(b => b.items.indexOf(chrome.sel) >= 0)
            if (own)
                return { block: own.id, index: own.items.indexOf(chrome.sel) + 1 }
        }
        const pref = blocks.find(b => b.anchor === "right") ?? blocks.find(b => b.anchor === "center") ?? blocks[0]
        return pref ? { block: pref.id, index: pref.items.length } : null
    }

    function addItem(id) {
        const tgt = chrome.addTarget(id)
        if (!tgt) return
        Qt.callLater(() => {
            BarLayout.moveItem(id, tgt.block, tgt.index)
            if (!BarLayout.entry(id) || !BarLayout.entry(id).multi)
                chrome.editor.selectedItem = id
        })
    }

    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property bool lit: false
        property bool danger: false
        property bool filled: false
        property bool tonal: false
        property bool usable: true
        property int box: 40
        signal clicked

        implicitHeight: pill.box
        implicitWidth: pill.label !== "" ? pillRow.implicitWidth + (pill.icon !== "" ? 30 : 32) : pill.box
        radius: pillArea.pressed ? 12 : pill.box / 2
        opacity: pill.usable ? 1 : 0.38
        color: pill.filled ? Colors.primary
            : pill.tonal ? Colors.primaryContainer
            : pill.lit ? Colors.secondaryContainer
            : pillArea.containsMouse && pill.usable ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        readonly property color ink: pill.filled ? Colors.primaryText
            : pill.tonal ? Colors.primaryContainerText
            : pill.danger ? Colors.error
            : pill.lit ? Colors.secondaryContainerText : Colors.surfaceText

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            MaterialIconSymbol {
                visible: pill.icon !== ""
                content: pill.icon
                iconSize: 19
                customColor: pill.ink
            }

            CustomText {
                visible: pill.label !== ""
                content: pill.label
                size: 13
                weight: 600
                customColor: pill.ink
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: pill.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 24
        color: Colors.outlineVariant
    }

    component Card: Rectangle {
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.18)
    }

    component SectionLabel: CustomText {
        size: 13
        weight: 500
        customColor: Colors.primary
    }

    component ChoiceChip: Rectangle {
        id: cc
        property string label: ""
        property string icon: ""
        property bool lit: false
        signal clicked
        implicitHeight: 34
        implicitWidth: ccRow.implicitWidth + 24
        radius: 17
        color: cc.lit ? Colors.secondaryContainer
            : ccArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }
        RowLayout {
            id: ccRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: cc.icon !== "" || cc.lit
                content: cc.lit ? "check" : cc.icon
                iconSize: 15
                customColor: cc.lit ? Colors.secondaryContainerText : Colors.surfaceVariantText
            }
            CustomText {
                content: cc.label
                size: 12
                weight: cc.lit ? 700 : 500
                customColor: cc.lit ? Colors.secondaryContainerText : Colors.surfaceText
            }
        }
        MouseArea {
            id: ccArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.clicked()
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: chrome.pop !== ""
        onClicked: chrome.pop = ""
    }

    Card {
        id: capsule
        readonly property Item floor: chrome.bottomSurface && chrome.bottomSurface.visible && chrome.bottomSurface.side === "bottom"
            ? chrome.bottomSurface : chrome.topSurface && chrome.topSurface.side === "bottom" ? chrome.topSurface : null
        readonly property real dockTop: capsule.floor ? capsule.floor.bandRect.y : chrome.height
        readonly property bool raised: chrome.stage && chrome.dashLow
        readonly property real restY: capsule.raised
            ? (BarLayout.barSide === "top" && chrome.topSurface ? chrome.topSurface.rowItem.y + Appearance.size.barHeight + 16 : 20)
            : capsule.dockTop - 56 - 22
        property real restYAnim: capsule.restY
        Behavior on restYAnim { SpatialAnim { speed: "default" } }
        readonly property real fullW: capRow.implicitWidth + 12
        readonly property real restX: (chrome.width - capsule.fullW) / 2

        property real capT: chrome.editing ? 1 : 0
        Behavior on capT {
            NumberAnimation {
                duration: chrome.editing ? 560 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: chrome.editing ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        readonly property real wipe: Math.max(0, Math.min(1, (capsule.capT - 0.5) / 0.5))
        readonly property rect dockRect: {
            chrome.editing
            const f = capsule.floor
            if (!f)
                return Qt.rect(0, 0, 0, 0)
            let l = 1e9
            let r = -1e9
            let top = 1e9
            for (const blk of f.visibleBlocks) {
                const q = blk.mapToItem(chrome, 0, 0, blk.width, blk.height)
                l = Math.min(l, q.x)
                r = Math.max(r, q.x + q.width)
                top = Math.min(top, q.y)
            }
            return l < r ? Qt.rect(l, top, r - l, 0) : Qt.rect(0, 0, 0, 0)
        }
        readonly property bool fromDock: capsule.dockRect.width > 0 && !capsule.raised
        readonly property real startW: capsule.fromDock ? Math.min(capsule.fullW, capsule.dockRect.width) : capsule.fullW * 0.6
        readonly property real startX: capsule.fromDock ? capsule.dockRect.x + capsule.dockRect.width / 2 - capsule.startW / 2
                                                        : (chrome.width - capsule.startW) / 2
        readonly property real startY: capsule.fromDock ? capsule.dockRect.y - 4 : capsule.restYAnim + 26

        property real shelfFactor: chrome.shelfOpen ? 0 : 1
        Behavior on shelfFactor { EffectsAnim { speed: "fast" } }

        x: capsule.startX + (capsule.restX - capsule.startX) * capsule.capT
        y: capsule.startY + (capsule.restYAnim - capsule.startY) * capsule.capT
        width: capsule.startW + (capsule.fullW - capsule.startW) * capsule.capT
        height: 4 + 52 * capsule.capT
        radius: height / 2
        opacity: Math.min(1, capsule.capT * 5) * capsule.shelfFactor
        visible: opacity > 0.01

        Item {
            id: capWipe
            anchors.fill: capRow
            visible: false
            layer.enabled: true

            Rectangle {
                width: capWipe.width * 2
                height: capWipe.height
                x: -capWipe.width * 2 * (1 - capsule.wipe)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: 0.6; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        RowLayout {
            id: capRow
            anchors.centerIn: parent
            spacing: 4
            layer.enabled: capsule.wipe < 0.999
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: capWipe
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                id: logoBtn
                implicitWidth: 44
                implicitHeight: 44
                radius: logoArea.pressed ? 12 : 22
                color: logoArea.containsMouse ? Colors.primary : Colors.primaryContainer
                Behavior on radius { SpatialAnim { speed: "fast" } }
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                NebulaLogo {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    color: logoArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    rotation: logoArea.containsMouse ? -8 : 0
                    Behavior on rotation { SpatialAnim { speed: "fast" } }
                }

                MouseArea {
                    id: logoArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        GlobalStates.barEditMode = false
                        GlobalStates.settingsPage = 9
                        GlobalStates.settingsOpen = true
                    }
                }

                CustomToolTip { content: "Nebula settings"; visible: logoArea.containsMouse }
            }

            Divider { Layout.leftMargin: 2; Layout.rightMargin: 2 }

            Pill {
                icon: "add"
                label: "Add to bar"
                tonal: true
                box: 44
                onClicked: {
                    chrome.pop = ""
                    if (chrome.editor) {
                        chrome.editor.drawerMode = ""
                        chrome.editor.panelStage = false
                    }
                    chrome.shelfOpen = true
                }
            }
            Pill { icon: "undo"; box: 44; usable: chrome.canUndo; onClicked: chrome.undo() }
            Pill { icon: "redo"; box: 44; usable: chrome.canRedo; onClicked: chrome.redo() }
            Divider { Layout.leftMargin: 2; Layout.rightMargin: 2 }
            Pill {
                icon: "view_quilt"
                label: "Panels"
                box: 44
                lit: chrome.stage
                onClicked: {
                    if (chrome.stage) {
                        chrome.editor.panelStage = false
                        return
                    }
                    const own = chrome.panelOf(chrome.sel)
                    const first = chrome.panelList.find(p => BarLayout.isPlaced(p.item) || p.kind === "wallpaper" || p.kind === "launcher" || p.kind === "clipboard")
                    chrome.openStage(own ? chrome.sel : first ? first.item : "wallpaper")
                }
            }
            Pill {
                id: capSettings
                icon: "tune"
                label: "Bar & dock"
                box: 44
                lit: chrome.editor !== null && chrome.editor.drawerMode === "settings"
                onClicked: {
                    const e = chrome.editor
                    if (!e) return
                    if (e.drawerMode === "settings") {
                        e.drawerMode = ""
                        return
                    }
                    e.panelStage = false
                    e.selectedItem = ""
                    e.drawerFrom = capSettings.mapToItem(chrome, 0, 0, capSettings.width, capSettings.height)
                    e.drawerMode = "settings"
                }
            }
            Pill { icon: "restart_alt"; box: 44; onClicked: BarLayout.reset() }
            Pill {
                icon: "check"
                label: "Done"
                filled: true
                box: 44
                onClicked: GlobalStates.barEditMode = false
            }
        }
    }

    Card {
        id: toolbar
        readonly property var entry: chrome.sel !== "" && chrome.sel.indexOf("dash:") !== 0 ? BarLayout.entry(chrome.sel) : null
        readonly property var styleSpec: toolbar.entry && toolbar.entry.options
            ? toolbar.entry.options.find(o => o.key === "style" && (o.type === "grid" || o.type === "choice") && o.choices) ?? null : null
        readonly property var labelSpec: toolbar.entry && toolbar.entry.options
            ? toolbar.entry.options.find(o => o.key === "showLabel") ?? null : null
        readonly property var styleValue: toolbar.styleSpec ? BarLayout.opt(chrome.sel, "style") : undefined
        readonly property string styleLabel: {
            if (!toolbar.styleSpec) return ""
            const c = toolbar.styleSpec.choices.find(x => x.value === toolbar.styleValue)
            return c ? c.label : ""
        }
        readonly property var panel: chrome.panelOf(chrome.sel)
        readonly property string tint: chrome.sel !== "" ? BarLayout.itemStyle(chrome.sel, "tint", "none") : "none"
        readonly property bool placed: chrome.sel !== "" && BarLayout.isPlaced(chrome.sel)
        readonly property bool shown: chrome.editing && toolbar.entry !== null && chrome.selFound && !chrome.dragging
                                      && !chrome.stage && !chrome.drawerShown && !chrome.shelfOpen
        readonly property bool side: chrome.selEdge === "left" || chrome.selEdge === "right"
        readonly property bool below: chrome.selEdge !== "bottom"

        property real showT: toolbar.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: toolbar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toolbar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: toolbar.showT > 0.01
        opacity: Math.min(1, toolbar.showT * 1.5)
        transform: Scale {
            origin.x: chrome.selEdge === "left" ? -44
                : chrome.selEdge === "right" ? toolbar.width + 44
                : chrome.selRect.x + chrome.selRect.width / 2 - toolbar.x
            origin.y: toolbar.side ? toolbar.height / 2 : toolbar.below ? -44 : toolbar.height + 44
            xScale: 0.2 + 0.8 * toolbar.showT
            yScale: 0.3 + 0.7 * toolbar.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12,
            chrome.selEdge === "left" ? chrome.selRect.x + chrome.selRect.width + 44
            : chrome.selEdge === "right" ? chrome.selRect.x - width - 44
            : chrome.selRect.x + chrome.selRect.width / 2 - width / 2))
        y: toolbar.side ? Math.max(12, Math.min(capsule.y - height - 12, chrome.selRect.y + chrome.selRect.height / 2 - height / 2))
            : toolbar.below ? chrome.selRect.y + chrome.selRect.height + 44
            : Math.min(chrome.selRect.y - height - 44, capsule.y - height - 12)
        height: 52
        width: toolRow.implicitWidth + 12
        radius: 26

        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 2

            Rectangle {
                id: nameBtn
                implicitHeight: 40
                implicitWidth: nameRow.implicitWidth + 22
                radius: 20
                color: chrome.pop === "style" ? Colors.secondaryContainer
                    : nameArea.containsMouse && toolbar.styleSpec ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: nameRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        color: Colors.primaryContainer
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: toolbar.entry ? toolbar.entry.icon : "widgets"
                            iconSize: 15
                            customColor: Colors.primaryContainerText
                        }
                    }

                    CustomText {
                        content: !toolbar.entry ? ""
                            : toolbar.styleLabel !== "" ? toolbar.styleLabel + " · " + toolbar.entry.label
                            : toolbar.entry.label
                        size: 13
                        weight: 600
                    }

                    MaterialIconSymbol {
                        visible: toolbar.styleSpec !== null
                        content: chrome.pop === "style" ? "expand_less" : "expand_more"
                        iconSize: 18
                        customColor: Colors.surfaceVariantText
                    }
                }

                MouseArea {
                    id: nameArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: toolbar.styleSpec !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chrome.pop = chrome.pop === "style" ? "" : "style"
                }
            }

            Row {
                Layout.leftMargin: 10
                Layout.rightMargin: 8
                spacing: 7
                visible: toolbar.placed

                Repeater {
                    model: chrome.tints

                    Rectangle {
                        id: dot
                        required property var modelData
                        readonly property bool on: toolbar.tint === dot.modelData.value
                        width: 22
                        height: 22
                        radius: 11
                        color: dot.modelData.value === "none" ? "transparent" : BarLayout.roleColor(dot.modelData.value)
                        border.width: dot.modelData.value === "none" ? 2 : 0
                        border.color: Colors.outline

                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: 15
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.primary
                            visible: dot.on
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarLayout.setItemStyle(chrome.sel, "tint", dot.modelData.value)
                        }
                    }
                }
            }

            Divider { Layout.leftMargin: 4; Layout.rightMargin: 4 }

            Pill {
                visible: toolbar.labelSpec !== null && toolbar.placed
                icon: "text_fields"
                lit: toolbar.labelSpec !== null && BarLayout.opt(chrome.sel, "showLabel") === true
                onClicked: BarLayout.setOption(chrome.sel, "showLabel", !(BarLayout.opt(chrome.sel, "showLabel") === true))
            }
            Pill {
                visible: toolbar.panel !== null
                icon: "open_in_full"
                label: toolbar.panel ? toolbar.panel.label : ""
                lit: true
                onClicked: chrome.openStage(chrome.sel)
            }
            Pill {
                id: toolTune
                icon: "tune"
                onClicked: {
                    if (!chrome.editor)
                        return
                    chrome.editor.drawerFrom = toolTune.mapToItem(chrome, 0, 0, toolTune.width, toolTune.height)
                    chrome.editor.drawerMode = "options"
                }
            }
            Pill {
                visible: toolbar.placed
                icon: "delete"
                danger: true
                onClicked: {
                    const id = chrome.sel
                    chrome.editor.selectedItem = ""
                    Qt.callLater(() => BarLayout.hideItem(id))
                }
            }
        }
    }

    Card {
        id: blockBar
        readonly property string shape: chrome.selBlock !== "" ? BarLayout.blockShape(chrome.selBlock) : ""
        readonly property var blockInfo: chrome.selBlock !== "" ? BarLayout.blockById(chrome.selBlock) : null
        readonly property string panels: blockBar.blockInfo ? BarLayout.blockPanels(chrome.selBlock, blockBar.blockInfo.edge) : ""
        readonly property bool shown: chrome.editing && chrome.selBlock !== "" && chrome.blockFound && !chrome.dragging
                                      && !chrome.stage && !chrome.drawerShown && !chrome.shelfOpen
        readonly property bool side: chrome.blockEdge === "left" || chrome.blockEdge === "right"
        readonly property bool below: chrome.blockEdge !== "bottom"

        property real showT: blockBar.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: blockBar.shown ? 340 : 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: blockBar.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: blockBar.showT > 0.01
        opacity: Math.min(1, blockBar.showT * 1.5)
        transform: Scale {
            origin.x: chrome.blockRect.x + chrome.blockRect.width / 2 - blockBar.x
            origin.y: blockBar.side ? blockBar.height / 2 : blockBar.below ? -44 : blockBar.height + 44
            xScale: 0.2 + 0.8 * blockBar.showT
            yScale: 0.3 + 0.7 * blockBar.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12,
            chrome.blockEdge === "left" ? chrome.blockRect.x + chrome.blockRect.width + 44
            : chrome.blockEdge === "right" ? chrome.blockRect.x - width - 44
            : chrome.blockRect.x + chrome.blockRect.width / 2 - width / 2))
        y: blockBar.side ? Math.max(12, Math.min(capsule.y - height - 12, chrome.blockRect.y + chrome.blockRect.height / 2 - height / 2))
            : blockBar.below ? chrome.blockRect.y + chrome.blockRect.height + 48
            : Math.min(chrome.blockRect.y - height - 48, capsule.y - height - 12)
        height: 52
        width: blockRow.implicitWidth + 12
        radius: 26

        RowLayout {
            id: blockRow
            anchors.centerIn: parent
            spacing: 2

            CustomText {
                Layout.leftMargin: 12
                Layout.rightMargin: 6
                content: chrome.selBlock !== "" ? BarLayout.blockLabel(chrome.selBlock) : ""
                size: 13
                weight: 600
            }

            Repeater {
                model: chrome.shapeChoices

                Pill {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    lit: blockBar.shape === modelData.value
                    onClicked: BarLayout.setBlockShape(chrome.selBlock, modelData.value)
                }
            }

            Divider {
                visible: blockBar.shape === "pill"
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            Pill {
                visible: blockBar.shape === "pill"
                icon: "vertical_align_top"
                label: "Attached"
                lit: blockBar.panels === "attached"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", "attached")
            }

            Pill {
                visible: blockBar.shape === "pill"
                icon: "bubble_chart"
                label: "Floating"
                lit: blockBar.panels === "floating"
                onClicked: BarLayout.setBlockStyle(chrome.selBlock, "panels", "floating")
            }
        }
    }

    Card {
        id: styleCard
        readonly property bool shown: chrome.pop === "style" && toolbar.shown && toolbar.styleSpec !== null
        property real showT: styleCard.shown ? 1 : 0
        Behavior on showT {
            NumberAnimation {
                duration: styleCard.shown ? 300 : 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: styleCard.shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        visible: styleCard.showT > 0.01
        opacity: Math.min(1, styleCard.showT * 1.5)
        transform: Scale {
            origin.x: toolbar.x + 6 + nameBtn.width / 2 - styleCard.x
            origin.y: toolbar.below ? -8 : styleCard.height + 8
            xScale: 0.5 + 0.5 * styleCard.showT
            yScale: 0.15 + 0.85 * styleCard.showT
        }
        x: Math.max(12, Math.min(chrome.width - width - 12, toolbar.x))
        y: toolbar.below ? toolbar.y + toolbar.height + 8 : toolbar.y - height - 8
        width: 380
        height: styleFlow.implicitHeight + 28
        radius: 22

        Flow {
            id: styleFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 6

            Repeater {
                model: toolbar.styleSpec ? toolbar.styleSpec.choices : []

                ChoiceChip {
                    required property var modelData
                    label: modelData.label
                    icon: modelData.icon ?? ""
                    lit: toolbar.styleValue === modelData.value
                    onClicked: BarLayout.setOption(chrome.sel, "style", modelData.value)
                }
            }
        }
    }

    readonly property string dashId: chrome.sel.indexOf("dash:") === 0 ? chrome.sel.slice(5) : ""
    property rect dashCellRect: Qt.rect(0, 0, 0, 0)
    property rect dashPanelRect: Qt.rect(0, 0, 0, 0)
    property bool dashCellFound: false

    function locateDash() {
        const d = DashLayout.activeDash
        if (!d) {
            chrome.dashCellFound = false
            chrome.dashPanelRect = Qt.rect(0, 0, 0, 0)
            return
        }
        chrome.dashPanelRect = d.mapToItem(chrome, 0, 0, d.width, d.height)
        const c = chrome.dashId !== "" ? d.cellItem(chrome.dashId) : null
        chrome.dashCellFound = c !== null
        if (c)
            chrome.dashCellRect = c.mapToItem(chrome, 0, 0, c.width, c.height)
    }

    Timer {
        interval: 50
        repeat: true
        running: chrome.editing && DashLayout.activeDash !== null
        triggeredOnStart: true
        onTriggered: chrome.locateDash()
    }

    readonly property bool dashLow: chrome.dashPanelRect.height > 0
        && chrome.dashPanelRect.y + chrome.dashPanelRect.height / 2 > chrome.height / 2

    Card {
        id: dashBar
        readonly property var entry: chrome.dashId !== "" ? DashLayout.entry(chrome.dashId) : null
        readonly property var spec: DashLayout.items.find(i => i.id === chrome.dashId) ?? null
        readonly property bool legacy: dashBar.entry ? dashBar.entry.legacy === true : false
        readonly property var picks: chrome.dashId !== "" ? DashLayout.lookPicks(chrome.dashId) : []
        readonly property bool framed: !dashBar.legacy && DashLayout.opt(chrome.dashId, "background") !== false
        readonly property bool busy: DashLayout.activeDash !== null && DashLayout.activeDash.dragId !== ""
        readonly property bool shown: chrome.editing && dashBar.entry !== null && chrome.dashCellFound && !dashBar.busy
            && !(chrome.editor && chrome.editor.drawerMode === "inspector") && !chrome.shelfOpen
        readonly property bool below: chrome.dashCellRect.y - height - 14 < 12

        visible: dashBar.shown
        x: Math.max(12, Math.min(chrome.width - width - 12, chrome.dashCellRect.x - 6))
        y: dashBar.below ? chrome.dashCellRect.y + chrome.dashCellRect.height + 14 : chrome.dashCellRect.y - height - 14
        height: 52
        width: dashRow.implicitWidth + 12
        radius: 26
        z: 5

        RowLayout {
            id: dashRow
            anchors.centerIn: parent
            spacing: 2

            RowLayout {
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 8

                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: Colors.primaryContainer
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: dashBar.entry ? dashBar.entry.icon : "widgets"
                        iconSize: 15
                        customColor: Colors.primaryContainerText
                    }
                }

                CustomText {
                    content: dashBar.entry ? dashBar.entry.label : ""
                    size: 13
                    weight: 600
                }

                CustomText {
                    content: dashBar.spec ? dashBar.spec.w + "×" + dashBar.spec.h : ""
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }

            Divider { Layout.leftMargin: 4; Layout.rightMargin: 4 }

            Pill {
                visible: dashBar.picks.length > 0
                icon: "palette"
                lit: chrome.pop === "dashlook"
                onClicked: chrome.pop = chrome.pop === "dashlook" ? "" : "dashlook"
            }
            Pill {
                visible: !dashBar.legacy
                icon: dashBar.framed ? "crop_square" : "crop_free"
                lit: dashBar.framed
                onClicked: DashLayout.setOption(chrome.dashId, "background", !dashBar.framed)
            }
            Pill {
                visible: !dashBar.legacy
                icon: "content_copy"
                onClicked: {
                    const nid = DashLayout.duplicateItem(chrome.dashId)
                    if (nid !== "" && chrome.editor)
                        chrome.editor.selectedItem = "dash:" + nid
                }
            }
            Pill {
                icon: "tune"
                onClicked: {
                    chrome.pop = ""
                    if (chrome.editor) chrome.editor.drawerMode = "inspector"
                }
            }

            Divider { Layout.leftMargin: 4; Layout.rightMargin: 4 }

            Pill {
                icon: "delete"
                danger: true
                onClicked: {
                    const id = chrome.dashId
                    const d = DashLayout.activeDash
                    chrome.pop = ""
                    Qt.callLater(() => { if (d) d.removeItem(id); else DashLayout.dropItem(id) })
                }
            }
        }
    }

    Card {
        id: dashLook
        readonly property real thumbW: 104
        readonly property real thumbH: 74
        visible: chrome.pop === "dashlook" && dashBar.visible && dashBar.picks.length > 0
        x: Math.max(12, Math.min(chrome.width - width - 12, dashBar.x))
        y: dashBar.below ? dashBar.y + dashBar.height + 8 : dashBar.y - height - 8
        width: Math.max(300, lookCol.implicitWidth + 28)
        height: lookCol.implicitHeight + 28
        radius: 24
        z: 6

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: lookCol
            x: 14
            y: 14
            spacing: 14

            Repeater {
                model: dashLook.visible ? dashBar.picks : []

                delegate: ColumnLayout {
                    id: pick
                    required property var modelData
                    readonly property var value: DashLayout.opt(chrome.dashId, pick.modelData.key)
                    readonly property bool visual: pick.modelData.key !== "color" && pick.modelData.choices.length <= 4
                    spacing: 8

                    CustomText {
                        content: pick.modelData.label
                        size: 13
                        weight: 600
                    }

                    Row {
                        visible: pick.visual
                        spacing: 8

                        Repeater {
                            model: pick.visual ? pick.modelData.choices : []

                            delegate: Rectangle {
                                id: face
                                required property var modelData
                                readonly property bool on: pick.value === face.modelData.value
                                width: dashLook.thumbW
                                height: dashLook.thumbH + 26
                                radius: 16
                                color: face.on ? Colors.secondaryContainer
                                    : faceArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                                border.width: face.on ? 2 : 0
                                border.color: Colors.primary
                                Behavior on color { EffectsColorAnim { speed: "fast" } }

                                DashThumb {
                                    x: 6
                                    y: 6
                                    width: parent.width - 12
                                    height: dashLook.thumbH - 6
                                    instanceId: chrome.dashId
                                    overrides: {
                                        const o = {}
                                        o[pick.modelData.key] = face.modelData.value
                                        return o
                                    }
                                    srcW: chrome.dashCellRect.width
                                    srcH: chrome.dashCellRect.height
                                }

                                CustomText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    content: face.modelData.label
                                    size: 12
                                    weight: face.on ? 700 : 500
                                    customColor: face.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                }

                                MouseArea {
                                    id: faceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DashLayout.setOption(chrome.dashId, pick.modelData.key, face.modelData.value)
                                }
                            }
                        }
                    }

                    EditOptionRow {
                        visible: !pick.visual
                        Layout.preferredWidth: 300
                        instanceId: chrome.dashId
                        spec: pick.modelData
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 18
                color: moreArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIconSymbol { content: "tune"; iconSize: 16; customColor: Colors.primary }
                    CustomText { content: "All options"; size: 13; weight: 600; customColor: Colors.primary }
                }

                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        chrome.pop = ""
                        if (chrome.editor) chrome.editor.drawerMode = "inspector"
                    }
                }
            }
        }
    }

    Card {
        id: stageCard
        readonly property var panel: chrome.panelOf(chrome.sel)
        readonly property string kind: stageCard.panel ? stageCard.panel.kind : ""
        readonly property var spec: stageCard.kind !== "" ? BarLayout.panelSpecs[stageCard.kind] ?? null : null
        readonly property var styleOpt: {
            const map = { launcher: ["launcher", "style"], wallpaper: ["wallpaper", "style"], clipboard: ["clipboard", "style"] }
            const m = map[stageCard.kind]
            if (!m) return null
            const s = BarLayout.specFor(m[0], m[1])
            return s && s.choices ? { item: m[0], key: m[1], spec: s } : null
        }
        readonly property string opener: {
            switch (stageCard.kind) {
            case "wallpaper": return "Bottom centre of the screen, or its keyboard shortcut"
            case "clipboard": return "Bottom centre of the screen, or its keyboard shortcut"
            case "launcher": return ServiceLauncher.position === "item" ? "From the Apps item" : ServiceLauncher.position === "center" ? "Centre of the screen" : "Left edge of the screen"
            case "dashboard": {
                const host = BarLayout.baseId(BarLayout.panelHostItem("dashboard"))
                return "From " + (host === "notifications" ? "Notifications" : host === "logo" ? "the Logo" : "Dashboard")
            }
            case "calendar": return "From the Clock"
            case "weather": return "From Weather"
            }
            return ""
        }
        readonly property bool hostMissing: stageCard.kind !== "" && stageCard.kind !== "wallpaper" && stageCard.kind !== "launcher" && stageCard.kind !== "clipboard"
            && !BarLayout.isPlaced(BarLayout.panelHostItem(stageCard.kind))

        visible: chrome.editing && chrome.stage && !chrome.drawerShown && stageCard.kind !== "dashboard"
        x: chrome.previewRight ? 24 : chrome.width - width - 24
        y: BarLayout.barSide === "top" ? (chrome.topSurface ? chrome.topSurface.rowItem.y : 0) + Appearance.size.barHeight + 40
            : ServiceGaps.topFinal + 24
        width: 400
        height: stageBody.implicitHeight + 36
        radius: 28

        ColumnLayout {
            id: stageBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText {
                        content: stageCard.panel ? stageCard.panel.label + " panel" : "Panels"
                        size: 18
                        weight: 600
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: stageCard.hostMissing ? "Its bar item isn't placed, so there's nothing to preview"
                            : stageCard.spec ? "Open live · drag its edges to resize" : "Open live"
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }

                Pill {
                    icon: "close"
                    box: 38
                    onClicked: chrome.editor.panelStage = false
                }
            }

            EditChoice {
                Layout.fillWidth: true
                maxPerRow: 3
                choices: chrome.panelList.map(p => ({ value: p.item, label: p.label, icon: p.icon }))
                isActive: function(v) { return stageCard.panel !== null && stageCard.panel.item === v }
                onPicked: v => chrome.openStage(v)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.outlineVariant
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: stageCard.styleOpt !== null

                SectionLabel { content: "Style" }

                EditChoice {
                    Layout.fillWidth: true
                    choices: stageCard.styleOpt ? stageCard.styleOpt.spec.choices : []
                    value: stageCard.styleOpt ? BarLayout.opt(stageCard.styleOpt.item, stageCard.styleOpt.key) : undefined
                    onPicked: v => BarLayout.setOption(stageCard.styleOpt.item, stageCard.styleOpt.key, v)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: stageCard.spec !== null

                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { content: "Size"; Layout.fillWidth: true }
                    CustomText {
                        content: stageCard.spec
                            ? BarLayout.panelW(stageCard.kind) + " × " + (BarLayout.panelH(stageCard.kind) < 0 ? "auto" : BarLayout.panelH(stageCard.kind))
                            : ""
                        size: 12
                        weight: 700
                        customColor: Colors.primary
                    }
                }

                EditChoice {
                    Layout.fillWidth: true
                    choices: BarLayout.panelPresets(stageCard.kind)
                    isActive: function(v) { return BarLayout.presetActive(stageCard.kind, v) }
                    onPicked: v => BarLayout.applyPreset(stageCard.kind, v)
                }

                PanelSizeSliders {
                    Layout.fillWidth: true
                    kind: stageCard.kind
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: openCol.implicitHeight + 28
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        id: openCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 1
                        CustomText { content: "Opens from"; size: 13; weight: 500 }
                        CustomText {
                            Layout.fillWidth: true
                            content: stageCard.opener
                            size: 11
                            weight: 400
                            customColor: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }

                Pill {
                    id: stageMore
                    icon: "tune"
                    label: "More"
                    onClicked: {
                        chrome.editor.drawerFrom = stageMore.mapToItem(chrome, 0, 0, stageMore.width, stageMore.height)
                        chrome.editor.drawerMode = "options"
                    }
                }
            }
        }
    }

    Card {
        id: shelf
        readonly property bool wanted: chrome.shelfOpen && chrome.editing
        property real openT: shelf.wanted ? 1 : 0
        Behavior on openT {
            NumberAnimation {
                duration: shelf.wanted ? 520 : 400
                easing.type: Easing.BezierSpline
                easing.bezierCurve: shelf.wanted ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
            }
        }
        readonly property real fullW: Math.min(1180, chrome.width - 64)
        readonly property real fullX: (chrome.width - shelf.fullW) / 2
        readonly property real fullY: chrome.height - 360 - 24
        readonly property real inT: Math.max(0, Math.min(1, (shelf.openT - 0.6) / 0.4))
        property real cardsT: 1

        onWantedChanged: {
            if (!shelf.wanted)
                return
            shelf.cardsT = 0
            cascade.restart()
        }

        SequentialAnimation {
            id: cascade
            PauseAnimation { duration: 380 }
            NumberAnimation { target: shelf; property: "cardsT"; from: 0; to: 1; duration: 640 }
        }

        visible: shelf.openT > 0.01
        opacity: Math.min(1, shelf.openT * 4)
        clip: true
        x: capsule.restX + (shelf.fullX - capsule.restX) * shelf.openT
        y: capsule.restYAnim + (shelf.fullY - capsule.restYAnim) * shelf.openT
        width: capsule.fullW + (shelf.fullW - capsule.fullW) * shelf.openT
        height: 56 + 304 * shelf.openT
        radius: 28 + 2 * shelf.openT
        border.width: shelf.dropping ? 2 : 1
        border.color: shelf.dropping ? Colors.error : Qt.alpha(Colors.outline, 0.18)

        readonly property bool dropping: chrome.editor !== null && chrome.editor.mode === "item"
                                         && chrome.editor.fromBlock !== "" && chrome.editor.overDrawer

        property string group: "All"
        property string filter: ""
        readonly property string needle: shelf.filter.trim().toLowerCase()
        readonly property var parts: BarLayout.hiddenItems.filter(id => {
            const e = BarLayout.entry(id)
            if (!e) return false
            if (shelf.needle !== "")
                return e.label.toLowerCase().indexOf(shelf.needle) >= 0 || (e.group ?? "").toLowerCase().indexOf(shelf.needle) >= 0
            return shelf.group === "All" || e.group === shelf.group
        })

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            x: 20
            y: 16
            width: shelf.fullW - 40
            height: 324
            spacing: 14
            opacity: (shelf.dropping ? 0.25 : 1) * shelf.inT

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                CustomText {
                    content: "Parts"
                    size: 22
                    weight: 600
                    family: "Noto Serif Display"
                    renderType: Text.QtRendering
                }

                CustomText {
                    Layout.fillWidth: true
                    content: "drag one onto the bar or dock · click + to drop it next to your selection"
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }

                Rectangle {
                    Layout.preferredWidth: 260
                    implicitHeight: 40
                    radius: 20
                    color: Colors.surfaceContainerHigh
                    border.width: 1
                    border.color: partSearch.activeFocus ? Qt.alpha(Colors.primary, 0.7) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialIconSymbol {
                            content: "search"
                            iconSize: 16
                            customColor: Colors.outline
                        }

                        TextInput {
                            id: partSearch
                            Layout.fillWidth: true
                            clip: true
                            text: shelf.filter
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            font.pixelSize: 13
                            color: Colors.surfaceText
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: shelf.filter = partSearch.text
                            Keys.onEscapePressed: {
                                if (partSearch.text !== "") partSearch.text = ""
                                else chrome.shelfOpen = false
                            }

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: partSearch.text === "" && !partSearch.activeFocus
                                content: "Search parts"
                                size: 13
                                customColor: Colors.outline
                            }
                        }
                    }
                }

                Pill {
                    icon: "close"
                    onClicked: chrome.shelfOpen = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 160
                    Layout.maximumWidth: 160
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignTop
                    spacing: 2

                    Repeater {
                        model: ["All"].concat(BarLayout.groups)

                        Rectangle {
                            id: grp
                            required property string modelData
                            readonly property bool on: shelf.needle === "" && shelf.group === grp.modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 19
                            color: grp.on ? Colors.secondaryContainer
                                : grpArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : "transparent"

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                content: grp.modelData
                                size: 13
                                weight: grp.on ? 700 : 500
                                customColor: grp.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                            }

                            MouseArea {
                                id: grpArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    partSearch.text = ""
                                    shelf.group = grp.modelData
                                }
                            }
                        }
                    }
                }

                Flickable {
                    id: partFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: partGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: CustomScrollBar {}

                    GridLayout {
                        id: partGrid
                        width: partFlick.width
                        columns: Math.max(2, Math.floor(partFlick.width / 230))
                        columnSpacing: 12
                        rowSpacing: 12

                        Repeater {
                            model: shelf.visible ? shelf.parts : []

                            Rectangle {
                                id: part
                                required property string modelData
                                required property int index
                                readonly property real delay: Math.floor(part.index / Math.max(1, partGrid.columns)) * 70
                                    + (part.index % Math.max(1, partGrid.columns)) * 30
                                readonly property real landT: {
                                    const t = Math.max(0, Math.min(1, (shelf.cardsT * 640 - part.delay) / 260))
                                    return 1 - Math.pow(1 - t, 3)
                                }
                                transform: Translate { y: 12 * (1 - part.landT) }
                                readonly property var entry: BarLayout.entry(part.modelData)
                                readonly property bool multi: !!part.entry && !!part.entry.multi
                                readonly property bool dockOnly: !!part.entry && !BarLayout.allows(part.modelData, "bar")

                                Layout.fillWidth: true
                                Layout.preferredHeight: 126
                                radius: 20
                                color: partArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                                opacity: (chrome.editor && chrome.editor.mode === "item" && chrome.editor.itemId === part.modelData ? 0.35 : 1) * part.landT

                                Item {
                                    id: partStub
                                    visible: false
                                    readonly property bool editing: false
                                    readonly property real maxWidth: 220
                                    readonly property real fixedWidth: 0
                                    readonly property real iconSize: 18
                                    function hoverOpen(kind, item) {}
                                    function openPanel(kind, item) {}
                                    function closePanel() {}
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Rectangle {
                                        id: partPreview
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 58
                                        radius: 14
                                        color: Colors.surface
                                        clip: true

                                        Loader {
                                            id: partLoader
                                            anchors.centerIn: parent
                                            enabled: false
                                            asynchronous: true
                                            active: !part.multi
                                            source: active ? BarLayout.urlFor(part.modelData) : ""
                                            scale: item && item.implicitWidth > partPreview.width - 16
                                                ? (partPreview.width - 16) / item.implicitWidth : 1
                                            onLoaded: {
                                                item.host = partStub
                                                if ("itemId" in item)
                                                    item.itemId = part.modelData
                                            }
                                        }

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            visible: part.multi || partLoader.status !== Loader.Ready
                                                     || (partLoader.item && partLoader.item.implicitWidth < 2)
                                            content: part.entry ? part.entry.icon : "widgets"
                                            iconSize: 24
                                            customColor: Colors.primary
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            CustomText {
                                                Layout.fillWidth: true
                                                content: part.entry ? part.entry.label : part.modelData
                                                size: 13
                                                weight: 600
                                            }
                                            CustomText {
                                                Layout.fillWidth: true
                                                content: (part.entry ? part.entry.group : "") + (part.dockOnly ? " · dock" : part.multi ? " · add many" : "")
                                                size: 11
                                                weight: 400
                                                customColor: Colors.surfaceVariantText
                                            }
                                        }

                                        Pill {
                                            icon: "add"
                                            box: 32
                                            lit: true
                                            onClicked: chrome.addItem(part.modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: partArea
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: chrome.editor && chrome.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                    property real sx: 0
                                    property real sy: 0

                                    onPressed: mouse => {
                                        partArea.sx = mouse.x
                                        partArea.sy = mouse.y
                                    }
                                    onPositionChanged: mouse => {
                                        if (!partArea.pressed)
                                            return
                                        const e = chrome.editor
                                        if (e.mode === "" && Math.hypot(mouse.x - partArea.sx, mouse.y - partArea.sy) > 4)
                                            e.beginItem(part.modelData, "", -1, 32)
                                        if (e.mode !== "") {
                                            const p = partArea.mapToItem(null, mouse.x, mouse.y)
                                            e.update(p.x, p.y)
                                        }
                                    }
                                    onReleased: if (chrome.editor.mode !== "") chrome.editor.finish()
                                    onCanceled: chrome.editor.cancel()
                                }
                            }
                        }
                    }

                    CustomText {
                        anchors.centerIn: parent
                        visible: shelf.parts.length === 0
                        content: shelf.needle !== "" ? "Nothing matches that" : "Everything here is already on your bar"
                        size: 13
                        customColor: Colors.outline
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: shelf.dropping
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 56
                implicitHeight: 56
                radius: 28
                color: Colors.errorContainer
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "delete"
                    iconSize: 26
                    customColor: Colors.errorContainerText
                }
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "Release to remove " + (chrome.editor ? chrome.editor.label : "")
                size: 15
                weight: 600
            }
        }
    }
}
