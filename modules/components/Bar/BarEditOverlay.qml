pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit
import qs.modules.components.Widgets
import qs.modules.components.Bar

Scope {
    id: scope

    readonly property bool isOverlay: (SettingsConfig.general.editMode ?? "panel") === "overlay"
    readonly property bool shouldOpen: GlobalStates.editMode && scope.isOverlay
    property bool loaded: false

    Connections {
        target: GlobalStates
        function onEditModeChanged() {
            if (scope.shouldOpen) {
                unloadTimer.stop()
                scope.loaded = true
            } else {
                unloadTimer.restart()
            }
        }
    }

    Connections {
        target: SettingsConfig
        function onGeneralChanged() {
            if (scope.shouldOpen) {
                unloadTimer.stop()
                scope.loaded = true
            }
        }
    }

    Timer {
        id: unloadTimer
        interval: 10000
        onTriggered: if (!scope.shouldOpen) scope.loaded = false
    }

    LazyLoader {
        id: loader
        activeAsync: scope.loaded

        component: PanelWindow {
            id: win

            property real openProgress: scope.shouldOpen ? 1 : 0
            Behavior on openProgress { SpatialAnim { speed: "fast" } }

            visible: scope.shouldOpen || win.openProgress > 0.01
            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }

            WlrLayershell.namespace: "quickshell:edit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            HyprlandFocusGrab {
                windows: [win]
                active: scope.shouldOpen
                onCleared: if (scope.shouldOpen && !cardHover.hovered) GlobalStates.closeEdit()
            }

            // Scrim — click outside the card to dismiss
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.surface, 0.78)
                opacity: win.openProgress

                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.closeEdit()
                }
            }

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.margins: 32
                radius: 28
                color: Colors.surface
                border.width: 1
                border.color: Qt.alpha(Colors.outline, 0.18)
                clip: true
                opacity: win.openProgress
                scale: 0.96 + 0.04 * win.openProgress

                HoverHandler {
                    id: cardHover
                }

                MouseArea {
                    anchors.fill: parent
                }

                // Keyboard shortcuts
                Item {
                    anchors.fill: parent
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            GlobalStates.closeEdit()
                            event.accepted = true
                        } else if (event.key === Qt.Key_1) {
                            card.setTab("parts")
                            event.accepted = true
                        } else if (event.key === Qt.Key_2) {
                            card.setTab("widgets")
                            event.accepted = true
                        } else if (event.key === Qt.Key_3) {
                            card.setTab("panels")
                            event.accepted = true
                        } else if (event.key === Qt.Key_4) {
                            card.setTab("settings")
                            event.accepted = true
                        }
                    }
                }

                // ── State and Context ─────────────────────────────────────
                property string currentTab: GlobalStates.editLayer === "desktop" ? "widgets" : "parts"
                property string partGroup: "All"
                property string widgetSection: "All"
                property string selectedPanel: "calendar"
                property string selectedEdge: "top"

                function setTab(tab) {
                    card.currentTab = tab
                    if (tab === "parts") {
                        GlobalStates.editLayer = "edges"
                    } else if (tab === "widgets") {
                        GlobalStates.editLayer = "desktop"
                    }
                }

                readonly property string filter: GlobalStates.editAddQuery
                readonly property string needle: card.filter.trim().toLowerCase()

                readonly property var parts: BarLayout.hiddenItems.filter(id => {
                    const e = BarLayout.entry(id)
                    if (!e) return false
                    if (card.needle !== "")
                        return e.label.toLowerCase().indexOf(card.needle) >= 0 || (e.group ?? "").toLowerCase().indexOf(card.needle) >= 0
                    return card.partGroup === "All" || e.group === card.partGroup
                })

                readonly property var widgetRows: {
                    const out = []
                    const sections = WidgetCatalog.catalog
                    for (let s = 0; s < sections.length; s++) {
                        const sec = sections[s]
                        if (card.widgetSection !== "All" && sec.section !== card.widgetSection)
                            continue
                        for (let i = 0; i < sec.items.length; i++) {
                            const it = sec.items[i]
                            if (card.needle === "" || it.label.toLowerCase().indexOf(card.needle) >= 0 || sec.section.toLowerCase().indexOf(card.needle) >= 0)
                                out.push({ entry: it, section: sec.section })
                        }
                    }
                    return out
                }

                readonly property var panelList: [
                    { item: "clock",         kind: "calendar",      label: "Calendar",      icon: "calendar_month" },
                    { item: "weather",       kind: "weather",       label: "Weather",       icon: "partly_cloudy_day" },
                    { item: "notifications", kind: "notifications", label: "Notifications", icon: "notifications" },
                    { item: "dashboard",     kind: "dashboard",     label: "Dashboard",     icon: "space_dashboard" },
                    { item: "launcher",      kind: "launcher",      label: "Apps",          icon: "apps" },
                    { item: "wallpaper",     kind: "wallpaper",     label: "Wallpaper",     icon: "wallpaper" },
                    { item: "clipboard",     kind: "clipboard",     label: "Clipboard",     icon: "content_paste" },
                    { item: "popups",        kind: "notifPopup",    label: "Popups",        icon: "notifications_active" },
                    { item: "osd",           kind: "osd",           label: "OSD",           icon: "volume_up" }
                ]

                readonly property var currentPanelData: card.panelList.find(p => p.kind === card.selectedPanel || p.item === card.selectedPanel) ?? card.panelList[0]

                property QtObject editor: QtObject {
                    property string mode: ""
                    property string itemId: ""
                    property string fromBlock: ""
                    property int fromIndex: -1
                    property string label: ""
                    property string icon: ""
                    property string selectedItem: ""
                    property string selectedBlock: ""
                    property bool panelStage: false
                    property string drawerMode: ""
                    property rect drawerFrom: Qt.rect(0, 0, 0, 0)
                    function beginItem(id, blockId, idx, w) {
                        mode = "item"; itemId = id; fromBlock = blockId; fromIndex = idx;
                    }
                    function update(x, y) {}
                    function finish() { mode = "" }
                    function cancel() { mode = "" }
                }

                function addTarget(id) {
                    const real = BarLayout.allBlocks.filter(b => b.id !== "__sys")
                    if (card.editor.selectedBlock !== "") {
                        const blk = real.find(b => b.id === card.editor.selectedBlock)
                        if (blk) return { block: blk.id, index: blk.items.length }
                    }
                    if (card.editor.selectedItem !== "") {
                        const own = real.find(b => b.items.indexOf(card.editor.selectedItem) >= 0)
                        if (own) return { block: own.id, index: own.items.indexOf(card.editor.selectedItem) + 1 }
                    }
                    const entry = BarLayout.entry(id)
                    const dockish = !!entry && entry.id.indexOf("dock") === 0
                    const onEdge = real.filter(b => b.edge === (dockish ? "bottom" : "top"))
                    const blocks = onEdge.length > 0 ? onEdge : real
                    const pref = blocks.find(b => b.anchor === "right") ?? blocks.find(b => b.anchor === "center") ?? blocks[0]
                    return pref ? { block: pref.id, index: pref.items.length } : null
                }

                function addItem(id) {
                    const tgt = card.addTarget(id)
                    if (!tgt) return
                    Qt.callLater(() => {
                        BarLayout.moveItem(id, tgt.block, tgt.index)
                        if (!BarLayout.entry(id) || !BarLayout.entry(id).multi)
                            card.editor.selectedItem = id
                    })
                }

                function panelOf(id) {
                    const k = BarLayout.panelFor(id)
                    if (k !== "")
                        return card.panelList.find(p => p.kind === k) ?? null
                    const base = id ? BarLayout.baseId(id) : ""
                    return card.panelList.find(p => p.item === base && (p.kind === "notifPopup" || p.kind === "osd")) ?? null
                }

                function hostOf(p) {
                    const placed = id => id !== "" && BarLayout.isPlaced(id)
                    const gen = SettingsConfig.general ?? {}
                    switch (p.kind) {
                    case "calendar":
                    case "weather":
                    case "notifications":
                    case "dashboard":
                        return placed(p.item) ? { type: "item", item: p.item } : { type: "none", item: "" }
                    case "launcher":
                        return BarLayout.launcherItemHost ? { type: "item", item: "launcher" } : { type: "center", item: "" }
                    case "wallpaper":
                    case "clipboard": {
                        const mode = p.kind === "wallpaper" ? gen.wallpaperPanelMode : gen.clipboardPanelMode
                        if ((mode ?? "dock") === "center")
                            return { type: "center", item: "" }
                        return BarLayout.panelItemHost(p.kind) ? { type: "item", item: p.item } : { type: "sys", item: "" }
                    }
                    case "notifPopup":
                        if (BarLayout.popupMode === "item" || (BarLayout.popupMode === "island" && BarLayout.popupHostItem !== ""))
                            return { type: "item", item: BarLayout.popupHostItem }
                        return BarLayout.popupMode === "icon" ? { type: "icons", item: "" } : { type: "corner", item: "" }
                    case "osd":
                        return BarLayout.osdHostItem !== "" ? { type: "item", item: BarLayout.osdHostItem } : { type: "sys", item: "" }
                    }
                    return { type: "none", item: "" }
                }

                function hostText(p) {
                    const h = card.hostOf(p)
                    const name = id => {
                        const e = BarLayout.entry(id)
                        return e ? e.label : id
                    }
                    switch (h.type) {
                    case "item": return h.item === p.item || BarLayout.baseId(h.item) === p.item
                        ? "From its " + name(p.item) + " item" : "From the " + name(h.item) + " item"
                    case "sys": return "Centre of the " + BarLayout.sysEdge + " edge"
                    case "center": return "Centre of the screen"
                    case "icons": return "Over the app's dock icon"
                    case "corner": return "Screen corner"
                    }
                    return "Its " + name(p.item) + " item isn't placed"
                }

                function placeChoices(kind) {
                    switch (kind) {
                    case "launcher":
                        return [{ value: "item", label: "Apps item", icon: "apps" }, { value: "center", label: "Centre", icon: "center_focus_strong" }]
                    case "wallpaper":
                    case "clipboard":
                        return [{ value: "dock", label: "Item or edge", icon: "dock_to_bottom" }, { value: "center", label: "Centre panel", icon: "center_focus_strong" }]
                    case "notifPopup":
                        return [{ value: "item", label: "Popups item", icon: "notifications_active" }, { value: "bell", label: "The bell", icon: "notifications" },
                                { value: "icons", label: "Dock icons", icon: "apps" }]
                    case "osd":
                        return [{ value: "item", label: "OSD item", icon: "volume_up" }, { value: "sys", label: "Edge centre", icon: "dock_to_bottom" }]
                    }
                    return []
                }

                function currentPlaceValue(kind) {
                    const gen = SettingsConfig.general ?? {}
                    switch (kind) {
                    case "launcher": return ServiceLauncher.position === "center" ? "center" : "item"
                    case "wallpaper": return (gen.wallpaperPanelMode ?? "dock") === "center" ? "center" : "dock"
                    case "clipboard": return (gen.clipboardPanelMode ?? "dock") === "center" ? "center" : "dock"
                    case "notifPopup":
                        return BarLayout.isPlaced("popups") ? "item" : (gen.notifPopupStyle ?? "item") === "icon" ? "icons" : "bell"
                    case "osd": return BarLayout.osdHostItem !== "" ? "item" : "sys"
                    }
                    return ""
                }

                function setPlace(kind, v) {
                    switch (kind) {
                    case "launcher":
                        BarLayout.setOption("launcher", "position", v)
                        return
                    case "wallpaper":
                    case "clipboard":
                        BarLayout.setOption(kind, "place", v)
                        return
                    case "notifPopup":
                        if (v === "item") {
                            if (!BarLayout.isPlaced("popups"))
                                card.addItem("popups")
                            return
                        }
                        BarLayout.setOption("notifications", "popupStyle", v === "icons" ? "icon" : "item")
                        if (BarLayout.isPlaced("popups"))
                            Qt.callLater(() => BarLayout.hideItem("popups"))
                        return
                    case "osd":
                        if (v === "item") {
                            if (BarLayout.osdHostItem === "")
                                card.addItem("osd")
                        } else if (BarLayout.osdHostItem !== "") {
                            const id = BarLayout.osdHostItem
                            Qt.callLater(() => BarLayout.hideItem(id))
                        }
                        return
                    }
                }

                // Stub for previews
                Item {
                    id: partStub
                    visible: false
                    readonly property bool editing: false
                    readonly property real maxWidth: 220
                    readonly property real fixedWidth: 0
                    readonly property real iconSize: 0
                    readonly property real barH: 40
                    readonly property bool vertical: false
                    function hoverOpen(kind, item) {}
                    function openPanel(kind, item) {}
                    function closePanel() {}
                }

                // ── Card Content ──────────────────────────────────────────
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    // ── Header ────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: 13
                            color: Colors.primaryContainer

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "dashboard_customize"
                                iconSize: 22
                                customColor: Colors.primaryContainerText
                            }
                        }

                        ColumnLayout {
                            spacing: -2
                            CustomText {
                                content: "Editor"
                                size: 19
                                weight: 700
                            }
                            CustomText {
                                content: "Full-screen layout and widget customizer"
                                size: 12
                                customColor: Colors.outline
                            }
                        }

                        Item { Layout.preferredWidth: 16 }

                        // Navigation Tabs
                        Rectangle {
                            implicitHeight: 40
                            implicitWidth: tabRow.implicitWidth + 8
                            radius: 20
                            color: Colors.surfaceContainerLow

                            RowLayout {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: [
                                        { id: "parts",    label: "Bar parts",    icon: "dock_to_left" },
                                        { id: "widgets",  label: "Widgets",      icon: "widgets" },
                                        { id: "panels",   label: "Panels",       icon: "view_quilt" },
                                        { id: "settings", label: "Bar settings", icon: "settings" }
                                    ]

                                    delegate: Rectangle {
                                        id: navTab
                                        required property var modelData
                                        readonly property bool on: card.currentTab === navTab.modelData.id

                                        implicitWidth: tabInner.implicitWidth + 24
                                        implicitHeight: 34
                                        radius: 17
                                        color: navTab.on ? Colors.secondaryContainer
                                            : tabArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                                        RowLayout {
                                            id: tabInner
                                            anchors.centerIn: parent
                                            spacing: 6

                                            MaterialIconSymbol {
                                                content: navTab.modelData.icon
                                                iconSize: 16
                                                customColor: navTab.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                            }
                                            CustomText {
                                                content: navTab.modelData.label
                                                size: 12
                                                weight: navTab.on ? 700 : 500
                                                customColor: navTab.on ? Colors.secondaryContainerText : Colors.surfaceText
                                            }
                                        }

                                        MouseArea {
                                            id: tabArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: card.setTab(navTab.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Search box
                        Rectangle {
                            implicitWidth: 280
                            implicitHeight: 40
                            radius: 20
                            color: Colors.surfaceContainerHigh
                            border.width: 1
                            border.color: searchInput.activeFocus ? Qt.alpha(Colors.primary, 0.7) : "transparent"

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
                                    id: searchInput
                                    Layout.fillWidth: true
                                    clip: true
                                    text: card.filter
                                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                    font.pixelSize: 13
                                    font.weight: 500
                                    color: Colors.surfaceText
                                    selectionColor: Qt.alpha(Colors.primary, 0.4)
                                    selectedTextColor: Colors.surfaceText
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: if (GlobalStates.editAddQuery !== searchInput.text) GlobalStates.editAddQuery = searchInput.text
                                    Keys.onEscapePressed: {
                                        if (searchInput.text !== "") {
                                            searchInput.text = ""
                                            return
                                        }
                                        GlobalStates.closeEdit()
                                    }

                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchInput.text === "" && !searchInput.activeFocus
                                        content: "Search parts, widgets, panels"
                                        size: 13
                                        customColor: Colors.outline
                                    }
                                }

                                MaterialIconSymbol {
                                    visible: searchInput.text !== ""
                                    content: "close"
                                    iconSize: 14
                                    customColor: Colors.outline
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: searchInput.text = ""
                                    }
                                }
                            }
                        }

                        // Undo / Redo
                        RowLayout {
                            spacing: 4

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: uArea.containsMouse && EditSession.canUndo ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                                opacity: EditSession.canUndo ? 1 : 0.38

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "undo"
                                    iconSize: 18
                                    customColor: Colors.surfaceText
                                }
                                MouseArea {
                                    id: uArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: EditSession.canUndo ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (EditSession.canUndo) EditSession.undo()
                                }
                            }

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: rArea.containsMouse && EditSession.canRedo ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                                opacity: EditSession.canRedo ? 1 : 0.38

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "redo"
                                    iconSize: 18
                                    customColor: Colors.surfaceText
                                }
                                MouseArea {
                                    id: rArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: EditSession.canRedo ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (EditSession.canRedo) EditSession.redo()
                                }
                            }
                        }

                        // Close button / Esc
                        KeyCap {
                            text: "ESC"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.closeEdit()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Qt.alpha(Colors.outlineVariant, 0.35)
                    }

                    // ── Main Content Views ────────────────────────────────
                    StackLayout {
                        id: stack
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: card.currentTab === "parts" ? 0
                                    : card.currentTab === "widgets" ? 1
                                    : card.currentTab === "panels" ? 2 : 3

                        // ── Tab 0: Bar Parts ──────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 20

                            // Category Sidebar
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.fillHeight: true
                                spacing: 4

                                CustomText {
                                    content: "Categories"
                                    size: 11
                                    weight: 700
                                    customColor: Colors.outline
                                    Layout.leftMargin: 12
                                    Layout.bottomMargin: 4
                                }

                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    contentHeight: catCol.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: CustomScrollBar {}

                                    ColumnLayout {
                                        id: catCol
                                        width: parent.width
                                        spacing: 2

                                        Repeater {
                                            model: ["All"].concat(BarLayout.groups)

                                            Rectangle {
                                                id: catBtn
                                                required property string modelData
                                                readonly property bool on: card.needle === "" && card.partGroup === catBtn.modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 36
                                                radius: 18
                                                color: catBtn.on ? Colors.secondaryContainer
                                                    : catArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : "transparent"

                                                CustomText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 14
                                                    content: catBtn.modelData
                                                    size: 13
                                                    weight: catBtn.on ? 700 : 500
                                                    customColor: catBtn.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: catArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        searchInput.text = ""
                                                        card.partGroup = catBtn.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 1
                                color: Qt.alpha(Colors.outlineVariant, 0.25)
                            }

                            // Parts Grid
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Flickable {
                                    id: partFlick
                                    anchors.fill: parent
                                    clip: true
                                    contentWidth: width
                                    contentHeight: partGrid.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: CustomScrollBar {}

                                    GridLayout {
                                        id: partGrid
                                        width: partFlick.width
                                        columns: Math.max(2, Math.floor(partFlick.width / 260))
                                        columnSpacing: 14
                                        rowSpacing: 14

                                        Repeater {
                                            model: card.parts

                                            Rectangle {
                                                id: partCard
                                                required property string modelData
                                                readonly property var entry: BarLayout.entry(partCard.modelData)
                                                readonly property bool multi: !!partCard.entry && !!partCard.entry.multi

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 126
                                                radius: 20
                                                color: partArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

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
                                                            readonly property bool wide: !!item && item.implicitWidth > partPreview.width - 24
                                                            readonly property bool usable: status === Loader.Ready && !!item
                                                                && item.implicitWidth >= 2 && item.shown !== false
                                                            x: partLoader.wide ? 12 : Math.round((partPreview.width - width) / 2)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            visible: partLoader.usable
                                                            enabled: false
                                                            asynchronous: true
                                                            active: !partCard.multi
                                                            source: active ? BarLayout.urlFor(partCard.modelData) : ""
                                                            onLoaded: {
                                                                item.host = partStub
                                                                if ("itemId" in item)
                                                                    item.itemId = partCard.modelData
                                                            }
                                                        }

                                                        MaterialIconSymbol {
                                                            anchors.centerIn: parent
                                                            visible: partCard.multi || !partLoader.usable
                                                            content: partCard.entry ? partCard.entry.icon : "widgets"
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
                                                                content: partCard.entry ? partCard.entry.label : partCard.modelData
                                                                size: 13
                                                                weight: 600
                                                            }
                                                            CustomText {
                                                                Layout.fillWidth: true
                                                                content: (partCard.entry ? partCard.entry.group : "") + (partCard.multi ? " · add many" : "")
                                                                size: 11
                                                                customColor: Colors.surfaceVariantText
                                                            }
                                                        }

                                                        EditKit.Pill {
                                                            icon: "add"
                                                            box: 32
                                                            lit: true
                                                            tip: "Add to bar"
                                                            onClicked: card.addItem(partCard.modelData)
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: partArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }
                                            }
                                        }
                                    }
                                }

                                CustomText {
                                    anchors.centerIn: parent
                                    visible: card.parts.length === 0
                                    content: card.needle !== "" ? "Nothing matches that" : "Everything here is already on your bar"
                                    size: 14
                                    customColor: Colors.outline
                                }
                            }
                        }

                        // ── Tab 1: Widgets Studio ─────────────────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 14

                            // Section Chips
                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                clip: true
                                contentWidth: wChipRow.implicitWidth
                                boundsBehavior: Flickable.StopAtBounds

                                RowLayout {
                                    id: wChipRow
                                    height: 36
                                    spacing: 6

                                    Repeater {
                                        model: ["All"].concat(WidgetCatalog.catalog.map(s => s.section))

                                        Rectangle {
                                            id: wChip
                                            required property string modelData
                                            readonly property bool on: card.widgetSection === wChip.modelData
                                            implicitWidth: wChipText.implicitWidth + 24
                                            implicitHeight: 34
                                            radius: 17
                                            color: wChip.on ? Colors.secondaryContainer
                                                : wChipArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : Colors.surfaceContainerLow

                                            CustomText {
                                                id: wChipText
                                                anchors.centerIn: parent
                                                content: wChip.modelData
                                                size: 12
                                                weight: wChip.on ? 700 : 500
                                                customColor: wChip.on ? Colors.secondaryContainerText : Colors.surfaceText
                                            }

                                            MouseArea {
                                                id: wChipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: card.widgetSection = wChip.modelData
                                            }
                                        }
                                    }
                                }
                            }

                            // Widgets Grid
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Flickable {
                                    id: widgetFlick
                                    anchors.fill: parent
                                    clip: true
                                    contentWidth: width
                                    contentHeight: widgetGrid.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: CustomScrollBar {}

                                    GridLayout {
                                        id: widgetGrid
                                        width: widgetFlick.width
                                        columns: Math.max(2, Math.floor(widgetFlick.width / 260))
                                        columnSpacing: 14
                                        rowSpacing: 14

                                        Repeater {
                                            model: card.widgetRows

                                            Rectangle {
                                                id: wCard
                                                required property var modelData

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 126
                                                radius: 20
                                                color: wCardArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 8

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 58
                                                        radius: 14
                                                        color: Colors.surface

                                                        MaterialIconSymbol {
                                                            anchors.centerIn: parent
                                                            content: wCard.modelData.entry.icon ?? "widgets"
                                                            iconSize: 26
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
                                                                content: wCard.modelData.entry.label
                                                                size: 13
                                                                weight: 600
                                                            }
                                                            CustomText {
                                                                Layout.fillWidth: true
                                                                content: wCard.modelData.section
                                                                size: 11
                                                                customColor: Colors.surfaceVariantText
                                                            }
                                                        }

                                                        EditKit.Pill {
                                                            icon: "add"
                                                            box: 32
                                                            lit: true
                                                            tip: "Place on desktop"
                                                            onClicked: {
                                                                const size = WidgetCatalog.tileSize(wCard.modelData.entry)
                                                                WidgetCatalog.place(wCard.modelData.entry, size.width, size.height)
                                                                GlobalStates.widgetSettingsKey = wCard.modelData.entry.key
                                                            }
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: wCardArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }
                                            }
                                        }
                                    }
                                }

                                CustomText {
                                    anchors.centerIn: parent
                                    visible: card.widgetRows.length === 0
                                    content: "No widgets match your search"
                                    size: 14
                                    customColor: Colors.outline
                                }
                            }
                        }

                        // ── Tab 2: Panels Stage ───────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 24

                            // Panel Selector Sidebar
                            ColumnLayout {
                                Layout.preferredWidth: 220
                                Layout.fillHeight: true
                                spacing: 4

                                CustomText {
                                    content: "Panels"
                                    size: 11
                                    weight: 700
                                    customColor: Colors.outline
                                    Layout.leftMargin: 12
                                    Layout.bottomMargin: 4
                                }

                                Repeater {
                                    model: card.panelList

                                    Rectangle {
                                        id: pBtn
                                        required property var modelData
                                        readonly property bool on: card.selectedPanel === pBtn.modelData.kind

                                        Layout.fillWidth: true
                                        implicitHeight: 44
                                        radius: 14
                                        color: pBtn.on ? Colors.secondaryContainer
                                            : pArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 10

                                            MaterialIconSymbol {
                                                content: pBtn.modelData.icon
                                                iconSize: 18
                                                customColor: pBtn.on ? Colors.secondaryContainerText : Colors.primary
                                            }

                                            CustomText {
                                                Layout.fillWidth: true
                                                content: pBtn.modelData.label
                                                size: 13
                                                weight: pBtn.on ? 700 : 500
                                                customColor: pBtn.on ? Colors.secondaryContainerText : Colors.surfaceText
                                            }
                                        }

                                        MouseArea {
                                            id: pArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: card.selectedPanel = pBtn.modelData.kind
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }

                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 1
                                color: Qt.alpha(Colors.outlineVariant, 0.25)
                            }

                            // Panel Config Area
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: width
                                contentHeight: panelConfigCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: CustomScrollBar {}

                                ColumnLayout {
                                    id: panelConfigCol
                                    width: parent.width - 24
                                    spacing: 18

                                    RowLayout {
                                        spacing: 12
                                        Rectangle {
                                            implicitWidth: 44
                                            implicitHeight: 44
                                            radius: 14
                                            color: Colors.secondaryContainer
                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                content: card.currentPanelData.icon
                                                iconSize: 22
                                                customColor: Colors.secondaryContainerText
                                            }
                                        }
                                        ColumnLayout {
                                            spacing: 0
                                            CustomText {
                                                content: card.currentPanelData.label + " panel"
                                                size: 16
                                                weight: 700
                                            }
                                            CustomText {
                                                content: card.hostText(card.currentPanelData)
                                                size: 12
                                                customColor: Colors.outline
                                            }
                                        }
                                    }

                                    // Placement choices
                                    ColumnLayout {
                                        visible: card.placeChoices(card.currentPanelData.kind).length > 0
                                        spacing: 8
                                        Layout.fillWidth: true

                                        CustomText {
                                            content: "Opens from"
                                            size: 13
                                            weight: 600
                                            customColor: Colors.primary
                                        }

                                        RowLayout {
                                            spacing: 8
                                            Repeater {
                                                model: card.placeChoices(card.currentPanelData.kind)
                                                delegate: Rectangle {
                                                    id: placeChip
                                                    required property var modelData
                                                    readonly property bool on: card.currentPlaceValue(card.currentPanelData.kind) === placeChip.modelData.value
                                                    implicitWidth: placeRow.implicitWidth + 24
                                                    implicitHeight: 36
                                                    radius: 18
                                                    color: placeChip.on ? Colors.secondaryContainer
                                                        : placeArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : Colors.surfaceContainerHigh

                                                    RowLayout {
                                                        id: placeRow
                                                        anchors.centerIn: parent
                                                        spacing: 6
                                                        MaterialIconSymbol {
                                                            content: placeChip.modelData.icon
                                                            iconSize: 16
                                                            customColor: placeChip.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                                        }
                                                        CustomText {
                                                            content: placeChip.modelData.label
                                                            size: 12
                                                            weight: placeChip.on ? 700 : 500
                                                            customColor: placeChip.on ? Colors.secondaryContainerText : Colors.surfaceText
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: placeArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: card.setPlace(card.currentPanelData.kind, placeChip.modelData.value)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Size presets
                                    ColumnLayout {
                                        visible: BarLayout.panelPresets(card.currentPanelData.kind).length > 0
                                        spacing: 8
                                        Layout.fillWidth: true

                                        CustomText {
                                            content: "Size presets"
                                            size: 13
                                            weight: 600
                                            customColor: Colors.primary
                                        }

                                        RowLayout {
                                            spacing: 8
                                            Repeater {
                                                model: BarLayout.panelPresets(card.currentPanelData.kind)
                                                delegate: Rectangle {
                                                    id: presetChip
                                                    required property var modelData
                                                    readonly property bool on: BarLayout.presetActive(card.currentPanelData.kind, presetChip.modelData.value)
                                                    implicitWidth: presetText.implicitWidth + 24
                                                    implicitHeight: 36
                                                    radius: 18
                                                    color: presetChip.on ? Colors.secondaryContainer
                                                        : presetArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : Colors.surfaceContainerHigh

                                                    CustomText {
                                                        id: presetText
                                                        anchors.centerIn: parent
                                                        content: presetChip.modelData.label
                                                        size: 12
                                                        weight: presetChip.on ? 700 : 500
                                                        customColor: presetChip.on ? Colors.secondaryContainerText : Colors.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: presetArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: BarLayout.applyPreset(card.currentPanelData.kind, presetChip.modelData.value)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Corner radius
                                    ColumnLayout {
                                        spacing: 8
                                        Layout.fillWidth: true

                                        CustomText {
                                            content: "Corner radius"
                                            size: 13
                                            weight: 600
                                            customColor: Colors.primary
                                        }

                                        EditStepper {
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: 320
                                            value: Math.max(0, BarLayout.panelRadius(card.currentPanelData.kind))
                                            from: 0
                                            to: 40
                                            stepSize: 1
                                            onPicked: v => BarLayout.setPanelRadius(card.currentPanelData.kind, v)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Tab 3: Bar & Edge Settings ────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 24

                            // Edge Selector Sidebar
                            ColumnLayout {
                                Layout.preferredWidth: 200
                                Layout.fillHeight: true
                                spacing: 4

                                CustomText {
                                    content: "Targets"
                                    size: 11
                                    weight: 700
                                    customColor: Colors.outline
                                    Layout.leftMargin: 12
                                    Layout.bottomMargin: 4
                                }

                                Repeater {
                                    model: [
                                        { id: "top",     label: "Top bar",      icon: "border_top" },
                                        { id: "bottom",  label: "Bottom bar",   icon: "border_bottom" },
                                        { id: "left",    label: "Left bar",     icon: "border_left" },
                                        { id: "right",   label: "Right bar",    icon: "border_right" },
                                        { id: "general", label: "General",      icon: "tune" }
                                    ]

                                    Rectangle {
                                        id: edgeBtn
                                        required property var modelData
                                        readonly property bool on: card.selectedEdge === edgeBtn.modelData.id

                                        Layout.fillWidth: true
                                        implicitHeight: 44
                                        radius: 14
                                        color: edgeBtn.on ? Colors.secondaryContainer
                                            : edgeArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 10

                                            MaterialIconSymbol {
                                                content: edgeBtn.modelData.icon
                                                iconSize: 18
                                                customColor: edgeBtn.on ? Colors.secondaryContainerText : Colors.primary
                                            }

                                            CustomText {
                                                Layout.fillWidth: true
                                                content: edgeBtn.modelData.label
                                                size: 13
                                                weight: edgeBtn.on ? 700 : 500
                                                customColor: edgeBtn.on ? Colors.secondaryContainerText : Colors.surfaceText
                                            }
                                        }

                                        MouseArea {
                                            id: edgeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: card.selectedEdge = edgeBtn.modelData.id
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }

                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 1
                                color: Qt.alpha(Colors.outlineVariant, 0.25)
                            }

                            // Edge / General Settings Details
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: width
                                contentHeight: edgeConfigCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: CustomScrollBar {}

                                ColumnLayout {
                                    id: edgeConfigCol
                                    width: parent.width - 24
                                    spacing: 20

                                    // When General is selected
                                    ColumnLayout {
                                        visible: card.selectedEdge === "general"
                                        Layout.fillWidth: true
                                        spacing: 16

                                        CustomText {
                                            content: "Editor Mode"
                                            size: 14
                                            weight: 700
                                            customColor: Colors.primary
                                        }

                                        M3ButtonGroup {
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: 400
                                            Layout.preferredHeight: 38
                                            fillWidth: true
                                            iconSize: 16
                                            textSize: 12
                                            activeColor: Colors.secondaryContainer
                                            activeTextColor: Colors.secondaryContainerText
                                            model: [
                                                { value: "panel",   label: "In-bar panel",        icon: "dock_to_bottom" },
                                                { value: "overlay", label: "Fullscreen overlay",  icon: "fullscreen" }
                                            ]
                                            activeCheck: function(value) { return (SettingsConfig.general.editMode ?? "panel") === value }
                                            onSegmentClicked: function(value) {
                                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { editMode: value })
                                            }
                                        }

                                        Item { Layout.preferredHeight: 8 }

                                        CustomText {
                                            content: "Panel Gap"
                                            size: 14
                                            weight: 700
                                            customColor: Colors.primary
                                        }

                                        EditStepper {
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: 320
                                            value: BarLayout.panelGap
                                            from: 0
                                            to: 40
                                            stepSize: 2
                                            onPicked: v => {
                                                if (v !== BarLayout.panelGap)
                                                    BarLayout.setPanelGap(v)
                                            }
                                        }

                                        Item { Layout.preferredHeight: 8 }

                                        CustomText {
                                            content: "Screen Border"
                                            size: 14
                                            weight: 700
                                            customColor: Colors.primary
                                        }

                                        RowLayout {
                                            spacing: 12
                                            CustomText {
                                                content: "Enable border around the screen"
                                                size: 13
                                            }
                                            CustomToogle {
                                                isToggleOn: BarLayout.screenBorder.on === true
                                                onToggled: state => BarLayout.setBorder({ on: state })
                                            }
                                        }
                                    }

                                    // When an Edge (top, bottom, left, right) is selected
                                    ColumnLayout {
                                        visible: card.selectedEdge !== "general"
                                        Layout.fillWidth: true
                                        spacing: 16

                                        readonly property var edgeCfg: BarLayout.edge(card.selectedEdge)

                                        CustomText {
                                            content: card.selectedEdge.toUpperCase() + " Edge Properties"
                                            size: 15
                                            weight: 700
                                            customColor: Colors.primary
                                        }

                                        ColumnLayout {
                                            spacing: 6
                                            CustomText { content: "Thickness"; size: 13; weight: 600 }
                                            EditStepper {
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: 320
                                                value: Number(edgeCfg.thickness ?? 44)
                                                from: 24
                                                to: 96
                                                stepSize: 2
                                                onPicked: v => {
                                                    const o = {}
                                                    o.thickness = v
                                                    BarLayout.setEdge(card.selectedEdge, o)
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 6
                                            CustomText { content: "Corner Radius"; size: 13; weight: 600 }
                                            EditStepper {
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: 320
                                                value: Number(edgeCfg.radius ?? 18)
                                                from: 0
                                                to: 40
                                                stepSize: 1
                                                onPicked: v => {
                                                    const o = {}
                                                    o.radius = v
                                                    BarLayout.setEdge(card.selectedEdge, o)
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 6
                                            CustomText { content: "Edge Margin"; size: 13; weight: 600 }
                                            EditStepper {
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: 320
                                                value: Number(edgeCfg.margin ?? 0)
                                                from: 0
                                                to: 40
                                                stepSize: 2
                                                onPicked: v => {
                                                    const o = {}
                                                    o.margin = v
                                                    BarLayout.setEdge(card.selectedEdge, o)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // KeyCap component styled like CheatSheet
    component KeyCap: Rectangle {
        id: cap
        property string text: ""
        implicitWidth: Math.max(32, capText.implicitWidth + 16)
        implicitHeight: 28
        radius: 8
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.55)

        CustomText {
            id: capText
            anchors.centerIn: parent
            content: cap.text
            size: 11
            weight: 600
            customColor: Colors.surfaceText
        }
    }
}
