import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: drawer

    property QtObject editor: null
    property bool alive: false
    property real maxHeight: 600
    property string tab: "add"

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
    readonly property bool dashPage: drawer.selected.indexOf("dash:") === 0
    readonly property bool loose: drawer.itemPage && !drawer.dashPage && drawer.selected !== "dashboard" && !BarLayout.isPlaced(drawer.selected)
    readonly property bool chromeless: drawer.dashPage || drawer.loose
    readonly property string dashKey: drawer.dashPage ? drawer.selected.substring(5) : ""
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
    readonly property bool groupPage: !drawer.dashPage && drawer.selected !== ""
        && BarLayout.isGroup(drawer.selected)
    readonly property var groupMembers: drawer.groupPage ? BarLayout.groupMembers(drawer.selected) : []
    readonly property var groupCandidates: {
        if (!drawer.groupPage)
            return []
        const out = []
        for (const e of BarLayout.catalog) {
            if (e.id === "group" || !BarLayout.allows(e.id, "bar"))
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
        color: arrowArea.containsMouse && arrow.enabled ? Colors.primaryContainer : "transparent"
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

    function edgeRadius(card, dir) {
        const p = card ? card.parent : null
        if (!p)
            return 20
        const ch = p.children
        let idx = -1
        for (let i = 0; i < ch.length; i++)
            if (ch[i] === card) { idx = i; break }
        for (let i = idx + dir; i >= 0 && i < ch.length; i += dir) {
            if (!ch[i].visible)
                continue
            if (ch[i].isHeading === true)
                return 20
            if (ch[i].isCustomCard === true)
                return 5
        }
        return 20
    }

    function optValue(key) {
        return drawer.dashPage ? DashLayout.opt(drawer.dashKey, key)
                               : BarLayout.opt(drawer.selected, key)
    }

    function setOptValue(key, value) {
        if (drawer.dashPage)
            DashLayout.setOption(drawer.dashKey, key, value)
        else
            BarLayout.setOption(drawer.selected, key, value)
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
                                content: "Bar & dock"
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
                            { value: "bar",  label: "Bar",  icon: "toolbar" },
                            { value: "dock", label: "Dock", icon: "dock_to_bottom" }
                        ]
                        activeCheck: function(v) { return drawer.tab === v || (v === "bar" && drawer.tab === "add") }
                        onSegmentClicked: function(v) { drawer.tab = v }
                    }

                    ColumnLayout {
                        id: selectedSection
                        Layout.fillWidth: true
                        spacing: 8
                        visible: drawer.itemPage

                        readonly property var entry: drawer.dashPage ? DashLayout.entry(drawer.dashKey)
                                                                     : BarLayout.entry(drawer.selected)
                        readonly property var margin: drawer.dashPage ? [0, 0]
                                                                      : BarLayout.marginsFor(drawer.selected)
                        readonly property var options: {
                            const all = selectedSection.entry && selectedSection.entry.options
                                ? selectedSection.entry.options : []
                            return drawer.loose ? all.filter(o => o.setting || o.type === "heading") : all
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            M3IconButton {
                                visible: drawer.dashPage
                                icon: "arrow_back"
                                onClicked: if (drawer.editor) drawer.editor.selectedItem = "dashboard"
                            }
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
                                    content: drawer.dashPage ? "Dashboard item"
                                        : drawer.selected === "dashboard" ? "Your items, layout and grid"
                                        : drawer.loose ? "Not in your bar · panel settings only"
                                        : selectedSection.entry && selectedSection.entry.group ? selectedSection.entry.group + " item" : "Bar item"
                                    size: 12
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                            M3Button {
                                variant: "text"
                                visible: drawer.dashPage
                                icon: "delete"
                                label: "Remove"
                                onClicked: {
                                    const k = drawer.dashKey
                                    if (drawer.editor)
                                        drawer.editor.selectedItem = "dashboard"
                                    Qt.callLater(() => DashLayout.dropItem(k))
                                }
                            }
                            M3IconButton {
                                icon: "close"
                                onClicked: if (drawer.editor) drawer.editor.drawerMode = ""
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
                            visible: drawer.loose
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

                        CustomText {
                            Layout.fillWidth: true
                            visible: drawer.selected === "dashboard" || drawer.dashPage
                            wrapMode: Text.WordWrap
                            content: drawer.dashPage
                                ? "This item is live in the dashboard beside you. Drag it there to move it, or drag its corner to resize it."
                                : "Your dashboard is open beside you. Click an item there to change its options."
                            size: 12
                            customColor: Colors.outline
                        }

                        Rectangle {
                            id: previewStrip
                            Layout.fillWidth: true
                            Layout.preferredHeight: Appearance.size.barHeight + 16
                            visible: !drawer.chromeless && drawer.selected !== "dashboard" && previewLoader.status === Loader.Ready
                            radius: 12
                            color: Colors.surface

                            Item {
                                id: stubHost
                                width: 0
                                height: 0
                                visible: false
                                readonly property bool editing: false
                                readonly property real maxWidth: -1
                                readonly property real fixedWidth: 0
                                function hoverOpen(kind, item) {}
                                function openPanel(kind, item) {}
                                function closePanel() {}
                            }

                            BarItemChip {
                                anchors.centerIn: parent
                                width: Math.max(chipWidth, previewLoader.width)
                                height: Appearance.size.barHeight
                                itemId: drawer.selected
                                contentWidth: previewLoader.width
                                contentHeight: previewLoader.height
                                barH: Appearance.size.barHeight
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
        id: drawerBlock2
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock2, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock2, 1)
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
                                            M3Slider {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 30
                                                stepCount: Math.floor((panelRow.modelData.max - panelRow.modelData.min) / panelRow.step) + 1 + panelRow.offset
                                                currentStep: panelRow.isAuto ? 0
                                                    : Math.max(panelRow.offset, Math.min(stepCount - 1,
                                                        Math.round((panelRow.value - panelRow.modelData.min) / panelRow.step) + panelRow.offset))
                                                valueText: panelRow.modelData.auto && currentStep === 0 ? "Auto"
                                                    : String(panelRow.modelData.min + (currentStep - panelRow.offset) * panelRow.step)
                                                onStepChanged: s => {
                                                    const v = panelRow.modelData.auto && s === 0 ? -1
                                                        : panelRow.modelData.min + (s - panelRow.offset) * panelRow.step
                                                    if (Math.abs(v - panelRow.value) < panelRow.step / 2 && (v < 0) === (panelRow.value < 0))
                                                        return
                                                    const k = panelRow.kind
                                                    if (panelRow.modelData.key === "w")
                                                        BarLayout.setPanelSize(k, v, BarLayout.panelH(k))
                                                    else
                                                        BarLayout.setPanelSize(k, BarLayout.panelW(k), v)
                                                }
                                            }
                                            CustomText {
                                                Layout.preferredWidth: 48
                                                horizontalAlignment: Text.AlignRight
                                                content: panelRow.isAuto ? "Auto" : Math.round(panelRow.value) + "px"
                                                size: 12
                                                customColor: Colors.outline
                                            }
                                        }
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
        id: drawerBlock4
        autoRadius: false
        visible: drawer.iconSizable
        topRadius: drawer.edgeRadius(drawerBlock4, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock4, 1)
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: drawer.iconSizable
                                    spacing: 12

                                    CustomText {
                                        Layout.preferredWidth: 110
                                        content: "Size"
                                        size: 12
                                    }
                                    M3Slider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        stepCount: 16
                                        currentStep: drawer.itemIconSize > 0
                                            ? Math.round(drawer.itemIconSize) - 9 : 0
                                        valueText: currentStep === 0 ? "Auto" : String(currentStep + 9) + "px"
                                        onStepChanged: st => {
                                            const v = st === 0 ? 0 : st + 9
                                            if (v !== drawer.itemIconSize)
                                                BarLayout.setItemStyle(drawer.selected, "iconSize", v)
                                        }
                                    }
                                    CustomText {
                                        Layout.preferredWidth: 40
                                        horizontalAlignment: Text.AlignRight
                                        content: drawer.itemIconSize > 0 ? drawer.itemIconSize + "px" : "Auto"
                                        size: 12
                                        customColor: Colors.outline
                                    }
                                }
    }
    EditRow {
        id: drawerBlock6
        autoRadius: false
        visible: !drawer.chromeless
        topRadius: drawer.edgeRadius(drawerBlock6, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock6, 1)
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
        id: drawerBlock7
        autoRadius: false
        visible: !drawer.chromeless && drawer.itemTint !== "none"
        topRadius: drawer.edgeRadius(drawerBlock7, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock7, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 100000
                                    visible: !drawer.chromeless && drawer.itemTint !== "none"
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
        id: drawerBlock8
        autoRadius: false
        visible: !drawer.chromeless && (drawer.itemTint !== "none" || drawer.groupPage)
        topRadius: drawer.edgeRadius(drawerBlock8, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock8, 1)
                                Repeater {
                                    model: [
                                        { key: "radius", label: "Radius",    min: 0, max: 24,  step: 2, def: -1, auto: "Pill", shapeLabel: "",        tintOnly: true,  groupOnly: false },
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
                                            && (drawer.itemTint !== "none"
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
                                        M3Slider {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            stepCount: Math.round((chipRow.modelData.max - chipRow.modelData.min)
                                                                  / chipRow.modelData.step) + 1 + chipRow.off
                                            currentStep: chipRow.isAuto ? 0
                                                : Math.round((chipRow.value - chipRow.modelData.min) / chipRow.modelData.step) + chipRow.off
                                            valueText: chipRow.hasAuto && currentStep === 0 ? chipRow.modelData.auto
                                                : String(chipRow.modelData.min + (currentStep - chipRow.off) * chipRow.modelData.step)
                                            onStepChanged: st => {
                                                const v = chipRow.hasAuto && st === 0 ? -1
                                                    : chipRow.modelData.min + (st - chipRow.off) * chipRow.modelData.step
                                                if (v !== chipRow.value)
                                                    BarLayout.setItemStyle(drawer.selected, chipRow.modelData.key, v)
                                            }
                                        }
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                            content: chipRow.isAuto ? chipRow.modelData.auto
                                                   : (chipRow.value === 0 && !chipRow.hasAuto ? "Hug" : chipRow.value + "px")
                                            size: 12
                                            customColor: Colors.outline
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
        id: drawerBlock10
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock10, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock10, 1)
                                M3Button {
                                    Layout.alignment: Qt.AlignRight
                                    size: "xsmall"
                                    variant: "text"
                                    icon: "restart_alt"
                                    label: "Reset margins"
                                    enabledButton: selectedSection.margin[0] > 0 || selectedSection.margin[1] > 0
                                    onClicked: BarLayout.clearMargins(drawer.selected)
                                }
                                Repeater {
                                    model: [
                                        { side: "left",  label: "Left",  at: 0 },
                                        { side: "right", label: "Right", at: 1 }
                                    ]

                                    delegate: RowLayout {
                                        id: marginRow
                                        required property var modelData
                                        readonly property int px: selectedSection.margin[marginRow.modelData.at]

                                        Layout.fillWidth: true
                                        visible: !drawer.chromeless
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: marginRow.modelData.label + " margin"
                                            size: 12
                                        }
                                        M3Slider {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            stepCount: 21
                                            currentStep: Math.round(marginRow.px / 2)
                                            valueText: (currentStep * 2) + "px"
                                            onStepChanged: step => {
                                                if (step * 2 !== marginRow.px)
                                                    BarLayout.setMargin(drawer.selected, marginRow.modelData.side, step * 2)
                                            }
                                        }
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                            content: marginRow.px + "px"
                                            size: 12
                                            customColor: Colors.outline
                                        }
                                    }
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
        id: drawerBlock11
        autoRadius: false
        visible: drawer.groupPage
        topRadius: drawer.edgeRadius(drawerBlock11, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock11, 1)
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
        id: drawerBlock12
        autoRadius: false
        visible: drawer.groupPage
        topRadius: drawer.edgeRadius(drawerBlock12, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock12, 1)
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
        id: drawerBlock13
        autoRadius: false
        visible: drawer.groupPage && drawer.groupMembers.length === 0
        topRadius: drawer.edgeRadius(drawerBlock13, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock13, 1)
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
        id: drawerBlock14
        autoRadius: false
        visible: drawer.groupPage
        topRadius: drawer.edgeRadius(drawerBlock14, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock14, 1)
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
        id: drawerBlock15
        autoRadius: false
        visible: drawer.groupPage
        topRadius: drawer.edgeRadius(drawerBlock15, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock15, 1)
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
                                        listGetter: function(key) { return DashLayout.itemList(drawer.dashKey, key) }
                                        listAdd: function(key, v) { DashLayout.addItem(drawer.dashKey, key, v) }
                                        listRemove: function(key, v) { DashLayout.removeItem(drawer.dashKey, key, v) }
                                    }
                                }
    EditRow {
        id: drawerBlockNote16
        autoRadius: false
        visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
        topRadius: drawer.edgeRadius(drawerBlockNote16, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockNote16, 1)
    }
    EditRow {
        id: drawerBlock17
        autoRadius: false
        visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
        topRadius: drawer.edgeRadius(drawerBlock17, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock17, 1)
                                CustomText {
                                    Layout.fillWidth: true
                                    visible: selectedSection.options.length === 0 && drawer.selected !== "dashboard"
                                    wrapMode: Text.WordWrap
                                    content: drawer.dashPage ? "This item has no options."
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
                                                content: chip.entry && chip.entry.surfaces
                                                    ? (chip.entry.surfaces[0] === "dock" ? "Dock only, drag onto the dock" : "Bar only, drag onto the bar")
                                                    : chip.multi ? "Drag onto the bar or dock to add another" : "Drag onto the bar or dock"
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
                        id: barPage
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !drawer.itemPage && (drawer.tab === "bar" || drawer.tab === "add")

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Style"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup7
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        id: drawerBlock19
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock19, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock19, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Shape of every block"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    CustomText {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        content: "Click a block on the bar (or its tune button) to give it its own shape and tint. Flat and stepped blocks next to each other join; a pill floats on its own."
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
                                        activeCheck: function(value) { return BarLayout.edgeShapes("top").every(v => v === value) }
                                        onSegmentClicked: function(value) { BarLayout.setEdgeShape("top", value) }
                                    }
                                }
    }
    EditRow {
        id: drawerBlockBarSide
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlockBarSide, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockBarSide, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Position"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: [
                                            { value: "top",    label: "Top",    icon: "vertical_align_top" },
                                            { value: "bottom", label: "Bottom", icon: "vertical_align_bottom" },
                                            { value: "left",   label: "Left",   icon: "align_horizontal_left" },
                                            { value: "right",  label: "Right",  icon: "align_horizontal_right" }
                                        ]
                                        activeCheck: function(value) { return BarLayout.barSide === value }
                                        onSegmentClicked: function(value) { BarLayout.setSide("bar", value) }
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
    id: drawerGroup8
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        id: drawerBlock20
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock20, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock20, 1)
                                Repeater {
                                    model: [
                                        { key: "height",   label: "Height",        min: 32, max: 56,  step: 2, def: 40, auto: false },
                                        { key: "itemGap",  label: "Item gap",      min: 0,  max: 16,  step: 1, def: 6,  auto: false },
                                        { key: "blockGap", label: "Block gap",     min: 16, max: 120, step: 8, def: -1, auto: true },
                                        { key: "radius",   label: "Corner radius", min: 8,  max: 24,  step: 1, def: 18, auto: false }
                                    ]

                                    delegate: RowLayout {
                                        id: sizeRow
                                        required property var modelData
                                        readonly property real value: BarLayout.sizeValue(sizeRow.modelData.key, sizeRow.modelData.def)
                                        readonly property int offset: sizeRow.modelData.auto ? 1 : 0
                                        readonly property bool isAuto: sizeRow.modelData.auto && sizeRow.value < 0

                                        Layout.fillWidth: true
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: sizeRow.modelData.label
                                            size: 12
                                        }
                                        M3Slider {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            stepCount: Math.round((sizeRow.modelData.max - sizeRow.modelData.min) / sizeRow.modelData.step) + 1 + sizeRow.offset
                                            currentStep: sizeRow.isAuto ? 0
                                                : Math.round((sizeRow.value - sizeRow.modelData.min) / sizeRow.modelData.step) + sizeRow.offset
                                            valueText: sizeRow.modelData.auto && currentStep === 0 ? "Auto"
                                                : String(sizeRow.modelData.min + (currentStep - sizeRow.offset) * sizeRow.modelData.step)
                                            onStepChanged: s => {
                                                const v = sizeRow.modelData.auto && s === 0 ? -1
                                                    : sizeRow.modelData.min + (s - sizeRow.offset) * sizeRow.modelData.step
                                                if (v !== sizeRow.value)
                                                    BarLayout.setSize(sizeRow.modelData.key, v)
                                            }
                                        }
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                            content: sizeRow.isAuto ? "Auto" : sizeRow.value + "px"
                                            size: 12
                                            customColor: Colors.outline
                                        }
                                    }
                                }
    }
}

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
        id: drawerBlockBorderOn
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlockBorderOn, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockBorderOn, 1)
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
        id: drawerBlockBorderSize
        autoRadius: false
        visible: BarLayout.screenBorder.on === true
        topRadius: drawer.edgeRadius(drawerBlockBorderSize, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockBorderSize, 1)
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
                                        M3Slider {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            stepCount: Math.round((borderRow.modelData.max - borderRow.modelData.min) / borderRow.modelData.step) + 1
                                            currentStep: Math.round((borderRow.value - borderRow.modelData.min) / borderRow.modelData.step)
                                            valueText: String(borderRow.modelData.min + currentStep * borderRow.modelData.step)
                                            onStepChanged: s => {
                                                const v = borderRow.modelData.min + s * borderRow.modelData.step
                                                if (v !== borderRow.value) {
                                                    const o = {}
                                                    o[borderRow.modelData.key] = v
                                                    BarLayout.setBorder(o)
                                                }
                                            }
                                        }
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                            content: borderRow.value + "px"
                                            size: 12
                                            customColor: Colors.outline
                                        }
                                    }
                                }
    }
    EditRow {
        id: drawerBlockBorderSides
        autoRadius: false
        visible: BarLayout.screenBorder.on === true
        topRadius: drawer.edgeRadius(drawerBlockBorderSides, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockBorderSides, 1)
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
    content: "Blocks"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup10
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        id: drawerBlock22
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock22, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock22, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Add block"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        model: [{ value: "left", label: "Left", icon: "add" }, { value: "center", label: "Centre", icon: "add" }, { value: "right", label: "Right", icon: "add" }]
                                        activeCheck: function(v) { return false }
                                        onSegmentClicked: function(v) { BarLayout.addBlock(v) }
                                    }
                                }
    }
}
                    }

                    ColumnLayout {
                        id: dockPage
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !drawer.itemPage && drawer.tab === "dock"

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: true
    content: "Dock"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup11
    Layout.fillWidth: true
    visible: true
    spacing: 8
    EditRow {
        id: drawerBlock23
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock23, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock23, 1)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Show dock"; size: 13 }
                                        CustomText {
                                            content: BarLayout.dockOn ? "Turn off to hide the dock entirely"
                                                                      : "The dock is hidden."
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: BarLayout.dockOn
                                        onToggled: state => SettingsConfig.general =
                                            Object.assign({}, SettingsConfig.general, { dock: state })
                                    }
                                }
    }
    EditRow {
        id: drawerBlock24
        autoRadius: false
        visible: BarLayout.dockOn
        topRadius: drawer.edgeRadius(drawerBlock24, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock24, 1)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: BarLayout.dockOn
                                    enabled: BarLayout.edgeShapes("bottom").indexOf("flat") < 0
                                    opacity: enabled ? 1 : 0.5

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 100000
                                        spacing: 1

                                        CustomText { content: "Auto-hide"; size: 13 }
                                        CustomText {
                                            content: BarLayout.edgeShapes("bottom").indexOf("flat") >= 0
                                                ? "Not available while a dock block is flat"
                                                : "Slide away until the pointer reaches the edge"
                                            size: 11
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomToogle {
                                        isToggleOn: (SettingsConfig.general.dockAutoHide ?? true)
                                                    && BarLayout.edgeShapes("bottom").indexOf("flat") < 0
                                        onToggled: state => SettingsConfig.general =
                                            Object.assign({}, SettingsConfig.general, { dockAutoHide: state })
                                    }
                                }
    }
    EditRow {
        id: drawerBlock26
        autoRadius: false
        visible: BarLayout.dockOn
        topRadius: drawer.edgeRadius(drawerBlock26, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock26, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: BarLayout.dockOn

                                    CustomText { Layout.fillWidth: true; content: "Shape of every dock block"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: drawer.shapeChoices
                                        activeCheck: function(value) { return BarLayout.edgeShapes("bottom").every(v => v === value) }
                                        onSegmentClicked: function(value) { BarLayout.setEdgeShape("bottom", value) }
                                    }
                                }
    }
    EditRow {
        id: drawerBlockDockSide
        autoRadius: false
        visible: BarLayout.dockOn
        topRadius: drawer.edgeRadius(drawerBlockDockSide, -1)
        bottomRadius: drawer.edgeRadius(drawerBlockDockSide, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText { Layout.fillWidth: true; content: "Position"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        activeColor: Colors.secondaryContainer
                                        activeTextColor: Colors.secondaryContainerText
                                        model: [
                                            { value: "top",    label: "Top",    icon: "vertical_align_top" },
                                            { value: "bottom", label: "Bottom", icon: "vertical_align_bottom" },
                                            { value: "left",   label: "Left",   icon: "align_horizontal_left" },
                                            { value: "right",  label: "Right",  icon: "align_horizontal_right" }
                                        ]
                                        activeCheck: function(value) { return BarLayout.dockSide === value }
                                        onSegmentClicked: function(value) { BarLayout.setSide("dock", value) }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: BarLayout.dockOn
    content: "Size"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup12
    Layout.fillWidth: true
    visible: BarLayout.dockOn
    spacing: 8
    EditRow {
        id: drawerBlock27
        autoRadius: false
        visible: true
        topRadius: drawer.edgeRadius(drawerBlock27, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock27, 1)
                                Repeater {
                                    model: BarLayout.dockOn ? [
                                        { key: "height",   label: "Height",        min: 48, max: 80, step: 2, def: 60 },
                                        { key: "iconSize", label: "Icon size",     min: 24, max: 48, step: 2, def: 32 },
                                        { key: "itemGap",  label: "Item gap",      min: 0,  max: 16, step: 1, def: 2 },
                                        { key: "blockGap", label: "Block gap",     min: 16, max: 120, step: 8, def: -1, auto: true },
                                        { key: "radius",   label: "Corner radius", min: 8,  max: 28, step: 1, def: 18 }
                                    ].concat(BarLayout.edgeShapes("bottom").indexOf("pill") >= 0
                                        ? [{ key: "pillGap", label: "Bottom gap", min: 0, max: 40, step: 1, def: BarLayout.dockPillGap }]
                                        : []) : []

                                    delegate: RowLayout {
                                        id: dockRow
                                        required property var modelData
                                        readonly property real value: BarLayout.dockSize(dockRow.modelData.key, dockRow.modelData.def)
                                        readonly property int offset: dockRow.modelData.auto ? 1 : 0
                                        readonly property bool isAuto: !!dockRow.modelData.auto && dockRow.value < 0

                                        Layout.fillWidth: true
                                        spacing: 12

                                        CustomText {
                                            Layout.preferredWidth: 110
                                            content: dockRow.modelData.label
                                            size: 12
                                        }
                                        M3Slider {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            stepCount: Math.round((dockRow.modelData.max - dockRow.modelData.min) / dockRow.modelData.step) + 1 + dockRow.offset
                                            currentStep: dockRow.isAuto ? 0
                                                : Math.round((dockRow.value - dockRow.modelData.min) / dockRow.modelData.step) + dockRow.offset
                                            valueText: dockRow.modelData.auto && currentStep === 0 ? "Auto"
                                                : String(dockRow.modelData.min + (currentStep - dockRow.offset) * dockRow.modelData.step)
                                            onStepChanged: s => {
                                                const v = dockRow.modelData.auto && s === 0 ? -1
                                                    : dockRow.modelData.min + (s - dockRow.offset) * dockRow.modelData.step
                                                if (v !== dockRow.value)
                                                    BarLayout.setDockSize(dockRow.modelData.key, v)
                                            }
                                        }
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                            content: dockRow.isAuto ? "Auto" : dockRow.value + "px"
                                            size: 12
                                            customColor: Colors.outline
                                        }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: BarLayout.dockOn
    content: "Blocks"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup14
    Layout.fillWidth: true
    visible: BarLayout.dockOn
    spacing: 8
    EditRow {
        id: drawerBlock29
        autoRadius: false
        visible: BarLayout.dockOn
        topRadius: drawer.edgeRadius(drawerBlock29, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock29, 1)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: BarLayout.dockOn

                                    CustomText { Layout.fillWidth: true; content: "Add block"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                                    M3ButtonGroup {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        fillWidth: true
                                        iconSize: 16
                                        textSize: 12
                                        model: [{ value: "left", label: "Left", icon: "add" }, { value: "center", label: "Centre", icon: "add" }, { value: "right", label: "Right", icon: "add" }]
                                        activeCheck: function(v) { return false }
                                        onSegmentClicked: function(v) { BarLayout.addBlock(v, "bottom") }
                                    }
                                }
    }
}

EditHeading {
    Layout.fillWidth: true
    Layout.topMargin: 10
    visible: BarLayout.dockOn
    content: "Pinned apps"
    size: 13
    customColor: Colors.primary
}
ColumnLayout {
    id: drawerGroup15
    Layout.fillWidth: true
    visible: BarLayout.dockOn
    spacing: 8
    EditRow {
        id: drawerBlock30
        autoRadius: false
        visible: BarLayout.dockOn
        topRadius: drawer.edgeRadius(drawerBlock30, -1)
        bottomRadius: drawer.edgeRadius(drawerBlock30, 1)
                                ColumnLayout {
                                    id: pinSection
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    spacing: 8
                                    visible: BarLayout.dockOn

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
                                                source: Quickshell.iconPath(pinRow.modelData.icon, "image-missing")
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
