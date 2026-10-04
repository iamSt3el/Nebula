import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: appLauncher
    implicitHeight: parent.height

    signal closed

    property bool preview: false
    property int entranceDelay: 300
    property real entranceScale: 0.92
    property real entranceRise: 0

    onVisibleChanged: if (visible && col.visible && !appLauncher.preview) appLauncher.focusSearch()

    readonly property string mode: ServiceLauncher.mode
    readonly property bool isApps: mode === "apps"
    readonly property bool isEmoji: mode === "emoji"
    property string query: ""
    readonly property bool searching: appLauncher.query.length > 0

    property Item searchField: null
    property Item modeView: null
    readonly property Item styleItem: styleLoader.item
    readonly property var appView: appLauncher.styleItem ? appLauncher.styleItem.appView : null
    readonly property var activeView: appLauncher.isApps ? appLauncher.appView : appLauncher.modeView

    property string selectedCategory: "All"

    readonly property var _categoryMap: ({
        "AudioVideo": "Media",   "Audio": "Media",    "Video": "Media",
        "Development": "Dev",    "Education": "Education",
        "Game": "Games",         "Graphics": "Graphics",
        "Network": "Internet",   "Office": "Office",
        "Science": "Science",    "Settings": "Settings",
        "System": "System",      "Utility": "Utilities"
    })

    readonly property var _categoryIcons: ({
        "All": "apps", "Media": "play_circle", "Dev": "code", "Education": "school", "Games": "sports_esports",
        "Graphics": "brush", "Internet": "public", "Office": "description", "Science": "science",
        "Settings": "tune", "System": "settings", "Utilities": "build"
    })

    function categoryIcon(label) {
        return appLauncher._categoryIcons[label] ?? "category"
    }

    function categoryOf(app) {
        for (const c of (app?.categories ?? [])) {
            const l = appLauncher._categoryMap[c]
            if (l) return l
        }
        return ""
    }

    readonly property var availableCategories: {
        var seen = new Set()
        var result = [{ value: "All", label: "All" }]
        for (var app of ServiceApps.list) {
            for (var cat of (app.categories ?? [])) {
                var label = _categoryMap[cat]
                if (label && !seen.has(label)) {
                    seen.add(label)
                    result.push({ value: cat, label: label })
                }
            }
        }
        result.sort((a, b) => a.label === "All" ? -1 : b.label === "All" ? 1 : a.label.localeCompare(b.label))
        return result
    }

    readonly property string selectedLabel: {
        const c = appLauncher.availableCategories.find(x => x.value === appLauncher.selectedCategory)
        return c ? c.label : "All"
    }

    property var filteredApps: {
        var base = ServiceApps.filteredApps
        if (ServiceLauncher.sortMode === "used" && ServiceApps.currentSearchText.length === 0)
            base = ServiceApps.byUsage(base)
        if (selectedCategory === "All") return base
        var catKey = selectedCategory
        return base.filter(function(app) {
            return (app.categories ?? []).some(function(c) {
                return _categoryMap[c] === _categoryMap[catKey] || c === catKey
            })
        })
    }

    function usageCount(app) {
        const u = ServiceApps.usage[app?.id ?? ""]
        return u ? u.count : 0
    }

    function mostUsed(n) {
        const used = ServiceApps.byUsage(ServiceApps.list).filter(a => appLauncher.usageCount(a) > 0)
        const out = used.slice(0, n)
        for (const a of ServiceApps.pinnedApps) {
            if (out.length >= n) break
            if (out.indexOf(a) < 0) out.push(a)
        }
        return out
    }

    function favourites(n) {
        const out = Array.prototype.slice.call(ServiceApps.pinnedApps, 0, n)
        return out.length > 0 ? out : appLauncher.mostUsed(n)
    }

    function timeAgo(app) {
        const u = ServiceApps.usage[app?.id ?? ""]
        if (!u) return ""
        const m = Math.floor((Date.now() - u.last) / 60000)
        if (m < 1) return "Just now"
        if (m < 60) return m + " min ago"
        const h = Math.floor(m / 60)
        if (h < 24) return h + " h ago"
        const d = Math.floor(h / 24)
        return d === 1 ? "Yesterday" : d + " days ago"
    }

    function iconFor(app) {
        return IconUtil.getDesktopIconPath(app?.icon ?? "")
    }

    function launch(app) {
        if (!app) return
        ServiceApps.run(app)
        appLauncher.closed()
    }

    function openMenu(item, x, y, app) {
        const p = item.mapToItem(appLauncher, x, y)
        appLauncher.showContextMenu(p.x, p.y, app)
    }

    function focusSearch() {
        if (appLauncher.searchField && !appLauncher.preview)
            appLauncher.searchField.focusInput()
    }

    function setQuery(text) {
        if (appLauncher.searchField)
            appLauncher.searchField.text = text
        appLauncher.focusSearch()
    }

    function selectCategory(value) {
        appLauncher.selectedCategory = value
        if (appLauncher.appView) appLauncher.appView.activeIndex = 0
    }

    onClosed: {
        col.visible = false
        col.opacity = 0
        col.scale   = appLauncher.entranceScale
        if (appLauncher.searchField) appLauncher.searchField.text = ""
        appLauncher.query = ""
        ServiceApps.reset()
        ServiceLauncher.reset()
        if (appLauncher.appView) appLauncher.appView.activeIndex = 0
        if (appLauncher.styleItem && appLauncher.styleItem.reset) appLauncher.styleItem.reset()
        selectedCategory = "All"
    }

    function clearSearch() {
        if (appLauncher.searchField) appLauncher.searchField.text = ""
        appLauncher.query = ""
        ServiceLauncher.reset()
        ServiceApps.updateSearch("")
        appLauncher.selectedCategory = "All"
        if (appLauncher.appView) appLauncher.appView.activeIndex = 0
    }

    Component.onCompleted: {
        appLauncher.clearSearch()
        if (GlobalStates.launcherSeed !== "") {
            const seed = GlobalStates.launcherSeed
            GlobalStates.launcherSeed = ""
            Qt.callLater(function () {
                if (appLauncher.searchField) {
                    appLauncher.searchField.text = seed
                    appLauncher.searchField.cursorPosition = seed.length
                }
                appLauncher.updateQuery(seed)
            })
        }
    }

    function updateQuery(text) {
        appLauncher.query = text
        ServiceLauncher.query = text
        ServiceApps.updateSearch(ServiceLauncher.mode === "apps" ? text : "")
        if (activeView) activeView.activeIndex = 0
    }

    function activateSelected() {
        const v = appLauncher.activeView
        if (v) v.activateIndex(v.activeIndex)
    }

    function handleKey(event) {
        const view = appLauncher.activeView
        if (event.key === Qt.Key_Escape) {
            if (appLauncher.styleItem && appLauncher.styleItem.handleEscape && appLauncher.styleItem.handleEscape()) {
                event.accepted = true
            } else if (!appLauncher.isApps || appLauncher.searching) {
                appLauncher.setQuery("")
                event.accepted = true
            } else {
                appLauncher.closed()
            }
            return
        }
        if (event.key === Qt.Key_Backspace && appLauncher.searchField
                && appLauncher.searchField.cursorPosition === 0 && !appLauncher.isApps) {
            appLauncher.setQuery("")
            event.accepted = true
            return
        }
        if (!view) return
        if (view.navigate && view.navigate(event.key)) {
            event.accepted = true
            return
        }
        const cols = view.columns ?? 1
        const grid = cols > 1
        const last = (view.navCount ?? view.count) - 1
        function moveTo(i) {
            view.activeIndex = Math.max(0, Math.min(last, i))
            if (view.reveal) view.reveal(view.activeIndex)
            else view.positionViewAtIndex(view.activeIndex, GridView.Contain)
        }
        if (event.key === Qt.Key_Down) {
            moveTo(view.activeIndex + (grid ? cols : 1)); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            moveTo(view.activeIndex - (grid ? cols : 1)); event.accepted = true
        } else if (event.key === Qt.Key_Right && grid) {
            moveTo(view.activeIndex + 1); event.accepted = true
        } else if (event.key === Qt.Key_Left && grid) {
            moveTo(view.activeIndex - 1); event.accepted = true
        }
    }

    function showContextMenu(clickX, clickY, app) {
        ctxMenu.targetApp = app
        ctxMenu.x = Math.max(4, Math.min(clickX, width - ctxMenu.width - 4))
        ctxMenu.y = clickY
    }

    Connections {
        target: GlobalStates
        function onAppLauncherOpenChanged() {
            if (GlobalStates.appLauncherOpen) {
                appLauncher.clearSearch()
                return
            }
            if (!appLauncher.preview) {
                showTimer.stop()
                col.visible = false
                col.opacity = 0
                col.scale   = appLauncher.entranceScale
            }
        }
    }

    Item {
        id: col
        anchors.fill: parent
        anchors.margins: 10
        visible: false
        opacity: 0
        scale: appLauncher.entranceScale
        transform: Translate { id: colRise; y: 0 }

        Timer {
            id: showTimer
            interval: appLauncher.entranceDelay
            onTriggered: {
                col.visible = true
                entranceAnim.start()
                appLauncher.focusSearch()
            }
        }

        Component.onCompleted: showTimer.start()

        ParallelAnimation {
            id: entranceAnim
            NumberAnimation {
                target: col; property: "opacity"
                from: 0; to: 1
                duration: 200; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: col; property: "scale"
                from: appLauncher.entranceScale; to: 1
                duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
            NumberAnimation {
                target: colRise; property: "y"
                from: appLauncher.entranceRise; to: 0
                duration: M3Motion.spatialDuration("default")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            }
        }

        Loader {
            id: styleLoader
            anchors.fill: parent
            sourceComponent: {
                switch (ServiceLauncher.style) {
                case "spotlight":  return spotlightComp
                case "rail":       return railComp
                case "bento":      return bentoComp
                case "folders":    return foldersComp
                case "expressive": return expressiveComp
                case "hearth":     return hearthComp
                }
                return listComp
            }
            onLoaded: {
                const q = appLauncher.query
                if (appLauncher.searchField) appLauncher.searchField.text = q
                appLauncher.focusSearch()
            }
        }
    }

    Component { id: spotlightComp;  LauncherStyleSpotlight  { launcher: appLauncher } }
    Component { id: railComp;       LauncherStyleRail       { launcher: appLauncher } }
    Component { id: bentoComp;      LauncherStyleBento      { launcher: appLauncher } }
    Component { id: foldersComp;    LauncherStyleFolders    { launcher: appLauncher } }
    Component { id: listComp;       LauncherStyleList       { launcher: appLauncher } }
    Component { id: expressiveComp; LauncherStyleExpressive { launcher: appLauncher } }
    Component { id: hearthComp;     LauncherStyleHearth     { launcher: appLauncher } }

    // ── Context menu click-away ────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: ctxMenu.targetApp !== null
        z: 98
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: ctxMenu.targetApp = null
        onPressed: ctxMenu.targetApp = null
    }

    // ── Context menu ──────────────────────────────────────────────────────
    Rectangle {
        id: ctxMenu
        property var targetApp: null

        visible: targetApp !== null
        z: 99
        width: 220
        height: cmCol.implicitHeight + 16
        radius: 18
        color: Colors.surfaceContainer

        onHeightChanged: {
            if (y + height > appLauncher.height - 8)
                y = Math.max(4, appLauncher.height - height - 8)
        }

        scale: visible ? 1 : 0.88
        opacity: visible ? 1 : 0
        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            id: cmCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            spacing: 6

            // App header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 12
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 10
                        color: Qt.alpha(Colors.primary, 0.1)

                        Image {
                            anchors.centerIn: parent
                            width: 26; height: 26
                            source: IconUtil.getDesktopIconPath(ctxMenu.targetApp?.icon ?? "")
                            sourceSize.width: 26
                            sourceSize.height: 26
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CustomText {
                            Layout.fillWidth: true
                            content: ctxMenu.targetApp?.name ?? ""
                            size: 13; weight: 700
                            elide: Text.ElideRight
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: ctxMenu.targetApp?.genericName || ctxMenu.targetApp?.comment || ""
                            size: 10
                            customColor: Colors.outline
                            elide: Text.ElideRight
                            visible: (ctxMenu.targetApp?.genericName || ctxMenu.targetApp?.comment || "").length > 0
                        }
                    }
                }
            }

            // Actions
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cmActions.implicitHeight
                radius: 12
                color: Colors.surfaceContainerHigh
                clip: true

                ColumnLayout {
                    id: cmActions
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    // Launch
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol { content: "rocket_launch"; iconSize: 16; customColor: Colors.primary }
                            CustomText { Layout.fillWidth: true; content: "Launch"; size: 13 }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                ServiceApps.run(ctxMenu.targetApp)
                                ctxMenu.targetApp = null
                                appLauncher.closed()
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.surfaceContainerHighest }

                    // Pin / Unpin
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        readonly property bool pinned: ctxMenu.targetApp
                            ? ServiceApps.isPinned(ctxMenu.targetApp) : false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "push_pin"; iconSize: 16
                                fill: parent.parent.pinned ? 1 : 0
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: parent.parent.pinned ? "Unpin from Dock" : "Pin to Dock"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                ServiceApps.togglePin(ctxMenu.targetApp)
                                ctxMenu.targetApp = null
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.surfaceContainerHighest }

                    // Copy name
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol { content: "content_copy"; iconSize: 16; customColor: Colors.outline }
                            CustomText { Layout.fillWidth: true; content: "Copy Name"; size: 13 }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.clipboardText = ctxMenu.targetApp?.name ?? ""
                                ctxMenu.targetApp = null
                            }
                        }
                    }
                }
            }
        }
    }
}
