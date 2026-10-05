import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property int currentPage: firstPage
    signal settingClosed

    Connections {
        target: GlobalStates
        function onSettingsPageChanged() { root.currentPage = GlobalStates.settingsPage }

        // This Item is built once inside the FloatingWindow and only toggled via `visible`,
        // so the page has to be (re)selected on each open rather than at construction.
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen) {
                root.currentPage = GlobalStates.settingsPage
                rescanTimer.restart()
            } else
                GlobalStates.settingsPage = root.firstPage   // plain reopen lands on page one
        }
    }

    property real t: 0
    Component.onCompleted: root.t = Qt.binding(() => GlobalStates.settingsOpen ? 1 : 0)
    Behavior on t {
        NumberAnimation {
            duration: GlobalStates.settingsOpen ? M3Motion.panel.openDuration : M3Motion.panel.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: GlobalStates.settingsOpen ? M3Motion.panel.openCurve : M3Motion.panel.closeCurve
        }
    }

    opacity: Math.min(1, root.t * 1.6)
    scale: 0.92 + 0.08 * root.t
    transform: Translate { y: (1 - root.t) * 28 }

    // Section → page-index mapping
    readonly property var navSections: [
        { label: "System",  indices: [9, 14, 0, 12, 1, 2, 3, 13, 10, 11] },
        { label: "Connect", indices: [4, 5] },
        { label: "Apps",    indices: [6, 7, 8] }
    ]

    // Whatever sits at the top of the sidebar — not necessarily page 0
    readonly property int firstPage: navSections[0].indices[0]

    readonly property var pageFiles: ["Theme", "Sound", "Notifications", "Widgets", "Networking", "Bluetooth",
        "WeatherSettings", "MediaSettings", "About", "AppearanceSettings", "Sleep", "Storage", "Lockscreen",
        "NotesSettings", "LayoutsSettings"]

    readonly property var railOrder: root.navSections.reduce((all, g) => all.concat(g.indices), [])
    readonly property bool showSections: SettingsConfig.general.settingsSections ?? true
    readonly property bool railWide: SettingsConfig.general.settingsRailWide ?? false
    readonly property real railTarget: root.railWide ? 196 : 58
    property real railW: root.railTarget
    Behavior on railW { enabled: root.t > 0.5; SpatialAnim {} }
    property real heldPageW: -1
    readonly property real pageW: root.heldPageW >= 0 ? root.heldPageW : frame.width - root.railTarget

    onRailWideChanged: {
        if (root.t < 0.5)
            return
        root.heldPageW = frame.width - (root.railWide ? 58 : 196)
        pageRelease.restart()
    }

    Timer {
        id: pageRelease
        interval: M3Motion.spatialDuration("default") + 120
        onTriggered: root.heldPageW = -1
    }
    property int shownPage: firstPage
    property int swapDir: 1

    onCurrentPageChanged: {
        if (root.currentPage === root.shownPage && !pageSwap.running)
            return
        root.swapDir = root.railOrder.indexOf(root.currentPage) >= root.railOrder.indexOf(root.shownPage) ? 1 : -1
        if (!GlobalStates.settingsOpen || root.t < 0.5) {
            pageSwap.stop()
            root.shownPage = root.currentPage
            pageHost.opacity = 1
            pageShift.y = 0
            return
        }
        pageSwap.restart()
    }

    property Item pageItem: null
    property Flickable pageFlick: null
    property var sections: []
    property int activeSection: 0
    property int pinnedSection: -1

    property bool indexWanted: false
    property var searchIndex: []
    property string query: ""
    property bool searchOpen: false
    property int resultIndex: 0
    property var pendingJump: null

    property Item tipItem: null
    property string tipText: ""
    property real tipX: 0
    property real tipY: 0
    property bool tipBelow: false
    property bool tipShown: false

    readonly property var results: {
        const q = root.query.trim().toLowerCase()
        if (q.length < 2)
            return []
        const out = []
        for (let p = 0; p < Settings.pages.length; p++) {
            const at = Settings.pages[p].name.toLowerCase().indexOf(q)
            if (at >= 0)
                out.push({ page: p, section: "", label: Settings.pages[p].name, isPage: true, rank: at === 0 ? 0 : 1 })
        }
        for (let i = 0; i < root.searchIndex.length; i++) {
            const e = root.searchIndex[i]
            const l = e.label.toLowerCase()
            const at = l.indexOf(q)
            if (at < 0)
                continue
            out.push({ page: e.page, section: e.section, label: e.label, isPage: false,
                       rank: at === 0 ? 2 : (l.charAt(at - 1) === " " ? 3 : 4) })
        }
        out.sort((a, b) => a.rank - b.rank)
        return out.slice(0, 8)
    }
    onResultsChanged: root.resultIndex = 0

    onPageItemChanged: {
        root.pageFlick = root.findFlick(root.pageItem)
        root.activeSection = 0
        Qt.callLater(root.rescan)
        if (root.pageItem)
            rescanTimer.restart()
    }

    function findFlick(it) {
        if (!it)
            return null
        for (let i = 0; i < it.children.length; i++) {
            if (it.children[i] instanceof Flickable)
                return it.children[i]
        }
        return null
    }

    function contentYOf(it) {
        return it.mapToItem(root.pageFlick.contentItem, 0, 0).y
    }

    function collectHeadings(it, depth, out) {
        const kids = it.children
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (!c.visible)
                continue
            if (c instanceof Text) {
                if (c.size === 13 && c.customColor === Colors.primary && c.text !== "")
                    out.push(c)
                continue
            }
            if (depth < 4 && !(c instanceof Rectangle) && !(c instanceof Flickable))
                root.collectHeadings(c, depth + 1, out)
        }
    }

    function collectLabels(it, label, depth, out) {
        const kids = it.children
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (!c.visible)
                continue
            if (c instanceof Text) {
                if (c.text === label)
                    out.push(c)
                continue
            }
            if (depth < 14)
                root.collectLabels(c, label, depth + 1, out)
        }
    }

    function rescan() {
        const f = root.pageFlick
        if (!f) {
            if (root.sections.length > 0)
                root.sections = []
            return
        }
        const found = []
        root.collectHeadings(f.contentItem, 0, found)
        let rows = found.map(h => ({ title: h.text, item: h, at: root.contentYOf(h) }))
        const settled = rows.length < 2 || rows[0].at !== rows[rows.length - 1].at
        if (settled)
            rows.sort((m, n) => m.at - n.at)
        const old = root.sections
        let same = old.length === rows.length
        for (let i = 0; same && i < rows.length; i++)
            same = old[i].item === rows[i].item && old[i].title === rows[i].title
        if (!same)
            root.sections = rows.map(r => ({ title: r.title, item: r.item }))
        if (settled) {
            if (!scrollAnim.running)
                root.updateActive()
        } else {
            root.activeSection = 0
            if (GlobalStates.settingsOpen)
                rescanTimer.restart()
        }
    }

    function updateActive() {
        const f = root.pageFlick
        if (!f || root.sections.length === 0) {
            root.activeSection = 0
            return
        }
        if (f.atYEnd && f.contentHeight > f.height + 1) {
            root.activeSection = root.sections.length - 1
            return
        }
        const edge = f.contentY + 40
        let a = 0
        for (let i = 0; i < root.sections.length; i++) {
            const it = root.sections[i].item
            if (it && root.contentYOf(it) <= edge)
                a = i
        }
        root.activeSection = a
    }

    function scrollTo(y) {
        const f = root.pageFlick
        if (!f)
            return
        scrollAnim.stop()
        root.pinnedSection = -1
        scrollAnim.from = f.contentY
        scrollAnim.to = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), y))
        scrollAnim.start()
    }

    function openSection(i) {
        const s = root.sections[i]
        if (!s || !s.item)
            return
        root.activeSection = i
        root.scrollTo(root.contentYOf(s.item) - 10)
        root.pinnedSection = i
    }

    function indexPage(page, src) {
        const out = []
        const lines = src.split("\n")
        let section = ""
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i]
            const m = ln.match(/content:\s*"([^"]+)"/)
            if (!m)
                continue
            if (/size:\s*13\b/.test(ln) && ln.indexOf("Colors.primary") >= 0) {
                section = m[1]
                out.push({ page: page, section: "", label: m[1] })
            } else if (/size:\s*14\b/.test(ln) && ln.indexOf("customColor") < 0) {
                out.push({ page: page, section: section, label: m[1] })
            }
        }
        root.searchIndex = root.searchIndex.concat(out)
    }

    function openResult(r) {
        if (!r)
            return
        root.pendingJump = r.isPage ? null : { label: r.label, section: r.section }
        root.searchOpen = false
        searchInput.text = ""
        searchInput.focus = false
        if (root.currentPage !== r.page)
            root.currentPage = r.page
        else
            rescanTimer.restart()
    }

    function performJump() {
        const f = root.pageFlick
        const j = root.pendingJump
        root.pendingJump = null
        if (!f || !j)
            return
        const hits = []
        root.collectLabels(f.contentItem, j.label, 0, hits)
        if (hits.length === 0) {
            for (let i = 0; i < root.sections.length; i++) {
                if (root.sections[i].title === j.section) {
                    root.openSection(i)
                    break
                }
            }
            return
        }
        hits.sort((a, b) => root.contentYOf(a) - root.contentYOf(b))
        let floor = -1
        for (let i = 0; i < root.sections.length; i++) {
            const s = root.sections[i]
            if (j.section !== "" && s.title === j.section && s.item)
                floor = root.contentYOf(s.item)
        }
        let target = hits[0]
        for (let i = 0; i < hits.length; i++) {
            if (root.contentYOf(hits[i]) >= floor) {
                target = hits[i]
                break
            }
        }
        let card = target
        for (let a = target.parent; a && a !== f.contentItem; a = a.parent) {
            if (a.isCustomCard === true) {
                card = a
                break
            }
        }
        const at = card.mapToItem(f.contentItem, 0, 0)
        const grow = card === target ? 6 : 0
        root.scrollTo(at.y - 70)
        flashComponent.createObject(f.contentItem, {
            x: at.x - grow, y: at.y - grow, width: card.width + 2 * grow, height: card.height + 2 * grow,
            topLeftRadius: card.topRadius ?? 10, topRightRadius: card.topRadius ?? 10,
            bottomLeftRadius: card.bottomRadius ?? 10, bottomRightRadius: card.bottomRadius ?? 10
        })
    }

    function showTip(item, label, below) {
        root.tipItem = item
        root.tipText = label
        root.tipBelow = below === true
        const at = item.mapToItem(frame, item.width, root.tipBelow ? item.height : item.height / 2)
        root.tipX = at.x
        root.tipY = at.y
        tipHide.stop()
        if (!root.tipShown)
            tipShow.restart()
    }

    function hideTip(item) {
        if (root.tipItem !== item)
            return
        root.tipItem = null
        tipShow.stop()
        tipHide.restart()
    }

    Timer {
        id: rescanTimer
        interval: 120
        onTriggered: {
            root.rescan()
            if (root.pendingJump)
                root.performJump()
        }
    }

    Timer { id: tipShow; interval: 350; onTriggered: root.tipShown = root.tipItem !== null }
    Timer { id: tipHide; interval: 120; onTriggered: root.tipShown = false }

    Connections {
        target: root.pageFlick
        function onContentYChanged() { if (!scrollAnim.running) root.updateActive() }
        function onContentHeightChanged() { rescanTimer.restart() }
    }

    EffectsAnim {
        id: scrollAnim
        target: root.pageFlick
        property: "contentY"
        speed: "slow"
        onFinished: {
            if (root.pinnedSection >= 0)
                root.activeSection = root.pinnedSection
            else
                root.updateActive()
            root.pinnedSection = -1
        }
    }

    Instantiator {
        active: root.indexWanted
        model: root.pageFiles
        delegate: FileView {
            required property string modelData
            required property int index
            path: Quickshell.shellDir + "/modules/components/Setting/" + modelData + ".qml"
            onLoaded: root.indexPage(index, text())
        }
    }

    SequentialAnimation {
        id: pageSwap

        ParallelAnimation {
            NumberAnimation { target: pageHost; property: "opacity"; to: 0; duration: 90 }
            NumberAnimation {
                target: pageShift; property: "y"; to: -root.swapDir * 14
                duration: 90; easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.shownPage = root.currentPage
                pageShift.y = root.swapDir * 28
            }
        }
        PauseAnimation { duration: 24 }
        ParallelAnimation {
            EffectsAnim { target: pageHost; property: "opacity"; to: 1 }
            SpatialAnim { target: pageShift; property: "y"; to: 0 }
        }
    }

    Shortcut {
        sequence: "Ctrl+K"
        onActivated: searchInput.forceActiveFocus()
    }

    Component {
        id: flashComponent

        Rectangle {
            id: flash
            z: 50
            color: Colors.primary
            opacity: 0

            SequentialAnimation on opacity {
                running: true
                NumberAnimation { to: 0.22; duration: M3Motion.effects.fastDuration }
                PauseAnimation { duration: 520 }
                NumberAnimation { to: 0; duration: 520 }
                ScriptAction { script: flash.destroy() }
            }
        }
    }

    component PageSlot: Loader {
        required property int page
        anchors.fill: parent
        active: root.shownPage === page
        visible: active
        onLoaded: root.pageItem = item
    }

    component RailButton: Item {
        id: railButton
        property string icon: ""
        property string label: ""
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        implicitWidth: 38
        implicitHeight: 34
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: railButton.active ? Colors.primary
                 : railMouse.containsMouse ? Colors.surfaceContainerHighest : "transparent"
            Behavior on color { EffectsColorAnim {} }
        }

        MaterialIconSymbol {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            content: railButton.icon
            iconSize: 18
            fill: railButton.active ? 1 : 0
            customColor: railButton.active ? Colors.primaryText
                       : railMouse.containsMouse ? Colors.surfaceText : Colors.surfaceVariantText
            Behavior on fill { NumberAnimation { duration: 180 } }
        }

        CustomText {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.railWide ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { EffectsAnim {} }
            content: railButton.label
            size: 13
            weight: railButton.active ? 600 : 500
            customColor: railButton.active ? Colors.primaryText
                       : railMouse.containsMouse ? Colors.surfaceText : Colors.surfaceVariantText
        }

        MouseArea {
            id: railMouse
            anchors.fill: parent
            cursorShape: GlobalStates.fileDialogOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
            hoverEnabled: !GlobalStates.fileDialogOpen
            enabled: !GlobalStates.fileDialogOpen
            onEntered: if (!root.railWide) root.showTip(railButton, railButton.label, false)
            onExited: root.hideTip(railButton)
            onClicked: railButton.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.surface

        Rectangle {
            id: frame
            anchors.fill: parent
            anchors.margins: 10
            radius: 20
            color: Colors.surfaceContainer

            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    width: root.railW
                    height: parent.height
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: navFlick
                                anchors.fill: parent
                                contentHeight: navColumn.implicitHeight
                                contentWidth: width
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                onContentYChanged: root.tipShown = false

                                ColumnLayout {
                                    id: navColumn
                                    width: navFlick.width
                                    spacing: 0

                                    Repeater {
                                        model: root.navSections

                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Rectangle {
                                                visible: index !== 0
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: Math.max(26, navColumn.width - 12)
                                                Layout.topMargin: 4
                                                Layout.bottomMargin: 4
                                                implicitHeight: 1
                                                color: Colors.surfaceContainerHighest
                                            }

                                            Repeater {
                                                model: modelData.indices

                                                delegate: RailButton {
                                                    readonly property var pageData: Settings.pages[modelData]
                                                    icon: pageData?.icon ?? ""
                                                    label: pageData?.name ?? ""
                                                    active: root.currentPage === modelData
                                                    onClicked: root.currentPage = modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ScrollFade {
                                anchors.fill: parent
                                flickable: navFlick
                                color: Colors.surfaceContainerHigh
                            }
                        }

                        RailButton {
                            id: railToggle
                            icon: root.railWide ? "left_panel_close" : "left_panel_open"
                            label: root.railWide ? "Collapse sidebar" : "Expand sidebar"
                            onClicked: {
                                root.hideTip(railToggle)
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { settingsRailWide: !root.railWide })
                            }
                        }

                        RailButton {
                            icon: "edit"
                            label: "Edit Config"
                            onClicked: Quickshell.execDetached(["kitty", "-e", "nvim",
                                Quickshell.env("HOME") + "/.config/quickshell"])
                        }
                    }
                }

                RowLayout {
                x: root.railW
                width: root.pageW
                height: parent.height
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        Layout.leftMargin: 16
                        Layout.rightMargin: 12
                        spacing: 12

                        CustomText {
                            Layout.fillWidth: true
                            content: Settings.pages[root.shownPage]?.name ?? ""
                            opacity: pageHost.opacity
                            size: 26
                            weight: 400
                            family: SettingsConfig.general.displayFont ?? "Titan One"
                            renderType: Text.QtRendering
                        }

                        Rectangle {
                            id: searchField
                            Layout.preferredWidth: 230
                            Layout.preferredHeight: 36
                            radius: 18
                            color: Colors.surfaceContainerHighest
                            border.width: searchInput.activeFocus ? 2 : 0
                            border.color: Colors.primary

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                MaterialIconSymbol { content: "search"; iconSize: 18; customColor: Colors.outline }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Colors.surfaceText
                                    font.pixelSize: 13
                                    font.weight: 500
                                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                    selectByMouse: true
                                    clip: true
                                    onTextChanged: {
                                        root.query = text
                                        if (text !== "")
                                            root.searchOpen = true
                                    }
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            root.indexWanted = true
                                            root.searchOpen = true
                                        }
                                    }
                                    onAccepted: root.openResult(root.results[root.resultIndex])
                                    Keys.onDownPressed: root.resultIndex = Math.min(root.results.length - 1, root.resultIndex + 1)
                                    Keys.onUpPressed: root.resultIndex = Math.max(0, root.resultIndex - 1)
                                    Keys.onEscapePressed: {
                                        text = ""
                                        root.searchOpen = false
                                        focus = false
                                    }

                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchInput.text === ""
                                        content: "Search settings"
                                        size: 13
                                        weight: 500
                                        customColor: Colors.outline
                                    }
                                }

                                Rectangle {
                                    visible: searchInput.text === "" && !searchInput.activeFocus
                                    implicitWidth: hintText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 6
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Colors.outlineVariant

                                    CustomText {
                                        id: hintText
                                        anchors.centerIn: parent
                                        content: "Ctrl K"
                                        size: 11
                                        weight: 500
                                        customColor: Colors.outline
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: sectionsToggle
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: root.showSections ? Colors.secondaryContainer : Colors.surfaceContainerHighest
                            Behavior on color { EffectsColorAnim {} }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "toc"
                                iconSize: 18
                                customColor: root.showSections ? Colors.secondaryContainerText : Colors.surfaceVariantText
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.showTip(sectionsToggle, root.showSections ? "Hide sections" : "Show sections", true)
                                onExited: root.hideTip(sectionsToggle)
                                onClicked: {
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { settingsSections: !root.showSections })
                                    root.hideTip(sectionsToggle)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        clip: true

                        Item {
                            id: pageHost
                            width: parent.width
                            height: parent.height
                            transform: Translate { id: pageShift }

                        PageSlot { page: 0; sourceComponent: Theme {} }
                        PageSlot { page: 1; sourceComponent: Sound {} }
                        PageSlot { page: 2; sourceComponent: Notifications {} }
                        PageSlot { page: 3; sourceComponent: Widgets {} }
                        PageSlot { page: 4; sourceComponent: Networking {} }
                        PageSlot { page: 5; sourceComponent: Bluetooth {} }
                        PageSlot { page: 6; sourceComponent: WeatherSettings {} }
                        PageSlot { page: 7; sourceComponent: MediaSettings {} }
                        PageSlot { page: 8; sourceComponent: About {} }
                        PageSlot { page: 9; sourceComponent: AppearanceSettings {} }
                        PageSlot { page: 10; sourceComponent: Sleep {} }
                        PageSlot { page: 11; sourceComponent: Storage {} }
                        PageSlot { page: 12; sourceComponent: Lockscreen {} }
                        PageSlot { page: 13; sourceComponent: NotesSettings {} }
                        PageSlot { page: 14; sourceComponent: LayoutsSettings {} }
                        }
                    }
                }

                ColumnLayout {
                    id: tocColumn
                    visible: root.showSections && root.sections.length >= 2
                    opacity: pageHost.opacity
                    Layout.fillHeight: true
                    Layout.preferredWidth: 168
                    Layout.maximumWidth: 168
                    Layout.topMargin: 66
                    Layout.rightMargin: 12
                    Layout.leftMargin: 2
                    spacing: 2

                    CustomText {
                        Layout.leftMargin: 12
                        Layout.bottomMargin: 6
                        content: "ON THIS PAGE"
                        size: 11
                        weight: 700
                        customColor: Colors.outline
                        font.letterSpacing: 0.9
                    }

                    Repeater {
                        model: root.sections

                        delegate: Rectangle {
                            id: tocItem
                            required property var modelData
                            required property int index
                            readonly property bool current: root.activeSection === index

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 10
                            color: tocItem.current ? Colors.secondaryContainer
                                 : tocMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                            Behavior on color { EffectsColorAnim {} }

                            CustomText {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                content: tocItem.modelData.title
                                size: 13
                                weight: tocItem.current ? 700 : 500
                                customColor: tocItem.current ? Colors.secondaryContainerText : Colors.surfaceVariantText
                            }

                            MouseArea {
                                id: tocMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSection(tocItem.index)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: resultsPanel.visible
                onPressed: mouse => {
                    root.searchOpen = false
                    searchInput.focus = false
                    mouse.accepted = false
                }
            }

            Rectangle {
                id: resultsPanel
                visible: root.searchOpen && root.query.trim().length >= 2
                x: frame.width - width - 60 - (tocColumn.visible ? 182 : 0)
                y: 56
                width: 340
                height: resultsColumn.implicitHeight + 12
                radius: 18
                color: Colors.surfaceContainerHighest
                border.width: 1
                border.color: Colors.outlineVariant

                ColumnLayout {
                    id: resultsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 2

                    CustomText {
                        visible: root.results.length === 0
                        Layout.fillWidth: true
                        Layout.margins: 10
                        content: "No settings match “" + root.query.trim() + "”"
                        size: 13
                        weight: 500
                        customColor: Colors.outline
                    }

                    Repeater {
                        model: root.results

                        delegate: Rectangle {
                            id: resultRow
                            required property var modelData
                            required property int index
                            readonly property bool current: root.resultIndex === index

                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 12
                            color: resultRow.current ? Colors.secondaryContainer : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MaterialIconSymbol {
                                    content: Settings.pages[resultRow.modelData.page]?.icon ?? ""
                                    iconSize: 18
                                    customColor: resultRow.current ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: resultRow.modelData.label
                                        size: 13
                                        weight: 600
                                        customColor: resultRow.current ? Colors.secondaryContainerText : Colors.surfaceText
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        visible: !resultRow.modelData.isPage
                                        content: (Settings.pages[resultRow.modelData.page]?.name ?? "")
                                               + (resultRow.modelData.section !== "" ? "  ›  " + resultRow.modelData.section : "")
                                        size: 11
                                        weight: 500
                                        customColor: resultRow.current ? Colors.secondaryContainerText : Colors.outline
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.resultIndex = resultRow.index
                                onClicked: root.openResult(resultRow.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: railTip
                visible: opacity > 0.01
                opacity: root.tipShown && root.tipText !== "" ? 1 : 0
                x: root.tipBelow ? root.tipX - width : root.tipX + 18
                y: root.tipBelow ? root.tipY + 6 : root.tipY - height / 2
                width: tipLabel.implicitWidth + 24
                height: 30
                radius: 10
                color: Colors.inverseSurface
                Behavior on opacity { EffectsAnim { speed: "fast" } }
                Behavior on y { enabled: railTip.visible; EffectsAnim { speed: "fast" } }

                CustomText {
                    id: tipLabel
                    anchors.centerIn: parent
                    content: root.tipText
                    size: 12
                    weight: 600
                    customColor: Colors.inverseSurfaceText
                }
            }
        }
    }
}
