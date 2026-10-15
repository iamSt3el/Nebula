pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

Item {
    id: root
    anchors.fill: parent

    property real studioT: 0

    NumberAnimation {
        id: zoomIn
        target: root
        property: "studioT"
        to: 1
        duration: M3Motion.reveal.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: M3Motion.emphasizedCurve
    }

    NumberAnimation {
        id: zoomOut
        target: root
        property: "studioT"
        to: 0
        duration: M3Motion.panel.closeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: M3Motion.panel.closeCurve
    }

    function takeOpenAdd() {
        if (!GlobalStates.widgetOpenAdd)
            return
        GlobalStates.widgetOpenAdd = false
        root.pop = "add"
    }

    Component.onCompleted: {
        if (GlobalStates.widgetEditMode) {
            zoomIn.start()
            root.takeOpenAdd()
        }
    }

    Connections {
        target: GlobalStates

        function onWidgetEditModeChanged() {
            zoomIn.stop()
            zoomOut.stop()
            root.pop = ""
            if (GlobalStates.widgetEditMode) {
                zoomIn.start()
                root.takeOpenAdd()
            } else {
                zoomOut.start()
            }
        }

        function onWidgetSettingsKeyChanged() {
            if (root.pop === "style" || root.pop === "options") root.pop = ""
        }
    }

    visible: root.studioT > 0.002
    enabled: GlobalStates.widgetEditMode
    opacity: EditSession.peek ? 0 : 1
    Behavior on opacity { EffectsAnim { speed: "fast" } }

    readonly property real stageScale: 1
    readonly property real stageX: 0
    readonly property real stageY: 0

    Binding {
        target: GlobalStates
        property: "widgetStageScale"
        value: root.stageScale
    }

    Binding {
        target: GlobalStates
        property: "widgetStageOrigin"
        value: Qt.point(root.stageX, root.stageY)
    }

    function band(a, b) {
        return Math.max(0, Math.min(1, (root.studioT - a) / (b - a)))
    }

    readonly property real capsuleT: root.band(0.0, 0.5)
    readonly property real addT: root.band(0.2, 0.8)

    property string pop: ""

    readonly property string selKey: GlobalStates.widgetSettingsKey

    readonly property var target: {
        const hosts = WidgetLayout.hosts
        for (let i = hosts.length - 1; i >= 0; i--)
            if (hosts[i].configKey === root.selKey)
                return hosts[i]
        return null
    }

    readonly property var dragHost: {
        const hosts = WidgetLayout.hosts
        for (let i = 0; i < hosts.length; i++)
            if (hosts[i].dragging)
                return hosts[i]
        return null
    }

    readonly property var family: root.selKey !== "" ? WidgetCatalog.familyFor(root.selKey) : null
    readonly property bool hasStyles: root.family !== null && root.family.items.length > 1
                                      && root.family.items[0].styleKey !== undefined

    readonly property var activeItem: {
        if (!root.family)
            return null
        for (let i = 0; i < root.family.items.length; i++)
            if (root.family.items[i].key === root.selKey && WidgetCatalog.isActive(root.family.items[i]))
                return root.family.items[i]
        return root.family.items[0]
    }

    readonly property string selTitle: !root.activeItem ? ""
        : root.hasStyles ? root.activeItem.label + " · " + root.family.section : root.activeItem.label
    readonly property bool locked: root.selKey !== "" && (SettingsConfig.widgets[root.selKey + "Locked"] ?? false)

    readonly property var sections: WidgetCatalog.catalog
    readonly property int sectionIndex: Math.max(0, Math.min(GlobalStates.widgetSection, root.sections.length - 1))

    readonly property string filter: GlobalStates.editAddQuery
    readonly property string needle: root.filter.trim().toLowerCase()
    readonly property bool searching: root.needle !== ""

    readonly property var rows: {
        const out = []
        if (root.searching) {
            for (let s = 0; s < root.sections.length; s++) {
                const sec = root.sections[s]
                for (let i = 0; i < sec.items.length; i++) {
                    const it = sec.items[i]
                    if (it.label.toLowerCase().indexOf(root.needle) >= 0
                        || sec.section.toLowerCase().indexOf(root.needle) >= 0)
                        out.push({ entry: it, section: sec.section })
                }
            }
            return out
        }
        const sec = root.sections[root.sectionIndex]
        for (let i = 0; i < sec.items.length; i++)
            out.push({ entry: sec.items[i], section: sec.section })
        return out
    }

    function activate(entry, size) {
        if (WidgetCatalog.isActive(entry)) {
            GlobalStates.widgetSettingsKey = entry.key
        } else if (WidgetCatalog.familyOn(entry)) {
            WidgetCatalog.selectStyle(entry)
            GlobalStates.widgetSettingsKey = entry.key
        } else {
            WidgetCatalog.place(entry, size.width, size.height)
            GlobalStates.widgetSettingsKey = entry.key
        }
        root.pop = ""
    }

    function setSpan(c, r) {
        const t = root.target
        if (!t)
            return
        const patch = {}
        patch[t.configKey + "W"] = Math.max(t.minSpan.width, Math.min(t.maxSpan.width, c))
        patch[t.configKey + "H"] = Math.max(t.minSpan.height, Math.min(t.maxSpan.height, r))
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function toggleLock() {
        if (root.selKey === "")
            return
        const patch = {}
        patch[root.selKey + "Locked"] = !root.locked
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function removeSelected() {
        const key = root.selKey
        root.pop = ""
        GlobalStates.widgetSettingsKey = ""
        WidgetCatalog.remove(key)
    }

    function closePop() {
        if (GlobalStates.editKeysOpen) {
            GlobalStates.editKeysOpen = false
            return true
        }
        if (capRow.closeAll())
            return true
        if (root.pop !== "") {
            root.pop = ""
            return true
        }
        return false
    }

    function undo() { EditSession.undo() }
    function redo() { EditSession.redo() }

    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property bool lit: false
        property bool danger: false
        property bool filled: false
        property bool usable: true
        property int box: 40
        signal clicked

        implicitHeight: pill.box
        implicitWidth: pill.label !== "" ? pillRow.implicitWidth + (pill.icon !== "" ? 30 : 32) : pill.box
        radius: pillArea.pressed ? 12 : pill.box / 2
        opacity: pill.usable ? 1 : 0.38
        color: pill.filled ? Colors.primary
            : pill.lit ? Colors.secondaryContainer
            : pillArea.containsMouse && pill.usable ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            MaterialIconSymbol {
                visible: pill.icon !== ""
                content: pill.icon
                iconSize: 19
                customColor: pill.filled ? Colors.primaryText
                    : pill.danger ? Colors.error
                    : pill.lit ? Colors.secondaryContainerText : Colors.surfaceText
            }

            CustomText {
                visible: pill.label !== ""
                content: pill.label
                size: 13
                weight: 600
                customColor: pill.filled ? Colors.primaryText
                    : pill.danger ? Colors.error
                    : pill.lit ? Colors.secondaryContainerText : Colors.surfaceText
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

    component Glass: Rectangle {
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.18)
    }

    component SectionLabel: CustomText {
        size: 13
        weight: 500
        customColor: Colors.primary
    }

    MouseArea {
        anchors.fill: parent
        visible: root.pop !== ""
        onClicked: root.pop = ""
    }

    Item {
        id: guides
        anchors.fill: parent
        visible: root.dragHost !== null

        readonly property var lines: {
            const d = root.dragHost
            if (!d)
                return { v: [], h: [], gaps: [] }
            const L = d.landing
            const a = { l: L.x, r: L.x + d.width, t: L.y, b: L.y + d.height,
                        cx: L.x + d.width / 2, cy: L.y + d.height / 2 }
            const v = [], h = [], gaps = []
            let gapR = null, gapL = null
            const hosts = WidgetLayout.hosts
            for (let i = 0; i < hosts.length; i++) {
                const o = hosts[i]
                if (o === d || !o.visible)
                    continue
                const b = { l: o.homeX, r: o.homeX + o.width, t: o.homeY, b: o.homeY + o.height,
                            cx: o.homeX + o.width / 2, cy: o.homeY + o.height / 2 }
                for (const ka of ["l", "r", "cx"])
                    for (const kb of ["l", "r", "cx"])
                        if (Math.abs(a[ka] - b[kb]) < 1 && v.indexOf(a[ka]) < 0) v.push(a[ka])
                for (const ka of ["t", "b", "cy"])
                    for (const kb of ["t", "b", "cy"])
                        if (Math.abs(a[ka] - b[kb]) < 1 && h.indexOf(a[ka]) < 0) h.push(a[ka])
                const overlapY = a.t < b.b && b.t < a.b
                if (overlapY && b.l >= a.r && (gapR === null || b.l - a.r < gapR.w))
                    gapR = { x: a.r, w: b.l - a.r, y: (Math.max(a.t, b.t) + Math.min(a.b, b.b)) / 2 }
                if (overlapY && b.r <= a.l && (gapL === null || a.l - b.r < gapL.w))
                    gapL = { x: b.r, w: a.l - b.r, y: (Math.max(a.t, b.t) + Math.min(a.b, b.b)) / 2 }
            }
            const mid = WidgetSizes.screenSize
            if (Math.abs(a.cx - mid.x / 2) < 1 && v.indexOf(a.cx) < 0) v.push(a.cx)
            if (Math.abs(a.cy - mid.y / 2) < 1 && h.indexOf(a.cy) < 0) h.push(a.cy)
            if (gapR && gapR.w <= 240) gaps.push(gapR)
            if (gapL && gapL.w <= 240) gaps.push(gapL)
            return { v: v, h: h, gaps: gaps }
        }

        Repeater {
            model: guides.lines.v
            Rectangle {
                required property real modelData
                x: root.stageX + modelData * root.stageScale - 0.75
                width: 1.5
                height: guides.height
                color: Qt.alpha(Colors.tertiary, 0.85)
            }
        }

        Repeater {
            model: guides.lines.h
            Rectangle {
                required property real modelData
                y: root.stageY + modelData * root.stageScale - 0.75
                height: 1.5
                width: guides.width
                color: Qt.alpha(Colors.tertiary, 0.85)
            }
        }

        Repeater {
            model: guides.lines.gaps
            Item {
                id: gapMark
                required property var modelData
                x: root.stageX + modelData.x * root.stageScale
                y: root.stageY + modelData.y * root.stageScale
                width: modelData.w * root.stageScale

                Rectangle {
                    width: parent.width
                    height: 1.5
                    color: Colors.tertiary
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    width: gapText.implicitWidth + 14
                    height: 20
                    radius: 8
                    color: Colors.tertiary

                    CustomText {
                        id: gapText
                        anchors.centerIn: parent
                        content: Math.round(gapMark.modelData.w)
                        size: 11
                        weight: 700
                        customColor: Colors.tertiaryText
                    }
                }
            }
        }
    }

    Glass {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        y: GlobalStates.editTopInset + 16 - 30 * (1 - root.capsuleT)
        opacity: root.capsuleT
        height: 56
        width: capRow.implicitWidth + 12
        radius: 28

        EditCapsuleRow {
            id: capRow
            anchors.centerIn: parent
            addLabel: "Add"
            addLit: root.pop === "add"
            actions: [
                { key: "tidy", icon: "auto_awesome_motion", label: "Tidy" },
                { key: "look", icon: "palette", label: "Look", lit: root.pop === "look" }
            ]
            onLogo: {
                GlobalStates.closeEdit()
                GlobalStates.settingsPage = 9
                GlobalStates.settingsOpen = true
            }
            onAdd: {
                if (root.pop === "add") {
                    root.pop = ""
                    return
                }
                GlobalStates.widgetSettingsKey = ""
                root.pop = "add"
            }
            onAction: key => {
                if (key === "tidy")
                    WidgetLayout.tidy()
                else if (key === "look")
                    root.pop = root.pop === "look" ? "" : "look"
            }
        }
    }

    EditHistoryCard {
        z: 5
        open: capRow.historyOpen && GlobalStates.widgetEditMode
        x: Math.max(12, Math.min(root.width - width - 12, capsule.x + capsule.width / 2 - width / 2))
        y: capsule.y + capsule.height + 10
        onPicked: capRow.historyOpen = false
    }

    Glass {
        id: lookCard
        visible: root.pop === "look"
        anchors.horizontalCenter: capsule.horizontalCenter
        anchors.top: capsule.bottom
        anchors.topMargin: 10
        width: 340
        height: lookBody.implicitHeight + 36
        radius: 26

        ColumnLayout {
            id: lookBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SectionLabel { content: "Card surface" }

                CustomCard {
                    autoRadius: false
                M3ButtonGroup {
                    Layout.fillWidth: true
                    fillWidth: true
                    model: [
                        { value: "flat",    label: "Solid", icon: "square" },
                        { value: "frosted", label: "Frost", icon: "blur_on" }
                    ]
                    activeCheck: function(v) { return WidgetSizes.cardStyle === v }
                    onSegmentClicked: function(v) {
                        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { cardStyle: v })
                    }
                }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: WidgetSizes.cardStyle !== "flat"

                SectionLabel { content: "Card opacity" }

                CustomCard {
                    autoRadius: false
                M3Slider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    stepCount: 5
                    stepLabels: ["clear", "frosted", "hazy", "light", "solid"]
                    currentStep: {
                        const vals = [0.30, 0.45, 0.60, 0.75, 0.90]
                        const cur = SettingsConfig.widgets.cardOpacity ?? 0.60
                        let best = 0
                        for (let i = 1; i < vals.length; i++)
                            if (Math.abs(vals[i] - cur) < Math.abs(vals[best] - cur)) best = i
                        return best
                    }
                    onStepChanged: step => {
                        const vals = [0.30, 0.45, 0.60, 0.75, 0.90]
                        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { cardOpacity: vals[step] })
                    }
                }
                }
            }
        }
    }

    Glass {
        id: toolbar
        readonly property var t: root.target
        readonly property bool shown: t !== null && root.dragHost === null && !t.resizing
                                      && root.pop !== "add"
        readonly property real tx: t ? root.stageX + t.x * root.stageScale : 0
        readonly property real ty: t ? root.stageY + t.y * root.stageScale : 0
        readonly property real tw: t ? t.width * root.stageScale : 0
        readonly property real th: t ? t.height * root.stageScale : 0
        readonly property bool below: toolbar.ty + toolbar.th + 18 + height < root.height - 90

        visible: toolbar.shown
        opacity: toolbar.shown ? 1 : 0
        x: Math.max(12, Math.min(root.width - width - 12, toolbar.tx + toolbar.tw / 2 - width / 2))
        y: toolbar.below ? toolbar.ty + toolbar.th + 18 : Math.max(12, toolbar.ty - height - 18)
        height: 52
        width: toolRow.implicitWidth + 12
        radius: 26

        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 2

            Rectangle {
                id: styleButton
                implicitHeight: 40
                implicitWidth: styleRow.implicitWidth + 22
                radius: 20
                color: root.pop === "style" ? Colors.secondaryContainer
                    : styleArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: styleRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        color: Colors.primaryContainer

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: (root.family && root.family.icon) ? root.family.icon : "widgets"
                            iconSize: 15
                            customColor: Colors.primaryContainerText
                        }
                    }

                    CustomText {
                        content: root.selTitle
                        size: 13
                        weight: 600
                    }

                    MaterialIconSymbol {
                        visible: root.hasStyles
                        content: root.pop === "style" ? "expand_less" : "expand_more"
                        iconSize: 18
                        customColor: Colors.surfaceVariantText
                    }
                }

                MouseArea {
                    id: styleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.hasStyles
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pop = root.pop === "style" ? "" : "style"
                }
            }

            Rectangle {
                id: sizeGroup
                readonly property var t: root.target
                readonly property bool sizable: t !== null && t.resizable
                    && (t.minSpan.width !== t.maxSpan.width || t.minSpan.height !== t.maxSpan.height)
                readonly property var presets: {
                    if (!sizable)
                        return []
                    const m = { label: "M", c: t.defaultSpan.width, r: t.defaultSpan.height }
                    const sm = { label: "S", c: t.minSpan.width, r: t.minSpan.height }
                    const lg = { label: "L", c: Math.min(t.maxSpan.width, t.defaultSpan.width + 1),
                                 r: Math.min(t.maxSpan.height, t.defaultSpan.height + 1) }
                    const out = []
                    if (sm.c !== m.c || sm.r !== m.r) out.push(sm)
                    out.push(m)
                    if (lg.c !== m.c || lg.r !== m.r) out.push(lg)
                    return out
                }
                visible: sizable
                Layout.leftMargin: 4
                implicitHeight: 40
                implicitWidth: sizeRow.implicitWidth + 6
                radius: 20
                color: Colors.surfaceContainerHigh

                RowLayout {
                    id: sizeRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: sizeGroup.presets

                        Rectangle {
                            id: preset
                            required property var modelData
                            readonly property bool on: sizeGroup.t !== null
                                && sizeGroup.t.cols === preset.modelData.c && sizeGroup.t.rows === preset.modelData.r
                            implicitWidth: 36
                            implicitHeight: 34
                            radius: 17
                            color: preset.on ? Colors.secondaryContainer
                                : presetArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"

                            CustomText {
                                anchors.centerIn: parent
                                content: preset.modelData.label
                                size: 12
                                weight: preset.on ? 700 : 500
                                customColor: preset.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                            }

                            MouseArea {
                                id: presetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setSpan(preset.modelData.c, preset.modelData.r)
                            }
                        }
                    }

                    CustomText {
                        Layout.leftMargin: 4
                        Layout.rightMargin: 8
                        content: sizeGroup.t ? sizeGroup.t.cols + "×" + sizeGroup.t.rows : ""
                        size: 11
                        weight: 600
                        customColor: Colors.outline
                    }
                }
            }

            Divider { Layout.leftMargin: 6; Layout.rightMargin: 4 }

            Pill {
                icon: "tune"
                visible: root.target !== null && root.target.optionsComponent !== null
                lit: root.pop === "options"
                onClicked: root.pop = root.pop === "options" ? "" : "options"
            }
            Pill {
                icon: "restart_alt"
                onClicked: if (root.target) WidgetCatalog.resetLayout(root.target.configKey)
            }
            Pill {
                icon: root.locked ? "lock" : "lock_open"
                lit: root.locked
                onClicked: root.toggleLock()
            }
            Pill {
                icon: "delete"
                danger: true
                onClicked: root.removeSelected()
            }
        }
    }

    Glass {
        id: styleCard
        visible: root.pop === "style" && toolbar.visible && root.hasStyles
        x: Math.max(12, Math.min(root.width - width - 12, toolbar.x))
        y: toolbar.below ? toolbar.y + toolbar.height + 8 : toolbar.y - height - 8
        width: 240
        height: styleCol.implicitHeight + 16
        radius: 22

        ColumnLayout {
            id: styleCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: root.hasStyles ? root.family.items : []

                Rectangle {
                    id: styleRowItem
                    required property var modelData
                    readonly property bool on: WidgetCatalog.isActive(styleRowItem.modelData)
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 14
                    color: styleRowItem.on ? Colors.secondaryContainer
                        : styleRowArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        CustomText {
                            Layout.fillWidth: true
                            content: styleRowItem.modelData.label
                            size: 13
                            weight: styleRowItem.on ? 700 : 500
                            customColor: styleRowItem.on ? Colors.secondaryContainerText : Colors.surfaceText
                        }

                        MaterialIconSymbol {
                            visible: styleRowItem.on
                            content: "check"
                            iconSize: 17
                            customColor: Colors.secondaryContainerText
                        }
                    }

                    MouseArea {
                        id: styleRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            WidgetCatalog.selectStyle(styleRowItem.modelData)
                            GlobalStates.widgetSettingsKey = styleRowItem.modelData.key
                        }
                    }
                }
            }
        }
    }

    Glass {
        id: optionsCard
        visible: root.pop === "options" && toolbar.visible
        readonly property real underY: toolbar.y + toolbar.height + 8
        readonly property real overY: toolbar.y - height - 8
        readonly property bool fitsUnder: optionsCard.underY + height <= root.height - 12
        readonly property bool fitsOver: optionsCard.overY >= 12
        readonly property real leftX: toolbar.tx - width - 16
        readonly property real rightX: toolbar.tx + toolbar.tw + 16
        readonly property bool side: !optionsCard.fitsUnder
            && (optionsCard.leftX >= 12 || optionsCard.rightX + width <= root.width - 12 || !optionsCard.fitsOver)
        x: !optionsCard.side ? Math.max(12, Math.min(root.width - width - 12, toolbar.x + toolbar.width - width))
            : optionsCard.leftX >= 12 ? optionsCard.leftX
            : Math.min(root.width - width - 12, optionsCard.rightX)
        y: optionsCard.fitsUnder ? optionsCard.underY
            : optionsCard.side ? Math.max(12, Math.min(root.height - height - 12, toolbar.ty))
            : optionsCard.overY
        width: 340
        height: Math.min(root.height * 0.6, optFlick.contentHeight + 36)
        radius: 26

        Flickable {
            id: optFlick
            anchors.fill: parent
            anchors.margins: 18
            clip: true
            contentWidth: width
            contentHeight: optBody.implicitHeight
            ScrollBar.vertical: CustomScrollBar {}

            ColumnLayout {
                id: optBody
                width: optFlick.width
                spacing: 10

                SectionLabel { content: "Options" }

                Loader {
                    Layout.fillWidth: true
                    active: optionsCard.visible
                    sourceComponent: root.target ? root.target.optionsComponent : null
                }
            }
        }
    }

    Glass {
        id: sheet
        readonly property bool open: root.pop === "add"
        onOpenChanged: if (sheet.open) Qt.callLater(() => trayInput.forceActiveFocus())
        property real openT: sheet.open ? 1 : 0
        Behavior on openT { SpatialAnim { speed: "default" } }

        visible: sheet.openT > 0.01
        opacity: Math.min(1, sheet.openT * 1.6)
        width: Math.min(1180, root.width - 64)
        height: 312
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 58 - 20 - height + 60 * (1 - sheet.openT)
        radius: 30

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                EditAddTabs {
                    current: "widgets"
                }

                CustomText {
                    Layout.fillWidth: true
                    content: "click one to place it in the next free spot"
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
                    border.color: trayInput.activeFocus ? Qt.alpha(Colors.primary, 0.7) : "transparent"

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
                            id: trayInput
                            Layout.fillWidth: true
                            clip: true
                            text: root.filter
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            font.pixelSize: 13
                            font.weight: 500
                            color: Colors.surfaceText
                            selectionColor: Qt.alpha(Colors.primary, 0.4)
                            selectedTextColor: Colors.surfaceText
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: if (GlobalStates.editAddQuery !== trayInput.text) GlobalStates.editAddQuery = trayInput.text
                            onActiveFocusChanged: GlobalStates.widgetTextFocus = trayInput.activeFocus
                            Keys.onEscapePressed: {
                                if (trayInput.text !== "") {
                                    trayInput.text = ""
                                    return
                                }
                                trayInput.focus = false
                                root.pop = ""
                            }

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: trayInput.text === "" && !trayInput.activeFocus
                                content: "Search parts, widgets and tiles"
                                size: 13
                                customColor: Colors.outline
                            }
                        }
                    }
                }

                Pill {
                    icon: "close"
                    onClicked: root.pop = ""
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                clip: true
                contentWidth: chipRow.implicitWidth
                contentHeight: 34
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: chipRow
                    height: 34
                    spacing: 6

                    Repeater {
                        model: root.sections

                        delegate: Rectangle {
                            id: sectionChip
                            required property var modelData
                            required property int index

                            readonly property bool on: !root.searching && sectionChip.index === root.sectionIndex

                            implicitWidth: sectionRow.implicitWidth + 24
                            implicitHeight: 32
                            radius: 16
                            color: sectionChip.on ? Colors.secondaryContainer
                                : sectionArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                            Behavior on color { EffectsColorAnim {} }

                            RowLayout {
                                id: sectionRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialIconSymbol {
                                    content: sectionChip.modelData.icon ?? "widgets"
                                    iconSize: 15
                                    customColor: sectionChip.on ? Colors.secondaryContainerText : Colors.outline
                                }

                                CustomText {
                                    content: sectionChip.modelData.section
                                    size: 12
                                    weight: sectionChip.on ? 700 : 500
                                    customColor: sectionChip.on ? Colors.secondaryContainerText : Colors.surfaceText
                                }
                            }

                            MouseArea {
                                id: sectionArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    GlobalStates.editAddQuery = ""
                                    GlobalStates.widgetSection = sectionChip.index
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: stripFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: strip.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: strip
                    height: stripFlick.height
                    spacing: 12

                    Repeater {
                        model: sheet.visible ? root.rows : []

                        delegate: Rectangle {
                            id: trayCard
                            required property var modelData

                            readonly property var entry: trayCard.modelData.entry
                            readonly property bool active: WidgetCatalog.isActive(trayCard.entry)
                            readonly property bool famOn: WidgetCatalog.familyOn(trayCard.entry)

                            Layout.preferredWidth: 196
                            Layout.fillHeight: true
                            radius: 22
                            color: cardArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                            border.width: trayCard.active ? 1.5 : 0
                            border.color: Qt.alpha(Colors.primary, 0.6)
                            Behavior on color { EffectsColorAnim {} }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Rectangle {
                                    id: cardThumb
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    clip: true
                                    color: Colors.surfaceContainerLow

                                    Loader {
                                        id: cardPreview
                                        sourceComponent: trayCard.entry.comp
                                        transformOrigin: Item.TopLeft
                                        scale: (item && item.implicitWidth > 0 && item.implicitHeight > 0)
                                            ? Math.min((cardThumb.width - 12) / item.implicitWidth,
                                                       (cardThumb.height - 12) / item.implicitHeight, 1)
                                            : 1
                                        x: (cardThumb.width - width * scale) / 2
                                        y: (cardThumb.height - height * scale) / 2
                                    }

                                    Rectangle {
                                        visible: trayCard.active || trayCard.famOn
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 6
                                        width: badgeText.implicitWidth + 14
                                        height: 20
                                        radius: 8
                                        color: Qt.alpha(Colors.surface, 0.85)

                                        CustomText {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            content: trayCard.active ? "On your desk" : "Swap style"
                                            size: 10
                                            weight: 700
                                            customColor: Colors.primary
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: trayCard.entry.label
                                        size: 13
                                        weight: 600
                                    }

                                    Rectangle {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 14
                                        color: trayCard.active ? Colors.primary : Colors.secondaryContainer

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: trayCard.active ? "check" : trayCard.famOn ? "swap_horiz" : "add"
                                            iconSize: 16
                                            customColor: trayCard.active ? Colors.primaryText : Colors.secondaryContainerText
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cardArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const size = (cardPreview.item && cardPreview.item.implicitWidth > 0)
                                        ? Qt.size(cardPreview.item.implicitWidth, cardPreview.item.implicitHeight)
                                        : WidgetCatalog.tileSize(trayCard.entry)
                                    root.activate(trayCard.entry, size)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        visible: root.rows.length === 0

                        CustomText {
                            anchors.centerIn: parent
                            content: "Nothing matches that"
                            size: 12
                            customColor: Colors.outline
                        }
                    }
                }
            }
        }
    }

    EditKeysSheet {
        z: 400
        desktop: true
    }
}
