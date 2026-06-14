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

Rectangle{
    anchors.fill: parent
    topLeftRadius: Appearance.radius.large
    topRightRadius: Appearance.radius.extraLarge
    color: Colors.surface
    anchors.bottom:  parent.bottom


    Behavior on implicitHeight{
        NumberAnimation{
            duration: Appearance.duration.normal
            easing.type: Easing.OutQuad
        }
    }
    //
    // Connections{
    //     target: loader
    //     function onAnimationChanged(){
    //         if(loader.animation){
    //             timer.start();
    //         }else{
    //             colLoader.active = false
    //         }
    //     }
    // }
    //
    Timer{
        id: timer
        interval: 300
        running: true
        onTriggered:{
            colLoader.active = true
        }
    }
    Loader{
        id: colLoader
        active: false
        visible: active
        anchors.fill: parent
        sourceComponent: ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            property string activeTab: "all"

            Component.onCompleted: searchInput.forceActiveFocus()

            Connections {
                target: ServiceWallpaper
                function onOnlineModeChanged() {
                    if (ServiceWallpaper.onlineMode) col.activeTab = "all"
                }
            }

            // Stable online row model — append-only on pagination so existing
            // delegates are never destroyed mid-scroll; only clears on page-1 results.
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
                    if (!ServiceWallpaper.onlineMode) onlineRowModel.clear()
                }
            }

            NumberAnimation on opacity {
                from: 0; to: 1; duration: 100; running: col.visible
            }
            NumberAnimation on scale {
                from: 0.8; to: 1; duration: 100; running: col.visible
            }

            // ── Top bar (local + online share one rectangle) ─────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                clip: true
                radius: Appearance.radius.extraLarge
                color: Colors.surfaceContainer

                // ── Local content ─────────────────────────────────────────────
                RowLayout {
                    id: localContent
                    anchors.fill: parent
                    anchors.rightMargin: 10
                    anchors.leftMargin: 10
                    spacing: 10
                    enabled: !ServiceWallpaper.onlineMode
                    opacity: ServiceWallpaper.onlineMode ? 0 : 1
                    scale: ServiceWallpaper.onlineMode ? 0.92 : 1
                    Behavior on opacity { NumberAnimation { duration: Appearance.duration.normal } }
                    Behavior on scale   { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

                    Rectangle {
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 400
                        radius: 20
                        color: Colors.surfaceContainerHighest
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            anchors.leftMargin: 10
                            spacing: 10
                            MaterialIconSymbol { content: "search"; iconSize: 18 }
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                font.pixelSize: 16
                                font.weight: 800
                                color: Colors.inverseSurface
                                onTextChanged: ServiceWallpaper.updateSearch(text)
                                Keys.onEscapePressed: text = ""
                            }
                        }
                    }
                    // All / Favorites tab pills
                    Repeater {
                        model: [["grid_view", "All", "all"], ["favorite", "Favorites", "favorites"]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: col.activeTab === modelData[2]
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: _tabRow.implicitWidth + 20
                            radius: 20
                            color: active ? Colors.primary : Colors.surfaceContainerHighest
                            Behavior on color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                id: _tabRow
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialIconSymbol {
                                    content: modelData[0]; iconSize: 15
                                    customColor: parent.parent.active ? Colors.primaryText : Colors.surfaceText
                                }
                                CustomText {
                                    content: modelData[1]; size: 12
                                    customColor: parent.parent.active ? Colors.primaryText : Colors.surfaceText
                                }
                            }
                            CustomMouseArea {
                                radius: parent.radius
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: col.activeTab = modelData[2]
                            }
                        }
                    }

                    // Sort pills
                    ButtonGroup {
                        Layout.preferredHeight: 30
                        model: [
                            {icon: "schedule",      label: "Newest", value: "newest"},
                            {icon: "sort_by_alpha",  label: "Name",   value: "name"}
                        ]
                        activeCheck: v => ServiceWallpaper.localSortBy === v
                        onSegmentClicked: v => ServiceWallpaper.localSortBy = v
                    }

                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 40
                        radius: 20
                        color: Colors.surfaceContainerHighest
                        MaterialIconSymbol { anchors.centerIn: parent; content: "refresh"; iconSize: 20 }
                        CustomMouseArea {
                            radius: parent.radius
                            cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: ServiceWallpaper.refresh()
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: _onlineRow.implicitWidth + 30
                        radius: 20
                        color: Colors.surfaceContainerHighest
                        RowLayout {
                            id: _onlineRow
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 6
                            MaterialIconSymbol { content: "public"; iconSize: 18 }
                            CustomText { content: "Online"; size: 12 }
                        }
                        CustomMouseArea {
                            radius: parent.radius
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            onClicked: { ServiceWallpaper.onlineMode = true; ServiceWallpaper.fetchWallhaven(true) }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: _countRow.implicitWidth + 30
                        radius: 20
                        color: Colors.surfaceContainerHighest
                        RowLayout {
                            id: _countRow
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 10
                            MaterialIconSymbol { content: "wallpaper"; iconSize: 18 }
                            CustomText { content: ServiceWallpaper.cacheModel.count + " wallpapers"; size: 12 }
                        }
                    }
                }

                // ── Online content ────────────────────────────────────────────
                RowLayout {
                    id: onlineConfigCol
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 6
                    enabled: ServiceWallpaper.onlineMode
                    opacity: ServiceWallpaper.onlineMode ? 1 : 0
                    scale: ServiceWallpaper.onlineMode ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: Appearance.duration.normal } }
                    Behavior on scale   { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

                    property var sortOpts: [
                        ["Recent",   "date_added"], ["Hot",      "toplist"],
                        ["Views",    "views"],      ["Fav",      "favorites"],
                        ["Random",   "random"],     ["Relevant", "relevance"]
                    ]
                    property var rangeOpts: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]

                    function toggleCat(pos) {
                        let c = SettingsConfig.wallhaven.categories.split("")
                        c[pos] = c[pos] === "1" ? "0" : "1"
                        if (!c.includes("1")) return
                        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, {categories: c.join("")})
                    }
                    function togglePur(pos) {
                        let p = SettingsConfig.wallhaven.purity.split("")
                        p[pos] = p[pos] === "1" ? "0" : "1"
                        if (!p.includes("1")) return
                        SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, {purity: p.join("")})
                    }

                    // Back button
                    Rectangle {
                        height: 28; radius: 14
                        color: Colors.surfaceContainerHighest
                        implicitWidth: _backRow.implicitWidth + 20
                        RowLayout {
                            id: _backRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIconSymbol { content: "arrow_back"; iconSize: 14; customColor: Colors.surfaceText }
                            CustomText { content: "Local"; size: 11; customColor: Colors.surfaceText }
                        }
                        CustomMouseArea {
                            radius: parent.radius
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceWallpaper.onlineMode = false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Sorting group
                    ButtonGroup {
                        model: onlineConfigCol.sortOpts.map(o => ({label: o[0], value: o[1]}))
                        activeCheck: v => SettingsConfig.wallhaven.sorting === v
                        onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, {sorting: v})
                    }

                    // TopRange group (only when sorting=toplist)
                    ButtonGroup {
                        visible: SettingsConfig.wallhaven.sorting === "toplist"
                        model: onlineConfigCol.rangeOpts.map(v => ({label: v, value: v}))
                        activeCheck: v => SettingsConfig.wallhaven.topRange === v
                        onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, {topRange: v})
                    }

                    // Order group (↓ ↑)
                    ButtonGroup {
                        model: [
                            {icon: "arrow_downward", value: "desc"},
                            {icon: "arrow_upward",   value: "asc"}
                        ]
                        activeCheck: v => SettingsConfig.wallhaven.order === v
                        onSegmentClicked: v => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, {order: v})
                    }

                    // Categories group
                    ButtonGroup {
                        model: [
                            {label: "General", value: 0},
                            {label: "Anime",   value: 1},
                            {label: "People",  value: 2}
                        ]
                        activeCheck: v => SettingsConfig.wallhaven.categories[v] === "1"
                        onSegmentClicked: v => onlineConfigCol.toggleCat(v)
                    }

                    // Purity group — SFW/Sketchy share a group; NSFW is separate (different color, conditional)
                    ButtonGroup {
                        model: [
                            {label: "SFW",     value: 0},
                            {label: "Sketchy", value: 1}
                        ]
                        activeCheck: v => SettingsConfig.wallhaven.purity[v] === "1"
                        onSegmentClicked: v => onlineConfigCol.togglePur(v)
                    }
                    Rectangle {
                        visible: SettingsConfig.wallhaven.apiKey.length > 0
                        readonly property bool active: SettingsConfig.wallhaven.purity[2] === "1"
                        height: 30; radius: 15
                        implicitWidth: _nsfwText.implicitWidth + 24
                        color: active ? Colors.error : "transparent"
                        border.width: 1
                        border.color: Colors.outline
                        Behavior on color { ColorAnimation { duration: 150 } }
                        CustomText {
                            id: _nsfwText
                            anchors.centerIn: parent
                            content: "NSFW"; size: 11
                            customColor: parent.active ? Colors.errorText : Colors.surfaceText
                        }
                        CustomMouseArea {
                            radius: parent.radius
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: onlineConfigCol.togglePur(2)
                        }
                    }

                    // Fetch button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: ServiceWallpaper.isFetchingOnline ? Colors.surfaceContainerHighest : Colors.primary
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: ServiceWallpaper.isFetchingOnline ? "hourglass_empty" : "search"
                            iconSize: 16
                            customColor: ServiceWallpaper.isFetchingOnline ? Colors.surfaceText : Colors.primaryText
                        }
                        CustomMouseArea {
                            radius: parent.radius
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (!ServiceWallpaper.isFetchingOnline) ServiceWallpaper.fetchWallhaven(true)
                        }
                    }
                }
            }
            // ── End top bar ───────────────────────────────────────────────────

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true

                // Centered fetch / error overlay
                Rectangle {
                    anchors.centerIn: parent
                    visible: ServiceWallpaper.onlineMode &&
                    (ServiceWallpaper.isFetchingOnline || ServiceWallpaper.onlineError.length > 0)
                    z: 1
                    implicitWidth: _overlayRow.implicitWidth + 32
                    implicitHeight: _overlayRow.implicitHeight + 20
                    radius: 14
                    color: Colors.surfaceContainer

                    RowLayout {
                        id: _overlayRow
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialIconSymbol {
                            content: ServiceWallpaper.onlineError.length > 0 ? "error" : "downloading"
                            iconSize: 20
                            customColor: ServiceWallpaper.onlineError.length > 0 ? Colors.error : Colors.surfaceText
                        }
                        CustomText {
                            content: ServiceWallpaper.onlineError.length > 0
                            ? ServiceWallpaper.onlineError
                            : "Fetching wallpapers…"
                            size: 13
                            customColor: ServiceWallpaper.onlineError.length > 0 ? Colors.error : Colors.surfaceText
                        }
                    }
                }

                ListView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: CustomScrollBar{}

                    flickDeceleration: 3000
                    maximumFlickVelocity: 6000
                    pixelAligned: true

                    // 1. Centralized spacing control (adjust this to change layout gaps)
                    property real itemSpacing: 8
                    spacing: itemSpacing

                    // 2. Resolve your conditional data model structure cleanly at the root
                    readonly property var currentDataArray: ServiceWallpaper.onlineMode
                    ? ServiceWallpaper.onlineWallpapers
                    : (col.activeTab === "favorites"
                    ? ServiceWallpaper.favoritedWallpapers
                    : ServiceWallpaper.filteredWallpapers)

                    // Online mode uses a stable ListModel (append-only) to avoid full delegate recycling.
                    model: ServiceWallpaper.onlineMode
                        ? onlineRowModel
                        : (currentDataArray ? Math.ceil(currentDataArray.length / 4) : 0)

                    // Unchanged Pagination Trigger Function
                    onAtYEndChanged: {
                        if (atYEnd && ServiceWallpaper.onlineMode)
                        ServiceWallpaper.fetchNextPage()
                    }

                    delegate: Item {
                        id: rowContainer
                        width: grid.width

                        readonly property real cellWidth: (grid.width - (grid.itemSpacing * 3)) / 4

                        // Captures your original aspect ratio rule: height / (4 / 2)
                         property real targetHeight: cellWidth * 1
                        //property real targetHeight: grid.height / 2
                        property int rowIndex: index

                        // Material You Parallax position calculations
                        property real rowCenterY: y + (targetHeight / 2)
                        property real viewCenterY: grid.contentY + (grid.height / 2)
                        property real distanceFromCenter: Math.abs(rowCenterY - viewCenterY)
                        property real maxDistance: grid.height / 2

                        // M3 carousel: center rows full-size, outer rows compress.
                        property real maskRatio: Math.max(0.62, 1.0 - (distanceFromCenter / maxDistance) * 0.52)
                        height: targetHeight * maskRatio

                        // 0 at center → 1 at max compression. Drives radius morphing.
                        property real compressRatio: (1.0 - maskRatio) / (1.0 - 0.62)
                        // M3 shape token: extraLarge (12dp) at center → near-pill at edges.
                        property real dynamicRadius: 12 + compressRatio * 36

                        Row {
                            anchors.centerIn: parent
                            spacing: grid.itemSpacing

                            Repeater {
                                model: 4 // Rigid 4 columns grid distribution

                                delegate: Rectangle {
                                    id: wallpaperItemImageContainer

                                    // Maps localized loop index smoothly to flat 1D backend model array
                                    property int wallpaperIndex: (rowContainer.rowIndex * 4) + index

                                    // Dynamically binds item payload data down to child layers
                                    property var modelData: (grid.currentDataArray && wallpaperIndex < grid.currentDataArray.length) 
                                    ? grid.currentDataArray[wallpaperIndex] 
                                    : null

                                    // Hides out-of-bound structural item cells on the final row
                                    visible: modelData !== null

                                    // Automatically fits columns evenly across layout width minus gaps
                                    width: (grid.width - (grid.itemSpacing * 3)) / 4
                                    height: rowContainer.height
                                    // Shape morphs from extraLarge rounded rect → pill as row compresses.
                                    radius: rowContainer.dynamicRadius
                                    clip: true
                                    color: area.containsMouse ? Colors.primary : "transparent"

                                    // The Dynamic Masking Element Container
                                    Item {
                                        id: maskContainer
                                        anchors.fill: parent
                                        scale: tileHover.hovered ? 0.98 : 1.0
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                        }

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: maskContainer.width
                                                height: maskContainer.height
                                                radius: rowContainer.dynamicRadius
                                            }
                                        }

                                        Image {
                                            id: thumbnail
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -(rowContainer.rowCenterY - rowContainer.viewCenterY) * 0.12
                                            width: parent.width
                                            height: rowContainer.targetHeight

                                            sourceSize: Qt.size(width, height)
                                            asynchronous: true
                                            smooth: true
                                            cache: true

                                            source: if (!wallpaperItemImageContainer.modelData) { "" }
                                            else {
                                                ServiceWallpaper.onlineMode
                                                ? wallpaperItemImageContainer.modelData.thumbUrl
                                                : "file://" + wallpaperItemImageContainer.modelData
                                            }
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                    }

                                    // Loading spinner for online thumbnails still fetching
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28; height: 28
                                        radius: 14
                                        color: Colors.surfaceContainer
                                        visible: ServiceWallpaper.onlineMode && thumbnail.status === Image.Loading

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: "hourglass_empty"
                                            iconSize: 16
                                        }
                                    }

                                    HoverHandler { id: tileHover }

                                    MouseArea {
                                        id: area
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (ServiceWallpaper.onlineMode)
                                            ServiceWallpaper.downloadAndSetWallpaper(wallpaperItemImageContainer.modelData)
                                            else
                                            ServiceWallpaper.setWallpaper(wallpaperItemImageContainer.modelData)
                                        }
                                    }

                                    // Download progress overlay (online mode, active download only)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        radius: 8
                                        color: Qt.rgba(0, 0, 0, 0.6)
                                        visible: ServiceWallpaper.onlineMode && 
                                        wallpaperItemImageContainer.modelData &&
                                        ServiceWallpaper.downloadingId === wallpaperItemImageContainer.modelData.id
                                        z: 3

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            MaterialIconSymbol {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                content: "downloading"
                                                iconSize: 28
                                                customColor: "white"
                                            }

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: Math.min(80, parent.parent.width - 16)
                                                height: 4
                                                radius: 2
                                                color: Qt.rgba(1, 1, 1, 0.3)

                                                Rectangle {
                                                    width: parent.width * ServiceWallpaper.downloadProgress
                                                    height: parent.height
                                                    radius: parent.radius
                                                    color: "white"
                                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                                }
                                            }

                                            CustomText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                content: {
                                                    const mb = (ServiceWallpaper.downloadedBytes / (1024 * 1024)).toFixed(1)
                                                    if (ServiceWallpaper.downloadTotalBytes > 0) {
                                                        const total = (ServiceWallpaper.downloadTotalBytes / (1024 * 1024)).toFixed(1)
                                                        return mb + " / " + total + " MB"
                                                    }
                                                    return mb + " MB"
                                                }
                                                size: 11
                                                customColor: "white"
                                            }
                                        }
                                    }

                                    // Heart / favourite button (local mode only)
                                    Rectangle {
                                        id: heartBtn
                                        visible: !ServiceWallpaper.onlineMode && wallpaperItemImageContainer.modelData !== null
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        width: 28; height: 28; radius: 14
                                        z: 2

                                        readonly property bool faved: ServiceWallpaper.favoritedWallpapers.indexOf(
                                            wallpaperItemImageContainer.modelData) >= 0

                                            color: faved ? Colors.error : Colors.surfaceContainer
                                            opacity: faved || tileHover.hovered ? 0.92 : 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            Behavior on color   { ColorAnimation  { duration: 150 } }

                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                content: heartBtn.faved ? "favorite" : "favorite_border"
                                                iconSize: 16
                                                customColor: heartBtn.faved ? Colors.errorText : Colors.surfaceText
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    ServiceWallpaper.toggleFavorite(wallpaperItemImageContainer.modelData)
                                                    mouse.accepted = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } // GridView

                } // Item
            }
        }
    }
