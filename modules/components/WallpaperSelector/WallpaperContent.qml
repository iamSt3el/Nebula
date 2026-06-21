import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    anchors.fill: parent
    topLeftRadius: Appearance.radius.large
    topRightRadius: Appearance.radius.extraLarge
    color: Colors.surface
    anchors.bottom: parent.bottom

    Behavior on implicitHeight {
        NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad }
    }

    Timer {
        id: timer
        interval: 300
        running: true
        onTriggered: colLoader.active = true
    }

    Loader {
        id: colLoader
        active: false
        visible: active
        anchors.fill: parent

        sourceComponent: ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            property string activeTab: "all"

            // Drives top-bar height animation: 50px local → 82px online (2 rows)
            property real barH: ServiceWallpaper.onlineMode ? 82 : 50
            Behavior on barH { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

            Component.onCompleted: searchInput.forceActiveFocus()

            ListModel { id: onlineRowModel }

            Connections {
                target: ServiceWallpaper

                function onOnlineWallpapersChanged() {
                    if (!ServiceWallpaper.onlineMode) return
                    const total = ServiceWallpaper.onlineWallpapers.length
                    if (total === 0) { onlineRowModel.clear(); return }
                    const newRowCount = Math.ceil(total / 4)
                    if (onlineRowModel.count === 0 || ServiceWallpaper.onlinePage === 1) {
                        onlineRowModel.clear()
                        for (let i = 0; i < newRowCount; i++) onlineRowModel.append({})
                    } else {
                        const prev = onlineRowModel.count
                        for (let i = prev; i < newRowCount; i++) onlineRowModel.append({})
                    }
                }

                function onOnlineModeChanged() {
                    if (ServiceWallpaper.onlineMode) {
                        col.activeTab = "all"
                    } else {
                        onlineRowModel.clear()
                        onlineSearch.text = ""
                    }
                }
            }

            NumberAnimation on opacity { from: 0; to: 1; duration: 100; running: col.visible }
            NumberAnimation on scale   { from: 0.8; to: 1; duration: 100; running: col.visible }

            // ── Top bar ────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: col.barH
                clip: true
                radius: Appearance.radius.extraLarge
                color: Colors.surfaceContainer

                // ── Local controls ─────────────────────────────────────────────
                RowLayout {
                    id: localContent
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8
                    enabled: !ServiceWallpaper.onlineMode
                    opacity: ServiceWallpaper.onlineMode ? 0 : 1
                    scale:   ServiceWallpaper.onlineMode ? 0.92 : 1
                    Behavior on opacity { NumberAnimation { duration: Appearance.duration.normal } }
                    Behavior on scale   { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 35
                        radius: 20; color: Colors.surfaceContainerHighest
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 5; anchors.leftMargin: 10; spacing: 8
                            MaterialIconSymbol { content: "search"; iconSize: 18 }
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; font.pixelSize: 14; font.weight: 700
                                color: Colors.inverseSurface
                                onTextChanged: ServiceWallpaper.updateSearch(text)
                                Keys.onEscapePressed: text = ""
                            }
                            MaterialIconSymbol {
                                content: "close"; iconSize: 14; customColor: Colors.outline
                                visible: searchInput.text.length > 0
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: searchInput.text = ""
                                }
                            }
                        }
                    }

                    ButtonGroup {
                        model: [
                            { value: "all",       icon: "grid_view", label: "All" },
                            { value: "favorites", icon: "favorite",  label: "Fav" }
                        ]
                        activeCheck: v => col.activeTab === v
                        onSegmentClicked: v => col.activeTab = v
                    }

                    ButtonGroup {
                        model: [
                            { icon: "schedule",      value: "newest" },
                            { icon: "sort_by_alpha", value: "name"   }
                        ]
                        activeCheck: v => ServiceWallpaper.localSortBy === v
                        onSegmentClicked: v => ServiceWallpaper.localSortBy = v
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15; color: Colors.surfaceContainerHighest
                        MaterialIconSymbol { anchors.centerIn: parent; content: "refresh"; iconSize: 18 }
                        CustomMouseArea {
                            anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceWallpaper.refresh()
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15; color: Colors.surfaceContainerHighest
                        MaterialIconSymbol { anchors.centerIn: parent; content: "public"; iconSize: 18 }
                        CustomMouseArea {
                            anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ServiceWallpaper.updateSearch("")
                                searchInput.text = ""
                                ServiceWallpaper.onlineMode = true
                                ServiceWallpaper.fetchWallhaven(true)
                            }
                        }
                    }
                }

                // ── Online controls (two rows) ─────────────────────────────────
                ColumnLayout {
                    id: onlineConfigCol
                    anchors.fill: parent; anchors.margins: 8
                    spacing: 6
                    enabled: ServiceWallpaper.onlineMode
                    opacity: ServiceWallpaper.onlineMode ? 1 : 0
                    scale:   ServiceWallpaper.onlineMode ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: Appearance.duration.normal } }
                    Behavior on scale   { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

                    property var sortOpts: [
                        ["Recent","date_added"],["Hot","toplist"],
                        ["Views","views"],["Fav","favorites"],
                        ["Random","random"],["Relevant","relevance"]
                    ]
                    property var rangeOpts: ["1d","3d","1w","1M","3M","6M","1y"]

                    function toggleCat(pos) {
                        let c = SettingsConfig.wallhaven.categories.split("")
                        c[pos] = c[pos] === "1" ? "0" : "1"
                        if (!c.includes("1")) return
                        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { categories: c.join("") })
                    }
                    function togglePur(pos) {
                        let p = SettingsConfig.wallhaven.purity.split("")
                        p[pos] = p[pos] === "1" ? "0" : "1"
                        if (!p.includes("1")) return
                        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { purity: p.join("") })
                    }

                    // Row 1: back · search · fetch
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6

                        Rectangle {
                            height: 30; radius: 15; implicitWidth: _backRow.implicitWidth + 20
                            color: Colors.surfaceContainerHighest
                            RowLayout { id: _backRow; anchors.centerIn: parent; spacing: 4
                                MaterialIconSymbol { content: "arrow_back"; iconSize: 14; customColor: Colors.surfaceText }
                                CustomText { content: "Local"; size: 11; customColor: Colors.surfaceText }
                            }
                            CustomMouseArea {
                                anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                                onClicked: { ServiceWallpaper.updateSearch(searchInput.text); ServiceWallpaper.onlineMode = false }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; height: 30; radius: 15; color: Colors.surfaceContainerHighest
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 6
                                MaterialIconSymbol { content: "search"; iconSize: 14; customColor: Colors.outline }
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        content: "Search Wallhaven…"; size: 12; customColor: Colors.outline
                                        visible: onlineSearch.text.length === 0
                                    }
                                    TextInput {
                                        id: onlineSearch
                                        anchors.fill: parent; clip: true; font.pixelSize: 13
                                        color: Colors.inverseSurface; verticalAlignment: TextInput.AlignVCenter
                                        Keys.onEscapePressed: text = ""
                                        Keys.onReturnPressed: {
                                            if (!ServiceWallpaper.isFetchingOnline) {
                                                ServiceWallpaper.currentSearchText = text
                                                ServiceWallpaper.fetchWallhaven(true)
                                            }
                                        }
                                    }
                                }
                                MaterialIconSymbol {
                                    content: "close"; iconSize: 13; customColor: Colors.outline
                                    visible: onlineSearch.text.length > 0
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: onlineSearch.text = "" }
                                }
                            }
                        }

                        // Download progress pill — expands in when a download is active
                        Rectangle {
                            id: _headerDlPill
                            height: 30; radius: 15; clip: true
                            readonly property bool isActive: ServiceWallpaper.downloadingId !== ""
                            implicitWidth: isActive ? (_dlPillRow.implicitWidth + 20) : 0
                            Behavior on implicitWidth { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }
                            color: Qt.alpha(Colors.primary, 0.15)

                            RowLayout {
                                id: _dlPillRow; anchors.centerIn: parent; spacing: 6
                                MaterialIconSymbol { content: "download"; iconSize: 14; customColor: Colors.primary }
                                CustomText {
                                    content: Math.round(ServiceWallpaper.downloadProgress * 100) + "%"
                                    size: 11; customColor: Colors.primary; weight: 600
                                }
                                Rectangle {
                                    width: 18; height: 18; radius: 9
                                    color: Qt.alpha(Colors.primary, 0.3)
                                    MaterialIconSymbol { anchors.centerIn: parent; content: "close"; iconSize: 11; customColor: Colors.primary }
                                    CustomMouseArea {
                                        anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                                        onClicked: ServiceWallpaper.cancelDownload()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: ServiceWallpaper.isFetchingOnline ? Colors.surfaceContainerHighest : Colors.primary
                            Behavior on color { ColorAnimation { duration: 150 } }
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: ServiceWallpaper.isFetchingOnline ? "hourglass_empty" : "search"
                                iconSize: 16
                                customColor: ServiceWallpaper.isFetchingOnline ? Colors.surfaceText : Colors.primaryText
                            }
                            CustomMouseArea {
                                anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!ServiceWallpaper.isFetchingOnline) {
                                        ServiceWallpaper.currentSearchText = onlineSearch.text
                                        ServiceWallpaper.fetchWallhaven(true)
                                    }
                                }
                            }
                        }
                    }

                    // Row 2: filters (flickable)
                    Flickable {
                        Layout.fillWidth: true; height: 28
                        contentHeight: height; contentWidth: _filterRow.implicitWidth
                        clip: true; interactive: contentWidth > width
                        flickDeceleration: 3000; maximumFlickVelocity: 4000

                        RowLayout { id: _filterRow; height: parent.height; spacing: 6
                            ButtonGroup {
                                height: 28
                                model: onlineConfigCol.sortOpts.map(o => ({ label: o[0], value: o[1] }))
                                activeCheck: v => SettingsConfig.wallhaven.sorting === v
                                onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { sorting: v })
                            }
                            ButtonGroup {
                                height: 28; visible: SettingsConfig.wallhaven.sorting === "toplist"
                                model: onlineConfigCol.rangeOpts.map(v => ({ label: v, value: v }))
                                activeCheck: v => SettingsConfig.wallhaven.topRange === v
                                onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { topRange: v })
                            }
                            Rectangle { width: 1; height: 18; color: Colors.outline; opacity: 0.35 }
                            ButtonGroup {
                                height: 28
                                model: [{ icon: "arrow_downward", value: "desc" }, { icon: "arrow_upward", value: "asc" }]
                                activeCheck: v => SettingsConfig.wallhaven.order === v
                                onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { order: v })
                            }
                            Rectangle { width: 1; height: 18; color: Colors.outline; opacity: 0.35 }
                            ButtonGroup {
                                height: 28
                                model: [{ label: "General", value: 0 }, { label: "Anime", value: 1 }, { label: "People", value: 2 }]
                                activeCheck: v => SettingsConfig.wallhaven.categories[v] === "1"
                                onSegmentClicked: v => onlineConfigCol.toggleCat(v)
                            }
                            ButtonGroup {
                                height: 28
                                model: [{ label: "SFW", value: 0 }, { label: "Sketchy", value: 1 }]
                                activeCheck: v => SettingsConfig.wallhaven.purity[v] === "1"
                                onSegmentClicked: v => onlineConfigCol.togglePur(v)
                            }
                            Rectangle {
                                visible: SettingsConfig.wallhaven.apiKey.length > 0
                                readonly property bool active: SettingsConfig.wallhaven.purity[2] === "1"
                                height: 28; radius: 14; implicitWidth: _nsfwText.implicitWidth + 24
                                color: active ? Colors.error : "transparent"
                                border.width: 1; border.color: Colors.outline
                                Behavior on color { ColorAnimation { duration: 150 } }
                                CustomText {
                                    id: _nsfwText; anchors.centerIn: parent; content: "NSFW"; size: 11
                                    customColor: parent.active ? Colors.errorText : Colors.surfaceText
                                }
                                CustomMouseArea {
                                    anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                                    onClicked: onlineConfigCol.togglePur(2)
                                }
                            }
                        }
                    }
                }
            }
            // ── End top bar ────────────────────────────────────────────────────

            // Wallpaper count strip (local mode only)
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: -2
                visible: !ServiceWallpaper.onlineMode; spacing: 4
                MaterialIconSymbol { content: "wallpaper"; iconSize: 12; customColor: Colors.outline }
                CustomText { content: ServiceWallpaper.cacheModel.count + " wallpapers"; size: 11; customColor: Colors.outline }
                Item { Layout.fillWidth: true }
            }

            // ── Grid wrapper ───────────────────────────────────────────────────
            Item {
                id: gridWrapper
                Layout.fillHeight: true
                Layout.fillWidth: true

                // Fetch overlay — morphing shape loader while wallpapers load
                Loader {
                    anchors.centerIn: parent
                    z: 1
                    active: ServiceWallpaper.onlineMode
                         && ServiceWallpaper.isFetchingOnline
                         && ServiceWallpaper.onlineError.length === 0
                    visible: active
                    sourceComponent: CustomLoader { size: 80; color: Colors.primary }
                }

                // Error overlay
                Rectangle {
                    anchors.centerIn: parent
                    visible: ServiceWallpaper.onlineMode && ServiceWallpaper.onlineError.length > 0
                    z: 1
                    implicitWidth: _errRow.implicitWidth + 32; implicitHeight: _errRow.implicitHeight + 20
                    radius: 14; color: Colors.surfaceContainer
                    RowLayout {
                        id: _errRow; anchors.centerIn: parent; spacing: 8
                        MaterialIconSymbol { content: "error"; iconSize: 20; customColor: Colors.error }
                        CustomText {
                            content: ServiceWallpaper.onlineError
                            size: 13; customColor: Colors.error
                        }
                    }
                }

                // Local loading overlay
                Loader {
                    anchors.centerIn: parent
                    z: 1
                    active: !ServiceWallpaper.onlineMode && ServiceWallpaper.isProcessing
                    visible: active
                    sourceComponent: ColumnLayout {
                        spacing: 12
                        CustomLoader { size: 60; color: Colors.primary; Layout.alignment: Qt.AlignHCenter }
                        CustomText {
                            content: "Loading wallpapers…"
                            size: 13; customColor: Colors.outline
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Local empty state
                Rectangle {
                    anchors.centerIn: parent
                    z: 1
                    visible: !ServiceWallpaper.onlineMode
                          && !ServiceWallpaper.isProcessing
                          && (col.activeTab === "favorites"
                              ? ServiceWallpaper.favoritedWallpapers.length === 0
                              : ServiceWallpaper.filteredWallpapers.length === 0)
                    implicitWidth:  _emptyCol.implicitWidth  + 48
                    implicitHeight: _emptyCol.implicitHeight + 32
                    radius: 14; color: Colors.surfaceContainer

                    ColumnLayout {
                        id: _emptyCol
                        anchors.centerIn: parent; spacing: 8

                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            content: col.activeTab === "favorites" ? "favorite_border" : "image_not_supported"
                            iconSize: 32; customColor: Colors.outline
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: col.activeTab === "favorites"
                                ? "No favourites yet"
                                : ServiceWallpaper.wallpapers.length === 0
                                  ? "No wallpapers in folder"
                                  : "No wallpapers match search"
                            size: 13; customColor: Colors.outline
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: col.activeTab !== "favorites" && ServiceWallpaper.wallpapers.length === 0
                            content: ServiceWallpaper.wallpaperDir
                            size: 11; customColor: Qt.alpha(Colors.outline, 0.6)
                        }
                    }
                }

                // ── Wallpaper grid ─────────────────────────────────────────────
                ListView {
                    id: grid
                    anchors.fill: parent; clip: true; interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: CustomScrollBar {}
                    flickDeceleration: 3000; maximumFlickVelocity: 6000; pixelAligned: true

                    property real itemSpacing: 8
                    spacing: itemSpacing

                    readonly property var currentDataArray: ServiceWallpaper.onlineMode
                        ? ServiceWallpaper.onlineWallpapers
                        : (col.activeTab === "favorites"
                            ? ServiceWallpaper.favoritedWallpapers
                            : ServiceWallpaper.filteredWallpapers)

                    model: ServiceWallpaper.onlineMode
                        ? onlineRowModel
                        : (currentDataArray ? Math.ceil(currentDataArray.length / 4) : 0)

                    onAtYEndChanged: {
                        if (atYEnd && ServiceWallpaper.onlineMode) ServiceWallpaper.fetchNextPage()
                    }

                    delegate: Item {
                        id: rowContainer
                        width: grid.width

                        readonly property real cellWidth: (grid.width - (grid.itemSpacing * 3)) / 4
                        property real targetHeight: cellWidth * 1
                        property int  rowIndex:     index

                        property real rowCenterY:         y + (targetHeight / 2)
                        property real viewCenterY:        grid.contentY + (grid.height / 2)
                        property real distanceFromCenter: Math.abs(rowCenterY - viewCenterY)
                        property real maxDistance:        grid.height / 2

                        property real maskRatio:     Math.max(0.62, 1.0 - (distanceFromCenter / maxDistance) * 0.52)
                        height: targetHeight * maskRatio

                        property real compressRatio: (1.0 - maskRatio) / (1.0 - 0.62)
                        property real dynamicRadius: 12 + compressRatio * 36

                        Row {
                            anchors.centerIn: parent; spacing: grid.itemSpacing

                            Repeater {
                                model: 4

                                delegate: Rectangle {
                                    id: wallpaperItem

                                    property int wallpaperIndex: (rowContainer.rowIndex * 4) + index
                                    property var itemData: (grid.currentDataArray && wallpaperIndex < grid.currentDataArray.length)
                                        ? grid.currentDataArray[wallpaperIndex] : null

                                    readonly property bool isDownloading: ServiceWallpaper.onlineMode
                                        && itemData && ServiceWallpaper.downloadingId === itemData.id

                                    visible: itemData !== null
                                    width:  (grid.width - (grid.itemSpacing * 3)) / 4
                                    height: rowContainer.height
                                    radius: rowContainer.dynamicRadius
                                    clip:   true
                                    color:  tileArea.containsMouse ? Qt.alpha(Colors.primary, 0.15) : "transparent"

                                    // Masked image with parallax
                                    Item {
                                        id: maskContainer
                                        anchors.fill: parent
                                        scale: tileHover.hovered ? 0.97 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: maskContainer.width; height: maskContainer.height
                                                radius: rowContainer.dynamicRadius
                                            }
                                        }

                                        Image {
                                            id: thumbnail
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -(rowContainer.rowCenterY - rowContainer.viewCenterY) * 0.12
                                            width: parent.width; height: rowContainer.targetHeight
                                            sourceSize: Qt.size(width, height)
                                            asynchronous: true; smooth: true; cache: true
                                            source: {
                                                if (!wallpaperItem.itemData) return ""
                                                ServiceWallpaper.onlineMode
                                                    ? wallpaperItem.itemData.thumbUrl
                                                    : "file://" + wallpaperItem.itemData
                                            }
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                    }

                                    // Loading spinner (online thumbnails)
                                    Loader {
                                        anchors.centerIn: parent
                                        active: ServiceWallpaper.onlineMode && thumbnail.status === Image.Loading
                                        visible: active
                                        sourceComponent: CustomLoader { size: 52; color: Colors.primary }
                                    }

                                    HoverHandler { id: tileHover }

                                    MouseArea {
                                        id: tileArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                const mapped = tileArea.mapToItem(gridWrapper, mouse.x, mouse.y)
                                                ctxMenu.show(mapped.x, mapped.y,
                                                    wallpaperItem.itemData, ServiceWallpaper.onlineMode)
                                            } else {
                                                if (ServiceWallpaper.onlineMode)
                                                    ServiceWallpaper.downloadAndSetWallpaper(wallpaperItem.itemData)
                                                else
                                                    ServiceWallpaper.setWallpaper(wallpaperItem.itemData)
                                            }
                                        }
                                    }

                                    // ── Download overlay ───────────────────────
                                    Rectangle {
                                        anchors.fill: parent; radius: rowContainer.dynamicRadius
                                        color: Qt.rgba(0, 0, 0, 0.55)
                                        visible: wallpaperItem.isDownloading; z: 3

                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 8
                                            width: Math.min(parent.width - 16, 100)

                                            Loader {
                                                Layout.alignment: Qt.AlignHCenter
                                                active: wallpaperItem.isDownloading
                                                visible: active
                                                sourceComponent: CustomLoader { size: 56; color: "white" }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true; height: 4; radius: 2
                                                color: Qt.rgba(1, 1, 1, 0.2)
                                                Rectangle {
                                                    width: parent.width * ServiceWallpaper.downloadProgress
                                                    height: parent.height; radius: 2; color: Colors.primary
                                                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                                                }
                                            }

                                            CustomText {
                                                Layout.alignment: Qt.AlignHCenter
                                                content: {
                                                    const pct = Math.round(ServiceWallpaper.downloadProgress * 100)
                                                    const mb  = (ServiceWallpaper.downloadedBytes / (1024 * 1024)).toFixed(1)
                                                    if (ServiceWallpaper.downloadTotalBytes > 0) {
                                                        const tot = (ServiceWallpaper.downloadTotalBytes / (1024 * 1024)).toFixed(1)
                                                        return pct + "% · " + mb + "/" + tot + " MB"
                                                    }
                                                    return mb + " MB"
                                                }
                                                size: 10; customColor: "white"
                                            }
                                        }
                                    }

                                    // Favourite button (local mode)
                                    Rectangle {
                                        id: heartBtn
                                        visible: !ServiceWallpaper.onlineMode && wallpaperItem.itemData !== null
                                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                                        width: 28; height: 28; radius: 14; z: 2

                                        readonly property bool faved: ServiceWallpaper.favoritedWallpapers.indexOf(
                                            wallpaperItem.itemData) >= 0

                                        color:   faved ? Colors.error : Colors.surfaceContainer
                                        opacity: faved || tileHover.hovered ? 0.92 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        Behavior on color   { ColorAnimation  { duration: 150 } }

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: heartBtn.faved ? "favorite" : "favorite_border"; iconSize: 16
                                            customColor: heartBtn.faved ? Colors.errorText : Colors.surfaceText
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                ServiceWallpaper.toggleFavorite(wallpaperItem.itemData)
                                                mouse.accepted = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Context menu — fills gridWrapper so clamping uses the right bounds
                WallpaperContextMenu {
                    id: ctxMenu
                    anchors.fill: parent
                }
            }
        }
    }
}
