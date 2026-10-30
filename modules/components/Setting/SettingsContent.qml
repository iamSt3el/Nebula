import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services
import qs.modules.components.LockScreen

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
            } else {
                root.prefetchPage = -1
                GlobalStates.settingsPage = root.firstPage   // plain reopen lands on page one
            }
        }
    }

    property real t: 0
    Component.onCompleted: {
        if (GlobalStates.settingsOpen) {
            root.currentPage = GlobalStates.settingsPage
            root.shownPage = root.currentPage
        }
        root.t = Qt.binding(() => GlobalStates.settingsOpen ? 1 : 0)
    }
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
        { label: "Look",    indices: [0, 3, 14] },
        { label: "System",  indices: [1, 2, 12] },
        { label: "Desktop", indices: [15, 16, 17] },
        { label: "Connect", indices: [4, 5] },
        { label: "More",    indices: [6, 8] }
    ]

    readonly property var merges: [
        { pages: [0, 9], name: "Appearance", icon: "palette", tabs: ["Wallpaper & colours", "Fonts & bar"] },
        { pages: [3, 13], name: "Widgets", icon: "widgets", tabs: ["Widgets", "Sticky notes"] },
        { pages: [12, 10], name: "Lock & sleep", icon: "lock", tabs: ["Lock screen", "Sleep"] },
        { pages: [17, 18], name: "Keyboard & mouse", icon: "keyboard", tabs: ["Mouse & keyboard", "Shortcuts"] },
        { pages: [6, 7], name: "Built-in apps", icon: "apps", tabs: ["Weather", "Screenshots & recording"] },
        { pages: [8, 11], name: "About", icon: "info", tabs: ["Nebula", "Storage"] }
    ]

    function mergeOf(p) {
        return root.merges.find(m => m.pages.indexOf(p) >= 0) ?? null
    }

    function leadOf(p) {
        const m = root.mergeOf(p)
        return m ? m.pages[0] : p
    }

    function nameOf(p) {
        const m = root.mergeOf(p)
        return m ? m.name : (Settings.pages[p]?.name ?? "")
    }

    function iconOf(p) {
        const m = root.mergeOf(p)
        return m ? m.icon : (Settings.pages[p]?.icon ?? "")
    }

    function placeOf(p) {
        const m = root.mergeOf(p)
        return m ? m.name + "  ›  " + m.tabs[m.pages.indexOf(p)] : (Settings.pages[p]?.name ?? "")
    }


    // Whatever sits at the top of the sidebar — not necessarily page 0
    readonly property int firstPage: navSections[0].indices[0]

    readonly property var pageFiles: ["Theme", "Sound", "Notifications", "Widgets", "Networking", "Bluetooth",
        "WeatherSettings", "", "About", "", "", "", "Lockscreen",
        "", "LayoutsSettings", "DisplaysSettings", "WindowsSettings", "InputSettings", "",
        "ProfileSettings"]

    readonly property var railOrder: root.navSections.reduce((all, g) =>
        all.concat(g.indices.reduce((row, i) => row.concat(root.mergeOf(i)?.pages ?? [i]), [])), [])
    readonly property bool showSections: SettingsConfig.general.settingsSections ?? true
    readonly property bool tocWanted: root.showSections && root.sections.length >= 2
    property real tocT: root.tocWanted ? 1 : 0
    Behavior on tocT { enabled: root.t > 0.5; SpatialAnim {} }
    readonly property bool tocSpace: root.tocWanted || root.tocT > 0.01

    property bool statusMenuOpen: false
    readonly property bool focusing: ServiceFocus.phase === "focus" || ServiceFocus.phase === "break"
    readonly property string mode: root.focusing ? "focus" : ServiceNotification.dnd ? "quiet" : "available"
    readonly property var modes: [
        { value: "available", label: "Available", icon: "check_circle", hint: "Everything works as usual", tone: Colors.primary },
        { value: "focus", label: "Focus", icon: "timer", hint: "Starts a focus session", tone: Colors.tertiary },
        { value: "quiet", label: "Quiet", icon: "do_not_disturb_on", hint: "Turns on Do not disturb", tone: Colors.error }
    ]
    readonly property var currentMode: root.modes.find(m => m.value === root.mode) ?? root.modes[0]

    function setMode(m) {
        if (m === "focus") {
            if (!root.focusing)
                ServiceFocus.startFocus()
            return
        }
        if (root.focusing)
            ServiceFocus.stop()
        ServiceNotification.setDnd(m === "quiet")
    }
    readonly property bool islandWide: SettingsConfig.general.settingsRailWide ?? false
    property real islandW: root.islandWide ? 204 : 62
    Behavior on islandW { enabled: root.t > 0.5; SpatialAnim {} }
    readonly property string groupName: root.shownPage === 19 ? "You"
        : root.navSections.find(g => g.indices.indexOf(root.leadOf(root.shownPage)) >= 0)?.label ?? ""
    property point menuAt: Qt.point(0, 0)
    property point searchAt: Qt.point(0, 0)

    function pageStatus(i) {
        switch (i) {
        case 1:
            return ServicePipewire.muted ? "Muted" : Math.round(ServicePipewire.volume * 100) + "%"
        case 2:
            return ServiceNotification.dnd ? "Do not disturb" : ""
        case 4:
            if (ServiceNetwork.connectionType === "ethernet")
                return ServiceNetwork.currentSSID !== "" ? "Ethernet, " + ServiceNetwork.currentSSID + " as backup" : "Ethernet"
            return ServiceNetwork.connectionType === "wifi" ? ServiceNetwork.currentSSID : "Not connected"
        case 5: {
            if (!ServiceBluetooth.state)
                return "Off"
            const on = ServiceBluetooth.connectedDevicesList
            return on.length === 0 ? "On" : ServiceBluetooth.nameOf(on[0]) + (on.length > 1 ? " +" + (on.length - 1) : "") + " connected"
        }
        case 6:
            return ServiceWeather.temperature !== "" ? ServiceWeather.location + " · " + ServiceWeather.temperature : ""
        }
        return ""
    }
    property int shownPage: firstPage
    property int incomingPage: -1
    property int retiringPage: -1
    property int prefetchPage: -1
    property int swapDir: 1
    property real pageOpacity: 1

    function slotFor(p) {
        for (let i = 0; i < pageHost.children.length; i++)
            if (pageHost.children[i].page === p)
                return pageHost.children[i]
        return null
    }

    function prefetch(p) {
        const lead = root.leadOf(p)
        if (lead !== root.shownPage && lead !== root.incomingPage)
            root.prefetchPage = lead
    }

    function finishSwap() {
        const slot = root.slotFor(root.incomingPage)
        if (!slot || slot.status !== Loader.Ready)
            return
        pageIn.stop()
        pageOut.stop()
        const old = root.slotFor(root.shownPage)
        root.retiringPage = root.shownPage
        root.shownPage = root.incomingPage
        root.incomingPage = -1
        if (root.prefetchPage === root.shownPage)
            root.prefetchPage = -1
        root.pageItem = slot.item
        slot.opacity = 0
        slot.shift = root.swapDir * 20
        root.pageOpacity = 0
        if (old) {
            pageOut.target = old
            pageOut.start()
        }
        inFade.target = slot
        inSlide.target = slot
        pageIn.start()
    }

    onCurrentPageChanged: {
        if (root.leadOf(root.currentPage) !== root.currentPage) {
            root.currentPage = root.leadOf(root.currentPage)
            return
        }
        if (!GlobalStates.settingsOpen || root.t < 0.5) {
            pageIn.stop()
            pageOut.stop()
            root.incomingPage = -1
            root.retiringPage = -1
            root.prefetchPage = -1
            root.shownPage = root.currentPage
            const s = root.slotFor(root.shownPage)
            if (s) {
                s.opacity = 1
                s.shift = 0
            }
            root.pageOpacity = 1
            return
        }
        if (root.currentPage === root.shownPage) {
            root.incomingPage = -1
            return
        }
        root.swapDir = root.railOrder.indexOf(root.currentPage) >= root.railOrder.indexOf(root.shownPage) ? 1 : -1
        root.incomingPage = root.currentPage
        root.finishSwap()
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
    property string tipSub: ""
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
            const m = root.mergeOf(p)
            const names = [Settings.pages[p].name].concat(m ? [m.name, m.tabs[m.pages.indexOf(p)]] : [])
            const at = names.map(n => n.toLowerCase().indexOf(q)).filter(i => i >= 0).sort((a, b) => a - b)[0] ?? -1
            if (at >= 0)
                out.push({ page: p, section: "", label: root.placeOf(p), isPage: true, rank: at === 0 ? 0 : 1 })
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

    function showTip(item, label, below, sub) {
        root.tipItem = item
        root.tipText = label
        root.tipSub = sub ?? ""
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
            path: modelData === "" ? "" : Quickshell.shellDir + "/modules/components/Setting/" + modelData + ".qml"
            onLoaded: root.indexPage(index, text())
        }
    }

    NumberAnimation {
        id: pageOut
        property: "opacity"
        to: 0
        duration: M3Motion.effects.fastDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
    }

    SequentialAnimation {
        id: pageIn
        ParallelAnimation {
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                ParallelAnimation {
                    NumberAnimation {
                        id: inFade
                        property: "opacity"
                        to: 1
                        duration: M3Motion.effects.slowDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.88, 0.34, 1, 1, 1]
                    }
                    NumberAnimation {
                        target: root
                        property: "pageOpacity"
                        to: 1
                        duration: M3Motion.effects.slowDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.88, 0.34, 1, 1, 1]
                    }
                }
            }
            NumberAnimation {
                id: inSlide
                property: "shift"
                to: 0
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
        }
        ScriptAction { script: root.retiringPage = -1 }
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
        id: slot
        required property int page
        property real shift: 0
        anchors.fill: parent
        asynchronous: slot.page !== root.incomingPage
        active: slot.page === root.shownPage || slot.page === root.incomingPage
            || slot.page === root.retiringPage || slot.page === root.prefetchPage
        visible: slot.status === Loader.Ready
            && (slot.page === root.shownPage || (slot.page === root.retiringPage && slot.opacity > 0.01))
        layer.enabled: slot.visible && slot.opacity > 0.01 && slot.opacity < 0.99
        transform: Translate { y: slot.shift }
        onLoaded: {
            if (slot.page === root.shownPage)
                root.pageItem = slot.item
            else if (slot.page === root.incomingPage)
                Qt.callLater(root.finishSwap)
        }
    }

    component IslandButton: Item {
        id: islandButton
        property string icon: ""
        property string label: ""
        property int page: -1
        property bool active: false
        signal clicked()

        implicitWidth: root.islandWide ? root.islandW - 16 : 46
        implicitHeight: 42

        Rectangle {
            anchors.centerIn: parent
            width: root.islandWide ? islandButton.width : islandButton.active ? 46 : 40
            height: islandButton.active ? 42 : 40
            radius: root.islandWide ? height / 2 : islandButton.active ? 15 : 20
            color: islandButton.active ? Colors.primary
                 : islandMouse.containsMouse ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0)
            Behavior on width { SpatialAnim { speed: "fast" } }
            Behavior on height { SpatialAnim { speed: "fast" } }
            Behavior on radius { SpatialAnim { speed: "fast" } }
            Behavior on color { EffectsColorAnim {} }
        }

        MaterialIconSymbol {
            id: islandIcon
            x: root.islandWide ? 13 : Math.round((islandButton.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            content: islandButton.icon
            iconSize: 19
            fill: 1
            customColor: islandButton.active ? Colors.primaryText
                       : islandMouse.containsMouse ? Colors.surfaceText : Colors.surfaceVariantText
        }

        CustomText {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            width: islandButton.width - x - 10
            opacity: root.islandWide ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { EffectsAnim {} }
            content: islandButton.label
            size: 14
            weight: islandButton.active ? 600 : 500
            elide: Text.ElideRight
            customColor: islandButton.active ? Colors.primaryText
                       : islandMouse.containsMouse ? Colors.surfaceText : Colors.surfaceVariantText
        }

        MouseArea {
            id: islandMouse
            anchors.fill: parent
            cursorShape: GlobalStates.fileDialogOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
            hoverEnabled: !GlobalStates.fileDialogOpen
            enabled: !GlobalStates.fileDialogOpen
            onEntered: {
                const status = islandButton.page >= 0 ? root.pageStatus(islandButton.page) : ""
                if (!root.islandWide)
                    root.showTip(islandButton, islandButton.label, false, status)
                else if (status !== "")
                    root.showTip(islandButton, status, false)
            }
            onExited: root.hideTip(islandButton)
            onContainsMouseChanged: if (containsMouse && islandButton.page >= 0) root.prefetch(islandButton.page)
            onPressed: if (islandButton.page >= 0) root.prefetch(islandButton.page)
            onClicked: islandButton.clicked()
        }
    }

    component IslandDot: Item {
        implicitWidth: root.islandW - 16
        implicitHeight: 12

        Rectangle {
            anchors.centerIn: parent
            width: root.islandWide ? parent.width - 24 : 4
            height: root.islandWide ? 1 : 4
            radius: height / 2
            color: Colors.outlineVariant
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.surface

        Item {
            id: frame
            anchors.fill: parent
            anchors.margins: 8

            Rectangle {
                id: island
                anchors.verticalCenter: parent.verticalCenter
                width: root.islandW
                height: Math.min(parent.height, islandColumn.implicitHeight + 20)
                radius: 31
                color: Colors.surfaceContainer
                clip: true

                ColumnLayout {
                    id: islandColumn
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 2

                    Item {
                        id: profileButton
                        readonly property bool current: root.currentPage === 19
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        implicitHeight: 46

                        Item {
                            id: avatar
                            x: root.islandWide ? 12 : Math.round((profileButton.width - width) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42
                            height: 42

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: profileButton.current ? -4 : -2
                                radius: width / 2
                                color: profileButton.current ? Colors.primary : root.currentMode.tone
                                Behavior on color { EffectsColorAnim {} }
                                Behavior on anchors.margins { SpatialAnim { speed: "fast" } }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Colors.surfaceContainer
                            }

                            LockShapeImage {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: SettingsConfig.general.profile ?? ""
                                shapeName: "circle"
                                sourceSize: 96
                            }
                        }

                        ColumnLayout {
                            x: avatar.x + avatar.width + 12
                            width: profileButton.width - x - 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            opacity: root.islandWide ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { EffectsAnim {} }

                            CustomText {
                                Layout.fillWidth: true
                                content: SettingsConfig.profileName || Quickshell.env("USER") || "You"
                                family: SettingsConfig.general.displayFont ?? "Titan One"
                                renderType: Text.QtRendering
                                size: 15
                                elide: Text.ElideRight
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: root.currentMode.label
                                size: 11
                                customColor: Colors.outline
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!root.islandWide) root.showTip(profileButton, LockSession.greeting + ", " + (SettingsConfig.profileName || Quickshell.env("USER") || "you"), false, "Your profile")
                            onExited: root.hideTip(profileButton)
                            onClicked: root.currentPage = 19
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: navColumn.implicitHeight

                        SmoothFlickable {
                            id: navFlick
                            anchors.fill: parent
                            contentHeight: navColumn.implicitHeight
                            contentWidth: width
                            fadeSize: 28
                            wheelStep: 70
                            onContentYChanged: root.tipShown = false

                            Column {
                                id: navColumn
                                width: navFlick.width
                                spacing: 2

                                Repeater {
                                    model: root.navSections

                                    delegate: Column {
                                        id: navGroup
                                        required property var modelData
                                        required property int index
                                        width: navColumn.width
                                        spacing: 2

                                        IslandDot {
                                            visible: navGroup.index !== 0
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Repeater {
                                            model: navGroup.modelData.indices

                                            delegate: IslandButton {
                                                required property int modelData
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                icon: root.iconOf(modelData)
                                                label: root.nameOf(modelData)
                                                page: modelData
                                                active: root.leadOf(root.currentPage) === modelData
                                                onClicked: if (root.leadOf(root.currentPage) !== modelData) root.currentPage = modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    IslandDot { Layout.alignment: Qt.AlignHCenter }

                    IslandButton {
                        id: islandToggle
                        Layout.alignment: Qt.AlignHCenter
                        icon: root.islandWide ? "left_panel_close" : "left_panel_open"
                        label: root.islandWide ? "Collapse" : "Expand"
                        onClicked: {
                            root.hideTip(islandToggle)
                            SettingsConfig.general = Object.assign({}, SettingsConfig.general, { settingsRailWide: !root.islandWide })
                        }
                    }

                }
            }

            ColumnLayout {
                id: pageArea
                x: island.width + 18
                width: frame.width - x
                height: frame.height
                spacing: 0

                RowLayout {
                    id: header
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.rightMargin: 4
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: root.pageOpacity

                        CustomText {
                            content: root.groupName
                            size: 12
                            weight: 500
                            customColor: Colors.outline
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.nameOf(root.shownPage)
                            size: 32
                            weight: 400
                            elide: Text.ElideRight
                            family: SettingsConfig.general.displayFont ?? "Titan One"
                            renderType: Text.QtRendering
                        }
                    }

                    Rectangle {
                        id: searchField
                        Layout.preferredWidth: 260
                        Layout.preferredHeight: 44
                        radius: 22
                        color: Colors.surfaceContainer
                        border.width: searchInput.activeFocus ? 2 : 0
                        border.color: Colors.primary

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
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
                                        root.searchAt = searchField.mapToItem(frame, searchField.width, searchField.height)
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
                        id: statusChip
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: statusRow.implicitWidth + 28
                        radius: 22
                        color: statusMouse.containsMouse || root.statusMenuOpen ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                        Behavior on color { EffectsColorAnim {} }

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: root.currentMode.tone
                                Behavior on color { EffectsColorAnim {} }
                            }

                            CustomText { content: root.currentMode.label; size: 12; weight: 500 }

                            MaterialIconSymbol {
                                content: "expand_more"
                                iconSize: 16
                                customColor: Colors.outline
                                rotation: root.statusMenuOpen ? 180 : 0
                                Behavior on rotation { SpatialAnim { speed: "fast" } }
                            }
                        }

                        MouseArea {
                            id: statusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.menuAt = statusChip.mapToItem(frame, statusChip.width, statusChip.height)
                                root.statusMenuOpen = !root.statusMenuOpen
                            }
                        }
                    }

                    Rectangle {
                        id: sectionsToggle
                        visible: root.sections.length >= 2
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: root.showSections ? Colors.secondaryContainer : Colors.surfaceContainer
                        Behavior on color { EffectsColorAnim {} }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "toc"
                            iconSize: 19
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

                    Rectangle {
                        id: lockButton
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: lockMouse.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                        Behavior on color { EffectsColorAnim {} }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "lock"
                            iconSize: 19
                            customColor: Colors.surfaceVariantText
                        }

                        MouseArea {
                            id: lockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTip(lockButton, "Lock now", true)
                            onExited: root.hideTip(lockButton)
                            onClicked: {
                                root.hideTip(lockButton)
                                GlobalStates.settingsOpen = false
                                Quickshell.execDetached(["loginctl", "lock-session"])
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    spacing: 0

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Item {
                            id: pageHost
                            width: parent.width
                            height: parent.height

                            PageSlot { page: 0; sourceComponent: Theme {} }
                            PageSlot { page: 1; sourceComponent: Sound {} }
                            PageSlot { page: 2; sourceComponent: Notifications {} }
                            PageSlot { page: 3; sourceComponent: Widgets {} }
                            PageSlot { page: 4; sourceComponent: Networking {} }
                            PageSlot { page: 5; sourceComponent: Bluetooth {} }
                            PageSlot { page: 6; sourceComponent: WeatherSettings {} }
                            PageSlot { page: 8; sourceComponent: About {} }
                            PageSlot { page: 12; sourceComponent: Lockscreen {} }
                            PageSlot { page: 14; sourceComponent: LayoutsSettings {} }
                            PageSlot { page: 15; sourceComponent: DisplaysSettings {} }
                            PageSlot { page: 16; sourceComponent: WindowsSettings {} }
                            PageSlot { page: 17; sourceComponent: InputSettings {} }
                            PageSlot { page: 19; sourceComponent: ProfileSettings {} }
                        }
                    }

                    ColumnLayout {
                        id: tocColumn
                        visible: root.tocSpace
                        opacity: root.pageOpacity * Math.max(0, Math.min(1, root.tocT))
                        transform: Translate { x: (1 - root.tocT) * 28 }
                        Layout.fillHeight: true
                        Layout.preferredWidth: 168
                        Layout.maximumWidth: 168
                        Layout.topMargin: 6
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
                                     : tocMouse.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
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
                visible: resultsPanel.visible
                enabled: resultsPanel.visible
                onPressed: mouse => {
                    root.searchOpen = false
                    searchInput.focus = false
                    mouse.accepted = false
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 20
                visible: root.statusMenuOpen
                enabled: root.statusMenuOpen
                onPressed: root.statusMenuOpen = false
            }

            Rectangle {
                id: statusMenu
                z: 21
                x: root.menuAt.x - width
                y: root.menuAt.y + 6
                width: 236
                height: statusMenuColumn.implicitHeight + 12
                radius: 18
                color: Colors.surfaceContainerHighest
                border.width: 1
                border.color: Colors.outlineVariant
                visible: opacity > 0.01
                opacity: root.statusMenuOpen ? 1 : 0
                scale: root.statusMenuOpen ? 1 : 0.92
                transformOrigin: Item.TopRight
                Behavior on opacity { EffectsAnim { speed: "fast" } }
                Behavior on scale { SpatialAnim { speed: "fast" } }

                ColumnLayout {
                    id: statusMenuColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: root.modes

                        delegate: Rectangle {
                            id: modeRow
                            required property var modelData
                            readonly property bool selected: root.mode === modeRow.modelData.value

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 12
                            color: modeRow.selected ? Colors.secondaryContainer
                                 : modeMouse.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
                            Behavior on color { EffectsColorAnim {} }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MaterialIconSymbol {
                                    content: modeRow.modelData.icon
                                    iconSize: 19
                                    customColor: modeRow.modelData.tone
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    CustomText {
                                        content: modeRow.modelData.label
                                        size: 13
                                        weight: 600
                                        customColor: modeRow.selected ? Colors.secondaryContainerText : Colors.surfaceText
                                    }

                                    CustomText {
                                        content: modeRow.modelData.hint
                                        size: 11
                                        customColor: modeRow.selected ? Qt.alpha(Colors.secondaryContainerText, 0.8) : Colors.outline
                                    }
                                }

                                MaterialIconSymbol {
                                    visible: modeRow.selected
                                    content: "check"
                                    iconSize: 18
                                    customColor: Colors.secondaryContainerText
                                }
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.setMode(modeRow.modelData.value)
                                    root.statusMenuOpen = false
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: resultsPanel
                visible: root.searchOpen && root.query.trim().length >= 2
                x: root.searchAt.x - width
                y: root.searchAt.y + 6
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
                                    content: root.iconOf(resultRow.modelData.page)
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
                                        content: root.placeOf(resultRow.modelData.page)
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
                width: tipRow.implicitWidth + 24
                height: 30
                radius: 10
                color: Colors.inverseSurface
                Behavior on opacity { EffectsAnim { speed: "fast" } }
                Behavior on y { enabled: railTip.visible; EffectsAnim { speed: "fast" } }

                RowLayout {
                    id: tipRow
                    anchors.centerIn: parent
                    spacing: 6

                    CustomText {
                        content: root.tipText
                        size: 12
                        weight: 600
                        customColor: Colors.inverseSurfaceText
                    }

                    CustomText {
                        visible: root.tipSub !== ""
                        content: "· " + root.tipSub
                        size: 12
                        customColor: Qt.alpha(Colors.inverseSurfaceText, 0.75)
                    }
                }
            }
        }
    }
}
