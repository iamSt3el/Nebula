import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit

Item {
    id: drawer

    property QtObject editor: null
    property Item chrome: null
    property bool alive: false
    property bool fineOpen: false
    property string sidePage: ""
    property var sideSpec: null
    property real sideY: 0
    property bool closing: false
    property bool pendingClose: false
    onAliveChanged: if (!drawer.alive) drawer.sidePage = ""
    onSelectedChanged: if (drawer.selected !== "") drawer.sidePage = ""
    readonly property var selEntry: BarLayout.entry(drawer.selected)
    readonly property var selMargin: BarLayout.marginsFor(drawer.selected)
    readonly property string lookSummary: {
        const t = drawer.itemTint
        const tint = t === "none" ? "No tint" : (t === "surfaceText" ? "Neutral" : t.charAt(0).toUpperCase() + t.slice(1)) + " tint"
        const size = drawer.iconSizable ? (drawer.itemIconSize > 0 ? Math.round(drawer.itemIconSize) + " px" : "auto size") : ""
        return size !== "" ? tint + " · " + size : tint
    }

    function openSide(page, item, spec) {
        const same = drawer.sidePage === page && (page !== "opt" || (drawer.sideSpec && spec && drawer.sideSpec.key === spec.key))
        if (same) {
            drawer.sidePage = ""
            return
        }
        drawer.sideSpec = spec
        drawer.sideY = item ? item.mapToItem(drawer, 0, 0).y : 0
        drawer.sidePage = page
    }

    function shapeName(name) {
        if (name === "" || name === "none")
            return "None"
        const words = name.replace(/([A-Z0-9]+)/g, " $1").trim().toLowerCase()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    property real maxHeight: 600
    property string tab: "add"
    property string edgeSide: "top"
    readonly property var edgeCfg: BarLayout.edge(drawer.edgeSide)
    readonly property var edgeBlocks: BarLayout.allBlocks.filter(b => b.edge === drawer.edgeSide)
    readonly property string edgePanels: {
        const own = BarLayout.edgePanels(drawer.edgeSide)
        if (own !== "")
            return own
        const styles = drawer.edgeBlocks.filter(b => BarLayout.ownPanels(b.id) === "")
            .map(b => BarLayout.panelStyleFor(b.id, drawer.edgeSide, BarLayout.blockShape(b.id, drawer.edgeSide)))
        return styles.length > 0 && styles.every(v => v === styles[0]) ? styles[0] : ""
    }
    readonly property int panelOverrides: BarLayout.edgeOverrides(drawer.edgeSide, "panels").length
    readonly property int gapOverrides: BarLayout.edgeOverrides(drawer.edgeSide, "panelGap").length

    Connections {
        target: drawer.editor
        ignoreUnknownSignals: true
        function onSelectedBlockChanged() {
            const b = drawer.editor && drawer.editor.selectedBlock !== "" ? BarLayout.blockById(drawer.editor.selectedBlock) : null
            if (b && b.edge)
                drawer.edgeSide = b.edge
        }
    }

    readonly property bool dragOut: !!drawer.editor && drawer.editor.mode !== ""
        && (drawer.editor.fromBlock !== "" || (drawer.editor.mode === "app" && drawer.editor.appPinned))
    readonly property bool hiding: drawer.dragOut && drawer.editor.overDrawer
    property string selected: ""
    readonly property string liveSelected: drawer.editor ? drawer.editor.selectedItem : ""
    onLiveSelectedChanged: Qt.callLater(drawer.applySelected)
    function applySelected() {
        if (!drawer.closing)
            drawer.selected = drawer.liveSelected
    }
    readonly property bool itemPage: drawer.selected !== ""
    readonly property bool dashPage: false
    readonly property bool loose: drawer.itemPage && !BarLayout.isPlaced(drawer.selected)
    readonly property bool anchorPage: drawer.itemPage && !drawer.dashPage && BarLayout.isAnchorItem(drawer.selected)
    readonly property bool osdPage: drawer.anchorPage && BarLayout.baseId(drawer.selected) === "osd"
    readonly property bool chromeless: drawer.dashPage || drawer.loose || drawer.anchorPage
    readonly property string itemTint: drawer.dashPage ? "none"
        : BarLayout.itemStyle(drawer.selected, "tint", "none")
    readonly property string itemShape: drawer.dashPage ? "none"
        : BarLayout.chipShape(drawer.selected)
    property real previewW: 0
    property real previewH: 0
    property bool previewSizable: false
    readonly property bool iconSizable: !drawer.chromeless && drawer.previewSizable
    readonly property real itemIconSize: drawer.dashPage ? 0
        : BarLayout.itemStyle(drawer.selected, "iconSize", 0)
    readonly property bool iconItem: !drawer.dashPage
        && BarLayout.iconOnly(drawer.previewW, drawer.previewH)
    readonly property bool shapedChip: drawer.iconItem && drawer.itemShape !== "none"
    readonly property bool splitItem: !drawer.dashPage && drawer.selected !== "" && BarLayout.inSplit(drawer.selected)
    readonly property bool chipStyled: drawer.itemTint !== "none" || drawer.splitItem
    readonly property bool ownShape: {
        const s = drawer.selected !== "" ? BarLayout.specFor(drawer.selected, "shape") : null
        return !!s && s.type === "shape" && (!s.onlyIf || s.onlyIf.values.indexOf(drawer.optValue(s.onlyIf.key)) >= 0)
    }
    readonly property bool rotatable: !drawer.chromeless && drawer.selected !== "" && (drawer.shapedChip
        || (({ cpu: ["shape"], memory: ["shape"], gpu: ["shape"], temperature: ["shape"], battery: ["shape", "fill", "sweep"],
               volume: ["cookie", "fill", "sweep"], brightness: ["cookie", "fill", "sweep"] })[BarLayout.baseId(drawer.selected)] ?? []).indexOf(drawer.optValue("style")) >= 0)
    readonly property color plateFill: {
        const b = drawer.splitItem ? BarLayout.blockOfItem(drawer.selected) : null
        const t = b ? BarLayout.blockStyle(b.id, "tint", "none") : "none"
        return t === "none" ? Colors.surface : Qt.tint(Colors.surface, Qt.alpha(BarLayout.roleColor(t), 0.22))
    }
    readonly property bool groupPage: !drawer.dashPage && drawer.selected !== ""
        && BarLayout.isGroup(drawer.selected)
    readonly property var groupMembers: drawer.groupPage ? BarLayout.groupMembers(drawer.selected) : []
    readonly property var groupCandidates: {
        if (!drawer.groupPage)
            return []
        const out = []
        for (const e of BarLayout.catalog) {
            if (e.id === "group")
                continue
            if (drawer.groupMembers.indexOf(e.id) >= 0)
                continue
            if (!e.multi && BarLayout.hiddenItems.indexOf(e.id) < 0)
                continue
            out.push(e.id)
        }
        return out
    }

    readonly property var tintChoices: [
        { value: "none",        label: "None" },
        { value: "primary",     label: "Primary" },
        { value: "secondary",   label: "Secondary" },
        { value: "tertiary",    label: "Tertiary" },
        { value: "surfaceText", label: "Neutral" }
    ]

    function optValue(key) {
        return BarLayout.opt(drawer.selected, key)
    }

    function setOptValue(key, value) {
        BarLayout.setOption(drawer.selected, key, value)
    }

    function optList(key) {
        const v = drawer.optValue(key)
        return v && typeof v.length === "number" ? Array.prototype.slice.call(v).filter(x => typeof x === "string") : []
    }

    function optListAdd(key, v) {
        const l = drawer.optList(key)
        if (l.indexOf(v) < 0)
            drawer.setOptValue(key, l.concat([v]))
    }

    function optListRemove(key, v) {
        drawer.setOptValue(key, drawer.optList(key).filter(x => x !== v))
    }

    visible: drawer.alive
    readonly property real liveHeight: Math.min(contentLoader.item ? contentLoader.item.contentHeight : 0, drawer.maxHeight)
    onLiveHeightChanged: Qt.callLater(drawer.applyHeight)
    function applyHeight() {
        if (!drawer.closing)
            drawer.height = drawer.liveHeight
    }
    Component.onCompleted: {
        drawer.selected = drawer.liveSelected
        drawer.height = drawer.liveHeight
    }

    function open() {
        if (!morph.opened) {
            const f = drawer.editor ? drawer.editor.drawerFrom : Qt.rect(0, 0, 0, 0)
            morph.instant = true
            if (f.width > 0 && drawer.parent) {
                const p = drawer.parent.mapToItem(drawer, f.x, f.y)
                morph.srcWidth = f.width
                morph.srcHeight = f.height
                morph.srcRadius = f.height / 2
                morph.srcX = p.x
                morph.srcY = p.y
            } else {
                morph.srcWidth = 140
                morph.srcHeight = 32
                morph.srcRadius = 16
                morph.srcX = (drawer.width - 140) / 2
                morph.srcY = 0
            }
            morph.instant = false
            if (drawer.editor)
                drawer.editor.drawerFrom = Qt.rect(0, 0, 0, 0)
        }
        drawer.closing = false
        drawer.pendingClose = false
        drawer.selected = drawer.liveSelected
        drawer.alive = true
        Qt.callLater(morph.open)
    }

    function close() {
        drawer.closing = true
        if (sidePanel.showT > 0.02) {
            drawer.pendingClose = true
            return
        }
        morph.close()
    }

    Connections {
        target: sidePanel
        function onShowTChanged() {
            if (sidePanel.showT > 0.02 || sidePanel.open)
                return
            if (drawer.closing)
                drawer.sidePage = ""
            if (drawer.pendingClose) {
                drawer.pendingClose = false
                morph.close()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    EditSidePanel {
        id: sidePanel
        z: 3
        readonly property real hostW: drawer.parent ? drawer.parent.width : 1920
        readonly property real hostH: drawer.parent ? drawer.parent.height : 1080
        readonly property var spec: drawer.sideSpec
        readonly property var spot: drawer.chrome
            ? drawer.chrome.placeBeside(Qt.rect(drawer.x, drawer.y, drawer.width, drawer.height), sidePanel.width, sidePanel.height,
                                        drawer.y + drawer.sideY - 14, drawer.chrome.openNow)
            : { side: "right", x: drawer.x + drawer.width + 12, y: drawer.y + drawer.sideY - 14 }
        open: drawer.sidePage !== "" && drawer.alive && drawer.itemPage && !drawer.closing
        Binding on fromLeft {
            when: sidePanel.open
            restoreMode: Binding.RestoreNone
            value: sidePanel.spot.side === "left"
        }
        maxHeight: sidePanel.hostH * 0.7
        Binding on x {
            when: sidePanel.open
            restoreMode: Binding.RestoreNone
            value: sidePanel.spot.x - drawer.x
        }
        Binding on y {
            when: sidePanel.open
            restoreMode: Binding.RestoreNone
            value: sidePanel.spot.y - drawer.y
        }
        Behavior on x {
            enabled: sidePanel.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        Behavior on y {
            enabled: sidePanel.showT > 0.99
            SpatialAnim { speed: "move" }
        }
        title: drawer.sidePage === "look" ? "Look"
            : drawer.sidePage === "space" ? "Space around it"
            : drawer.sidePage === "itemshape" ? "Shape"
            : sidePanel.spec ? (sidePanel.spec.label ?? "") : ""
        canReset: drawer.sidePage === "look" ? BarLayout.itemLookChanged(drawer.selected)
            : drawer.sidePage === "space" ? (drawer.selMargin[0] > 0 || drawer.selMargin[1] > 0) : false
        onBack: drawer.sidePage = drawer.sidePage === "itemshape" ? "look" : ""
        onReset: {
            if (drawer.sidePage === "look")
                BarLayout.resetItemLook(drawer.selected)
            else if (drawer.sidePage === "space")
                BarLayout.clearMargins(drawer.selected)
        }

        BarEditDrawerLook {
            host: drawer
        }

        ColumnLayout {
            id: drawerGroup4
            Layout.fillWidth: true
            visible: drawer.sidePage === "space"
            spacing: 8
            readonly property string selEdge: BarLayout.blockOfItem(drawer.selected)?.edge ?? "top"
            readonly property bool upright: drawerGroup4.selEdge === "left" || drawerGroup4.selEdge === "right"
            Repeater {
                model: [{ side: "left", label: drawerGroup4.upright ? "Top" : "Left", i: 0 },
                        { side: "right", label: drawerGroup4.upright ? "Bottom" : "Right", i: 1 }]
                delegate: RowLayout {
                    id: marginRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    CustomText {
                        Layout.preferredWidth: 60
                        content: marginRow.modelData.label
                        size: 12
                    }
                    EditStepper {
                        Layout.fillWidth: true
                        value: drawer.selMargin[marginRow.modelData.i]
                        from: 0
                        to: 40
                        stepSize: 2
                        onPicked: v => BarLayout.setMargin(drawer.selected, marginRow.modelData.side, v)
                    }
                }
            }
            CustomText {
                Layout.fillWidth: true
                content: drawerGroup4.upright ? "Space above and below this part on the bar" : "Space to the left and right of this part on the bar"
                size: 11
                wrapMode: Text.WordWrap
                customColor: Colors.outline
            }
        }

        ShapePicker {
            Layout.fillWidth: true
            visible: drawer.sidePage === "itemshape"
            columns: 5
            centered: true
            autoLabel: "None"
            autoIcon: "crop_square"
            autoHint: "Rounded rectangle"
            pickedHint: ""
            selected: drawer.itemShape === "none" ? "" : drawer.itemShape
            onPicked: name => BarLayout.setItemStyle(drawer.selected, "shape", name === "" ? "none" : name)
        }

        EditPickList {
            visible: drawer.sidePage === "opt" && !!sidePanel.spec && sidePanel.spec.type !== "shape"
            choices: drawer.sidePage === "opt" && sidePanel.spec && sidePanel.spec.type !== "shape" ? (sidePanel.spec.choices ?? []) : []
            value: sidePanel.spec ? drawer.optValue(sidePanel.spec.key) : undefined
            onPicked: v => drawer.setOptValue(sidePanel.spec.key, v)
        }

        ShapePicker {
            Layout.fillWidth: true
            visible: drawer.sidePage === "opt" && !!sidePanel.spec && sidePanel.spec.type === "shape"
            columns: 5
            centered: true
            showAuto: false
            selected: sidePanel.spec && sidePanel.spec.type === "shape" ? String(drawer.optValue(sidePanel.spec.key) ?? "") : ""
            onPicked: name => drawer.setOptValue(sidePanel.spec.key, name)
        }
    }

    MorphCard {
        id: morph
        anchors.fill: parent
        srcWidth: 140
        srcHeight: 32
        srcRadius: 16
        contentHeight: drawer.height
        cardRadius: 24
        cardColor: Colors.surfaceContainer
        cardBorderWidth: drawer.hiding ? 2 : 0
        cardBorderColor: Colors.primary
        onCloseFinished: drawer.alive = false

        Loader {
            id: contentLoader
            active: drawer.alive
            sourceComponent: Component {
                Item {
                    id: body
                    width: drawer.width
                    height: drawer.height

                    readonly property real contentHeight: flick.contentHeight

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        contentWidth: flick.width
                        contentHeight: drawerCol.implicitHeight + 36
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: flick.contentHeight > flick.height

                        ColumnLayout {
                            id: drawerCol
                            x: 18
                            y: 18
                            width: flick.width - 36
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                visible: !drawer.itemPage
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 100000
                                    spacing: 0
                                    CustomText {
                                        content: drawer.tab === "general" ? "All edges"
                                            : drawer.edgeSide.charAt(0).toUpperCase() + drawer.edgeSide.slice(1) + " edge"
                                        size: 18
                                        weight: 600
                                    }
                                    CustomText {
                                        content: drawer.tab === "general" ? "Border, shadow, panels and pinned apps"
                                            : drawer.edgeBlocks.length === 0 ? "Nothing here yet · drag an item onto this edge or add a block"
                                            : drawer.edgeBlocks.length === 1 ? "1 block" : drawer.edgeBlocks.length + " blocks"
                                        size: 12
                                        weight: 400
                                        customColor: Colors.surfaceVariantText
                                    }
                                }
                                M3IconButton {
                                    icon: "close"
                                    tip: "Close · Esc"
                                    onClicked: if (drawer.editor) drawer.editor.drawerMode = ""
                                }
                            }

                            BarEditDrawerItem {
                                host: drawer
                            }

                            BarEditDrawerAdd {
                                host: drawer
                            }

                            BarEditDrawerEdge {
                                host: drawer
                            }

                            BarEditDrawerGeneral {
                                host: drawer
                            }
                        }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 24
                        color: "transparent"

                        ScrollFade {
                            anchors.fill: parent
                            flickable: flick
                            size: 28
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: Colors.surfaceContainer
                        opacity: drawer.dragOut ? 0.94 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            EffectsAnim { speed: "default" }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: drawer.hiding ? 70 : 64
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: Layout.preferredWidth / 2
                                color: drawer.hiding ? Colors.primary : Colors.surfaceContainerHighest
                                Behavior on Layout.preferredWidth {
                                    SpatialAnim { speed: "fast" }
                                }
                                Behavior on color {
                                    EffectsColorAnim { speed: "default" }
                                }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: drawer.editor && drawer.editor.mode === "app" ? "keep_off" : "delete"
                                    iconSize: drawer.hiding ? 31 : 28
                                    Behavior on iconSize { SpatialAnim { speed: "fast" } }
                                    customColor: drawer.hiding ? Colors.primaryText : Colors.surfaceText
                                }
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: !drawer.editor ? ""
                                    : (drawer.hiding ? "Release to " : "Drop here to ")
                                      + (drawer.editor.mode === "app" ? "unpin " : "hide ")
                                      + drawer.editor.label
                                size: 14
                                weight: 600
                                customColor: drawer.hiding ? Colors.primary : Colors.surfaceText
                            }
                        }
                    }
                }
            }
        }
    }
}
