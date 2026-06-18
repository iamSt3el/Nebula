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
    property bool offlineMode: false

    NumberAnimation on scale   { from: 0.9; to: 1; duration: 200 }
    NumberAnimation on opacity { from: 0;   to: 1; duration: 200 }

    Component.onCompleted: ServiceManga.fetchByOrigin("", true)

    // ── Root card ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 20
        color: Colors.surfaceContainer
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Top bar ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Back button
                Rectangle {
                    visible: root.viewState === "detail" || root.viewState === "reader"
                    implicitWidth: 34; implicitHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol { anchors.centerIn: parent; content: "arrow_back"; iconSize: 20; customColor: Colors.surfaceText }
                    RippleEffect {
                        anchors.fill: parent; radius: 10
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

                // Title / search bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34; radius: 10
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 8

                        MaterialIconSymbol {
                            content: root.searchActive ? "search" : "menu_book"
                            iconSize: 18; customColor: Colors.outline
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            visible: root.viewState === "browse"
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont
                            color: Colors.surfaceText; background: null
                            placeholderText: "Search manga..."
                            placeholderTextColor: Colors.outline
                            onTextChanged: { searchDebounce.restart(); root.searchActive = text.length > 0 }
                            Keys.onReturnPressed: { searchDebounce.stop(); ServiceManga.searchManga(text, true) }
                        }

                        CustomText { visible: root.viewState === "favs";    content: "Favorites"; size: 13; Layout.fillWidth: true }
                        CustomText { visible: root.viewState === "offline"; content: "Downloads"; size: 13; Layout.fillWidth: true }
                        CustomText {
                            visible: root.viewState === "detail" || root.viewState === "reader"
                            content: root.viewState === "reader"
                                ? ("Ch. " + (ServiceManga.currentChapterId || ""))
                                : (ServiceManga.currentManga ? ServiceManga.currentManga.title : "")
                            size: 13; Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }
                }

                // Site selector ButtonGroup (browse / favs)
                ButtonGroup {
                    visible: root.viewState === "browse" || root.viewState === "favs"
                    height: 30
                    model: [
                        { value: "weebcentral", label: "Weeb"  },
                        { value: "comix",       label: "Comix" }
                    ]
                    activeCheck: function(v) { return ServiceManga.currentSite === v }
                    textSize: 11
                    onSegmentClicked: function(v) { ServiceManga.switchSite(v) }
                }

                // Refresh button (not in reader)
                Rectangle {
                    visible: root.viewState !== "reader"
                    implicitWidth: 34; implicitHeight: 34; radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol {
                        anchors.centerIn: parent; content: "refresh"; iconSize: 18; customColor: Colors.outline
                        RotationAnimation on rotation {
                            running: ServiceManga.isFetchingManga || ServiceManga.isFetchingFavs || ServiceManga.isFetchingDetail
                            loops: Animation.Infinite; from: 0; to: 360; duration: 900
                        }
                    }
                    RippleEffect {
                        anchors.fill: parent; radius: 10
                        onClicked: {
                            if (root.viewState === "favs") {
                                ServiceManga.checkFavoritesForUpdates(); ServiceManga.fetchFavorites()
                            } else if (root.viewState === "offline") {
                                ServiceManga.fetchDownloads()
                            } else if (root.viewState === "detail" && ServiceManga.currentManga) {
                                ServiceManga.fetchMangaDetail(ServiceManga.currentManga.id)
                            } else if (searchInput.text.length > 0) {
                                ServiceManga.searchManga(searchInput.text, true)
                            } else {
                                ServiceManga.fetchByOrigin(ServiceManga.currentOrigin, true)
                            }
                        }
                    }
                }

                // Reader refresh pages
                Rectangle {
                    visible: root.viewState === "reader"
                    implicitWidth: 34; implicitHeight: 34; radius: 10
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol { anchors.centerIn: parent; content: "refresh"; iconSize: 18; customColor: Colors.outline }
                    RippleEffect {
                        anchors.fill: parent; radius: 10
                        onClicked: root.offlineMode
                            ? ServiceManga.fetchOfflineChapterPages(ServiceManga.currentChapterId)
                            : ServiceManga.refreshChapterPages()
                    }
                }
            }

            // ── Navigation row ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                visible: root.viewState !== "detail" && root.viewState !== "reader"

                // View switcher with Favs badge overlay
                Item {
                    implicitWidth: viewNav.implicitWidth
                    height: 30

                    ButtonGroup {
                        id: viewNav
                        height: 30
                        model: [
                            { value: "browse",  icon: "menu_book", label: "Browse"  },
                            { value: "favs",    icon: "bookmark",  label: "Favs"    },
                            { value: "offline", icon: "download",  label: "Offline" }
                        ]
                        activeCheck: function(v) { return root.viewState === v }
                        textSize: 12; iconSize: 14
                        onSegmentClicked: function(v) {
                            root.viewState = v
                            if (v === "favs")    ServiceManga.fetchFavorites()
                            else if (v === "offline") ServiceManga.fetchDownloads()
                        }
                    }

                    // New-chapters badge on Favs
                    Rectangle {
                        visible: ServiceManga.favNewCount > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: -5; anchors.rightMargin: -5
                        width: Math.max(16, favBadge.implicitWidth + 6); height: 16
                        radius: 8; color: "#e53935"
                        CustomText { id: favBadge; anchors.centerIn: parent; content: ServiceManga.favNewCount; size: 8; customColor: "white" }
                    }
                }

                // Origin chips (browse only)
                Flickable {
                    visible: root.viewState === "browse"
                    Layout.fillWidth: true
                    height: 30
                    contentWidth: originBtns.implicitWidth
                    contentHeight: height
                    clip: true
                    interactive: contentWidth > width

                    ButtonGroup {
                        id: originBtns
                        height: 30
                        model: {
                            const base = [
                                { value: "",       label: "Hot"    },
                                { value: "latest", label: "Latest" }
                            ]
                            const extra = [
                                { value: "ko", label: "Manhwa" },
                                { value: "ja", label: "Manga"  },
                                { value: "zh", label: "Manhua" }
                            ]
                            return ServiceManga.currentSite === "weebcentral" ? base.concat(extra) : base
                        }
                        activeCheck: function(v) {
                            return root.viewState === "browse"
                                && ServiceManga.currentOrigin === v
                                && !root.searchActive
                        }
                        textSize: 12
                        onSegmentClicked: function(v) {
                            root.viewState = "browse"
                            ServiceManga.fetchByOrigin(v, true)
                        }
                    }
                }

                Item { visible: root.viewState !== "browse"; Layout.fillWidth: true }
            }

            // ── Content area ──────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── BROWSE ────────────────────────────────────────────────────
                GridView {
                    id: browseGrid
                    visible: root.viewState === "browse"
                    anchors.fill: parent; clip: true
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
                        width: browseGrid.cellWidth; height: browseGrid.cellHeight
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4
                            radius: 12; color: Colors.surfaceContainerHigh; clip: true
                            Image {
                                id: coverImg; anchors.fill: parent
                                source: modelData.thumbUrl; fillMode: Image.PreserveAspectCrop
                                smooth: true; asynchronous: true
                            }
                            // Shimmer placeholder
                            Rectangle {
                                anchors.fill: parent; radius: 12
                                color: Colors.surfaceContainerHighest
                                visible: coverImg.status !== Image.Ready
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: coverImg.status === Image.Loading
                                    NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            // Title gradient
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 52; radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) }
                                }
                                CustomText {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                                    content: modelData.title; size: 10; color: "white"
                                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                }
                            }
                            RippleEffect {
                                anchors.fill: parent; radius: 12
                                onClicked: {
                                    ServiceManga.clearChapterList()
                                    ServiceManga.fetchMangaDetail(modelData.id)
                                    root.viewState = "detail"
                                }
                            }
                        }
                    }
                }

                // Browse loading / empty
                Loader {
                    anchors.centerIn: parent
                    active: root.viewState === "browse" && ServiceManga.mangaList.length === 0
                    visible: active
                    sourceComponent: Column {
                        spacing: 14
                        CustomLoader {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 44; color: Colors.primary; running: true
                            visible: ServiceManga.isFetchingManga
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: ServiceManga.isFetchingManga ? "Loading..." : (ServiceManga.mangaError || "No results")
                            size: 13; customColor: Colors.outline
                        }
                    }
                }

                // ── FAVS ──────────────────────────────────────────────────────
                GridView {
                    id: favsGrid
                    visible: root.viewState === "favs"
                    anchors.fill: parent; clip: true
                    cellWidth:  Math.floor((width - 8) / 3)
                    cellHeight: Math.floor(cellWidth * 1.45) + 8
                    model: ScriptModel { values: ServiceManga.favoritesList }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Item {
                        required property var modelData
                        width: favsGrid.cellWidth; height: favsGrid.cellHeight
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4
                            radius: 12; color: Colors.surfaceContainerHigh; clip: true
                            Image {
                                id: favCoverImg; anchors.fill: parent
                                source: modelData.image || ""; fillMode: Image.PreserveAspectCrop
                                smooth: true; asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: parent; radius: 12
                                color: Colors.surfaceContainerHighest
                                visible: favCoverImg.status !== Image.Ready
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: favCoverImg.status === Image.Loading
                                    NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            Rectangle {
                                visible: modelData.hasNewChapters || false
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                                height: 18; width: newLbl.implicitWidth + 10; radius: 6; color: "#e53935"
                                CustomText { id: newLbl; anchors.centerIn: parent; content: "NEW"; size: 9; customColor: "white" }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 52; radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) }
                                }
                                CustomText {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                                    content: modelData.title; size: 10; color: "white"
                                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                }
                            }
                            RippleEffect {
                                anchors.fill: parent; radius: 12
                                onClicked: {
                                    ServiceManga.clearChapterList()
                                    ServiceManga.fetchMangaDetail(modelData.id)
                                    root.viewState = "detail"
                                }
                            }
                        }
                    }
                }

                Loader {
                    anchors.centerIn: parent
                    active: root.viewState === "favs" && ServiceManga.favoritesList.length === 0
                    visible: active
                    sourceComponent: Column {
                        spacing: 14
                        CustomLoader {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 44; color: Colors.primary; running: true
                            visible: ServiceManga.isFetchingFavs
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: ServiceManga.isFetchingFavs ? "Loading..." : "No favorites yet"
                            size: 13; customColor: Colors.outline
                        }
                    }
                }

                // ── OFFLINE ───────────────────────────────────────────────────
                Flickable {
                    id: offlineFlick
                    visible: root.viewState === "offline"
                    anchors.fill: parent; clip: true
                    contentWidth: width; contentHeight: offlineCol.implicitHeight + 12
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: offlineCol
                        width: offlineFlick.width - 8; x: 4; y: 4; spacing: 8

                        Repeater {
                            model: ScriptModel { values: ServiceManga.downloadsList }
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: seriesHeader.implicitHeight + (expanded ? chaptersList.implicitHeight + 4 : 0)
                                radius: 12; color: Colors.surfaceContainerHigh; clip: true
                                property bool expanded: false
                                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                Item {
                                    id: seriesHeader
                                    width: parent.width; implicitHeight: 56
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 10; spacing: 10
                                        Image {
                                            Layout.preferredWidth: 40; Layout.preferredHeight: 56
                                            source: modelData.image || ""; fillMode: Image.PreserveAspectCrop
                                            smooth: true; asynchronous: true
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            CustomText { content: modelData.title || ""; size: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                            CustomText {
                                                content: (modelData.chapters ? modelData.chapters.length : 0) + " chapters"
                                                size: 11; customColor: Colors.outline
                                            }
                                        }
                                        MaterialIconSymbol {
                                            content: parent.parent.parent.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                            iconSize: 20; customColor: Colors.outline
                                        }
                                    }
                                    RippleEffect {
                                        anchors.fill: parent; radius: 12
                                        onClicked: parent.parent.expanded = !parent.parent.expanded
                                    }
                                }

                                Column {
                                    id: chaptersList
                                    visible: parent.expanded
                                    width: parent.width
                                    y: seriesHeader.implicitHeight + 4
                                    spacing: 0

                                    Repeater {
                                        model: modelData.chapters || []
                                        delegate: Item {
                                            required property var modelData
                                            width: parent.width; height: 44

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    CustomText { content: "Ch. " + (modelData.chapterNum || "?"); size: 12; customColor: Colors.primary }
                                                    CustomText { content: modelData.title || ""; size: 11; customColor: Colors.outline; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }

                                                // Play
                                                Rectangle {
                                                    width: 28; height: 28; radius: 8; color: Colors.primary
                                                    MaterialIconSymbol { anchors.centerIn: parent; content: "play_arrow"; iconSize: 16; customColor: Colors.primaryText }
                                                    RippleEffect {
                                                        anchors.fill: parent; radius: 8
                                                        hoverColor: Qt.alpha(Colors.primaryText, 0.12)
                                                        rippleColor: Qt.alpha(Colors.primaryText, 0.25)
                                                        onClicked: {
                                                            root.offlineMode = true
                                                            ServiceManga.fetchOfflineChapterPages(modelData.chapterId)
                                                            root.viewState = "reader"
                                                        }
                                                    }
                                                }

                                                // Delete
                                                Rectangle {
                                                    width: 28; height: 28; radius: 8; color: Colors.surfaceContainerHighest
                                                    MaterialIconSymbol { anchors.centerIn: parent; content: "delete_outline"; iconSize: 16; customColor: Colors.outline }
                                                    RippleEffect {
                                                        anchors.fill: parent; radius: 8
                                                        hoverColor: Qt.alpha(Colors.error, 0.12); rippleColor: Qt.alpha(Colors.error, 0.2)
                                                        onClicked: ServiceManga.deleteDownload(modelData.chapterId)
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.bottom: parent.bottom; width: parent.width - 24; x: 12
                                                height: 1; color: Colors.outline; opacity: 0.1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    anchors.centerIn: parent
                    active: root.viewState === "offline" && ServiceManga.downloadsList.length === 0
                    visible: active
                    sourceComponent: Column {
                        spacing: 10
                        MaterialIconSymbol { anchors.horizontalCenter: parent.horizontalCenter; content: "download"; iconSize: 36; customColor: Colors.outline }
                        CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: "No downloads yet"; size: 13; customColor: Colors.outline }
                    }
                }

                // ── DETAIL ────────────────────────────────────────────────────
                Flickable {
                    id: detailFlick
                    visible: root.viewState === "detail"
                    anchors.fill: parent; clip: true
                    contentWidth: width; contentHeight: detailCol.implicitHeight + 12
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: detailCol
                        width: detailFlick.width - 8; x: 4; y: 4; spacing: 10

                        // Loading state
                        Loader {
                            width: parent.width
                            active: ServiceManga.isFetchingDetail || ServiceManga.currentManga === null
                            visible: active
                            sourceComponent: Item {
                                width: parent.width; height: 140
                                Column {
                                    anchors.centerIn: parent; spacing: 12
                                    CustomLoader {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        size: 44; color: Colors.primary; running: true
                                        visible: ServiceManga.isFetchingDetail
                                    }
                                    CustomText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        content: ServiceManga.isFetchingDetail ? "Loading..." : (ServiceManga.detailError || "")
                                        size: 13; customColor: Colors.outline
                                    }
                                }
                            }
                        }

                        // Manga info header
                        RowLayout {
                            visible: !ServiceManga.isFetchingDetail && ServiceManga.currentManga !== null
                            width: parent.width; spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 110; Layout.preferredHeight: 160
                                radius: 12; clip: true; color: Colors.surfaceContainerHigh
                                Image {
                                    id: detailCoverImg; anchors.fill: parent
                                    source: ServiceManga.currentManga ? ServiceManga.currentManga.coverUrl : ""
                                    fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                                }
                                Rectangle {
                                    anchors.fill: parent; radius: 12; color: Colors.surfaceContainerHighest
                                    visible: detailCoverImg.status !== Image.Ready
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite; running: detailCoverImg.status === Image.Loading
                                        NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 8

                                CustomText {
                                    Layout.fillWidth: true
                                    content: ServiceManga.currentManga ? ServiceManga.currentManga.title : ""
                                    size: 15; wrapMode: Text.WordWrap
                                }
                                CustomText {
                                    visible: ServiceManga.currentManga && ServiceManga.currentManga.authors.length > 0
                                    content: ServiceManga.currentManga ? ServiceManga.currentManga.authors.join(", ") : ""
                                    size: 11; customColor: Colors.outline
                                }

                                // Status badge
                                Rectangle {
                                    implicitHeight: 22; implicitWidth: statusTxt.implicitWidth + 14; radius: 8
                                    color: {
                                        const s = ServiceManga.currentManga ? ServiceManga.currentManga.status : ""
                                        if (s === "ongoing")   return Qt.rgba(0.2, 0.7, 0.3, 0.25)
                                        if (s === "completed") return Qt.rgba(0.2, 0.4, 0.9, 0.25)
                                        return Colors.surfaceContainerHighest
                                    }
                                    CustomText { id: statusTxt; anchors.centerIn: parent; content: ServiceManga.currentManga ? ServiceManga.currentManga.status : ""; size: 10 }
                                }

                                // Action row
                                RowLayout { spacing: 8

                                    // Read
                                    Rectangle {
                                        height: 32; implicitWidth: readRow.implicitWidth + 22
                                        radius: 10; color: Colors.primary
                                        Row { id: readRow; anchors.centerIn: parent; spacing: 6
                                            MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: "menu_book"; iconSize: 16; customColor: Colors.primaryText }
                                            CustomText { anchors.verticalCenter: parent.verticalCenter; content: "Read"; size: 13; customColor: Colors.primaryText }
                                        }
                                        RippleEffect {
                                            anchors.fill: parent; radius: 10
                                            hoverColor: Qt.alpha(Colors.primaryText, 0.1); rippleColor: Qt.alpha(Colors.primaryText, 0.2)
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

                                    // Download All — circular progress arc (no sperm animation)
                                    Item {
                                        id: dlAllBtn
                                        width: 32; height: 32
                                        visible: ServiceManga.currentManga !== null
                                        property bool isBulkActive: ServiceManga.bulkDownload.mangaId !== ""
                                            && ServiceManga.currentManga
                                            && ServiceManga.bulkDownload.mangaId === ServiceManga.currentManga.id

                                        Rectangle {
                                            anchors.fill: parent; radius: 10
                                            color: dlAllBtn.isBulkActive
                                                ? Qt.alpha(Colors.primary, 0.12)
                                                : Colors.surfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        CustomCircularProgressBar {
                                            anchors.centerIn: parent; width: 22; height: 22
                                            visible: dlAllBtn.isBulkActive
                                            progress: ServiceManga.bulkDownloadValue >= 0 ? ServiceManga.bulkDownloadValue : 0
                                            thickness: 2.5; showText: false
                                            baseColor: Colors.surfaceContainerHighest
                                            lineColor: Colors.primary
                                        }

                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: "download_for_offline"; iconSize: 16; customColor: Colors.outline
                                            visible: !dlAllBtn.isBulkActive
                                        }

                                        RippleEffect {
                                            anchors.fill: parent; radius: 10
                                            onClicked: {
                                                const m = ServiceManga.currentManga
                                                if (!m || dlAllBtn.isBulkActive) return
                                                ServiceManga.downloadAllChapters(m)
                                            }
                                        }
                                    }

                                    // Bookmark toggle
                                    Rectangle {
                                        width: 32; height: 32; radius: 10
                                        color: ServiceManga.isFavorite(ServiceManga.currentManga?.id || "")
                                            ? Qt.alpha(Colors.primary, 0.15) : Colors.surfaceContainerHigh
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        MaterialIconSymbol {
                                            anchors.centerIn: parent
                                            content: ServiceManga.isFavorite(ServiceManga.currentManga?.id || "") ? "bookmark" : "bookmark_border"
                                            iconSize: 16
                                            customColor: ServiceManga.isFavorite(ServiceManga.currentManga?.id || "") ? Colors.primary : Colors.outline
                                        }
                                        RippleEffect {
                                            anchors.fill: parent; radius: 10
                                            onClicked: {
                                                const m = ServiceManga.currentManga
                                                if (!m) return
                                                if (ServiceManga.isFavorite(m.id)) ServiceManga.removeFavorite(m.id)
                                                else ServiceManga.addFavorite(m)
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
                            size: 12; customColor: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap; maximumLineCount: 5; elide: Text.ElideRight
                        }

                        // Chapters header
                        RowLayout {
                            visible: !ServiceManga.isFetchingDetail && ServiceManga.currentManga !== null
                            width: parent.width
                            CustomText { content: "Chapters"; size: 13 }
                            CustomText {
                                visible: (ServiceManga.currentManga?.chapters.length ?? 0) > 0
                                content: "(" + (ServiceManga.currentManga?.chapters.length ?? 0) + ")"
                                size: 12; customColor: Colors.outline
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // Chapter list
                        Column {
                            visible: !ServiceManga.isFetchingDetail
                            width: parent.width; spacing: 4

                            Repeater {
                                model: ScriptModel {
                                    values: ServiceManga.currentManga
                                        ? ServiceManga.currentManga.chapters.reverse()
                                        : []
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: parent.width; height: 54; radius: 10
                                    color: Colors.surfaceContainerHigh

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 6

                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 8
                                                CustomText {
                                                    content: "Ch. " + (modelData.chapter || (index + 1))
                                                    size: 12; customColor: Colors.primary
                                                    Layout.preferredWidth: implicitWidth
                                                }
                                                CustomText { content: modelData.title || ""; size: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            CustomText {
                                                visible: (modelData.publishAt || "").length > 0
                                                content: {
                                                    if (!modelData.publishAt) return ""
                                                    const d = new Date(modelData.publishAt)
                                                    return isNaN(d) ? modelData.publishAt : d.toLocaleDateString(Qt.locale(), "MMM d, yyyy")
                                                }
                                                size: 10; customColor: Colors.outline
                                            }
                                        }

                                        // Download indicator — circular progress arc, no sperm
                                        Item {
                                            id: dlBtn
                                            width: 32; height: 32
                                            property var prog: ServiceManga.getDownloadProgress(modelData.id)
                                            property string dlStatus: prog.status || "not_started"
                                            property real dlFraction: (prog.total > 0) ? (prog.done / prog.total) : 0

                                            Rectangle {
                                                anchors.fill: parent; radius: 10
                                                color: dlBtn.dlStatus === "done"  ? Qt.alpha(Colors.primary, 0.13)
                                                     : dlBtn.dlStatus === "error" ? Qt.alpha(Colors.error, 0.13)
                                                     : Colors.surfaceContainer
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            // Arc progress (downloading / pending)
                                            CustomCircularProgressBar {
                                                anchors.centerIn: parent; width: 22; height: 22
                                                visible: dlBtn.dlStatus === "downloading" || dlBtn.dlStatus === "pending"
                                                progress: dlBtn.dlFraction
                                                thickness: 2.5; showText: false
                                                baseColor: Colors.surfaceContainerHighest
                                                lineColor: Colors.primary
                                            }

                                            // Icon (idle states)
                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                visible: dlBtn.dlStatus !== "downloading" && dlBtn.dlStatus !== "pending"
                                                content: dlBtn.dlStatus === "done"  ? "check"
                                                       : dlBtn.dlStatus === "error" ? "error_outline"
                                                       : "download"
                                                iconSize: 15
                                                customColor: dlBtn.dlStatus === "done"  ? Colors.primary
                                                           : dlBtn.dlStatus === "error" ? Colors.error
                                                           : Colors.outline
                                            }

                                            RippleEffect {
                                                anchors.fill: parent; radius: 10
                                                onClicked: {
                                                    const s = dlBtn.dlStatus
                                                    if (s === "downloading" || s === "pending") return
                                                    if (s === "done") { ServiceManga.deleteDownload(modelData.id); return }
                                                    if (ServiceManga.currentManga) ServiceManga.startDownload(modelData, ServiceManga.currentManga)
                                                }
                                            }
                                        }
                                    }

                                    // Row tap → open reader
                                    RippleEffect {
                                        anchors.fill: parent; anchors.rightMargin: 44
                                        topLeftRadius: 10; topRightRadius: 0; bottomLeftRadius: 10; bottomRightRadius: 0
                                        hoverColor: Qt.alpha(Colors.primary, 0.06); rippleColor: Qt.alpha(Colors.primary, 0.12)
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

                // ── READER ────────────────────────────────────────────────────
                Item {
                    visible: root.viewState === "reader"
                    anchors.fill: parent

                    ListView {
                        id: readerList
                        anchors.fill: parent; clip: true
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

                        delegate: Item {
                            required property var modelData
                            width: readerList.width
                            height: pageImg.status === Image.Ready && pageImg.implicitWidth > 0
                                ? Math.round(pageImg.implicitHeight * width / pageImg.implicitWidth)
                                : width * 1.4

                            Image {
                                id: pageImg; anchors.fill: parent
                                source: modelData.localPath; fillMode: Image.PreserveAspectFit
                                smooth: true; asynchronous: true; cache: false
                                sourceSize.width: width
                            }

                            // Shimmer placeholder
                            Rectangle {
                                anchors.fill: parent; radius: 4; color: Colors.surfaceContainerHigh
                                visible: pageImg.status !== Image.Ready
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: pageImg.status === Image.Loading
                                    NumberAnimation { to: 0.5; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                                CustomText {
                                    anchors.centerIn: parent
                                    content: "p. " + (modelData.index + 1); size: 11; customColor: Colors.outline
                                }
                            }
                        }
                    }

                    // Pages loading overlay
                    Loader {
                        anchors.centerIn: parent
                        active: ServiceManga.isFetchingPages || ServiceManga.chapterPages.length === 0
                        visible: active
                        sourceComponent: Column {
                            spacing: 14
                            CustomLoader {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 44; color: Colors.primary; running: true
                                visible: ServiceManga.isFetchingPages
                            }
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: ServiceManga.isFetchingPages ? "Loading pages..." : (ServiceManga.pagesError || "No pages found")
                                size: 13; customColor: Colors.outline
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: searchDebounce; interval: 400
        onTriggered: {
            if (searchInput.text.length > 0) ServiceManga.searchManga(searchInput.text, true)
            else ServiceManga.fetchByOrigin(ServiceManga.currentOrigin, true)
        }
    }
}
