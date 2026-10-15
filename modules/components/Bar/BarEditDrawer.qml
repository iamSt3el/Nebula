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

    component Crumb: Rectangle {
        id: crumb
        property string icon: ""
        property string text: ""
        property bool lit: false
        signal clicked
        implicitWidth: crumbRow.implicitWidth + 20
        implicitHeight: 30
        radius: 15
        color: crumb.lit ? Colors.primary
            : crumbArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            id: crumbRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: crumb.icon !== ""
                content: crumb.icon
                iconSize: 15
                customColor: crumb.lit ? Colors.primaryText : Colors.surfaceVariantText
            }
            CustomText {
                content: crumb.text
                size: 12
                weight: crumb.lit ? 700 : 500
                customColor: crumb.lit ? Colors.primaryText : Colors.surfaceText
            }
        }

        MouseArea {
            id: crumbArea
            anchors.fill: parent
            enabled: !crumb.lit
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: crumb.clicked()
        }
    }

    component Chevron: MaterialIconSymbol {
        height: 30
        verticalAlignment: Text.AlignVCenter
        content: "chevron_right"
        iconSize: 16
        customColor: Colors.outline
    }

    property QtObject editor: null
    property bool alive: false
    property real maxHeight: 600
    property string tab: "add"
    property string edgeSide: "top"
    readonly property var edgeCfg: BarLayout.edge(drawer.edgeSide)
    readonly property var edgeBlocks: BarLayout.allBlocks.filter(b => b.edge === drawer.edgeSide)

    Connections {
        target: drawer.editor
        ignoreUnknownSignals: true
        function onSelectedBlockChanged() {
            const b = drawer.editor && drawer.editor.selectedBlock !== "" ? BarLayout.blockById(drawer.editor.selectedBlock) : null
            if (b && b.edge)
                drawer.edgeSide = b.edge
        }
    }

    readonly property var shapeChoices: [
        { value: "stepped", label: "Stepped", icon: "view_agenda" },
        { value: "flat",    label: "Flat",    icon: "remove" },
        { value: "pill",    label: "Pill",    icon: "circle" }
    ]
        ?? (SettingsConfig.general.flatBarMode === false ? "stepped" : "flat")
    readonly property bool dragOut: !!drawer.editor && drawer.editor.mode !== ""
        && (drawer.editor.fromBlock !== "" || (drawer.editor.mode === "app" && drawer.editor.appPinned))
    readonly property bool hiding: drawer.dragOut && drawer.editor.overDrawer
    readonly property string selected: drawer.editor ? drawer.editor.selectedItem : ""
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
        || (({ cpu: ["shape"], memory: ["shape"], gpu: ["shape"], temperature: ["shape"], battery: ["shape", "fill"],
               volume: ["cookie", "fill"], brightness: ["cookie", "fill"] })[BarLayout.baseId(drawer.selected)] ?? []).indexOf(drawer.optValue("style")) >= 0)
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

    component Chip: Rectangle {
        id: bchip
        property var entry: null
        property bool adding: false
        signal activated

        width: bchipRow.implicitWidth + 20
        height: 30
        radius: 15
        color: bchipArea.containsMouse ? Colors.surfaceContainerHighest
                                       : Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.3)

        Row {
            id: bchipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: bchip.adding ? "add" : (bchip.entry ? bchip.entry.icon : "")
                iconSize: 15
                customColor: bchip.adding ? Colors.primary : Colors.surfaceText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: bchip.entry ? bchip.entry.label : ""
                size: 12
                weight: 600
            }
            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: !bchip.adding
                content: "close"
                iconSize: 14
                customColor: bchipArea.containsMouse ? Colors.error : Colors.outline
            }
        }

        MouseArea {
            id: bchipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bchip.activated()
        }
    }

    component ChipArrow: Rectangle {
        id: arrow
        property string glyph: ""
        property bool enabled: true
        signal tapped

        width: 22
        height: 24
        radius: 8
        color: arrowArea.containsMouse && arrow.enabled ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
        opacity: arrow.enabled ? 1 : 0.3
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: arrow.glyph
            iconSize: 16
            customColor: arrowArea.containsMouse && arrow.enabled ? Colors.primaryContainerText
                                                                  : Colors.surfaceText
        }

        MouseArea {
            id: arrowArea
            anchors.fill: parent
            enabled: arrow.enabled
            visible: arrow.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.tapped()
        }
    }

    component MemberChip: Rectangle {
        id: mchip
        property var entry: null
        property bool canLeft: false
        property bool canRight: false
        signal moveLeft
        signal moveRight
        signal removed

        width: mchipRow.implicitWidth + 12
        height: 32
        radius: 16
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.3)

        Row {
            id: mchipRow
            anchors.centerIn: parent
            spacing: 2

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_left"
                enabled: mchip.canLeft
                onTapped: mchip.moveLeft()
            }

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: mchip.entry ? mchip.entry.icon : ""
                iconSize: 15
                customColor: Colors.surfaceText
            }

            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 5
                rightPadding: 3
                content: mchip.entry ? mchip.entry.label : ""
                size: 12
                weight: 600
            }

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_right"
                enabled: mchip.canRight
                onTapped: mchip.moveRight()
            }

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "close"
                onTapped: mchip.removed()
            }
        }
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
    height: Math.min(contentLoader.item ? contentLoader.item.contentHeight : 0, drawer.maxHeight)

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
        drawer.alive = true
        Qt.callLater(morph.open)
    }

    function close() {
        morph.close()
    }

    MouseArea {
        anchors.fill: parent
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
                                content: "Edges"
                                size: 18
                                weight: 600
                            }
                            CustomText {
                                content: "Shape, size and blocks"
                                size: 12
                                weight: 400
                                customColor: Colors.surfaceVariantText
                            }
                        }
                        M3IconButton {
                            icon: "close"
                            onClicked: if (drawer.editor) drawer.editor.drawerMode = ""
                        }
                    }

                    M3ButtonGroup {
                        visible: !drawer.itemPage
                        Layout.preferredWidth: drawerCol.width
                        Layout.preferredHeight: 36
                        fillWidth: true
                        iconSize: 16
                        textSize: 12
                        model: [
                            { value: "edges",   label: "Edges",   icon: "border_outer" },
                            { value: "general", label: "General", icon: "tune" }
                        ]
                        activeCheck: function(v) { return drawer.tab === v || (v === "edges" && drawer.tab !== "general") }
                        onSegmentClicked: function(v) { drawer.tab = v }
                    }

                    ColumnLayout {
                        id: selectedSection
                        Layout.fillWidth: true
                        spacing: 8
                        visible: drawer.itemPage

                        readonly property var entry: BarLayout.entry(drawer.selected)
                        readonly property var margin: BarLayout.marginsFor(drawer.selected)
                        readonly property var options: {
                            const all = selectedSection.entry && selectedSection.entry.options
                                ? selectedSection.entry.options : []
                            return drawer.loose && !drawer.anchorPage ? all.filter(o => o.setting || o.type === "heading") : all
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 100000
                                spacing: 0
                                CustomText {
                                    Layout.fillWidth: true
                                    content: selectedSection.entry ? selectedSection.entry.label : drawer.selected
                                    elide: Text.ElideRight
                                    size: 18
                                    weight: 600
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: drawer.anchorPage && !drawer.loose ? (drawer.osdPage ? "Volume and brightness pop out beside this block"
                                                                                               : "Notifications pop out beside this block")
                                        : drawer.loose ? "Not in your bar · panel settings only"
                                        : selectedSection.entry && selectedSection.entry.group ? selectedSection.entry.group + " item" : "Bar item"
                                    size: 12
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                            M3IconButton {
                                icon: "close"
                                onClicked: if (drawer.editor) drawer.editor.drawerMode = ""
                            }
                        }

                        Flow {
                            id: crumbs
                            readonly property var blk: drawer.itemPage && !drawer.dashPage && !drawer.loose
                                ? (BarLayout.allBlocks.find(b => b.id !== "__sys" && b.items.indexOf(drawer.selected) >= 0) ?? null) : null
                            Layout.fillWidth: true
                            visible: crumbs.blk !== null
                            spacing: 4

                            Crumb {
                                icon: crumbs.blk && (crumbs.blk.edge === "left" || crumbs.blk.edge === "right") ? "dock_to_left" : "dock_to_bottom"
                                text: crumbs.blk ? crumbs.blk.edge.charAt(0).toUpperCase() + crumbs.blk.edge.slice(1) + " edge" : ""
                                onClicked: {
                                    const e = drawer.editor
                                    if (!e || !crumbs.blk) return
                                    drawer.edgeSide = crumbs.blk.edge
                                    drawer.tab = "edges"
                                    e.drawerMode = "settings"
                                    e.selectedItem = ""
                                }
                            }
                            Chevron {}
                            Crumb {
                                icon: "view_column"
                                text: crumbs.blk ? BarLayout.blockLabel(crumbs.blk.id) + " block" : ""
                                onClicked: {
                                    const e = drawer.editor
                                    if (!e || !crumbs.blk) return
                                    const id = crumbs.blk.id
                                    e.drawerMode = ""
                                    e.selectedBlock = id
                                }
                            }
                            Chevron {}
                            Crumb {
                                lit: true
                                text: selectedSection.entry ? selectedSection.entry.label : drawer.selected
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: drawer.selected === "wallpaper"
                            wrapMode: Text.WordWrap
                            content: "The wallpaper panel is open where it normally appears, as a live preview."
                            size: 12
                            customColor: Colors.outline
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: drawer.anchorPage
                            wrapMode: Text.WordWrap
                            content: drawer.loose
                                ? (drawer.osdPage ? "Not placed, so the OSD opens at the centre of the " + BarLayout.sysEdge + " edge. Drag OSD from Add to bar onto a block to move it."
                                                  : "Not placed. Drag Popups from Add to bar onto a block to choose where popups appear.")
                                : "Nothing shows in the bar. Drag the pin to another block to move where it appears."
                            size: 12
                            customColor: Colors.outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: drawer.anchorPage
                            spacing: 8

                            M3Button {
                                Layout.fillWidth: true
                                icon: drawer.osdPage ? "volume_up" : "send"
                                label: drawer.osdPage ? "Show volume" : "Send a test popup"
                                onClicked: drawer.osdPage ? BarLayout.testOsd("volume") : BarLayout.testPopup(false)
                            }
                            M3Button {
                                Layout.fillWidth: true
                                variant: "tonal"
                                icon: drawer.osdPage ? "brightness_6" : "priority_high"
                                label: drawer.osdPage ? "Show brightness" : "Send an urgent one"
                                onClicked: drawer.osdPage ? BarLayout.testOsd("brightness") : BarLayout.testPopup(true)
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: drawer.loose && !drawer.anchorPage
                            wrapMode: Text.WordWrap
                            content: "This item isn't in your bar. Only its panel settings are shown."
                            size: 12
                            customColor: Colors.outline
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: drawer.selected === "launcher"
                            wrapMode: Text.WordWrap
                            content: "The launcher is open as a live preview. Changes show up as you make them."
                            size: 12
                            customColor: Colors.outline
                        }


                        Rectangle {
                            id: previewStrip
                            Layout.fillWidth: true
                            Layout.preferredHeight: Appearance.size.barHeight + 16
                            visible: !drawer.chromeless && drawer.selected !== "dashboard" && previewLoader.status === Loader.Ready
                            radius: 12
                            color: drawer.splitItem ? Colors.surfaceContainerHighest : Colors.surface

                            Item {
                                id: stubHost
                                width: 0
                                height: 0
                                visible: false
                                readonly property bool editing: false
                                readonly property bool split: drawer.splitItem
                                readonly property real barH: Appearance.size.barHeight
                                readonly property color plateFill: drawer.plateFill
                                readonly property real maxWidth: -1
                                readonly property real fixedWidth: 0
                                function hoverOpen(kind, item) {}
                                function openPanel(kind, item) {}
                                function closePanel() {}
                            }

                            BarItemPlate {
                                anchors.centerIn: parent
                                width: Math.max(plateW, previewLoader.width)
                                height: Appearance.size.barHeight
                                itemId: drawer.selected
                                contentWidth: previewLoader.width
                                contentHeight: previewLoader.height
                                barH: Appearance.size.barHeight
                                fill: drawer.plateFill
                                shapeOverride: previewLoader.item ? (previewLoader.item.plateShape ?? "") : ""
                                shown: drawer.splitItem
                            }

                            BarItemChip {
                                anchors.centerIn: parent
                                width: Math.max(chipWidth, previewLoader.width)
                                height: Appearance.size.barHeight
                                itemId: drawer.selected
                                contentWidth: previewLoader.width
                                contentHeight: previewLoader.height
                                barH: Appearance.size.barHeight
                                shown: !drawer.splitItem
                            }

                            Loader {
                                id: previewLoader
                                anchors.centerIn: parent
                                enabled: false
                                width: item ? item.implicitWidth : 0
                                height: item ? item.implicitHeight : 0
                                source: drawer.selected !== "" && !drawer.dashPage
                                        ? BarLayout.urlFor(drawer.selected) : ""
                                onWidthChanged: drawer.previewW = previewLoader.width
                                onHeightChanged: drawer.previewH = previewLoader.height
                                onStatusChanged: if (previewLoader.status !== Loader.Ready)
                                    drawer.previewSizable = false
                                onLoaded: {
                                    item.host = stubHost
                                    if ("itemId" in item)
                                        item.itemId = drawer.selected
                                    drawer.previewSizable = item.iconSizable === true
                                }
                            }
                        }

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: panelSizeSection.spec !== null && !!drawer.editor && drawer.editor.panelStage
    content: "Panel size"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup2
    Layout.fillWidth: true
    visible: panelSizeSection.spec !== null && !!drawer.editor && drawer.editor.panelStage
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    id: panelSizeSection
                                    readonly property string kind: drawer.dashPage ? "" : BarLayout.panelFor(drawer.selected)
                                    readonly property var spec: BarLayout.panelSpecs[panelSizeSection.kind] ?? null
                                    readonly property bool custom: panelSizeSection.kind !== ""
                                        && BarLayout.panelCustom(panelSizeSection.kind)
                                    readonly property real roomH: Math.max(0, drawer.Window.height - Appearance.size.barHeight - 16)

                                    Layout.fillWidth: true
                                    visible: panelSizeSection.spec !== null && !!drawer.editor && drawer.editor.panelStage
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4

                                        CustomText {
                                            Layout.fillWidth: true
                                            content: "Panel size"
                                            size: 13
                                            customColor: Colors.primary
                                        }
                                        M3Button {
                                            variant: "text"
                                            icon: "restart_alt"
                                            label: "Default size"
                                            enabledButton: panelSizeSection.custom
                                            onClicked: BarLayout.clearPanelSize(panelSizeSection.kind)
                                        }
                                    }

                                    CustomText {
                                        Layout.fillWidth: true
                                        visible: drawer.selected !== "dashboard"
                                        wrapMode: Text.WordWrap
                                        content: "The " + (panelSizeSection.spec ? panelSizeSection.spec.label.toLowerCase() : "")
                                            + " panel is open as a live preview. Drag its edges or use the sliders to resize it."
                                        size: 12
                                        customColor: Colors.outline
                                    }

                                    Repeater {
                                        model: panelSizeSection.spec ? [
                                            { key: "w", label: "Width",  min: panelSizeSection.spec.minW, auto: false,
                                              max: panelSizeSection.spec.maxW },
                                            { key: "h", label: "Height", min: panelSizeSection.spec.minH, auto: panelSizeSection.spec.defH < 0,
                                              max: Math.max(panelSizeSection.spec.minH,
                                                            Math.min(panelSizeSection.spec.maxH, panelSizeSection.roomH)) }
                                        ] : []

                                        delegate: RowLayout {
                                            id: panelRow
                                            required property var modelData
                                            readonly property string kind: panelSizeSection.kind
                                            readonly property real value: panelRow.modelData.key === "w" ? BarLayout.panelW(panelRow.kind)
                                                                                                         : BarLayout.panelH(panelRow.kind)
                                            readonly property int offset: panelRow.modelData.auto ? 1 : 0
                                            readonly property bool isAuto: panelRow.modelData.auto && panelRow.value < 0
                                            readonly property int step: 10

                                            Layout.fillWidth: true
                                            spacing: 12

                                            CustomText {
                                                Layout.preferredWidth: 110
                                                content: panelRow.modelData.label
                                                size: 12
                                            }
                                            EditStepper {
                                                Layout.fillWidth: true
                                                value: panelRow.isAuto ? panelRow.modelData.min : Math.round(panelRow.value)
                                                from: panelRow.modelData.min
                                                to: panelRow.modelData.max
                                                stepSize: panelRow.step
                                                canAuto: !!panelRow.modelData.auto
                                                isAuto: panelRow.isAuto
                                                onPicked: v => {
                                                    const k = panelRow.kind
                                                    if (panelRow.modelData.key === "w")
                                                        BarLayout.setPanelSize(k, v, BarLayout.panelH(k))
                                                    else
                                                        BarLayout.setPanelSize(k, BarLayout.panelW(k), v)
                                                }
                                                onAutoPicked: {
                                                    const k = panelRow.kind
                                                    BarLayout.setPanelSize(k, BarLayout.panelW(k), -1)
                                                }
                                            }
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: drawerGroupOpen.visible
    content: "Panel"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupOpen
    Layout.fillWidth: true
    visible: drawer.itemPage && !drawer.dashPage && BarLayout.hasOpenChoice(drawer.selected)
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: "Open the panel with"
                                        size: 13
                                    }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: [
                                            { value: "click", label: "Click", icon: "ads_click" },
                                            { value: "hover", label: "Hover", icon: "arrow_selector_tool" }
                                        ]
                                        activeCheck: function(v) { return BarLayout.openOn(drawer.selected) === v }
                                        onSegmentClicked: function(v) { BarLayout.setOpenOn(drawer.selected, v) }
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        visible: BarLayout.openOn(drawer.selected) === "hover"
                                        wrapMode: Text.WordWrap
                                        content: "Pointing at the item opens its panel and leaving closes it. A click still keeps it open."
                                        size: 11
                                        customColor: Colors.outline
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: !drawer.chromeless
    content: "Look"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup3
    Layout.fillWidth: true
    visible: !drawer.chromeless
    spacing: 8
    EditRow {
        visible: drawer.iconSizable
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: drawer.iconSizable
                                    spacing: 12

                                    CustomText {
                                        Layout.preferredWidth: 110
                                        content: "Size"
                                        size: 12
                                    }
                                    EditStepper {
                                        Layout.fillWidth: true
                                        value: drawer.itemIconSize > 0 ? Math.round(drawer.itemIconSize) : 18
                                        from: 10
                                        to: 24
                                        stepSize: 1
                                        offValue: 18
                                        canAuto: true
                                        isAuto: !(drawer.itemIconSize > 0)
                                        onPicked: v => BarLayout.setItemStyle(drawer.selected, "iconSize", v)
                                        onAutoPicked: BarLayout.setItemStyle(drawer.selected, "iconSize", 0)
                                    }
                                }
    }
    EditRow {
        visible: !drawer.chromeless
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: !drawer.chromeless
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Tint"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }

                                    EditChoice {
                                        Layout.fillWidth: true
                                        maxPerRow: 5
                                        minCell: 76
                                        choices: drawer.tintChoices
                                        value: drawer.itemTint
                                        onPicked: v => BarLayout.setItemStyle(drawer.selected, "tint", v)
                                    }
                                }
    }
    EditRow {
        visible: !drawer.chromeless && drawer.chipStyled && !drawer.ownShape
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 100000
                                    visible: !drawer.chromeless && drawer.chipStyled && !drawer.ownShape
                                    spacing: 8

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: "Shape"
                                        size: 12
                                    }

                                    CustomText {
                                        Layout.fillWidth: true
                                        visible: !drawer.iconItem
                                        wrapMode: Text.WordWrap
                                        content: "Single-icon items only."
                                        size: 12
                                        customColor: Colors.outline
                                    }

                                    ShapePicker {
                                        Layout.fillWidth: true
                                        centered: true
                                        visible: drawer.iconItem
                                        autoLabel: "None"
                                        autoIcon: "crop_square"
                                        autoHint: "Rounded rectangle"
                                        pickedHint: ""
                                        selected: drawer.itemShape === "none" ? "" : drawer.itemShape
                                        onPicked: name => BarLayout.setItemStyle(drawer.selected, "shape",
                                                                                name === "" ? "none" : name)
                                    }
                                }
    }
    EditRow {
        visible: drawer.rotatable
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    CustomText {
                                        Layout.preferredWidth: 110
                                        content: "Rotate"
                                        size: 12
                                    }
                                    EditStepper {
                                        readonly property real angle: BarLayout.itemStyle(drawer.selected, "rotate", 0)
                                        Layout.fillWidth: true
                                        value: angle
                                        from: 0
                                        to: 345
                                        stepSize: 15
                                        unit: "°"
                                        onPicked: v => {
                                            if (v !== angle)
                                                BarLayout.setItemStyle(drawer.selected, "rotate", v)
                                        }
                                    }
                                }
    }
    EditRow {
        visible: !drawer.chromeless && (drawer.chipStyled || drawer.groupPage)
                                Repeater {
                                    model: [
                                        { key: "radius", label: "Radius",    min: 0, max: 24,  step: 1, def: -1, auto: "Pill", shapeLabel: "",        tintOnly: true,  groupOnly: false },
                                        { key: "pad",    label: "Padding",   min: 0, max: 24,  step: 2, def: 10, auto: "",     shapeLabel: "Padding", tintOnly: true,  groupOnly: false },
                                        { key: "gap",    label: "Spacing",   min: 0, max: 20,  step: 2, def: -1, auto: "Auto", shapeLabel: "Spacing", tintOnly: false, groupOnly: true },
                                        { key: "minW",   label: "Min width", min: 0, max: 160, step: 8, def: 0,  auto: "",     shapeLabel: "",        tintOnly: true,  groupOnly: false },
                                        { key: "minH",   label: "Height",    min: 0, max: 56,  step: 2, def: 0,  auto: "",     shapeLabel: "Size",    tintOnly: false, groupOnly: false }
                                    ]

                                    delegate: RowLayout {
                                        id: chipRow
                                        required property var modelData
                                        readonly property bool hasAuto: chipRow.modelData.auto !== ""
                                        readonly property real value: BarLayout.itemStyle(drawer.selected,
                                                                                          chipRow.modelData.key,
                                                                                          chipRow.modelData.def)
                                        readonly property int off: chipRow.hasAuto ? 1 : 0
                                        readonly property bool isAuto: chipRow.hasAuto && chipRow.value < 0

                                        Layout.fillWidth: true
                                        visible: !drawer.chromeless
                                            && (drawer.chipStyled
                                                || (!chipRow.modelData.tintOnly && drawer.groupPage))
                                            && (!chipRow.modelData.groupOnly || drawer.groupPage)
                                            && (!drawer.shapedChip || chipRow.modelData.shapeLabel !== "")
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: drawer.shapedChip && chipRow.modelData.shapeLabel !== ""
                                                     ? chipRow.modelData.shapeLabel : chipRow.modelData.label
                                            size: 12
                                        }
                                        EditStepper {
                                            Layout.fillWidth: true
                                            value: chipRow.isAuto ? Math.max(chipRow.modelData.min, chipRow.modelData.def) : chipRow.value
                                            from: chipRow.modelData.min
                                            to: chipRow.modelData.max
                                            stepSize: chipRow.modelData.step
                                            presets: chipRow.modelData.key === "minW" ? [{ label: "Hug", value: 0 }] : []
                                            canAuto: chipRow.hasAuto
                                            isAuto: chipRow.isAuto
                                            autoLabel: chipRow.hasAuto ? chipRow.modelData.auto : "Auto"
                                            autoText: chipRow.hasAuto ? chipRow.modelData.auto : "Auto"
                                            offValue: chipRow.modelData.key === "radius" ? 12 : chipRow.modelData.key === "gap" ? 6 : chipRow.modelData.min
                                            onPicked: v => {
                                                if (v !== chipRow.value)
                                                    BarLayout.setItemStyle(drawer.selected, chipRow.modelData.key, v)
                                            }
                                            onAutoPicked: BarLayout.setItemStyle(drawer.selected, chipRow.modelData.key, -1)
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: !drawer.chromeless
    content: "Spacing"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup4
    Layout.fillWidth: true
    visible: !drawer.chromeless
    spacing: 8
    EditRow {
        visible: true
                                M3Button {
                                    Layout.alignment: Qt.AlignRight
                                    size: "xsmall"
                                    variant: "text"
                                    icon: "restart_alt"
                                    label: "Reset margins"
                                    enabledButton: selectedSection.margin[0] > 0 || selectedSection.margin[1] > 0
                                    onClicked: BarLayout.clearMargins(drawer.selected)
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !drawer.chromeless
                                    spacing: 10

                                    EditStepper {
                                        Layout.fillWidth: true
                                        value: selectedSection.margin[0]
                                        from: 0
                                        to: 40
                                        stepSize: 2
                                        onPicked: v => BarLayout.setMargin(drawer.selected, "left", v)
                                    }
                                    Rectangle {
                                        implicitWidth: 38
                                        implicitHeight: 34
                                        radius: 10
                                        color: Colors.secondaryContainer

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: selectedSection.entry && selectedSection.entry.icon ? selectedSection.entry.icon : "widgets"
                                            iconSize: 18
                                            customColor: Colors.secondaryContainerText
                                        }
                                    }
                                    EditStepper {
                                        Layout.fillWidth: true
                                        lead: true
                                        value: selectedSection.margin[1]
                                        from: 0
                                        to: 40
                                        stepSize: 2
                                        onPicked: v => BarLayout.setMargin(drawer.selected, "right", v)
                                    }
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: "Space before and after this part"
                                    size: 11
                                    customColor: Colors.outline
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: drawer.groupPage
    content: "Group"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup5
    Layout.fillWidth: true
    visible: drawer.groupPage
    spacing: 8
    EditRow {
        visible: drawer.groupPage
                                CustomText {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    visible: drawer.groupPage
                                    content: "Items in this group"
                                    size: 13
                                    customColor: Colors.primary
                                }
    }
    EditRow {
        visible: drawer.groupPage
                                Flow {
                                    Layout.fillWidth: true
                                    visible: drawer.groupPage
                                    spacing: 6

                                    Repeater {
                                        model: drawer.groupMembers

                                        delegate: MemberChip {
                                            required property string modelData
                                            required property int index
                                            entry: BarLayout.entry(modelData)
                                            canLeft: index > 0
                                            canRight: index < drawer.groupMembers.length - 1
                                            onMoveLeft: BarLayout.moveInGroup(drawer.selected, modelData, -1)
                                            onMoveRight: BarLayout.moveInGroup(drawer.selected, modelData, 1)
                                            onRemoved: BarLayout.removeFromGroup(drawer.selected, modelData)
                                        }
                                    }
                                }
    }
    EditRow {
        visible: drawer.groupPage && drawer.groupMembers.length === 0
                                CustomText {
                                    Layout.fillWidth: true
                                    visible: drawer.groupPage && drawer.groupMembers.length === 0
                                    wrapMode: Text.WordWrap
                                    content: "Empty. Add items below, then give the group a tint."
                                    size: 12
                                    customColor: Colors.outline
                                }
    }
    EditRow {
        visible: drawer.groupPage
                                CustomText {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    visible: drawer.groupPage
                                    content: "Add"
                                    size: 13
                                    customColor: Colors.primary
                                }
    }
    EditRow {
        visible: drawer.groupPage
                                Flow {
                                    Layout.fillWidth: true
                                    visible: drawer.groupPage
                                    spacing: 6

                                    Repeater {
                                        model: drawer.groupCandidates

                                        delegate: Chip {
                                            required property string modelData
                                            entry: BarLayout.entry(modelData)
                                            adding: true
                                            onActivated: BarLayout.addToGroup(drawer.selected, modelData)
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: drawer.selected !== "dashboard"
    content: "Options"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup6
    Layout.fillWidth: true
    visible: drawer.selected !== "dashboard"
    spacing: 8
                                Repeater {
                                    model: selectedSection.options

                                    delegate: EditOptionRow {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spec: modelData
                                        getter: function(key) { return drawer.optValue(key) }
                                        setter: function(key, v) { drawer.setOptValue(key, v) }
                                        listGetter: function(key) { return drawer.optList(key) }
                                        listAdd: function(key, v) { drawer.optListAdd(key, v) }
                                        listRemove: function(key, v) { drawer.optListRemove(key, v) }
                                    }
                                }
    EditRow {
        visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
    }
    EditRow {
        visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
                                CustomText {
                                    Layout.fillWidth: true
                                    visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
                                    wrapMode: Text.WordWrap
                                    content: drawer.dashPage || drawer.anchorPage ? "This item has no options."
                                                             : "This item has no options besides its margins."
                                    size: 12
                                    customColor: Colors.outline
                                }
    }
}
                    }

                    ColumnLayout {
                        id: addPage
                        Layout.fillWidth: true
                        spacing: 10
                        visible: false

                        Repeater {
                            model: BarLayout.groups

                            delegate: RowLayout {
                                id: groupRow
                                required property string modelData
                                readonly property var chips: BarLayout.hiddenItems.filter(id => {
                                    const e = BarLayout.entry(id)
                                    return e && e.group === groupRow.modelData
                                })

                                Layout.fillWidth: true
                                spacing: 12
                                visible: groupRow.chips.length > 0

                                CustomText {
                                    Layout.preferredWidth: 72
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 8
                                    content: groupRow.modelData
                                    size: 12
                                    weight: 600
                                    customColor: Colors.outline
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: groupRow.chips

                                        delegate: Rectangle {
                                            id: chip
                                            required property string modelData
                                            readonly property var entry: BarLayout.entry(chip.modelData)
                                            readonly property bool multi: !!chip.entry && !!chip.entry.multi

                                            width: chipRow.implicitWidth + 22
                                            height: 32
                                            radius: 16
                                            color: chipArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                                            border.width: 1
                                            border.color: Qt.alpha(Colors.outline, chip.multi ? 0.5 : 0.3)
                                            opacity: drawer.editor && drawer.editor.mode === "item" && drawer.editor.itemId === chip.modelData ? 0.3 : 1

                                            Row {
                                                id: chipRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                MaterialIconSymbol {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    content: chip.multi ? "add" : (chip.entry ? chip.entry.icon : "")
                                                    iconSize: 16
                                                }
                                                CustomText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    content: chip.entry ? chip.entry.label : chip.modelData
                                                    size: 12
                                                    weight: 600
                                                }
                                            }

                                            MouseArea {
                                                id: chipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                preventStealing: true
                                                cursorShape: drawer.editor && drawer.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                                property real sx: 0
                                                property real sy: 0

                                                onPressed: mouse => {
                                                    chipArea.sx = mouse.x
                                                    chipArea.sy = mouse.y
                                                }
                                                onPositionChanged: mouse => {
                                                    if (!chipArea.pressed)
                                                        return
                                                    const e = drawer.editor
                                                    if (e.mode === "" && Math.hypot(mouse.x - chipArea.sx, mouse.y - chipArea.sy) > 4)
                                                        e.beginItem(chip.modelData, "", -1, 32)
                                                    if (e.mode !== "") {
                                                        const p = chipArea.mapToItem(null, mouse.x, mouse.y)
                                                        e.update(p.x, p.y)
                                                    }
                                                }
                                                onReleased: if (drawer.editor.mode !== "") drawer.editor.finish()
                                                onCanceled: drawer.editor.cancel()
                                            }

                                            CustomToolTip {
                                                content: chip.multi ? "Drag onto the bar or dock to add another" : "Drag onto the bar or dock"
                                                visible: chipArea.containsMouse && !chipArea.pressed
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: BarLayout.hiddenItems.length === 0
                            content: "Every item is already on the bar or dock."
                            size: 13
                            customColor: Colors.outline
                        }

                        CustomText {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            wrapMode: Text.WordWrap
                            content: "Drag an item onto the bar or dock. Click one that is already there to change its options."
                            size: 12
                            customColor: Colors.outline
                        }
                    }

                    ColumnLayout {
                        id: edgesPage
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !drawer.itemPage && drawer.tab !== "general"

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Edge"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupEdge
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Screen edge"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    CustomText {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        content: drawer.edgeBlocks.length === 0
                                            ? "Nothing here yet. Drag an item onto this edge, or add a block below."
                                            : drawer.edgeBlocks.length === 1 ? "1 block on this edge" : drawer.edgeBlocks.length + " blocks on this edge"
                                        size: 11
                                        customColor: Colors.outline
                                    }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: [
                                            { value: "top",    label: "Top",    icon: "border_top" },
                                            { value: "right",  label: "Right",  icon: "border_right" },
                                            { value: "bottom", label: "Bottom", icon: "border_bottom" },
                                            { value: "left",   label: "Left",   icon: "border_left" }
                                        ]
                                        activeCheck: function(value) { return drawer.edgeSide === value }
                                        onSegmentClicked: function(value) { drawer.edgeSide = value }
                                    }
                                }
    }
    EditRow {
        visible: drawer.edgeBlocks.length > 0
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Show this edge"; size: 13 }
                                        CustomText {
                                            content: drawer.edgeCfg.hidden ? "Hidden. Its blocks stay saved." : "Turn off to hide every block on this edge"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: !drawer.edgeCfg.hidden
                                        onToggled: state => BarLayout.setEdge(drawer.edgeSide, "hidden", !state)
                                    }
                                }
    }
    EditRow {
        visible: drawer.edgeBlocks.length > 0 && !drawer.edgeCfg.hidden
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Auto-hide"; size: 13 }
                                        CustomText {
                                            content: "Slide away until the pointer reaches the edge"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: drawer.edgeCfg.autoHide
                                        onToggled: state => BarLayout.setEdge(drawer.edgeSide, "autoHide", state)
                                    }
                                }
    }
    EditRow {
        visible: drawer.edgeBlocks.length > 0 && !drawer.edgeCfg.hidden
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Hide in game mode"; size: 13 }
                                        CustomText {
                                            content: "Tuck this edge away while game mode hides widgets"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: drawer.edgeCfg.gameHide === true
                                        onToggled: state => BarLayout.setEdge(drawer.edgeSide, "gameHide", state)
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Shape"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupEdgeShape
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: drawer.edgeBlocks.length === 0 ? "Shape for new blocks on this edge" : "Shape of every block on this edge"
                                        size: 13
                                        weight: 600
                                        customColor: Colors.surfaceVariantText
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        content: drawer.edgeBlocks.length === 0
                                            ? "No blocks here yet. The first block you add or drop on this edge starts with this shape."
                                            : "Click a block (or its tune button) to give it its own shape. Flat and stepped blocks next to each other join; a pill floats on its own."
                                        size: 11
                                        customColor: Colors.outline
                                    }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: drawer.shapeChoices
                                        activeCheck: function(value) { return BarLayout.edgeShapes(drawer.edgeSide).every(v => v === value) }
                                        onSegmentClicked: function(value) { BarLayout.setEdgeShape(drawer.edgeSide, value) }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Size"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupEdgeSize
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                Repeater {
                                    model: [
                                        { key: "height",   label: "Thickness",  min: 28, max: 80,  step: 2, auto: -9,
                                          presets: [{ label: "Slim", value: 32 }, { label: "Default", value: 40 }, { label: "Roomy", value: 48 }] },
                                        { key: "iconSize", label: "Icon size",  min: 16, max: 48,  step: 2, auto: 0, autoText: "Auto" },
                                        { key: "radius",   label: "Corners",    min: 8,  max: 28,  step: 1, auto: -9,
                                          presets: [{ label: "Soft", value: 12 }, { label: "Round", value: 20 }, { label: "Full", value: 28 }] },
                                        { key: "itemGap",  label: "Item gap",   min: 0,  max: 16,  step: 1, auto: -9 },
                                        { key: "blockGap", label: "Block gap",  min: 0,  max: 120, step: 8, auto: -1, autoText: "Auto" }
                                    ].concat(BarLayout.edgeShapes(drawer.edgeSide).indexOf("pill") >= 0
                                        ? (drawer.edgeSide === "left" || drawer.edgeSide === "right"
                                            ? [{ key: "pillGap",   label: drawer.edgeSide === "left" ? "Left gap" : "Right gap", min: 0, max: 40, step: 1, auto: -9 },
                                               { key: "pillStart", label: "Top gap",    min: 0, max: 80, step: 1, auto: -9 },
                                               { key: "pillEnd",   label: "Bottom gap", min: 0, max: 80, step: 1, auto: -9 }]
                                            : [{ key: "pillGap",   label: drawer.edgeSide === "top" ? "Top gap" : "Bottom gap", min: 0, max: 40, step: 1, auto: -9 },
                                               { key: "pillStart", label: "Left gap",   min: 0, max: 80, step: 1, auto: -9 },
                                               { key: "pillEnd",   label: "Right gap",  min: 0, max: 80, step: 1, auto: -9 }])
                                        : [])

                                    delegate: RowLayout {
                                        id: edgeRow
                                        required property var modelData
                                        readonly property bool canAuto: edgeRow.modelData.auto !== -9
                                        readonly property real value: Number(drawer.edgeCfg[edgeRow.modelData.key])
                                        readonly property bool isAuto: edgeRow.canAuto && edgeRow.value === edgeRow.modelData.auto

                                        Layout.fillWidth: true
                                        spacing: 12

                                        HoverHandler {
                                            onHoveredChanged: BarLayout.hoverGap(hovered, edgeRow.modelData.key, drawer.edgeSide, "")
                                        }

                                        CustomText {
                                            Layout.preferredWidth: 84
                                            content: edgeRow.modelData.label
                                            size: 12
                                        }
                                        EditStepper {
                                            Layout.fillWidth: true
                                            value: edgeRow.isAuto ? edgeRow.modelData.min : edgeRow.value
                                            from: edgeRow.modelData.min
                                            to: edgeRow.modelData.max
                                            stepSize: edgeRow.modelData.step
                                            presets: edgeRow.modelData.presets ?? []
                                            canAuto: edgeRow.canAuto
                                            isAuto: edgeRow.isAuto
                                            autoText: edgeRow.modelData.autoText ?? "Auto"
                                            onPicked: v => {
                                                if (v !== edgeRow.value)
                                                    BarLayout.setEdge(drawer.edgeSide, edgeRow.modelData.key, v)
                                                BarLayout.flashGap(edgeRow.modelData.key, drawer.edgeSide, "")
                                            }
                                            onAutoPicked: {
                                                BarLayout.setEdge(drawer.edgeSide, edgeRow.modelData.key, edgeRow.modelData.auto)
                                                BarLayout.flashGap(edgeRow.modelData.key, drawer.edgeSide, "")
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: {
                                        const shapes = BarLayout.edgeShapes(drawer.edgeSide)
                                        return shapes.indexOf("pill") >= 0 && shapes.indexOf("stepped") >= 0
                                    }
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Line up bottoms"; size: 13 }
                                        CustomText {
                                            Layout.fillWidth: true
                                            content: "Stepped tabs hang deeper so they end level with the pills"
                                            size: 11
                                            wrapMode: Text.WordWrap
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: drawer.edgeCfg.lineUp === true
                                        onToggled: state => BarLayout.setEdge(drawer.edgeSide, "lineUp", state)
                                    }
                                }

    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Blocks"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupEdgeBlocks
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Add a block on this edge"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        model: drawer.edgeSide === "left" || drawer.edgeSide === "right"
                                            ? [{ value: "left", label: "Top", icon: "add" }, { value: "center", label: "Middle", icon: "add" }, { value: "right", label: "Bottom", icon: "add" }]
                                            : [{ value: "left", label: "Left", icon: "add" }, { value: "center", label: "Centre", icon: "add" }, { value: "right", label: "Right", icon: "add" }]
                                        activeCheck: function(v) { return false }
                                        onSegmentClicked: function(v) { BarLayout.addBlock(v, drawer.edgeSide) }
                                    }
                                }
    }
}
                    }

                    ColumnLayout {
                        id: generalPage
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !drawer.itemPage && drawer.tab === "general"

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Screen border"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupBorder
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Border around the screen"; size: 13 }
                                        CustomText {
                                            content: "A frame in the bar colour; the bar and panels curve into it"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: BarLayout.screenBorder.on === true
                                        onToggled: state => BarLayout.setBorder({ on: state })
                                    }
                                }
    }
    EditRow {
        visible: BarLayout.screenBorder.on === true
                                Repeater {
                                    model: [
                                        { key: "size",   label: "Thickness",     min: 2, max: 32, step: 2 },
                                        { key: "radius", label: "Corner radius", min: 0, max: 40, step: 2 }
                                    ]

                                    delegate: RowLayout {
                                        id: borderRow
                                        required property var modelData
                                        readonly property real value: Number(BarLayout.screenBorder[borderRow.modelData.key])

                                        Layout.fillWidth: true
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: borderRow.modelData.label
                                            size: 12
                                        }
                                        EditStepper {
                                            Layout.fillWidth: true
                                            value: borderRow.value
                                            from: borderRow.modelData.min
                                            to: borderRow.modelData.max
                                            stepSize: borderRow.modelData.step
                                            onPicked: v => {
                                                const o = {}
                                                o[borderRow.modelData.key] = v
                                                BarLayout.setBorder(o)
                                            }
                                        }
                                    }
                                }
    }
    EditRow {
        visible: BarLayout.screenBorder.on === true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Sides"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: [
                                            { value: "top",    label: "Top",    icon: "border_top" },
                                            { value: "bottom", label: "Bottom", icon: "border_bottom" },
                                            { value: "left",   label: "Left",   icon: "border_left" },
                                            { value: "right",  label: "Right",  icon: "border_right" }
                                        ]
                                        activeCheck: function(value) { return BarLayout.screenBorder[value] !== false }
                                        onSegmentClicked: function(value) {
                                            const o = {}
                                            o[value] = BarLayout.screenBorder[value] === false
                                            BarLayout.setBorder(o)
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Shadow"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupShadow
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Shadow under the bar"; size: 13 }
                                        CustomText {
                                            content: "A soft shadow around every edge, its panels and the border"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: BarLayout.barShadow.on === true
                                        onToggled: state => BarLayout.setShadow({ on: state })
                                    }
                                }
    }
    EditRow {
        visible: BarLayout.barShadow.on === true
                                Repeater {
                                    model: [
                                        { key: "size",     label: "Size",     min: 4, max: 48,  step: 2 },
                                        { key: "strength", label: "Strength", min: 5, max: 100, step: 5 }
                                    ]

                                    delegate: RowLayout {
                                        id: shadowRow
                                        required property var modelData
                                        readonly property real value: Number(BarLayout.barShadow[shadowRow.modelData.key])

                                        Layout.fillWidth: true
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: shadowRow.modelData.label
                                            size: 12
                                        }
                                        EditStepper {
                                            Layout.fillWidth: true
                                            value: shadowRow.value
                                            from: shadowRow.modelData.min
                                            to: shadowRow.modelData.max
                                            stepSize: shadowRow.modelData.step
                                            onPicked: v => {
                                                const o = {}
                                                o[shadowRow.modelData.key] = v
                                                BarLayout.setShadow(o)
                                            }
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Panels"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroupPanels
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        HoverHandler {
                                            onHoveredChanged: BarLayout.hoverGap(hovered, "panelGap", "", "")
                                        }

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: "Panel gap"
                                            size: 12
                                        }
                                        EditStepper {
                                            Layout.fillWidth: true
                                            value: BarLayout.panelGap
                                            from: 0
                                            to: 40
                                            stepSize: 2
                                            onPicked: v => {
                                                if (v !== BarLayout.panelGap)
                                                    BarLayout.setPanelGap(v)
                                                BarLayout.flashGap("panelGap", "", "")
                                            }
                                        }
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: "Space between floating or merged panels and their bar, and beside blocks on the side edges. Changing it resets every block to this gap."
                                        size: 11
                                        wrapMode: Text.WordWrap
                                        customColor: Colors.outline
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Pinned apps"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup15
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        visible: true
                                ColumnLayout {
                                    id: pinSection
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    spacing: 8
                                    visible: true

                                    property string query: ""
                                    readonly property var results: pinSection.query.trim().length === 0 ? []
                                        : ServiceApps.fuzzyQuery(pinSection.query.trim()).slice(0, 8)

                                    CustomText { content: "Pinned apps"; size: 13; customColor: Colors.primary }

                                    CustomText {
                                        content: "Drag icons in the dock to reorder them, or onto this card to unpin."
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        size: 12
                                        customColor: Colors.outline
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: Colors.surfaceContainerHigh
                                        border.width: pinInput.activeFocus ? 2 : 0
                                        border.color: Colors.primary

                                        MaterialIconSymbol {
                                            id: pinSearchIcon
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            content: "search"
                                            iconSize: 16
                                            customColor: Colors.outline
                                        }

                                        TextInput {
                                            id: pinInput
                                            anchors.left: pinSearchIcon.right
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            selectByMouse: true
                                            color: Colors.surfaceText
                                            selectionColor: Qt.alpha(Colors.primary, 0.35)
                                            font.pixelSize: 13
                                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                            onTextChanged: pinSection.query = pinInput.text
                                            Keys.onEscapePressed: event => {
                                                if (pinInput.text !== "") {
                                                    pinInput.text = ""
                                                    event.accepted = true
                                                } else {
                                                    event.accepted = false
                                                }
                                            }

                                            CustomText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: pinInput.text === ""
                                                content: "Search apps to pin"
                                                size: 13
                                                customColor: Colors.outline
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: pinSection.results

                                        delegate: RowLayout {
                                            id: pinRow
                                            required property var modelData
                                            readonly property bool pinned: ServiceApps.isPinnedById(pinRow.modelData.id)

                                            Layout.fillWidth: true
                                            spacing: 10

                                            Image {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                source: IconUtil.themeIcon(pinRow.modelData.icon, "image-missing")
                                                sourceSize.width: 44
                                                sourceSize.height: 44
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            CustomText {
                                                Layout.fillWidth: true
                                                content: pinRow.modelData.name
                                                elide: Text.ElideRight
                                                size: 13
                                            }
                                            M3Button {
                                                variant: pinRow.pinned ? "text" : "tonal"
                                                icon: pinRow.pinned ? "check" : "push_pin"
                                                label: pinRow.pinned ? "Pinned" : "Pin"
                                                onClicked: ServiceApps.togglePinById(pinRow.modelData.id)
                                            }
                                        }
                                    }
                                }
    }
}
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
