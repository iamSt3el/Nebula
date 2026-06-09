import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    // "browse" | "favs" | "offline" | "detail" | "reader"
    property string viewState: "browse"
    property bool searchActive: false
    property bool offlineMode: false  // reading an offline chapter

    NumberAnimation on scale   { from: 0.9; to: 1; duration: 200 }
    NumberAnimation on opacity { from: 0;   to: 1; duration: 200 }

    Component.onCompleted: ServiceManga.fetchByOrigin("", true)

    // ── Root card ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 20
        color: Colors.surfaceContainer
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── Top bar ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Back button (detail / reader)
                Rectangle {
                    visible: root.viewState === "detail" || root.viewState === "reader"
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "arrow_back"
                        iconSize: 20
                        color: Colors.surfaceText
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.viewState === "reader") {
                                root.viewState = root.offlineMode ? "offline" : "detail"
                                root.offlineMode = false
                                ServiceManga.clearChapterPages()
                            } else {
                                root.viewState = "browse"
                                ServiceManga.clearChapterList()
                            }
                        }
                    }
                }

                // Title / search input
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIconSymbol {
                            content: root.searchActive ? "search" : "menu_book"
                            iconSize: 18
                            color: Colors.outline
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            visible: root.viewState === "browse"
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont
                            color: Colors.surfaceText
                            background: null
                            placeholderText: "Search manga..."
                            placeholderTextColor: Colors.outline
                            onTextChanged: {
                                searchDebounce.restart()
                                root.searchActive = text.length > 0
                            }
                            Keys.onReturnPressed: {
                                searchDebounce.stop()
                                ServiceManga.searchManga(text, true)
                            }
                        }

                        CustomText {
                            visible: root.viewState === "favs"
                            content: "Favorites"
                            size: 13
                            color: Colors.surfaceText
                            Layout.fillWidth: true
                        }

                        CustomText {
                            visible: root.viewState === "offline"
                            content: "Downloads"
                            size: 13
                            color: Colors.surfaceText
                            Layout.fillWidth: true
                        }

                        CustomText {
                            visible: root.viewState === "detail" || root.viewState === "reader"
                            content: root.viewState === "reader"
                                ? ("Ch. " + (ServiceManga.currentChapterId || ""))
                                : (ServiceManga.currentManga ? ServiceManga.currentManga.title : "")
                            size: 13
                            color: Colors.surfaceText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // Site selector dropdown (browse / favs only)
                CustomList {
                    id: siteDropdown
                    visible: root.viewState === "browse" || root.viewState === "favs"
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 30
                    list: [
                        { description: "WeebCentral", key: "weebcentral" },
                        { description: "Comix.to",    key: "comix"       }

                    ]
                    onListChildClicked: (item) => ServiceManga.switchSite(item.key)

                    Binding on currentVal {
                        value: ServiceManga._sites[ServiceManga.currentSite].label
                    }
                }

                // Refresh pages button (reader only)
                Rectangle {
                    visible: root.viewState === "reader"
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "refresh"
                        iconSize: 18
                        color: Colors.outline
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.offlineMode)
                                ServiceManga.fetchOfflineChapterPages(ServiceManga.currentChapterId)
                            else
                                ServiceManga.refreshChapterPages()
                        }
                    }
                }

                // Refresh button (browse / favs / offline)
                Rectangle {
                    visible: root.viewState === "browse" || root.viewState === "favs" || root.viewState === "offline"
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "refresh"
                        iconSize: 18
                        color: Colors.outline

                        RotationAnimation on rotation {
                            running: ServiceManga.isFetchingManga || ServiceManga.isFetchingFavs
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.viewState === "favs") {
                                ServiceManga.checkFavoritesForUpdates()
                                ServiceManga.fetchFavorites()
                            } else if (root.viewState === "offline") {
                                ServiceManga.fetchDownloads()
                            } else if (searchInput.text.length > 0) {
                                ServiceManga.searchManga(searchInput.text, true)
                            } else {
                                ServiceManga.fetchByOrigin(ServiceManga.currentOrigin, true)
                            }
                        }
                    }
                }
            }

            // ── Chip row (scrollable) ─────────────────────────────────────────
            Flickable {
                visible: root.viewState !== "detail" && root.viewState !== "reader"
                Layout.fillWidth: true
                height: 30
                contentWidth: chipRow.implicitWidth
                contentHeight: height
                clip: true
                interactive: contentWidth > width

                Row {
                    id: chipRow
                    spacing: 6
                    height: parent.height

                    // Browse section chips
                    Repeater {
                        model: {
                            const base = [
                                { label: "Hot",    origin: ""       },
                                { label: "Latest", origin: "latest" },
                            ]
                            const weeb = [
                                { label: "Manhwa", origin: "ko" },
                                { label: "Manga",  origin: "ja" },
                                { label: "Manhua", origin: "zh" },
                            ]
                            return ServiceManga.currentSite === "weebcentral" ? base.concat(weeb) : base
                        }
                        delegate: Rectangle {
                            required property var modelData
                            property bool sel: root.viewState === "browse"
                                && ServiceManga.currentOrigin === modelData.origin
                                && !root.searchActive
                            height: 26
                            width: chipLbl.implicitWidth + 16
                            radius: 8
                            color: sel ? Colors.primary : Colors.surfaceContainerHigh

                            CustomText {
                                id: chipLbl
                                anchors.centerIn: parent
                                content: modelData.label
                                size: 12
                                color: sel ? Colors.primaryText : Colors.outline
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.viewState = "browse"
                                    ServiceManga.fetchByOrigin(modelData.origin, true)
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: 1; height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.outline
                        opacity: 0.3
                    }

                    // Favs chip
                    Rectangle {
                        property bool sel: root.viewState === "favs"
                        height: 26
                        width: favsRow.implicitWidth + 16
                        radius: 8
                        color: sel ? Colors.primary : Colors.surfaceContainerHigh

                        Row {
                            id: favsRow
                            anchors.centerIn: parent
                            spacing: 4
                            CustomText {
                                content: "Favs"
                                size: 12
                                color: parent.parent.sel ? Colors.primaryText : Colors.outline
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            // New badge
                            Rectangle {
                                visible: ServiceManga.favNewCount > 0
                                height: 16; width: Math.max(16, badgeTxt.implicitWidth + 6)
                                radius: 8
                                color: "#e53935"
                                anchors.verticalCenter: parent.verticalCenter
                                CustomText {
                                    id: badgeTxt
                                    anchors.centerIn: parent
                                    content: ServiceManga.favNewCount
                                    size: 9
                                    color: "white"
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.viewState = "favs"
                                ServiceManga.fetchFavorites()
                            }
                        }
                    }

                    // Offline chip
                    Rectangle {
                        property bool sel: root.viewState === "offline"
                        height: 26
                        width: offlineLbl.implicitWidth + 16
                        radius: 8
                        color: sel ? Colors.primary : Colors.surfaceContainerHigh

                        CustomText {
                            id: offlineLbl
                            anchors.centerIn: parent
                            content: "Offline"
                            size: 12
                            color: parent.sel ? Colors.primaryText : Colors.outline
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.viewState = "offline"
                                ServiceManga.fetchDownloads()
                            }
                        }
                    }
                }
            }

            // ── Content area ─────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── BROWSE view ──────────────────────────────────────────────
                GridView {
                    id: browseGrid
                    visible: root.viewState === "browse"
                    anchors.fill: parent
                    clip: true

                    cellWidth:  Math.floor((width - 8) / 3)
                    cellHeight: Math.floor(cellWidth * 1.45) + 8

                    model: ScriptModel { values: ServiceManga.mangaList }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    onAtYEndChanged: {
                        if (atYEnd && ServiceManga.hasMoreManga && !ServiceManga.isFetchingManga)
                            ServiceManga.fetchNextMangaPage()
                    }

                    delegate: Item {
                        required property var modelData
                        width:  browseGrid.cellWidth
                        height: browseGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 12
                            color: Colors.surfaceContainerHigh
                            clip: true

                            Image {
                                id: coverImg
                                anchors.fill: parent
                                source: modelData.thumbUrl
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Colors.surfaceContainerHigh
                                visible: coverImg.status === Image.Loading || coverImg.status === Image.Null
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "image"
                                    iconSize: 28
                                    color: Colors.outline
                                    RotationAnimation on rotation {
                                        running: coverImg.status === Image.Loading
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 1000
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 52
                                radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) }
                                }

                                CustomText {
                                    anchors {
                                        left: parent.left; right: parent.right
                                        bottom: parent.bottom
                                        margins: 6
                                    }
                                    content: modelData.title
                                    size: 10
                                    color: "white"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ServiceManga.clearChapterList()
                                    ServiceManga.fetchMangaDetail(modelData.id)
                                    root.viewState = "detail"
                                }
                            }
                        }
                    }
                }

                // Empty / loading for browse
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.viewState === "browse" && ServiceManga.mangaList.length === 0

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: ServiceManga.isFetchingManga ? "hourglass_top" : "search_off"
                        iconSize: 36
                        color: Colors.outline
                        RotationAnimation on rotation {
                            running: ServiceManga.isFetchingManga
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 1200
                        }
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: ServiceManga.isFetchingManga ? "Loading..." : (ServiceManga.mangaError || "No results")
                        size: 13
                        color: Colors.outline
                    }
                }

                // ── FAVS view ────────────────────────────────────────────────
                GridView {
                    id: favsGrid
                    visible: root.viewState === "favs"
                    anchors.fill: parent
                    clip: true

                    cellWidth:  Math.floor((width - 8) / 3)
                    cellHeight: Math.floor(cellWidth * 1.45) + 8

                    model: ScriptModel { values: ServiceManga.favoritesList }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        required property var modelData
                        width:  favsGrid.cellWidth
                        height: favsGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 12
                            color: Colors.surfaceContainerHigh
                            clip: true

                            Image {
                                id: favCoverImg
                                anchors.fill: parent
                                source: modelData.image || ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Colors.surfaceContainerHigh
                                visible: favCoverImg.status === Image.Loading || favCoverImg.status === Image.Null
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "image"
                                    iconSize: 28
                                    color: Colors.outline
                                    RotationAnimation on rotation {
                                        running: favCoverImg.status === Image.Loading
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 1000
                                    }
                                }
                            }

                            // NEW badge
                            Rectangle {
                                visible: modelData.hasNewChapters || false
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 18; width: newLbl.implicitWidth + 10
                                radius: 6
                                color: "#e53935"
                                CustomText {
                                    id: newLbl
                                    anchors.centerIn: parent
                                    content: "NEW"
                                    size: 9
                                    color: "white"
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 52
                                radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) }
                                }

                                CustomText {
                                    anchors {
                                        left: parent.left; right: parent.right
                                        bottom: parent.bottom
                                        margins: 6
                                    }
                                    content: modelData.title
                                    size: 10
                                    color: "white"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ServiceManga.clearChapterList()
                                    ServiceManga.fetchMangaDetail(modelData.id)
                                    root.viewState = "detail"
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.viewState === "favs" && ServiceManga.favoritesList.length === 0

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: ServiceManga.isFetchingFavs ? "hourglass_top" : "bookmark"
                        iconSize: 36
                        color: Colors.outline
                        RotationAnimation on rotation {
                            running: ServiceManga.isFetchingFavs
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 1200
                        }
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: ServiceManga.isFetchingFavs ? "Loading..." : "No favorites yet"
                        size: 13
                        color: Colors.outline
                    }
                }

                // ── OFFLINE view ─────────────────────────────────────────────
                Flickable {
                    id: offlineFlick
                    visible: root.viewState === "offline"
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: offlineCol.implicitHeight + 12

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: offlineCol
                        width: offlineFlick.width - 8
                        x: 4; y: 4
                        spacing: 8

                        Repeater {
                            model: ScriptModel { values: ServiceManga.downloadsList }
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: seriesHeader.height + (expanded ? chaptersList.height + 4 : 0)
                                radius: 12
                                color: Colors.surfaceContainerHigh
                                clip: true

                                property bool expanded: false

                                // Series header row
                                Item{
                                    implicitWidth: parent.width
                                    implicitHeight: 56
                                    RowLayout {
                                        id: seriesHeader
                                        anchors.fill: parent
                                        spacing: 10

                                        Image {
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 56
                                            Layout.leftMargin: 8
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            asynchronous: true
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            CustomText {
                                                content: modelData.title || ""
                                                size: 13
                                                color: Colors.surfaceText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            CustomText {
                                                content: (modelData.chapters ? modelData.chapters.length : 0) + " chapters"
                                                size: 11
                                                color: Colors.outline
                                            }
                                        }

                                        MaterialIconSymbol {
                                            content: expanded ? "expand_less" : "expand_more"
                                            iconSize: 20
                                            color: Colors.outline
                                            Layout.rightMargin: 10
                                        }

                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.parent.expanded = !parent.parent.expanded
                                    }
                                }

                                // Chapter list for this series
                                Column {
                                    id: chaptersList
                                    visible: parent.expanded
                                    width: parent.width
                                    y: seriesHeader.height + 4
                                    spacing: 2

                                    Repeater {
                                        model: modelData.chapters || []
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 44
                                            color: "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    CustomText {
                                                        content: "Ch. " + (modelData.chapterNum || "?")
                                                        size: 12
                                                        color: Colors.primary
                                                    }
                                                    CustomText {
                                                        content: modelData.title || ""
                                                        size: 11
                                                        color: Colors.outline
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                // Read offline button
                                                Rectangle {
                                                    height: 28
                                                    width: 28
                                                    radius: 8
                                                    color: Colors.primary

                                                    MaterialIconSymbol {
                                                        anchors.centerIn: parent
                                                        content: "play_arrow"
                                                        iconSize: 16
                                                        color: Colors.primaryText
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.offlineMode = true
                                                            ServiceManga.fetchOfflineChapterPages(modelData.chapterId)
                                                            root.viewState = "reader"
                                                        }
                                                    }
                                                }

                                                // Delete button
                                                Rectangle {
                                                    height: 28
                                                    width: 28
                                                    radius: 8
                                                    color: Colors.surfaceContainerHigh

                                                    MaterialIconSymbol {
                                                        anchors.centerIn: parent
                                                        content: "delete"
                                                        iconSize: 16
                                                        color: Colors.outline
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: ServiceManga.deleteDownload(modelData.chapterId)
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: parent.width - 24
                                                x: 12
                                                height: 1
                                                color: Colors.outline
                                                opacity: 0.15
                                            }
                                        }
                                    }
                                }

                                Behavior on height { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.viewState === "offline" && ServiceManga.downloadsList.length === 0

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: "download"
                        iconSize: 36
                        color: Colors.outline
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: "No downloads yet"
                        size: 13
                        color: Colors.outline
                    }
                }

                // ── DETAIL view ──────────────────────────────────────────────
                Flickable {
                    id: detailFlick
                    visible: root.viewState === "detail"
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: detailCol.implicitHeight + 12

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: detailCol
                        width: detailFlick.width - 8
                        x: 4
                        y: 4
                        spacing: 10

                        // Loading / error state
                        Column {
                            visible: ServiceManga.isFetchingDetail || ServiceManga.currentManga === null
                            width: parent.width
                            spacing: 10
                            topPadding: 40

                            MaterialIconSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: "hourglass_top"
                                iconSize: 36
                                color: Colors.outline
                                RotationAnimation on rotation {
                                    running: ServiceManga.isFetchingDetail
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 1200
                                }
                            }
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: ServiceManga.detailError || "Loading..."
                                size: 13
                                color: Colors.outline
                            }
                        }

                        // Manga info header
                        RowLayout {
                            visible: !ServiceManga.isFetchingDetail && ServiceManga.currentManga !== null
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 160
                                radius: 12
                                clip: true
                                color: Colors.surfaceContainerHigh
                                Image {
                                    id: detailCoverImg
                                    anchors.fill: parent
                                    source: ServiceManga.currentManga ? ServiceManga.currentManga.coverUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                }
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "image"
                                    iconSize: 28
                                    color: Colors.outline
                                    visible: detailCoverImg.status === Image.Loading || detailCoverImg.status === Image.Null
                                    RotationAnimation on rotation {
                                        running: detailCoverImg.status === Image.Loading
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 1000
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                CustomText {
                                    Layout.fillWidth: true
                                    content: ServiceManga.currentManga ? ServiceManga.currentManga.title : ""
                                    size: 15
                                    color: Colors.surfaceText
                                    wrapMode: Text.WordWrap
                                }

                                CustomText {
                                    visible: ServiceManga.currentManga && ServiceManga.currentManga.authors.length > 0
                                    content: ServiceManga.currentManga
                                        ? ServiceManga.currentManga.authors.join(", ")
                                        : ""
                                    size: 11
                                    color: Colors.outline
                                }

                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: statusText.implicitWidth + 12
                                        radius: 6
                                        color: {
                                            const s = ServiceManga.currentManga ? ServiceManga.currentManga.status : ""
                                            if (s === "ongoing")   return Qt.rgba(0.2, 0.7, 0.3, 0.3)
                                            if (s === "completed") return Qt.rgba(0.2, 0.4, 0.9, 0.3)
                                            return Colors.surfaceContainerHigh
                                        }
                                        CustomText {
                                            id: statusText
                                            anchors.centerIn: parent
                                            content: ServiceManga.currentManga ? ServiceManga.currentManga.status : ""
                                            size: 10
                                            color: Colors.surfaceVariantText
                                        }
                                    }
                                }

                                // Action buttons row
                                RowLayout {
                                    spacing: 8

                                    // Read button
                                    Rectangle {
                                        height: 30
                                        width: readRow.implicitWidth + 20
                                        radius: 10
                                        color: Colors.primary

                                        RowLayout {
                                            id: readRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            MaterialIconSymbol {
                                                content: "menu_book"
                                                iconSize: 16
                                                color: Colors.primaryText
                                            }
                                            CustomText {
                                                content: "Read"
                                                size: 13
                                                color: Colors.primaryText
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const chs = ServiceManga.currentManga ? ServiceManga.currentManga.chapters : []
                                                if (chs.length > 0) {
                                                    root.offlineMode = false
                                                    ServiceManga.fetchChapterPages(chs[chs.length - 1].id, ServiceManga.currentManga ? ServiceManga.currentManga.id : "")
                                                    root.viewState = "reader"
                                                }
                                            }
                                        }
                                    }

                                    // Download All button
                                    Rectangle {
                                        id: dlAllBtn
                                        height: 30
                                        width: 30
                                        radius: 10
                                        visible: ServiceManga.currentManga !== null

                                        property bool isBulkActive: ServiceManga.bulkDownload.mangaId !== ""
                                            && ServiceManga.currentManga
                                            && ServiceManga.bulkDownload.mangaId === ServiceManga.currentManga.id

                                        color: isBulkActive ? Colors.surfaceContainerHigh : Colors.surfaceContainerHigh

                                        // Circular progress bar shown during bulk download
                                        CustomCircularLoader {
                                            anchors.centerIn: parent
                                            size: 26
                                            trackWidth: 2.5
                                            highlightColor: Colors.primary
                                            trackColor: Colors.surfaceContainerHigh
                                            visible: parent.isBulkActive
                                            value: ServiceManga.bulkDownloadValue
                                        }

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: "download_for_offline"
                                            iconSize: 16
                                            color: Colors.outline
                                            visible: !parent.isBulkActive
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const m = ServiceManga.currentManga
                                                if (!m || dlAllBtn.isBulkActive) return
                                                ServiceManga.downloadAllChapters(m)
                                            }
                                        }
                                    }

                                    // Bookmark toggle
                                    Rectangle {
                                        height: 30
                                        width: 30
                                        radius: 10
                                        color: ServiceManga.isFavorite(ServiceManga.currentManga ? ServiceManga.currentManga.id : "")
                                               ? Colors.primary : Colors.surfaceContainerHigh

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: ServiceManga.isFavorite(ServiceManga.currentManga ? ServiceManga.currentManga.id : "")
                                                     ? "bookmark" : "bookmark_border"
                                            iconSize: 16
                                            color: ServiceManga.isFavorite(ServiceManga.currentManga ? ServiceManga.currentManga.id : "")
                                                   ? Colors.primaryText : Colors.outline
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const m = ServiceManga.currentManga
                                                if (!m) return
                                                if (ServiceManga.isFavorite(m.id))
                                                    ServiceManga.removeFavorite(m.id)
                                                else
                                                    ServiceManga.addFavorite(m)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Description
                        CustomText {
                            visible: !ServiceManga.isFetchingDetail && ServiceManga.currentManga !== null
                            width: parent.width
                            content: ServiceManga.currentManga ? ServiceManga.currentManga.description : ""
                            size: 12
                            color: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }

                        // Chapter list header
                        RowLayout {
                            visible: !ServiceManga.isFetchingDetail && ServiceManga.currentManga !== null
                            width: parent.width

                            CustomText {
                                content: "Chapters"
                                size: 13
                                color: Colors.surfaceText
                            }
                            CustomText {
                                visible: ((ServiceManga.currentManga ? ServiceManga.currentManga.chapters.length : 0)) > 0
                                content: "(" + ((ServiceManga.currentManga ? ServiceManga.currentManga.chapters.length : 0)) + ")"
                                size: 12
                                color: Colors.outline
                            }
                            Item { Layout.fillWidth: true }
                            MaterialIconSymbol {
                                content: "hourglass_top"
                                iconSize: 16
                                color: Colors.outline
                                visible: ServiceManga.isFetchingDetail
                                RotationAnimation on rotation {
                                    running: ServiceManga.isFetchingDetail
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }
                        }

                        // Chapter list
                        Column {
                            visible: !ServiceManga.isFetchingDetail
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: ScriptModel {
                                    values: ServiceManga.currentManga
                                        ? ServiceManga.currentManga.chapters.reverse()
                                        : []
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    height: 54
                                    radius: 10
                                    color: Colors.surfaceContainerHigh

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                CustomText {
                                                    content: "Ch. " + (modelData.chapter || (index + 1))
                                                    size: 12
                                                    color: Colors.primary
                                                    Layout.preferredWidth: implicitWidth
                                                }

                                                CustomText {
                                                    content: modelData.title || ""
                                                    size: 12
                                                    color: Colors.surfaceText
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            CustomText {
                                                visible: (modelData.publishAt || "").length > 0
                                                content: {
                                                    if (!modelData.publishAt) return ""
                                                    const d = new Date(modelData.publishAt)
                                                    return isNaN(d) ? modelData.publishAt
                                                        : d.toLocaleDateString(Qt.locale(), "MMM d, yyyy")
                                                }
                                                size: 10
                                                color: Colors.outline
                                            }
                                        }

                                        // Download button / progress
                                        Rectangle {
                                            height: 28
                                            width: 28
                                            radius: 8
                                            property var prog: ServiceManga.getDownloadProgress(modelData.id)
                                            property string dlStatus: prog.status || "not_started"
                                            color: dlStatus === "done" ? Qt.rgba(0.2,0.7,0.3,0.3)
                                                 : dlStatus === "error" ? Qt.rgba(0.8,0.2,0.2,0.3)
                                                 : Colors.surfaceContainer

                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                content: {
                                                    const s = parent.dlStatus
                                                    if (s === "done")   return "download_done"
                                                    if (s === "error")  return "error"
                                                    if (s === "downloading" || s === "pending") return "downloading"
                                                    return "download"
                                                }
                                                iconSize: 16
                                                color: parent.dlStatus === "done" ? "#4caf50"
                                                     : parent.dlStatus === "error" ? "#ef5350"
                                                     : Colors.outline
                                                RotationAnimation on rotation {
                                                    running: parent.parent.dlStatus === "downloading" || parent.parent.dlStatus === "pending"
                                                    loops: Animation.Infinite
                                                    from: 0; to: 360; duration: 1000
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const s = parent.dlStatus
                                                    if (s === "downloading" || s === "pending") return
                                                    if (s === "done") {
                                                        ServiceManga.deleteDownload(modelData.id)
                                                        return
                                                    }
                                                    if (ServiceManga.currentManga)
                                                        ServiceManga.startDownload(modelData, ServiceManga.currentManga)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.rightMargin: 40
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.offlineMode = false
                                            ServiceManga.fetchChapterPages(modelData.id, ServiceManga.currentManga ? ServiceManga.currentManga.id : "")
                                            root.viewState = "reader"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── READER view ──────────────────────────────────────────────
                ListView {
                    id: readerList
                    visible: root.viewState === "reader"
                    anchors.fill: parent
                    clip: true
                    spacing: SettingsConfig.manga.pageSpacing
                    maximumFlickVelocity: 4000
                    cacheBuffer: SettingsConfig.manga.preloadPages

                    model: ScriptModel { values: ServiceManga.chapterPages }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    WheelHandler {
                        grabPermissions: WheelHandler.CanTakeOverFromAnything
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const velocity = event.angleDelta.y * SettingsConfig.manga.scrollSpeed
                            if (readerList.verticalOvershoot !== 0.0 ||
                                (velocity > 0 && readerList.verticalVelocity <= 0) ||
                                (velocity < 0 && readerList.verticalVelocity >= 0)) {
                                readerList.flick(0, velocity - readerList.verticalVelocity)
                            } else {
                                readerList.cancelFlick()
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: ServiceManga.isFetchingPages || ServiceManga.chapterPages.length === 0
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: "hourglass_top"
                            iconSize: 36
                            color: Colors.outline
                            RotationAnimation on rotation {
                                running: ServiceManga.isFetchingPages
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: ServiceManga.pagesError || "Loading pages..."
                            size: 13
                            color: Colors.outline
                        }
                    }

                    delegate: Item {
                        required property var modelData
                        width: readerList.width
                        height: pageImg.status === Image.Ready && pageImg.implicitWidth > 0
                        ? Math.round(pageImg.implicitHeight * width / pageImg.implicitWidth)
                        : width * 1.4

                        Image {
                            id: pageImg
                            anchors.fill: parent
                            source: modelData.localPath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: false
                            sourceSize.width: width
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.surfaceContainerHigh
                            visible: pageImg.status !== Image.Ready
                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    content: "hourglass_top"
                                    iconSize: 24
                                    color: Colors.outline
                                    RotationAnimation on rotation {
                                        running: pageImg.status === Image.Loading
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 1000
                                    }
                                }
                                CustomText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    content: "p. " + (modelData.index + 1)
                                    size: 11
                                    color: Colors.outline
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 400
        onTriggered: {
            if (searchInput.text.length > 0)
                ServiceManga.searchManga(searchInput.text, true)
            else
                ServiceManga.fetchByOrigin(ServiceManga.currentOrigin, true)
        }
    }
}
