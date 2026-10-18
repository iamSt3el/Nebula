import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property string tab: "all"
    property bool railOpen: false
    property string railTab: "colour"
    property var picked: null

    property bool filterOpen: false
    property bool colourOpen: false
    property var draft: ({})
    property real sheetX: 0
    property real sheetY: 0
    property real popX: 0
    property real popY: 0
    property string themeMatch: ""

    readonly property bool online: ServiceWallpaper.onlineMode
    readonly property var items: root.online ? ServiceWallpaper.onlineWallpapers
        : root.tab === "favorites" ? ServiceWallpaper.favoritedWallpapers
        : ServiceWallpaper.filteredWallpapers
    readonly property int itemCount: root.items ? root.items.length : 0
    readonly property var wh: SettingsConfig.wallhaven

    readonly property string pickedId: root.online ? root.idOf(root.picked) : ""
    readonly property string pickedLocal: root.online ? ServiceWallpaper.localFor(root.picked) : ""
    readonly property string pickedFile: root.online ? root.pickedLocal
        : root.picked ? ServiceWallpaper.getOriginalPath(root.picked) : ""
    readonly property var pickedInfo: ServiceWallpaper.infoFor(root.pickedFile)
    readonly property var details: root.online ? ServiceWallpaper.detailsFor(root.pickedId) : null
    onPickedFileChanged: ServiceWallpaper.requestInfo(root.pickedFile)

    readonly property string metaText: {
        if (!root.online && !root.pickedInfo) return ""
        const parts = []
        if (root.pickedInfo) {
            parts.push(root.pickedInfo.width + " × " + root.pickedInfo.height)
            parts.push(ServiceWallpaper.formatBytes(root.pickedInfo.bytes))
        } else if (root.online && root.pickedId !== "") {
            parts.push((root.picked.resolution || "").replace("x", " × "))
            parts.push(ServiceWallpaper.formatBytes(root.picked.fileSize))
        }
        const f = root.online ? (root.picked && root.picked.fullUrl ? root.picked.fullUrl : "") : root.pickedFile
        const ext = f.split("?")[0].split(".").pop().toUpperCase()
        if (f && ext.length <= 4) parts.push(ext === "JPEG" ? "JPG" : ext)
        if (root.online && root.pickedLocal !== "") parts.push("Downloaded")
        return parts.filter(p => p !== "").join("  ·  ")
    }

    readonly property string statsText: {
        if (!root.online || root.pickedId === "") return ""
        const by = root.details && root.details.uploader ? "by " + root.details.uploader + "  ·  " : ""
        return by + root.kfmt(root.picked.favorites || 0) + " favourites  ·  " + root.kfmt(root.picked.views || 0) + " views"
    }

    readonly property bool pickedIsCurrent: root.online
        ? root.pickedLocal !== "" && root.pickedLocal === ServiceWallpaper.currentSource
        : root.picked !== null && root.picked === ServiceWallpaper.currentCachePath
    readonly property var preview: !root.online ? (root.picked ? ServiceWallpaper.previewFor(root.picked) : null)
        : ServiceWallpaper.onlinePreviewFor(root.picked)
    readonly property bool downloading: root.pickedId !== "" && ServiceWallpaper.downloadingId === root.pickedId
    readonly property bool queued: root.pickedId !== "" && ServiceWallpaper.queuedIds.indexOf(root.pickedId) >= 0
    readonly property bool pickFailed: root.pickedId !== "" && ServiceWallpaper.failedIds.indexOf(root.pickedId) >= 0
    readonly property int queueLen: ServiceWallpaper.queuedIds.length
    readonly property bool busy: ServiceWallpaper.downloadingId !== "" || root.queueLen > 0

    readonly property var sortNames: ({ date_added: "Latest", toplist: "Top", views: "Views", favorites: "Favs", random: "Random", relevance: "Relevant" })
    readonly property var rangeNames: ({ "1d": "1 day", "3d": "3 days", "1w": "1 week", "1M": "1 month", "3M": "3 months", "6M": "6 months", "1y": "1 year" })
    readonly property var rangeWords: ({ "1d": "day", "3d": "3 days", "1w": "week", "1M": "month", "3M": "3 months", "6M": "6 months", "1y": "year" })

    function kfmt(n) {
        if (n < 1000) return String(n)
        return (n / 1000).toFixed(1).replace(".0", "") + "k"
    }

    function capital(s) {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
    }

    function catsText(bits) {
        const names = ["General", "Anime", "People"].filter((n, i) => String(bits)[i] === "1")
        return names.length === 3 ? "All categories" : names.join(", ")
    }

    function purityText(bits) {
        return ["SFW", "Sketchy", "NSFW"].filter((n, i) => String(bits)[i] === "1").join(", ")
    }

    function summaryText(w) {
        const parts = [root.sortNames[w.sorting] || "Top"]
        if (w.sorting === "toplist") parts[0] += " · " + (root.rangeNames[w.topRange] || w.topRange)
        parts.push(root.catsText(w.categories))
        parts.push(root.purityText(w.purity))
        return parts.join(" · ")
    }

    function orderNames(sorting) {
        return sorting === "date_added" ? ["Newest first", "Oldest first"] : ["Highest first", "Lowest first"]
    }

    function idOf(it) {
        return it && typeof it === "object" && it.id !== undefined ? it.id : ""
    }

    function nameOf(it) {
        if (!it) return ""
        if (root.online) return root.idOf(it) !== "" ? "wallhaven-" + it.id : ""
        const p = ServiceWallpaper.getOriginalPath(it)
        const f = p.split("/").pop()
        const dot = f.lastIndexOf(".")
        return dot > 0 ? f.slice(0, dot) : f
    }

    function thumbOf(it) {
        if (!it) return ""
        if (root.online) return typeof it === "object" && it.thumbUrl ? it.thumbUrl : ""
        return typeof it === "string" ? "file://" + it : ""
    }

    function apply(it) {
        if (!it) return
        const local = root.online ? ServiceWallpaper.localFor(it) : ""
        if (local !== "") ServiceWallpaper.applyFile(local)
        else if (root.online) ServiceWallpaper.downloadAndSetWallpaper(it)
        else ServiceWallpaper.setWallpaper(it)
    }

    function pick(i) {
        if (i < 0 || i >= root.itemCount) return
        grid.currentIndex = i
        root.picked = root.items[i]
    }

    function revealRow(i) {
        const maxY = Math.max(0, grid.contentHeight - grid.height)
        grid.contentY = Math.min(maxY, Math.floor(i / grid.cols) * grid.cellHeight)
    }

    function shuffle() {
        if (root.itemCount < 2) return
        let i = Math.floor(Math.random() * root.itemCount)
        if (root.items[i] === root.picked) i = (i + 1) % root.itemCount
        root.pick(i)
        grid.positionViewAtIndex(i, GridView.Contain)
    }

    function setTab(t) {
        root.closeOverlays()
        if (t === "online") {
            if (!root.online) {
                search.text = ""
                ServiceWallpaper.updateSearch("")
                ServiceWallpaper.onlineMode = true
                ServiceWallpaper.fetchWallhaven(true)
            }
        } else {
            if (root.online) {
                search.text = ""
                ServiceWallpaper.onlineMode = false
            }
            root.tab = t
        }
        grid.currentIndex = -1
    }

    function searchFor(t) {
        root.closeOverlays()
        search.text = t
        grid.contentY = 0
        ServiceWallpaper.searchOnline(t)
    }

    function showMenu(x, y, data, isOnline) {
        ctxLoader.active = true
        ctxLoader.item.show(x, y, data, isOnline)
    }

    function closeOverlays() {
        root.filterOpen = false
        root.colourOpen = false
    }

    function openSheet() {
        if (root.filterOpen) {
            root.filterOpen = false
            return
        }
        root.colourOpen = false
        const p = summaryChip.mapToItem(root, 0, summaryChip.height + 6)
        root.sheetX = p.x
        root.sheetY = p.y
        root.draft = Object.assign({}, SettingsConfig.wallhaven)
        root.filterOpen = true
        ServiceWallpaper.requestCount(root.draft)
    }

    function setDraft(p) {
        root.draft = Object.assign({}, root.draft, p)
        ServiceWallpaper.requestCount(root.draft)
    }

    function flipDraft(key, pos) {
        const bits = String(root.draft[key]).split("")
        bits[pos] = bits[pos] === "1" ? "0" : "1"
        if (!bits.includes("1")) return
        const p = {}
        p[key] = bits.join("")
        root.setDraft(p)
    }

    function resetDraft() {
        root.setDraft({ categories: "111", purity: "100", sorting: "toplist", order: "desc", topRange: "1M", atleast: "", ratios: "" })
    }

    function applySheet() {
        SettingsConfig.wallhaven = Object.assign({}, root.draft)
        root.filterOpen = false
        grid.contentY = 0
        ServiceWallpaper.fetchWallhaven(true)
    }

    function openColours() {
        if (root.colourOpen) {
            root.colourOpen = false
            return
        }
        root.filterOpen = false
        const p = colourChip.mapToItem(root, 0, colourChip.height + 6)
        root.popX = Math.min(p.x, root.width - 430)
        root.popY = p.y
        root.themeMatch = ServiceWallpaper.matchThemeColor()
        root.colourOpen = true
    }

    function pickColour(hex) {
        root.colourOpen = false
        grid.contentY = 0
        ServiceWallpaper.setOnlineColor(hex)
    }

    function toggleFit() {
        if (ServiceWallpaper.fitsScreen()) ServiceWallpaper.patchWallhaven({ atleast: "", ratios: "" })
        else ServiceWallpaper.patchWallhaven({ atleast: ServiceWallpaper.fitAtleast, ratios: ServiceWallpaper.fitRatio })
    }

    readonly property var narrowing: {
        const w = root.wh
        const out = []
        if (ServiceWallpaper.fitsScreen(w)) {
            out.push({ key: "fit", label: "Fits my screen", dot: "" })
        } else {
            if ((w.atleast ?? "") !== "") out.push({ key: "atleast", label: "At least " + w.atleast.replace("x", "×"), dot: "" })
            if ((w.ratios ?? "") !== "") out.push({ key: "ratios", label: w.ratios.replace("x", ":"), dot: "" })
        }
        if (ServiceWallpaper.onlineColor !== "")
            out.push({ key: "colour", label: "#" + ServiceWallpaper.onlineColor, dot: "#" + ServiceWallpaper.onlineColor })
        if (w.categories !== "111") out.push({ key: "cats", label: "Only " + root.catsText(w.categories), dot: "" })
        if (w.sorting === "toplist" && ["1d", "3d", "1w"].indexOf(w.topRange) >= 0)
            out.push({ key: "range", label: "Top of the past " + root.rangeNames[w.topRange], dot: "" })
        return out
    }

    function dropNarrowing(key) {
        if (key === "colour") {
            ServiceWallpaper.setOnlineColor("")
            return
        }
        const p = {}
        if (key === "fit") { p.atleast = ""; p.ratios = "" }
        else if (key === "atleast") p.atleast = ""
        else if (key === "ratios") p.ratios = ""
        else if (key === "cats") p.categories = "111"
        else if (key === "range") p.topRange = "1y"
        ServiceWallpaper.patchWallhaven(p)
    }

    function clearNarrowing() {
        ServiceWallpaper.onlineColor = ""
        const p = { atleast: "", ratios: "", categories: "111" }
        if (root.wh.sorting === "toplist") p.topRange = "1y"
        ServiceWallpaper.patchWallhaven(p)
    }

    onPickedChanged: {
        if (!root.picked) return
        if (root.online) onlineTimer.restart()
        else previewTimer.restart()
    }

    function syncOnline() {
        if (!root.online) {
            onlineModel.clear()
            return
        }
        const n = ServiceWallpaper.onlineWallpapers.length
        if (n < onlineModel.count) onlineModel.clear()
        for (let i = onlineModel.count; i < n; i++) onlineModel.append({})
        if (root.idOf(root.picked) === "" && n > 0) root.picked = ServiceWallpaper.onlineWallpapers[0]
    }

    function pickDefault() {
        const cur = ServiceWallpaper.currentCachePath
        const i = root.online ? -1 : root.items.indexOf(cur)
        if (i >= 0) {
            root.pick(i)
            Qt.callLater(root.revealRow, i)
        } else if (!root.online && ServiceWallpaper.wallpapers.indexOf(cur) >= 0) {
            root.picked = cur
        } else if (root.itemCount > 0) {
            root.picked = root.items[0]
        }
    }

    ListModel { id: onlineModel }

    Connections {
        target: ServiceWallpaper
        function onOnlineWallpapersChanged() { root.syncOnline() }
        function onOnlineModeChanged() {
            root.picked = null
            grid.currentIndex = -1
            root.syncOnline()
            if (!root.online) root.pickDefault()
        }
    }

    Timer {
        id: previewTimer
        interval: 120
        onTriggered: ServiceWallpaper.requestPreview(root.picked)
    }

    Timer {
        id: onlineTimer
        interval: 220
        onTriggered: {
            if (root.pickedId === "") return
            ServiceWallpaper.requestOnlinePreview(root.picked)
            ServiceWallpaper.requestDetails(root.pickedId)
        }
    }

    Component.onCompleted: {
        root.syncOnline()
        root.pickDefault()
        if (!GlobalStates.barEditMode) search.forceActiveFocus()
    }

    Item {
        id: pal
        visible: false
        property color primary: root.preview ? root.preview.primary : Colors.primary
        property color primaryText: root.preview ? root.preview.primaryText : Colors.primaryText
        property color secondary: root.preview ? root.preview.secondary : Colors.secondary
        property color secondaryContainer: root.preview ? root.preview.secondaryContainer : Colors.secondaryContainer
        property color secondaryContainerText: root.preview ? root.preview.secondaryContainerText : Colors.secondaryContainerText
        property color primaryContainer: root.preview ? root.preview.primaryContainer : Colors.primaryContainer
        property color tertiary: root.preview ? root.preview.tertiary : Colors.tertiary
        property color tertiaryContainer: root.preview ? root.preview.tertiaryContainer : Colors.tertiaryContainer
        property color container: root.preview ? root.preview.surfaceContainer : Colors.surfaceContainer
        property color containerHigh: root.preview ? root.preview.surfaceContainerHigh : Colors.surfaceContainerHigh
        property color containerHighest: root.preview ? root.preview.surfaceContainerHighest : Colors.surfaceContainerHighest
        property color text: root.preview ? root.preview.surfaceText : Colors.surfaceText
        property color subtext: root.preview ? root.preview.surfaceVariantText : Colors.surfaceVariantText
        property color outlineVariant: root.preview ? root.preview.outlineVariant : Colors.outlineVariant

        Behavior on primary { EffectsColorAnim { speed: "slow" } }
        Behavior on primaryText { EffectsColorAnim { speed: "slow" } }
        Behavior on secondary { EffectsColorAnim { speed: "slow" } }
        Behavior on secondaryContainer { EffectsColorAnim { speed: "slow" } }
        Behavior on secondaryContainerText { EffectsColorAnim { speed: "slow" } }
        Behavior on primaryContainer { EffectsColorAnim { speed: "slow" } }
        Behavior on tertiary { EffectsColorAnim { speed: "slow" } }
        Behavior on tertiaryContainer { EffectsColorAnim { speed: "slow" } }
        Behavior on container { EffectsColorAnim { speed: "slow" } }
        Behavior on containerHigh { EffectsColorAnim { speed: "slow" } }
        Behavior on containerHighest { EffectsColorAnim { speed: "slow" } }
        Behavior on text { EffectsColorAnim { speed: "slow" } }
        Behavior on subtext { EffectsColorAnim { speed: "slow" } }
        Behavior on outlineVariant { EffectsColorAnim { speed: "slow" } }
    }

    component PalIconButton: Rectangle {
        id: pib
        property Item tone: null
        property string icon: ""
        property bool lit: false
        property int box: 44
        signal clicked
        implicitWidth: box
        implicitHeight: box
        radius: pibArea.pressed ? 12 : box / 2
        color: pib.lit ? tone.secondaryContainer : pibArea.containsMouse ? tone.containerHighest : tone.containerHigh
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: pib.icon
            iconSize: 20
            customColor: pib.lit ? tone.secondaryContainerText : tone.text
        }
        CustomMouseArea {
            id: pibArea
            radius: pib.radius
            hoverEnabled: true
            onClicked: pib.clicked()
        }
    }

    component FChip: Rectangle {
        id: fc
        property Item tone: null
        property string icon: ""
        property string label: ""
        property string trailing: ""
        property string dot: ""
        property bool lit: false
        property bool open: false
        property bool dim: false
        property int h: 32
        signal clicked
        implicitHeight: fc.h
        implicitWidth: fcRow.implicitWidth + 24
        radius: 9
        opacity: fc.dim ? 0.45 : 1
        color: fc.lit ? tone.secondaryContainer : fc.open ? tone.containerHighest
            : fcArea.containsMouse && !fc.dim ? tone.containerHigh : "transparent"
        border.width: fc.lit || fc.open ? 0 : 1
        border.color: tone.outlineVariant
        Behavior on color { EffectsColorAnim { speed: "fast" } }
        RowLayout {
            id: fcRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                visible: fc.dot !== ""
                implicitWidth: 14
                implicitHeight: 14
                radius: 7
                color: fc.dot !== "" ? fc.dot : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }
            MaterialIconSymbol {
                visible: fc.icon !== ""
                content: fc.icon
                iconSize: 16
                customColor: fc.lit ? tone.secondaryContainerText : fc.open ? tone.text : tone.subtext
            }
            CustomText {
                visible: fc.label !== ""
                content: fc.label
                size: 12
                weight: 500
                customColor: fc.lit ? tone.secondaryContainerText : fc.open ? tone.text : tone.subtext
            }
            MaterialIconSymbol {
                visible: fc.trailing !== ""
                content: fc.trailing
                iconSize: 16
                customColor: fc.lit ? tone.secondaryContainerText : fc.open ? tone.text : tone.subtext
            }
        }
        CustomMouseArea {
            id: fcArea
            radius: fc.radius
            hoverEnabled: true
            enabled: !fc.dim
            onClicked: fc.clicked()
        }
    }

    component Pill: Rectangle {
        id: pl
        property string icon: ""
        property string label: ""
        property color fg: "white"
        implicitHeight: 24
        implicitWidth: plRow.implicitWidth + 18
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.58)
        RowLayout {
            id: plRow
            anchors.centerIn: parent
            spacing: 4
            MaterialIconSymbol {
                visible: pl.icon !== ""
                content: pl.icon
                iconSize: 13
                customColor: pl.fg
            }
            CustomText {
                visible: pl.label !== ""
                content: pl.label
                size: 11
                weight: 600
                customColor: pl.fg
            }
        }
    }

    component SRow: RowLayout {
        id: srow
        property Item tone: null
        property string label: ""
        Layout.fillWidth: true
        Layout.minimumHeight: 30
        spacing: 6
        CustomText {
            Layout.preferredWidth: 92
            content: srow.label
            size: 12
            weight: 600
            customColor: srow.tone ? srow.tone.subtext : Colors.surfaceVariantText
        }
    }

    component EdgePath: ShapePath {
        property real o: 1.5
        property real r: 17
        property real w: 10
        property real h: 10
        fillColor: "transparent"
        strokeWidth: 3
        startX: o + r
        startY: o
        PathLine { x: o + w - r; y: o }
        PathArc { x: o + w; y: o + r; radiusX: r; radiusY: r }
        PathLine { x: o + w; y: o + h - r }
        PathArc { x: o + w - r; y: o + h; radiusX: r; radiusY: r }
        PathLine { x: o + r; y: o + h }
        PathArc { x: o; y: o + h - r; radiusX: r; radiusY: r }
        PathLine { x: o; y: o + r }
        PathArc { x: o + r; y: o; radiusX: r; radiusY: r }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 20

        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillHeight: true
            spacing: 4

            CustomText {
                Layout.leftMargin: 14
                Layout.bottomMargin: 6
                content: "Browse"
                size: 12
                weight: 600
                customColor: pal.subtext
            }

            Repeater {
                model: [
                    { key: "all", icon: "photo_library", label: "All" },
                    { key: "favorites", icon: "favorite", label: "Favourites" },
                    { key: "online", icon: "public", label: "Online" }
                ]
                Rectangle {
                    id: railItem
                    required property var modelData
                    readonly property bool lit: railItem.modelData.key === "online" ? root.online
                        : !root.online && root.tab === railItem.modelData.key
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: railArea.pressed ? 14 : 23
                    color: railItem.lit ? pal.secondaryContainer : railArea.containsMouse ? pal.containerHigh : Qt.alpha(pal.containerHigh, 0)
                    Behavior on color { EffectsColorAnim { speed: "fast" } }
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12
                        MaterialIconSymbol {
                            content: railItem.modelData.icon
                            iconSize: 20
                            customColor: railItem.lit ? pal.secondaryContainerText : pal.subtext
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: railItem.modelData.label
                            size: 14
                            weight: 500
                            customColor: railItem.lit ? pal.secondaryContainerText : pal.text
                        }
                        CustomText {
                            content: railItem.modelData.key === "all" ? String(ServiceWallpaper.wallpapers.length)
                                : railItem.modelData.key === "favorites" ? String(ServiceWallpaper.favoritedWallpapers.length)
                                : root.online ? String(root.itemCount) : ""
                            size: 12
                            weight: 500
                            customColor: railItem.lit ? pal.secondaryContainerText : pal.subtext
                        }
                    }
                    CustomMouseArea {
                        id: railArea
                        radius: railItem.radius
                        hoverEnabled: true
                        onClicked: root.setTab(railItem.modelData.key)
                    }
                }
            }

            CustomText {
                visible: root.online && ServiceWallpaper.recentSearches.length > 0
                Layout.leftMargin: 14
                Layout.topMargin: 14
                Layout.bottomMargin: 4
                content: "Recent searches"
                size: 12
                weight: 600
                customColor: pal.subtext
            }

            Repeater {
                model: root.online ? ServiceWallpaper.recentSearches : []
                Rectangle {
                    id: recentRow
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 19
                    color: recentArea.containsMouse ? pal.containerHigh : Qt.alpha(pal.containerHigh, 0)
                    Behavior on color { EffectsColorAnim { speed: "fast" } }
                    CustomMouseArea {
                        id: recentArea
                        radius: recentRow.radius
                        hoverEnabled: true
                        onClicked: root.searchFor(recentRow.modelData)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 10
                        MaterialIconSymbol {
                            content: "history"
                            iconSize: 18
                            customColor: pal.subtext
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: recentRow.modelData
                            size: 13
                            elide: Text.ElideRight
                            customColor: pal.text
                        }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: forgetArea.containsMouse ? pal.containerHighest : "transparent"
                            opacity: recentArea.containsMouse || forgetArea.containsMouse ? 1 : 0.6
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "close"
                                iconSize: 16
                                customColor: pal.subtext
                            }
                            CustomMouseArea {
                                id: forgetArea
                                radius: 13
                                hoverEnabled: true
                                onClicked: ServiceWallpaper.forgetSearch(recentRow.modelData)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            CustomText {
                Layout.leftMargin: 14
                content: "Folder"
                size: 12
                weight: 600
                customColor: pal.subtext
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 8
                MaterialIconSymbol {
                    content: "folder"
                    iconSize: 18
                    customColor: pal.primary
                }
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceWallpaper.wallpaperDir.replace(Quickshell.env("HOME"), "~")
                    size: 13
                    weight: 500
                    elide: Text.ElideMiddle
                    customColor: pal.text
                }
                PalIconButton {
                    tone: pal
                    icon: "refresh"
                    box: 36
                    onClicked: ServiceWallpaper.refresh()
                }
            }
        }

        ColumnLayout {
            id: centerCol
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 22
                    color: pal.containerHigh
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 10
                        MaterialIconSymbol {
                            content: "search"
                            iconSize: 18
                            customColor: pal.subtext
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text.length === 0
                                content: root.online ? "Search Wallhaven, press Enter"
                                    : "Search " + ServiceWallpaper.wallpapers.length + " wallpapers"
                                size: 14
                                weight: 400
                                customColor: pal.subtext
                            }
                            TextInput {
                                id: search
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                font.pixelSize: 14
                                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                color: pal.text
                                onTextChanged: if (!root.online) {
                                    if (root.tab === "favorites" && text.length > 0) root.tab = "all"
                                    ServiceWallpaper.updateSearch(text)
                                }
                                Keys.onReturnPressed: {
                                    if (root.online) {
                                        root.closeOverlays()
                                        grid.contentY = 0
                                        ServiceWallpaper.searchOnline(text.trim())
                                    } else if (root.itemCount > 0) {
                                        root.pick(0)
                                        grid.forceActiveFocus()
                                    }
                                }
                                Keys.onEscapePressed: {
                                    if (root.filterOpen || root.colourOpen) root.closeOverlays()
                                    else text = ""
                                }
                                Keys.onDownPressed: {
                                    grid.forceActiveFocus()
                                    if (grid.currentIndex < 0) root.pick(0)
                                }
                            }
                        }
                        Rectangle {
                            visible: search.text.length === 0 && !search.activeFocus
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 6
                            color: "transparent"
                            border.width: 1
                            border.color: pal.outlineVariant
                            CustomText {
                                anchors.centerIn: parent
                                content: "/"
                                size: 11
                                weight: 600
                                customColor: pal.subtext
                            }
                        }
                        MaterialIconSymbol {
                            visible: search.text.length > 0
                            content: "close"
                            iconSize: 16
                            customColor: pal.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: search.text = ""
                            }
                        }
                    }
                }

                M3ButtonGroup {
                    visible: !root.online
                    Layout.preferredHeight: 40
                    model: [{ value: "name", label: "Name", icon: "sort_by_alpha" }, { value: "newest", label: "Newest", icon: "schedule" }]
                    activeCheck: v => ServiceWallpaper.localSortBy === v
                    onSegmentClicked: v => ServiceWallpaper.localSortBy = v
                    activeColor: pal.primary
                    activeTextColor: pal.primaryText
                    inactiveColor: pal.containerHigh
                    inactiveTextColor: pal.text
                    iconSize: 16
                    textSize: 12
                }

                PalIconButton {
                    tone: pal
                    icon: "tune"
                    lit: root.railOpen
                    onClicked: root.railOpen = !root.railOpen
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: root.online
                spacing: 6

                FChip {
                    id: summaryChip
                    tone: pal
                    icon: "trending_up"
                    label: root.summaryText(root.wh)
                    trailing: root.filterOpen ? "expand_less" : "expand_more"
                    open: root.filterOpen
                    onClicked: root.openSheet()
                }
                FChip {
                    tone: pal
                    icon: "aspect_ratio"
                    label: "Fits my screen"
                    lit: ServiceWallpaper.fitsScreen(root.wh)
                    onClicked: root.toggleFit()
                }
                FChip {
                    id: colourChip
                    tone: pal
                    icon: ServiceWallpaper.onlineColor === "" ? "palette" : ""
                    dot: ServiceWallpaper.onlineColor === "" ? "" : "#" + ServiceWallpaper.onlineColor
                    label: ServiceWallpaper.onlineColor === "" ? "Any colour" : "#" + ServiceWallpaper.onlineColor
                    trailing: root.colourOpen ? "expand_less" : "expand_more"
                    open: root.colourOpen
                    onClicked: root.openColours()
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceWallpaper.isFetchingOnline && ServiceWallpaper.requestPage === 1 ? "Searching…"
                        : ServiceWallpaper.onlineTotal === 1 ? "1 result"
                        : ServiceWallpaper.onlineTotal + " results"
                    size: 12
                    weight: 500
                    customColor: pal.subtext
                }
            }

            Item {
                id: gridWrap
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cols: Math.max(3, Math.round(width / 190))
                    cellWidth: Math.floor(width / cols)
                    cellHeight: Math.round((cellWidth - 14) * 10 / 16) + 14
                    currentIndex: -1
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: false
                    model: root.online ? onlineModel : root.items
                    cacheBuffer: cellHeight * 2
                    ScrollBar.vertical: CustomScrollBar {}

                    onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.itemCount
                                                && activeFocus) root.picked = root.items[currentIndex]
                    Keys.onReturnPressed: root.apply(root.picked)
                    Keys.onEnterPressed: root.apply(root.picked)
                    Keys.onEscapePressed: {
                        if (root.filterOpen || root.colourOpen) root.closeOverlays()
                        else search.forceActiveFocus()
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_F && !root.online && root.picked) {
                            ServiceWallpaper.toggleFavorite(root.picked)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Slash) {
                            search.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    onContentYChanged: if (root.online && contentY > contentHeight - height - cellHeight * 2)
                        ServiceWallpaper.fetchNextPage()

                    footer: Item {
                        id: skel
                        readonly property bool shown: root.online && ServiceWallpaper.isFetchingOnline
                            && ServiceWallpaper.requestPage > 1
                        width: grid.width
                        height: skel.shown ? grid.cellHeight : 0
                        visible: skel.shown
                        Row {
                            Repeater {
                                model: grid.cols
                                Item {
                                    required property int index
                                    width: grid.cellWidth
                                    height: grid.cellHeight
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 7
                                        radius: 17
                                        color: pal.containerHigh
                                        SequentialAnimation on opacity {
                                            running: skel.shown
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: index * 150 }
                                            NumberAnimation { from: 0.45; to: 1; duration: 700; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 1; to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property var modelData: cell.index < root.itemCount ? root.items[cell.index] : null
                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property bool isPicked: root.online
                            ? (root.idOf(root.picked) !== "" && root.idOf(root.picked) === root.idOf(cell.modelData))
                            : root.picked === cell.modelData
                        readonly property bool isCurrent: !root.online && cell.modelData === ServiceWallpaper.currentCachePath

                        readonly property string cid: root.online ? root.idOf(cell.modelData) : ""
                        readonly property bool dl: cell.cid !== "" && ServiceWallpaper.downloadingId === cell.cid
                        readonly property int qpos: cell.cid !== "" ? ServiceWallpaper.queuedIds.indexOf(cell.cid) + 1 : 0
                        readonly property bool failed: cell.cid !== "" && ServiceWallpaper.failedIds.indexOf(cell.cid) >= 0
                        readonly property string local: cell.cid !== "" ? ServiceWallpaper.localFor(cell.modelData) : ""
                        readonly property bool onlineInUse: cell.local !== "" && cell.local === ServiceWallpaper.currentSource
                        readonly property bool hovered: cellHover.hovered && !cell.dl && !cell.failed
                        readonly property bool faved: !root.online && ServiceWallpaper.favoritedWallpapers.indexOf(cell.modelData) >= 0
                        readonly property bool statusChip: cell.onlineInUse || cell.qpos > 0

                        HoverHandler { id: cellHover }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 22
                            color: "transparent"
                            border.width: 3
                            border.color: pal.primary
                            opacity: cell.isPicked ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { EffectsAnim { speed: "fast" } }
                        }

                        ClippingRectangle {
                            id: tile
                            anchors.fill: parent
                            anchors.margins: 7
                            radius: 17
                            color: pal.container

                            Image {
                                anchors.fill: parent
                                source: root.thumbOf(cell.modelData)
                                sourceSize.width: 320
                                sourceSize.height: 320
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { EffectsAnim { speed: "fast" } }
                            }
                        }

                        Loader {
                            anchors.fill: tile
                            active: cell.isCurrent || cell.faved || cell.statusChip || cell.local !== ""
                            sourceComponent: Item {
                                Pill {
                                    visible: cell.isCurrent && !cell.hovered
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    label: "In use"
                                }

                                MaterialIconSymbol {
                                    visible: cell.faved && !cell.hovered
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    content: "favorite"
                                    iconSize: 16
                                    customColor: "white"
                                }

                                Pill {
                                    visible: cell.statusChip
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    icon: cell.onlineInUse ? "check_circle" : "schedule"
                                    label: cell.onlineInUse ? "In use" : "Queued · " + cell.qpos
                                    color: cell.onlineInUse ? Qt.rgba(0, 0, 0, 0.58) : pal.secondaryContainer
                                    fg: cell.onlineInUse ? "white" : pal.secondaryContainerText
                                }

                                Rectangle {
                                    visible: cell.local !== "" && !cell.isPicked && !cell.onlineInUse
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: "download_done"
                                        iconSize: 16
                                        customColor: "white"
                                    }
                                }
                            }
                        }

                        Loader {
                            anchors.fill: tile
                            active: cell.hovered && cell.modelData !== null
                            sourceComponent: Item {
                                id: hov
                                readonly property string orig: root.online ? "" : ServiceWallpaper.getOriginalPath(cell.modelData)
                                readonly property var info: hov.orig !== "" ? ServiceWallpaper.infoFor(hov.orig) : null
                                readonly property var seeds: hov.orig !== "" ? ServiceWallpaper.seedsFor(hov.orig) : null
                                readonly property var dots: cell.cid !== "" ? (cell.modelData.colors || []).slice(0, 4)
                                    : hov.seeds ? hov.seeds.seeds.map(x => x.seed).slice(0, 4) : []

                                Timer {
                                    interval: 180
                                    running: hov.orig !== ""
                                    onTriggered: {
                                        ServiceWallpaper.requestInfo(hov.orig)
                                        ServiceWallpaper.requestSeeds(hov.orig)
                                    }
                                }

                                Pill {
                                    visible: cell.cid !== "" && !cell.statusChip
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    icon: "favorite"
                                    label: cell.cid !== "" ? root.kfmt(cell.modelData.favorites || 0) : ""
                                }

                                Pill {
                                    visible: label !== ""
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    label: cell.cid !== "" ? (cell.modelData.resolution || "").replace("x", "×")
                                        : hov.info ? hov.info.width + "×" + hov.info.height
                                          + " · " + ServiceWallpaper.formatBytes(hov.info.bytes) : ""
                                }

                                Rectangle {
                                    visible: hov.dots.length > 0
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    implicitHeight: 24
                                    implicitWidth: dotRow.implicitWidth + 14
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.58)
                                    Row {
                                        id: dotRow
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Repeater {
                                            model: hov.dots
                                            Rectangle {
                                                required property string modelData
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: modelData
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.25)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Loader {
                            anchors.fill: tile
                            active: cell.dl || cell.failed
                            sourceComponent: Item {
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 17
                                    color: Qt.rgba(0, 0, 0, 0.42)
                                }

                                Shape {
                                    id: edge
                                    anchors.fill: parent
                                    visible: cell.dl
                                    preferredRendererType: Shape.CurveRenderer
                                    readonly property real per: 2 * (width - 3 - 34) + 2 * (height - 3 - 34) + 2 * Math.PI * 17
                                    EdgePath {
                                        w: edge.width - 3
                                        h: edge.height - 3
                                        strokeColor: Qt.rgba(1, 1, 1, 0.18)
                                    }
                                    EdgePath {
                                        w: edge.width - 3
                                        h: edge.height - 3
                                        strokeColor: pal.primary
                                        capStyle: ShapePath.FlatCap
                                        strokeStyle: ShapePath.DashLine
                                        dashPattern: [Math.max(0.01, ServiceWallpaper.downloadProgress * edge.per / 3), edge.per / 3 * 2]
                                    }
                                }

                                Pill {
                                    anchors.centerIn: parent
                                    implicitHeight: 30
                                    icon: cell.failed ? "refresh" : "download"
                                    label: cell.failed ? "Failed · tap to retry"
                                        : Math.round(ServiceWallpaper.downloadProgress * 100) + "%"
                                          + (ServiceWallpaper.downloadTotalBytes > 0
                                             ? " · " + (ServiceWallpaper.downloadedBytes / 1048576).toFixed(1)
                                               + " / " + (ServiceWallpaper.downloadTotalBytes / 1048576).toFixed(1) + " MB" : "")
                                    color: cell.failed ? Colors.errorContainer : Qt.rgba(0, 0, 0, 0.58)
                                    fg: cell.failed ? Colors.errorContainerText : "white"
                                }
                            }
                        }

                        Loader {
                            anchors.right: tile.right
                            anchors.top: tile.top
                            anchors.margins: 8
                            active: cell.isPicked
                            sourceComponent: Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: pal.primary
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "check"
                                    iconSize: 16
                                    customColor: pal.primaryText
                                }
                            }
                        }

                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    const m = cellArea.mapToItem(root, mouse.x, mouse.y)
                                    root.showMenu(m.x, m.y, cell.modelData, root.online)
                                    return
                                }
                                root.closeOverlays()
                                grid.forceActiveFocus()
                                root.pick(cell.index)
                                if (cell.failed) ServiceWallpaper.downloadAndSetWallpaper(cell.modelData)
                            }
                            onDoubleClicked: root.apply(cell.modelData)
                        }

                        Loader {
                            anchors.left: tile.left
                            anchors.top: tile.top
                            anchors.margins: 8
                            active: !root.online && cell.hovered && cell.modelData !== null
                            sourceComponent: Rectangle {
                                width: 28
                                height: 28
                                radius: favArea.pressed ? 9 : 14
                                color: cell.faved ? Colors.error : favArea.containsMouse ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(0, 0, 0, 0.55)
                                Behavior on color { EffectsColorAnim { speed: "fast" } }
                                Behavior on radius { SpatialAnim { speed: "fast" } }
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "favorite"
                                    iconSize: 16
                                    customColor: cell.faved ? Colors.errorText : "white"
                                }
                                MouseArea {
                                    id: favArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceWallpaper.toggleFavorite(cell.modelData)
                                }
                            }
                        }
                    }
                }

                FrameAnimation {
                    id: scroller
                    property real target: 0
                    property real velocity: 0
                    property bool coasting: false
                    onTriggered: {
                        const maxY = Math.max(0, grid.contentHeight - grid.height)
                        const dt = Math.min(0.05, frameTime)
                        if (scroller.coasting) {
                            const next = Math.max(0, Math.min(maxY, grid.contentY + scroller.velocity * dt))
                            scroller.velocity *= Math.exp(-dt * 4)
                            grid.contentY = next
                            if (Math.abs(scroller.velocity) < 20 || next <= 0 || next >= maxY) scroller.stop()
                            return
                        }
                        const t = Math.max(0, Math.min(maxY, scroller.target))
                        const d = t - grid.contentY
                        if (Math.abs(d) < 0.5) {
                            grid.contentY = t
                            scroller.stop()
                            return
                        }
                        grid.contentY += d * (1 - Math.exp(-dt * 13))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    property var samples: []
                    onWheel: wheel => {
                        wheel.accepted = false
                        const maxY = Math.max(0, grid.contentHeight - grid.height)
                        if (maxY <= 0) return
                        if (wheel.phase !== Qt.NoScrollPhase && (wheel.pixelDelta.y !== 0 || wheel.phase === Qt.ScrollEnd)) {
                            const now = Date.now()
                            if (wheel.phase === Qt.ScrollEnd) {
                                const recent = samples.filter(x => now - x.t < 120)
                                if (recent.length > 1) {
                                    const span = Math.max(16, now - recent[0].t)
                                    const dy = recent.reduce((acc, x) => acc + x.dy, 0)
                                    scroller.velocity = -dy / span * 1000
                                    if (Math.abs(scroller.velocity) > 150) {
                                        scroller.coasting = true
                                        scroller.restart()
                                    }
                                }
                                samples = []
                                wheel.accepted = true
                                return
                            }
                            scroller.stop()
                            grid.cancelFlick()
                            samples = samples.filter(x => now - x.t < 120).concat([{ t: now, dy: wheel.pixelDelta.y }])
                            grid.contentY = Math.max(0, Math.min(maxY, grid.contentY - wheel.pixelDelta.y))
                            wheel.accepted = true
                            return
                        }
                        if (wheel.angleDelta.y === 0) return
                        const base = scroller.running && !scroller.coasting ? scroller.target : grid.contentY
                        grid.cancelFlick()
                        scroller.coasting = false
                        scroller.target = Math.max(0, Math.min(maxY, base - wheel.angleDelta.y / 120 * grid.cellHeight))
                        if (!scroller.running) scroller.start()
                        wheel.accepted = true
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: !root.online && root.itemCount === 0
                    CustomLoader {
                        Layout.alignment: Qt.AlignHCenter
                        visible: ServiceWallpaper.isProcessing
                        size: 60
                        color: pal.primary
                    }
                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !ServiceWallpaper.isProcessing
                        content: root.tab === "favorites" ? "favorite" : "image_not_supported"
                        iconSize: 32
                        customColor: pal.subtext
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceWallpaper.isProcessing ? "Loading wallpapers…"
                            : root.tab === "favorites" ? "No favourites yet — press F on a wallpaper"
                            : ServiceWallpaper.wallpapers.length === 0 ? "No wallpapers in " + ServiceWallpaper.wallpaperDir
                            : "No wallpapers match your search"
                        size: 13
                        weight: 400
                        customColor: pal.subtext
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.online && root.itemCount === 0 && ServiceWallpaper.isFetchingOnline
                    CustomLoader {
                        Layout.alignment: Qt.AlignHCenter
                        size: 60
                        color: pal.primary
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: "Looking on Wallhaven…"
                        size: 13
                        customColor: pal.subtext
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 420)
                    spacing: 10
                    visible: root.online && root.itemCount === 0 && !ServiceWallpaper.isFetchingOnline
                        && ServiceWallpaper.onlineErrorKind === ""

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 4
                        implicitWidth: 72
                        implicitHeight: 72
                        radius: 36
                        color: pal.containerHigh
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "search_off"
                            iconSize: 34
                            customColor: pal.primary
                        }
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        content: ServiceWallpaper.currentSearchText.length > 0
                            ? "Nothing for “" + ServiceWallpaper.currentSearchText + "”"
                            : "Nothing matches these filters"
                        size: 17
                        weight: 600
                        elide: Text.ElideRight
                        customColor: pal.text
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.narrowing.length > 0
                        content: "These filters are narrowing it down. Remove one to search again:"
                        size: 13
                        wrapMode: Text.WordWrap
                        customColor: pal.subtext
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6
                        visible: root.narrowing.length > 0
                        Repeater {
                            model: root.narrowing
                            Rectangle {
                                id: nchip
                                required property var modelData
                                implicitHeight: 32
                                implicitWidth: nRow.implicitWidth + 22
                                radius: 16
                                color: nArea.containsMouse ? pal.containerHighest : pal.containerHigh
                                RowLayout {
                                    id: nRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIconSymbol {
                                        content: "close"
                                        iconSize: 16
                                        customColor: pal.subtext
                                    }
                                    Rectangle {
                                        visible: nchip.modelData.dot !== ""
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: nchip.modelData.dot !== "" ? nchip.modelData.dot : "transparent"
                                    }
                                    CustomText {
                                        content: nchip.modelData.label
                                        size: 12
                                        weight: 500
                                        customColor: pal.text
                                    }
                                }
                                CustomMouseArea {
                                    id: nArea
                                    radius: nchip.radius
                                    hoverEnabled: true
                                    onClicked: root.dropNarrowing(nchip.modelData.key)
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        visible: root.narrowing.length > 0
                        implicitHeight: 42
                        implicitWidth: clearRow.implicitWidth + 36
                        radius: clearArea.pressed ? 12 : 21
                        color: pal.primary
                        Behavior on radius { SpatialAnim { speed: "fast" } }
                        RowLayout {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIconSymbol { content: "filter_alt_off"; iconSize: 18; customColor: pal.primaryText }
                            CustomText { content: "Search with no filters"; size: 13; weight: 600; customColor: pal.primaryText }
                        }
                        CustomMouseArea {
                            id: clearArea
                            radius: parent.radius
                            onClicked: root.clearNarrowing()
                        }
                    }
                }

                ColumnLayout {
                    id: errBox
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 400)
                    spacing: 10
                    visible: root.online && root.itemCount === 0 && !ServiceWallpaper.isFetchingOnline
                        && ["key", "network", "http"].indexOf(ServiceWallpaper.onlineErrorKind) >= 0
                    readonly property bool isKey: ServiceWallpaper.onlineErrorKind === "key"

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 4
                        implicitWidth: 72
                        implicitHeight: 72
                        radius: 36
                        color: errBox.isKey ? Colors.errorContainer : pal.containerHigh
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: errBox.isKey ? "key_off" : "cloud_off"
                            iconSize: 34
                            customColor: errBox.isKey ? Colors.errorContainerText : pal.primary
                        }
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        content: ServiceWallpaper.onlineError
                        size: 17
                        weight: 600
                        wrapMode: Text.WordWrap
                        customColor: pal.text
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        content: errBox.isKey ? "NSFW results need a valid key. Check it in the wallpaper settings, or search without NSFW for now."
                            : "Nothing was loaded. Check your connection and try again."
                        size: 13
                        wrapMode: Text.WordWrap
                        customColor: pal.subtext
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        spacing: 10
                        Rectangle {
                            implicitHeight: 42
                            implicitWidth: errA.implicitWidth + 36
                            radius: errAArea.pressed ? 12 : 21
                            color: pal.primary
                            Behavior on radius { SpatialAnim { speed: "fast" } }
                            RowLayout {
                                id: errA
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol { content: errBox.isKey ? "settings" : "refresh"; iconSize: 18; customColor: pal.primaryText }
                                CustomText { content: errBox.isKey ? "Open settings" : "Try again"; size: 13; weight: 600; customColor: pal.primaryText }
                            }
                            CustomMouseArea {
                                id: errAArea
                                radius: parent.radius
                                onClicked: {
                                    if (ServiceWallpaper.onlineErrorKind === "key") {
                                        root.railTab = "source"
                                        if (settingsRail.item) settingsRail.item.tab = "source"
                                        root.railOpen = true
                                    } else {
                                        ServiceWallpaper.fetchWallhaven(true)
                                    }
                                }
                            }
                        }
                        Rectangle {
                            visible: ServiceWallpaper.onlineErrorKind === "key"
                            implicitHeight: 42
                            implicitWidth: errB.implicitWidth + 36
                            radius: errBArea.pressed ? 12 : 21
                            color: pal.containerHigh
                            Behavior on radius { SpatialAnim { speed: "fast" } }
                            RowLayout {
                                id: errB
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol { content: "shield"; iconSize: 18; customColor: pal.text }
                                CustomText { content: "SFW only"; size: 13; weight: 600; customColor: pal.text }
                            }
                            CustomMouseArea {
                                id: errBArea
                                radius: parent.radius
                                onClicked: ServiceWallpaper.patchWallhaven({ purity: "100" })
                            }
                        }
                    }
                }

                Rectangle {
                    id: loadPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    visible: root.online && ServiceWallpaper.isFetchingOnline && ServiceWallpaper.requestPage > 1
                    implicitHeight: 34
                    implicitWidth: loadRow.implicitWidth + 28
                    radius: 17
                    color: pal.containerHighest
                    RowLayout {
                        id: loadRow
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialIconSymbol {
                            content: "progress_activity"
                            iconSize: 16
                            customColor: pal.primary
                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: loadPill.visible
                            }
                        }
                        CustomText {
                            content: "Loading page " + ServiceWallpaper.requestPage + " of " + ServiceWallpaper.onlineLastPage
                            size: 12
                            weight: 500
                            customColor: pal.text
                        }
                    }
                }

                Rectangle {
                    id: toast
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    readonly property bool rate: ServiceWallpaper.onlineErrorKind === "rate"
                    visible: root.online && (toast.rate || (root.itemCount > 0
                        && ["network", "http"].indexOf(ServiceWallpaper.onlineErrorKind) >= 0))
                    implicitHeight: 76
                    radius: 20
                    color: pal.containerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 14

                        Item {
                            implicitWidth: 52
                            implicitHeight: 52
                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeColor: pal.outlineVariant
                                    strokeWidth: 4
                                    fillColor: "transparent"
                                    PathAngleArc { centerX: 26; centerY: 26; radiusX: 22; radiusY: 22; startAngle: 0; sweepAngle: 360 }
                                }
                                ShapePath {
                                    strokeColor: pal.primary
                                    strokeWidth: 4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    PathAngleArc {
                                        centerX: 26
                                        centerY: 26
                                        radiusX: 22
                                        radiusY: 22
                                        startAngle: -90
                                        sweepAngle: toast.rate ? 360 * ServiceWallpaper.onlineRetryIn / 15 : 0
                                        Behavior on sweepAngle { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                                    }
                                }
                            }
                            CustomText {
                                anchors.centerIn: parent
                                visible: toast.rate
                                content: String(ServiceWallpaper.onlineRetryIn)
                                size: 15
                                weight: 600
                                customColor: pal.text
                            }
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                visible: !toast.rate
                                content: "cloud_off"
                                iconSize: 22
                                customColor: pal.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            CustomText {
                                Layout.fillWidth: true
                                content: toast.rate ? "Wallhaven is busy" : "Couldn't load more"
                                size: 14
                                weight: 600
                                customColor: pal.text
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: toast.rate
                                    ? "It allows 45 searches a minute. Page " + ServiceWallpaper.requestPage + " loads again in "
                                      + ServiceWallpaper.onlineRetryIn + " s, and you keep your place."
                                    : ServiceWallpaper.onlineError
                                size: 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                customColor: pal.subtext
                            }
                        }

                        Rectangle {
                            implicitHeight: 36
                            implicitWidth: retryLbl.implicitWidth + 24
                            radius: 18
                            color: retryArea.containsMouse ? pal.containerHigh : "transparent"
                            CustomText {
                                id: retryLbl
                                anchors.centerIn: parent
                                content: "Retry now"
                                size: 13
                                weight: 600
                                customColor: pal.primary
                            }
                            CustomMouseArea {
                                id: retryArea
                                radius: 18
                                hoverEnabled: true
                                onClicked: ServiceWallpaper.retryOnlineNow()
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.filterOpen
                    radius: 18
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }

        ColumnLayout {
            visible: !root.railOpen
            Layout.preferredWidth: 340
            Layout.maximumWidth: 340
            Layout.fillHeight: true
            spacing: 12

            ClippingRectangle {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(hero.width * 10 / 16)
                radius: 24
                color: pal.container

                Image {
                    id: heroThumb
                    anchors.fill: parent
                    visible: root.online && root.pickedLocal === ""
                    source: root.online && root.pickedLocal === "" ? root.thumbOf(root.picked) : ""
                    sourceSize.width: 320
                    sourceSize.height: 320
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }

                Item {
                    id: heroFull
                    anchors.fill: parent
                    visible: !root.online || root.pickedLocal !== ""

                    readonly property string wanted: heroFull.visible && root.pickedFile !== "" ? "file://" + root.pickedFile : ""
                    property Image front: null

                    function other(img) {
                        return img === fullA ? fullB : fullA
                    }

                    function show(img) {
                        if (img === heroFull.front || img.source.toString() !== heroFull.wanted)
                            return
                        const old = heroFull.front
                        img.z = 1
                        if (old)
                            old.z = 0
                        heroFull.front = img
                        heroFade.stop()
                        img.opacity = 0
                        heroFade.target = img
                        heroFade.start()
                    }

                    function settle() {
                        if (heroFull.front)
                            heroFull.other(heroFull.front).opacity = 0
                    }

                    onWantedChanged: {
                        if (heroFull.wanted === "") {
                            heroFade.stop()
                            fullA.source = ""
                            fullB.source = ""
                            fullA.opacity = 0
                            fullB.opacity = 0
                            heroFull.front = null
                            return
                        }
                        if (heroFull.front && heroFull.front.source.toString() === heroFull.wanted) {
                            heroFull.other(heroFull.front).source = ""
                            return
                        }
                        if (heroFade.running) {
                            heroFade.complete()
                            heroFull.settle()
                        }
                        const back = heroFull.front ? heroFull.other(heroFull.front) : fullA
                        back.source = heroFull.wanted
                        if (back.status === Image.Ready)
                            heroFull.show(back)
                    }

                    Component.onCompleted: if (heroFull.wanted !== "") fullA.source = heroFull.wanted

                    EffectsAnim {
                        id: heroFade
                        property: "opacity"
                        from: 0
                        to: 1
                        speed: "default"
                        onFinished: heroFull.settle()
                    }

                    Image {
                        id: fullA
                        anchors.fill: parent
                        sourceSize.width: 1280
                        sourceSize.height: 720
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0
                        onStatusChanged: if (status === Image.Ready) heroFull.show(fullA)
                    }

                    Image {
                        id: fullB
                        anchors.fill: parent
                        sourceSize.width: 1280
                        sourceSize.height: 720
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0
                        onStatusChanged: if (status === Image.Ready) heroFull.show(fullB)
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 14
                    visible: root.picked !== null
                    height: 32
                    radius: 16
                    width: badgeRow.implicitWidth + 24
                    color: Qt.rgba(0, 0, 0, 0.55)
                    RowLayout {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIconSymbol {
                            content: root.downloading ? "download" : root.pickedIsCurrent ? "check_circle"
                                : root.online ? "public" : "auto_awesome"
                            iconSize: 16
                            customColor: "white"
                        }
                        CustomText {
                            content: root.downloading ? "Downloading · " + Math.round(ServiceWallpaper.downloadProgress * 100) + "%"
                                : root.pickedIsCurrent ? "In use"
                                : root.online ? "Wallhaven" + (root.pickedId !== "" && root.picked.category
                                                               ? " · " + root.capital(root.picked.category) : "")
                                : "Previewing — nothing applied yet"
                            size: 12
                            weight: 500
                            customColor: "white"
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    visible: root.downloading
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.25)
                    Rectangle {
                        width: parent.width * ServiceWallpaper.downloadProgress
                        height: parent.height
                        radius: 3
                        color: pal.primary
                        Behavior on width { SpatialAnim { speed: "fast" } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: mouse => {
                        const m = mapToItem(root, mouse.x, mouse.y)
                        root.showMenu(m.x, m.y, root.picked, root.online)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    CustomText {
                        Layout.fillWidth: true
                        content: root.nameOf(root.picked)
                        size: 18
                        weight: 600
                        elide: Text.ElideRight
                        customColor: pal.text
                    }
                    CustomText {
                        Layout.fillWidth: true
                        visible: root.metaText !== ""
                        content: root.metaText
                        size: 12
                        weight: 500
                        customColor: pal.text
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.online ? (root.downloading && ServiceWallpaper.downloadTotalBytes > 0
                                ? (ServiceWallpaper.downloadedBytes / 1048576).toFixed(1) + " of "
                                  + (ServiceWallpaper.downloadTotalBytes / 1048576).toFixed(1) + " MB downloaded"
                                : root.statsText)
                            : root.pickedIsCurrent ? "Your shell is wearing these colours"
                            : root.preview ? "Your shell will take these colours"
                            : "Reading colours…"
                        size: 12
                        weight: 400
                        elide: Text.ElideRight
                        customColor: pal.subtext
                    }
                }

                SeedSwatches {
                    id: heroSeeds
                    visible: !root.online && !ServiceWallpaper.gowallActive && heroSeeds.seeds.length > 1
                    path: !root.online ? root.pickedFile : ""
                    disc: 26
                    ring: pal.primary
                }

                Row {
                    spacing: 6
                    visible: !root.online && !heroSeeds.visible
                    Repeater {
                        model: [pal.primary, pal.primaryContainer, pal.secondary, pal.secondaryContainer, pal.tertiary, pal.tertiaryContainer]
                        Rectangle {
                            required property color modelData
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.online && root.pickedId !== ""
                    spacing: 5
                    Repeater {
                        model: root.preview ? [pal.primary, pal.secondaryContainer, pal.tertiary, pal.secondaryContainerText, pal.containerHighest] : []
                        Rectangle {
                            required property color modelData
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: modelData
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                        }
                    }
                    CustomText {
                        Layout.fillWidth: true
                        Layout.leftMargin: root.preview ? 6 : 0
                        elide: Text.ElideRight
                        content: !ServiceWallpaper.previewUsable ? "Gowall decides your colours"
                            : root.pickedIsCurrent ? "Your shell is wearing these colours"
                            : root.preview ? "Your shell will take these colours" : "Reading colours…"
                        size: 12
                        customColor: pal.subtext
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 28
                visible: root.online && root.queueLen === 0 && root.details !== null && root.details.tags.length > 0
                clip: true
                Row {
                    spacing: 6
                    Repeater {
                        model: root.details ? root.details.tags.slice(0, 6) : []
                        Rectangle {
                            id: tagChip
                            required property var modelData
                            height: 28
                            width: tagRow.implicitWidth + 22
                            radius: 14
                            color: tagArea.containsMouse ? pal.containerHighest : pal.containerHigh
                            Behavior on color { EffectsColorAnim { speed: "fast" } }
                            RowLayout {
                                id: tagRow
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIconSymbol { content: "sell"; iconSize: 14; customColor: pal.subtext }
                                CustomText { content: tagChip.modelData.name; size: 12; weight: 500; customColor: pal.text }
                            }
                            CustomMouseArea {
                                id: tagArea
                                radius: 14
                                hoverEnabled: true
                                onClicked: root.searchFor(tagChip.modelData.name)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.online && root.queueLen > 0
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    CustomText { content: "Up next"; size: 12; weight: 600; customColor: pal.subtext }
                    Item { Layout.fillWidth: true }
                    CustomText { content: root.queueLen + " waiting"; size: 12; customColor: pal.subtext }
                }

                Repeater {
                    model: ServiceWallpaper.queuedItems.slice(0, 2)
                    Rectangle {
                        id: qrow
                        required property var modelData
                        readonly property bool applies: ServiceWallpaper.applyId === qrow.modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: 16
                        color: pal.containerHigh
                        border.width: qrow.applies ? 2 : 0
                        border.color: pal.primary
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 12
                            ClippingRectangle {
                                implicitWidth: 64
                                implicitHeight: 40
                                radius: 10
                                color: pal.container
                                Image {
                                    anchors.fill: parent
                                    source: qrow.modelData.thumbUrl || ""
                                    sourceSize.width: 160
                                    sourceSize.height: 160
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CustomText { content: "wallhaven-" + qrow.modelData.id; size: 13; weight: 600; customColor: pal.text }
                                CustomText {
                                    content: ServiceWallpaper.formatBytes(qrow.modelData.fileSize || 0)
                                        + (qrow.applies ? " · applies when done" : " · saves to your folder")
                                    size: 11
                                    customColor: pal.subtext
                                }
                            }
                            PalIconButton {
                                tone: pal
                                icon: "close"
                                box: 36
                                onClicked: ServiceWallpaper.unqueueDownload(qrow.modelData.id)
                            }
                        }
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: (root.queueLen > 2 ? "+" + (root.queueLen - 2) + " more. " : "")
                        + "Only your last pick gets applied; the rest are saved to your folder."
                    size: 12
                    wrapMode: Text.WordWrap
                    customColor: pal.subtext
                }
            }

            Item { Layout.fillHeight: true }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !(root.online && root.queueLen > 0)
                spacing: 3

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    topLeftRadius: 20
                    topRightRadius: 20
                    bottomLeftRadius: 5
                    bottomRightRadius: 5
                    color: pal.containerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        spacing: 10

                        CustomText {
                            Layout.fillWidth: true
                            content: "Transition"
                            size: 13
                            weight: 500
                            customColor: pal.text
                        }

                        CustomListNew {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 30
                            color: pal.containerHighest
                            list: Settings.transitionTypes
                            currentVal: Settings.transitionOrDefault(SettingsConfig.theme.transitionType)
                            onListChildClicked: child => {
                                const currentVal = child.name
                                if (currentVal && currentVal !== SettingsConfig.theme.transitionType)
                                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { transitionType: currentVal })
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    topLeftRadius: 5
                    topRightRadius: 5
                    bottomLeftRadius: 20
                    bottomRightRadius: 20
                    color: pal.containerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 10

                        CustomText {
                            Layout.fillWidth: true
                            content: "Workspace glide"
                            size: 13
                            weight: 500
                            customColor: pal.text
                        }

                        CustomToogle {
                            isToggleOn: SettingsConfig.general.wallpaperGlide ?? true
                            onToggled: state => {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperGlide: state })
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    id: applyBtn
                    readonly property bool usable: root.picked !== null && !root.pickedIsCurrent && !root.downloading && !root.queued
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: applyArea.pressed ? 14 : 24
                    color: applyBtn.usable ? pal.primary : pal.containerHighest
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    RowLayout {
                        id: applyRow
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialIconSymbol {
                            content: root.queued ? "schedule" : root.pickFailed ? "refresh"
                                : root.online && root.pickedLocal === "" ? "download" : "check"
                            iconSize: 20
                            customColor: applyBtn.usable ? pal.primaryText : pal.subtext
                        }
                        CustomText {
                            content: root.downloading ? "Downloading " + Math.round(ServiceWallpaper.downloadProgress * 100) + "%"
                                : root.queued ? "Queued · " + ServiceWallpaper.queuePosition(root.pickedId)
                                : root.pickFailed ? "Retry download"
                                : root.pickedIsCurrent ? "In use"
                                : root.online ? "Set wallpaper" : "Apply wallpaper"
                            size: 14
                            weight: 600
                            customColor: applyBtn.usable ? pal.primaryText : pal.subtext
                        }
                    }
                    CustomMouseArea {
                        id: applyArea
                        radius: applyBtn.radius
                        enabled: applyBtn.usable
                        onClicked: root.apply(root.picked)
                    }
                }

                PalIconButton {
                    tone: pal
                    visible: root.online && root.busy
                    icon: "cancel"
                    box: 48
                    onClicked: ServiceWallpaper.cancelAllDownloads()
                }

                PalIconButton {
                    tone: pal
                    visible: root.online && !root.busy && root.pickedId !== "" && root.pickedLocal === ""
                    icon: "bookmark_add"
                    box: 48
                    onClicked: ServiceWallpaper.saveWallpaper(root.picked)
                }

                PalIconButton {
                    tone: pal
                    visible: root.online && root.pickedId !== ""
                    icon: "image_search"
                    box: 48
                    onClicked: root.searchFor("like:" + root.pickedId)
                }

                PalIconButton {
                    tone: pal
                    visible: root.online && root.pickedId !== ""
                    icon: "open_in_new"
                    box: 48
                    onClicked: ServiceWallpaper.openOnWallhaven(root.picked)
                }

                PalIconButton {
                    tone: pal
                    visible: !root.online && root.picked !== null
                    icon: "favorite"
                    box: 48
                    lit: !root.online && root.picked !== null
                        && ServiceWallpaper.favoritedWallpapers.indexOf(root.picked) >= 0
                    onClicked: ServiceWallpaper.toggleFavorite(root.picked)
                }

                PalIconButton {
                    tone: pal
                    visible: !root.online
                    icon: "shuffle"
                    box: 48
                    onClicked: root.shuffle()
                }
            }
        }

        Loader {
            id: settingsRail
            active: root.railOpen
            visible: active
            Layout.fillHeight: true
            Layout.preferredWidth: 352
            sourceComponent: WallpaperSettingsRail {
                tab: root.railTab
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 40
        visible: root.filterOpen || root.colourOpen
        onClicked: root.closeOverlays()
        onWheel: wheel => wheel.accepted = true
    }

    Loader {
        z: 41
        x: root.sheetX
        y: root.sheetY
        active: root.filterOpen
        visible: active
        sourceComponent: Component {
            Rectangle {
                id: sheet
                width: Math.min(centerCol.width, Math.max(620, sheetCol.implicitWidth + 40))
                height: sheetCol.implicitHeight + 32
                radius: 24
                color: pal.containerHighest

                readonly property var d: root.draft
                readonly property bool hasKey: (SettingsConfig.wallhaven.apiKey ?? "").length > 0
                readonly property var atleastOpts: {
                    const base = ["", "1920x1080", "2560x1440", "3840x2160"]
                    if (base.indexOf(ServiceWallpaper.fitAtleast) < 0) base.push(ServiceWallpaper.fitAtleast)
                    return base
                }
                readonly property var ratioOpts: {
                    const base = ["", "16x9", "16x10", "21x9", "32x9"]
                    if (base.indexOf(ServiceWallpaper.fitRatio) < 0) base.push(ServiceWallpaper.fitRatio)
                    return base
                }

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => wheel.accepted = true
                }

                ColumnLayout {
                    id: sheetCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 8

                    SRow {
                        tone: pal
                        label: "Sort"
                        Repeater {
                            model: [["date_added", "Latest"], ["toplist", "Top"], ["views", "Views"], ["favorites", "Favs"], ["random", "Random"], ["relevance", "Relevant"]]
                            FChip {
                                required property var modelData
                                tone: pal
                                h: 30
                                label: modelData[1]
                                icon: sheet.d.sorting === modelData[0] ? "check" : ""
                                lit: sheet.d.sorting === modelData[0]
                                onClicked: root.setDraft({ sorting: modelData[0] })
                            }
                        }
                    }

                    SRow {
                        tone: pal
                        label: "Top of the"
                        visible: sheet.d.sorting === "toplist"
                        Repeater {
                            model: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
                            FChip {
                                required property string modelData
                                tone: pal
                                h: 30
                                label: root.rangeWords[modelData]
                                icon: sheet.d.topRange === modelData ? "check" : ""
                                lit: sheet.d.topRange === modelData
                                onClicked: root.setDraft({ topRange: modelData })
                            }
                        }
                    }

                    SRow {
                        tone: pal
                        label: "Categories"
                        Repeater {
                            model: ["General", "Anime", "People"]
                            FChip {
                                required property string modelData
                                required property int index
                                readonly property bool isOn: String(sheet.d.categories)[index] === "1"
                                tone: pal
                                h: 30
                                label: modelData
                                icon: isOn ? "check" : ""
                                lit: isOn
                                onClicked: root.flipDraft("categories", index)
                            }
                        }
                    }

                    SRow {
                        tone: pal
                        label: "Content"
                        Repeater {
                            model: ["SFW", "Sketchy", "NSFW"]
                            FChip {
                                required property string modelData
                                required property int index
                                readonly property bool isOn: String(sheet.d.purity)[index] === "1"
                                tone: pal
                                h: 30
                                dim: index === 2 && !sheet.hasKey
                                label: index === 2 && !sheet.hasKey ? "NSFW · needs API key" : modelData
                                icon: index === 2 && !sheet.hasKey ? "lock" : isOn ? "check" : ""
                                lit: isOn
                                onClicked: root.flipDraft("purity", index)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: fitCol.implicitHeight + 20
                        radius: 18
                        color: pal.containerHigh

                        ColumnLayout {
                            id: fitCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                MaterialIconSymbol { content: "aspect_ratio"; iconSize: 22; customColor: pal.primary }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    CustomText { content: "Fits my screen"; size: 14; weight: 600; customColor: pal.text }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: ServiceWallpaper.fitAtleast.replace("x", "×") + " or larger, "
                                            + ServiceWallpaper.fitRatio.replace("x", ":") + " · read from "
                                            + Array.prototype.map.call(Quickshell.screens, s => s.name).join(" and ")
                                        size: 11
                                        elide: Text.ElideRight
                                        customColor: pal.subtext
                                    }
                                }
                                CustomToogle {
                                    isToggleOn: ServiceWallpaper.fitsScreen(sheet.d)
                                    onToggled: state => root.setDraft(state
                                        ? { atleast: ServiceWallpaper.fitAtleast, ratios: ServiceWallpaper.fitRatio }
                                        : { atleast: "", ratios: "" })
                                }
                            }

                            SRow {
                                tone: pal
                                label: "At least"
                                Repeater {
                                    model: sheet.atleastOpts
                                    FChip {
                                        required property string modelData
                                        tone: pal
                                        h: 30
                                        label: modelData === "" ? "Any" : modelData.replace("x", "×")
                                        icon: (sheet.d.atleast ?? "") === modelData ? "check" : ""
                                        lit: (sheet.d.atleast ?? "") === modelData
                                        onClicked: root.setDraft({ atleast: modelData })
                                    }
                                }
                            }

                            SRow {
                                tone: pal
                                label: "Ratio"
                                Repeater {
                                    model: sheet.ratioOpts
                                    FChip {
                                        required property string modelData
                                        tone: pal
                                        h: 30
                                        label: modelData === "" ? "Any" : modelData.replace("x", ":")
                                        icon: (sheet.d.ratios ?? "") === modelData ? "check" : ""
                                        lit: (sheet.d.ratios ?? "") === modelData
                                        onClicked: root.setDraft({ ratios: modelData })
                                    }
                                }
                            }
                        }
                    }

                    SRow {
                        tone: pal
                        label: "Order"
                        visible: sheet.d.sorting !== "random" && sheet.d.sorting !== "relevance"
                        FChip {
                            tone: pal
                            h: 30
                            icon: "arrow_downward"
                            label: root.orderNames(sheet.d.sorting)[0]
                            lit: sheet.d.order === "desc"
                            onClicked: root.setDraft({ order: "desc" })
                        }
                        FChip {
                            tone: pal
                            h: 30
                            icon: "arrow_upward"
                            label: root.orderNames(sheet.d.sorting)[1]
                            lit: sheet.d.order === "asc"
                            onClicked: root.setDraft({ order: "asc" })
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: pal.outlineVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitHeight: 40
                            implicitWidth: resetRow.implicitWidth + 24
                            radius: 20
                            color: resetArea.containsMouse ? pal.containerHigh : "transparent"
                            RowLayout {
                                id: resetRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol { content: "restart_alt"; iconSize: 18; customColor: pal.primary }
                                CustomText { content: "Reset"; size: 13; weight: 600; customColor: pal.primary }
                            }
                            CustomMouseArea {
                                id: resetArea
                                radius: 20
                                hoverEnabled: true
                                onClicked: root.resetDraft()
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: "The count updates as you change filters"
                            size: 12
                            elide: Text.ElideRight
                            customColor: pal.subtext
                        }

                        Rectangle {
                            implicitHeight: 40
                            implicitWidth: showRow.implicitWidth + 36
                            radius: showArea.pressed ? 12 : 20
                            color: pal.primary
                            Behavior on radius { SpatialAnim { speed: "fast" } }
                            RowLayout {
                                id: showRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol { content: "done"; iconSize: 18; customColor: pal.primaryText }
                                CustomText {
                                    content: ServiceWallpaper.draftCount === -1 ? "Counting…"
                                        : ServiceWallpaper.draftCount < 0 ? "Show results"
                                        : ServiceWallpaper.draftCount === 1 ? "Show 1 result"
                                        : "Show " + ServiceWallpaper.draftCount + " results"
                                    size: 13
                                    weight: 600
                                    customColor: pal.primaryText
                                }
                            }
                            CustomMouseArea {
                                id: showArea
                                radius: parent.radius
                                onClicked: root.applySheet()
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        z: 41
        x: root.popX
        y: root.popY
        active: root.colourOpen
        visible: active
        sourceComponent: Component {
            Rectangle {
                id: colourPop
                width: 404
                height: popCol.implicitHeight + 32
                radius: 22
                color: pal.containerHighest

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => wheel.accepted = true
                }

                ColumnLayout {
                    id: popCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { content: "Colour"; size: 12; weight: 600; customColor: pal.subtext }
                        Item { Layout.fillWidth: true }
                        CustomText {
                            content: "Any colour"
                            size: 12
                            weight: 600
                            customColor: pal.primary
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickColour("")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: matchArea.pressed ? 14 : 24
                        color: ServiceWallpaper.onlineColor !== "" && ServiceWallpaper.onlineColor === root.themeMatch
                            ? pal.secondaryContainer : pal.containerHigh
                        Behavior on radius { SpatialAnim { speed: "fast" } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 16
                            spacing: 10
                            Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 14; color: Colors.primary }
                            MaterialIconSymbol { content: "arrow_forward"; iconSize: 18; customColor: pal.text }
                            Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 14; color: "#" + (root.themeMatch || "cc6633") }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                CustomText { content: "Match my theme"; size: 13; weight: 600; customColor: pal.text }
                                CustomText { content: "Closest Wallhaven colour to your primary"; size: 11; customColor: pal.subtext }
                            }
                        }
                        CustomMouseArea {
                            id: matchArea
                            radius: parent.radius
                            onClicked: root.pickColour(root.themeMatch)
                        }
                    }

                    Grid {
                        columns: 10
                        spacing: 8
                        Repeater {
                            model: ServiceWallpaper.wallhavenColors
                            Rectangle {
                                id: sw
                                required property string modelData
                                readonly property bool isOn: ServiceWallpaper.onlineColor === modelData
                                width: 30
                                height: 30
                                radius: 15
                                color: "#" + modelData
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: sw.isOn || swArea.containsMouse
                                    width: 38
                                    height: 38
                                    radius: 19
                                    color: "transparent"
                                    border.width: 2
                                    border.color: sw.isOn ? pal.primary : pal.outlineVariant
                                }
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    visible: sw.isOn
                                    content: "check"
                                    iconSize: 16
                                    customColor: Qt.color("#" + sw.modelData).hslLightness > 0.6 ? "black" : "white"
                                }
                                MouseArea {
                                    id: swArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickColour(sw.modelData)
                                }
                            }
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "Wallhaven searches by its own 29 colours. Matching uses hue, so a pale primary still finds a colour."
                        size: 11
                        wrapMode: Text.WordWrap
                        customColor: pal.subtext
                    }
                }
            }
        }
    }

    Loader {
        id: ctxLoader
        anchors.fill: parent
        z: 50
        active: false
        sourceComponent: WallpaperContextMenu {}
    }
}
