import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: lib

    signal closeRequested

    property string page: "home"
    readonly property bool searching: ServiceBooks.query !== ""
    readonly property var lead: ServiceBooks.reading[0] ?? null
    readonly property var others: ServiceBooks.reading.slice(1, 4)

    Component.onCompleted: {
        if (ServiceBooks.popular.length === 0)
            ServiceBooks.loadMorePopular()
        if (ServiceBooks.asura.length === 0)
            ServiceBooks.loadMoreAsura()
        if (!ServiceBooks.localScanned)
            ServiceBooks.scanLocal()
    }

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    component NavItem: Rectangle {
        id: nav
        property string icon: ""
        property string label: ""
        property string key: ""
        property string count: ""
        readonly property bool on: lib.page === nav.key && !lib.searching
        Layout.fillWidth: true
        implicitHeight: 44
        radius: navArea.pressed ? 14 : 22
        color: nav.on ? Colors.primaryContainer : navArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
        Behavior on color { EffectsColorAnim { speed: "fast" } }
        Behavior on radius { SpatialAnim { speed: "fast" } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12
            MaterialIconSymbol {
                content: nav.icon
                iconSize: 20
                fill: nav.on ? 1 : 0
                customColor: nav.on ? Colors.primaryContainerText : Colors.surfaceText
            }
            CustomText {
                Layout.fillWidth: true
                content: nav.label
                size: 14
                weight: nav.on ? 600 : 400
                customColor: nav.on ? Colors.primaryContainerText : Colors.surfaceText
            }
            CustomText {
                visible: nav.count !== ""
                content: nav.count
                size: 12
                customColor: nav.on ? Colors.primaryContainerText : Colors.surfaceVariantText
            }
        }
        MouseArea {
            id: navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                searchInput.text = ""
                lib.page = nav.key
                body.contentY = 0
            }
        }
    }

    component Heading: RowLayout {
        id: hd
        property string title: ""
        property string sub: ""
        property string link: ""
        signal linkClicked
        Layout.fillWidth: true
        spacing: 12
        CustomText { content: hd.title; size: 18; weight: 600 }
        CustomText { Layout.fillWidth: true; content: hd.sub; size: 13; elide: Text.ElideRight; customColor: Colors.surfaceVariantText }
        CustomText {
            visible: hd.link !== ""
            content: hd.link
            size: 13
            customColor: Colors.primary
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: hd.linkClicked()
            }
        }
    }

    component Grid7: Item {
        id: grid
        property var items: []
        property bool showProgress: false
        property bool removable: false
        property int limit: -1
        readonly property real gap: 18
        readonly property int cols: Math.max(3, Math.floor((grid.width + grid.gap) / (150 + grid.gap)))
        readonly property real tileW: (grid.width - (grid.cols - 1) * grid.gap) / grid.cols
        readonly property var shown: grid.limit > 0 ? grid.items.slice(0, grid.limit) : grid.items
        Layout.fillWidth: true
        implicitHeight: flow.implicitHeight

        Flow {
            id: flow
            width: grid.width
            spacing: grid.gap

            Repeater {
                model: grid.shown
                delegate: Item {
                    id: tile
                    required property var modelData
                    readonly property var e: ServiceBooks.entry(ServiceBooks.keyOf(tile.modelData))
                    width: grid.tileW
                    height: coverBox.height + 62

                    Item {
                        id: coverBox
                        width: parent.width
                        height: Math.round(width * 1.5)
                        scale: 1
                        BookCover {
                            anchors.fill: parent
                            anchors.margins: tileArea.containsMouse ? -3 : 0
                            Behavior on anchors.margins { SpatialAnim { speed: "fast" } }
                            source: tile.modelData.cover ?? ""
                            title: tile.modelData.title ?? ""
                            author: tile.modelData.author ?? ""
                        }
                        Rectangle {
                            visible: !!tile.e && (tile.e.progress ?? 0) > 0 && !grid.showProgress
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: badge.implicitWidth + 14
                            height: 22
                            radius: 11
                            color: Colors.primary
                            CustomText {
                                id: badge
                                anchors.centerIn: parent
                                content: tile.e ? Math.round((tile.e.progress ?? 0) * 100) + "%" : ""
                                size: 11
                                weight: 600
                                customColor: Colors.primaryText
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.top: coverBox.bottom
                        anchors.topMargin: 10
                        width: parent.width
                        spacing: 4
                        CustomText {
                            Layout.fillWidth: true
                            content: tile.modelData.title ?? ""
                            elide: Text.ElideRight
                            size: 13
                            weight: 500
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: tile.modelData.author || "Unknown author"
                            elide: Text.ElideRight
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }
                        Rectangle {
                            visible: grid.showProgress
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            implicitHeight: 4
                            radius: 2
                            color: Colors.surfaceContainerHighest
                            Rectangle {
                                width: parent.width * Math.max(0.02, tile.e ? (tile.e.progress ?? 0) : 0)
                                height: parent.height
                                radius: 2
                                color: Colors.primary
                            }
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: ServiceBooks.open(tile.modelData)
                    }

                    M3IconButton {
                        visible: grid.removable && tileArea.containsMouse
                        anchors.right: coverBox.right
                        anchors.top: coverBox.top
                        anchors.margins: 6
                        icon: "close"
                        tip: "Remove from your shelf"
                        onClicked: ServiceBooks.forget(tile.modelData.key)
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.surface
    }

    Rectangle {
        id: rail
        width: 240
        height: parent.height
        color: Colors.surfaceContainerLow

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 22
            spacing: 4

            RowLayout {
                Layout.leftMargin: 10
                Layout.bottomMargin: 18
                spacing: 10
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 14
                    color: Colors.primary
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "menu_book"
                        iconSize: 22
                        fill: 1
                        customColor: Colors.primaryText
                    }
                }
                Text {
                    text: "Reading"
                    font.family: "Titan One"
                    font.pixelSize: 22
                    color: Colors.surfaceText
                }
            }

            NavItem { icon: "home"; label: "Home"; key: "home" }
            NavItem { icon: "shelves"; label: "My shelf"; key: "shelf"; count: ServiceBooks.shelf.length > 0 ? String(ServiceBooks.shelf.length) : "" }
            NavItem { icon: "explore"; label: "Project Gutenberg"; key: "discover" }
            NavItem { icon: "auto_stories"; label: "Fantasy Novels"; key: "asura" }
            NavItem { icon: "folder_open"; label: "On this computer"; key: "local"; count: ServiceBooks.local.length > 0 ? String(ServiceBooks.local.length) : "" }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: eye.implicitHeight + 28
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: eye
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        MaterialIconSymbol { content: "visibility"; iconSize: 20; customColor: Colors.tertiary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Eye comfort"; size: 13; weight: 600 }
                            CustomText {
                                Layout.fillWidth: true
                                content: (ServiceBooks.cfg.eyeComfort ?? true) ? ServiceReading.filterName + " while reading" : "Off while reading"
                                elide: Text.ElideRight
                                size: 11
                                customColor: Colors.surfaceVariantText
                            }
                        }
                        CustomToogle {
                            isToggleOn: ServiceBooks.cfg.eyeComfort ?? true
                            onToggled: state => ServiceBooks.setCfg({ eyeComfort: state })
                        }
                    }
                    M3ButtonGroup {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        height: 30
                        fillWidth: true
                        textSize: 11
                        model: [{ value: "warm", label: "Warm" }, { value: "sepia", label: "Sepia" }, { value: "eink", label: "E-ink" }]
                        activeCheck: v => (ServiceBooks.cfg.eyeComfort ?? true) && ServiceReading.filter === v
                        onSegmentClicked: v => {
                            ServiceBooks.setCfg({ eyeComfort: true })
                            ServiceReading._set({ filter: v })
                        }
                    }
                }
            }
        }
    }

    Item {
        id: main
        x: rail.width
        width: parent.width - rail.width
        height: parent.height

        RowLayout {
            id: top
            x: 36
            y: 22
            width: parent.width - 72
            height: 52
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 26
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 14
                    spacing: 12
                    MaterialIconSymbol { content: "search"; iconSize: 20; customColor: Colors.surfaceVariantText }
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        clip: true
                        font.family: "Rubik"
                        font.pixelSize: 15
                        color: Colors.surfaceText
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.primaryText
                        onTextChanged: ServiceBooks.search(text, lib.page === "asura" ? "asura" : "gutenberg")
                        Keys.onEscapePressed: event => {
                            if (searchInput.text !== "") {
                                searchInput.text = ""
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            content: lib.page === "asura" ? "Search Fantasy Novels by title or author" : "Search Project Gutenberg by title, author or subject"
                            size: 15
                            customColor: Colors.surfaceVariantText
                        }
                    }
                    CustomCircularLoader {
                        visible: ServiceBooks.searching
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                    }
                    M3IconButton {
                        visible: searchInput.text !== ""
                        icon: "close"
                        tip: "Clear search"
                        onClicked: searchInput.text = ""
                    }
                }
            }

            M3IconButton {
                icon: "close"
                tip: "Close reading mode · Esc"
                onClicked: lib.closeRequested()
            }
        }

        SmoothFlickable {
            id: body
            x: 36
            y: top.y + top.height + 22
            width: parent.width - 72
            height: parent.height - y
            contentWidth: width
            contentHeight: pageCol.implicitHeight + 40
            clip: true

            ColumnLayout {
                id: pageCol
                width: body.width
                spacing: 26

                ColumnLayout {
                    visible: lib.searching
                    Layout.fillWidth: true
                    spacing: 14
                    Heading {
                        title: "Results"
                        sub: ServiceBooks.searching ? "Searching " + (ServiceBooks.searchSource === "asura" ? "Fantasy Novels" : "Project Gutenberg") + "…" : ServiceBooks.results.length + " books for “" + ServiceBooks.query + "”"
                    }
                    Grid7 { items: ServiceBooks.results }
                    CustomText {
                        visible: !ServiceBooks.searching && ServiceBooks.results.length === 0
                        content: "Nothing found. Try an author's surname or a shorter title."
                        size: 14
                        customColor: Colors.surfaceVariantText
                    }
                }

                Rectangle {
                    visible: !lib.searching && lib.page === "home" && lib.lead !== null
                    Layout.fillWidth: true
                    implicitHeight: 260
                    radius: 28
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 22

                        BookCover {
                            Layout.preferredWidth: 144
                            Layout.preferredHeight: 216
                            source: lib.lead ? lib.lead.cover : ""
                            title: lib.lead ? lib.lead.title : ""
                            author: lib.lead ? lib.lead.author : ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10
                            CustomText { content: "Continue reading"; size: 13; weight: 500; customColor: Colors.primary }
                            Text {
                                Layout.fillWidth: true
                                text: lib.lead ? lib.lead.title : ""
                                elide: Text.ElideRight
                                font.family: "Literata"
                                font.weight: Font.DemiBold
                                font.pixelSize: 32
                                color: Colors.surfaceText
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: lib.lead ? (lib.lead.author || "Unknown author") + " · chapter " + ((lib.lead.chapter ?? 0) + 1) + " of " + (lib.lead.chapters ?? "?") : ""
                                elide: Text.ElideRight
                                size: 14
                                customColor: Colors.surfaceVariantText
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 12
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 8
                                    radius: 4
                                    color: Colors.surfaceContainerHighest
                                    Rectangle {
                                        width: parent.width * Math.max(0.02, lib.lead ? (lib.lead.progress ?? 0) : 0)
                                        height: parent.height
                                        radius: 4
                                        color: Colors.primary
                                    }
                                }
                                CustomText { content: lib.lead ? Math.round((lib.lead.progress ?? 0) * 100) + "%" : ""; size: 13 }
                            }
                            Item { Layout.fillHeight: true }
                            RowLayout {
                                spacing: 10
                                M3Button {
                                    size: "medium"
                                    icon: "auto_stories"
                                    label: "Continue"
                                    onClicked: if (lib.lead) ServiceBooks.open(lib.lead)
                                }
                                M3Button {
                                    size: "medium"
                                    variant: "tonal"
                                    icon: "shelves"
                                    label: "My shelf"
                                    onClicked: lib.page = "shelf"
                                }
                            }
                        }

                        ColumnLayout {
                            visible: lib.others.length > 0
                            Layout.preferredWidth: 290
                            Layout.fillHeight: true
                            spacing: 12
                            CustomText { content: "Also in progress"; size: 13; customColor: Colors.surfaceVariantText }
                            Repeater {
                                model: lib.others
                                delegate: Item {
                                    id: other
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 64
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 12
                                        BookCover {
                                            Layout.preferredWidth: 42
                                            Layout.preferredHeight: 63
                                            radius: 6
                                            source: other.modelData.cover ?? ""
                                            title: other.modelData.title ?? ""
                                            author: other.modelData.author ?? ""
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            CustomText { Layout.fillWidth: true; content: other.modelData.title; elide: Text.ElideRight; size: 13; weight: 600 }
                                            CustomText {
                                                Layout.fillWidth: true
                                                content: (other.modelData.author || "Unknown") + " · " + Math.round((other.modelData.progress ?? 0) * 100) + "%"
                                                elide: Text.ElideRight
                                                size: 12
                                                customColor: Colors.surfaceVariantText
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 4
                                                radius: 2
                                                color: Colors.surfaceContainerHighest
                                                Rectangle {
                                                    width: parent.width * Math.max(0.02, other.modelData.progress ?? 0)
                                                    height: parent.height
                                                    radius: 2
                                                    color: Colors.primary
                                                }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ServiceBooks.open(other.modelData)
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                Rectangle {
                    visible: !lib.searching && lib.page === "home" && lib.lead === null
                    Layout.fillWidth: true
                    implicitHeight: 140
                    radius: 28
                    color: Colors.surfaceContainer
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 26
                        spacing: 18
                        MaterialIconSymbol { content: "auto_stories"; iconSize: 40; customColor: Colors.primary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            CustomText { content: "Pick a book to start"; size: 20; weight: 600 }
                            CustomText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                content: "Every book below is free and in the public domain. It downloads the first time you open it, then stays on your shelf for offline reading."
                                size: 13
                                customColor: Colors.surfaceVariantText
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: !lib.searching && (lib.page === "home" || lib.page === "discover")
                    Layout.fillWidth: true
                    spacing: 14
                    Heading {
                        title: "Popular on Project Gutenberg"
                        sub: "Free, public domain · downloads when you open one"
                        link: lib.page === "home" ? "See all" : ""
                        onLinkClicked: lib.page = "discover"
                    }
                    Grid7 {
                        items: ServiceBooks.popular
                        limit: lib.page === "home" ? Math.max(7, cols * 2) : -1
                    }
                    RowLayout {
                        visible: lib.page === "discover"
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        CustomCircularLoader {
                            visible: ServiceBooks.popularLoading
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                        }
                        M3Button {
                            visible: ServiceBooks.popularMore && !ServiceBooks.popularLoading
                            variant: "tonal"
                            size: "medium"
                            icon: "expand_more"
                            label: "Load more"
                            onClicked: ServiceBooks.loadMorePopular()
                        }
                    }
                }

                ColumnLayout {
                    visible: !lib.searching && (lib.page === "home" || lib.page === "asura")
                    Layout.fillWidth: true
                    spacing: 14
                    Heading {
                        title: "Popular fantasy novels"
                        sub: "Web novels · free chapters only, downloads when you open one"
                        link: lib.page === "home" ? "See all" : ""
                        onLinkClicked: lib.page = "asura"
                    }
                    Grid7 {
                        items: ServiceBooks.asura
                        limit: lib.page === "home" ? Math.max(7, cols * 2) : -1
                    }
                    RowLayout {
                        visible: lib.page === "asura"
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        CustomCircularLoader {
                            visible: ServiceBooks.asuraLoading
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                        }
                        M3Button {
                            visible: ServiceBooks.asuraMore && !ServiceBooks.asuraLoading
                            variant: "tonal"
                            size: "medium"
                            icon: "expand_more"
                            label: "Load more"
                            onClicked: ServiceBooks.loadMoreAsura()
                        }
                    }
                }

                ColumnLayout {
                    visible: !lib.searching && (lib.page === "shelf" || (lib.page === "home" && ServiceBooks.shelf.length > 0))
                    Layout.fillWidth: true
                    spacing: 14
                    Heading {
                        title: "My shelf"
                        sub: ServiceBooks.shelf.length + (ServiceBooks.shelf.length === 1 ? " book" : " books") + " · kept for offline reading"
                        link: lib.page === "home" ? "Open shelf" : ""
                        onLinkClicked: lib.page = "shelf"
                    }
                    Grid7 {
                        items: ServiceBooks.recent
                        showProgress: true
                        removable: lib.page === "shelf"
                        limit: lib.page === "home" ? cols : -1
                    }
                    CustomText {
                        visible: ServiceBooks.shelf.length === 0
                        content: "Books you open land here."
                        size: 14
                        customColor: Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    visible: !lib.searching && lib.page === "local"
                    Layout.fillWidth: true
                    spacing: 14
                    Heading {
                        title: "On this computer"
                        sub: "EPUB files in ~/Books"
                        link: "Scan again"
                        onLinkClicked: ServiceBooks.scanLocal()
                    }
                    Grid7 { items: ServiceBooks.local }
                    Rectangle {
                        visible: ServiceBooks.localScanned && ServiceBooks.local.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 120
                        radius: 24
                        color: Colors.surfaceContainer
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 16
                            MaterialIconSymbol { content: "folder_open"; iconSize: 34; customColor: Colors.primary }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                CustomText { content: "No EPUB files yet"; size: 16; weight: 600 }
                                CustomText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    content: "Put .epub files in ~/Books, then scan again."
                                    size: 13
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                            M3Button {
                                variant: "tonal"
                                icon: "create_new_folder"
                                label: "Open ~/Books"
                                onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/Books\" && xdg-open \"$HOME/Books\""])
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: ServiceBooks.opening
        color: Qt.alpha(Colors.scrim, 0.5)
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: 120
            radius: 28
            color: Colors.surfaceContainerHigh
            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 18
                CustomCircularLoader {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    CustomText {
                        Layout.fillWidth: true
                        content: "Opening " + (ServiceBooks.openItem ? ServiceBooks.openItem.title : "")
                        elide: Text.ElideRight
                        size: 15
                        weight: 600
                    }
                    CustomText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        content: ServiceBooks.entry(ServiceBooks.keyOf(ServiceBooks.openItem)) ? "From your shelf" : "Downloading it the first time, then it stays offline"
                        size: 12
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }

    Rectangle {
        visible: ServiceBooks.error !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: errRow.implicitWidth + 32
        height: 48
        radius: 24
        color: Colors.errorContainer
        RowLayout {
            id: errRow
            anchors.centerIn: parent
            spacing: 10
            MaterialIconSymbol { content: "error"; iconSize: 18; customColor: Colors.errorContainerText }
            CustomText { content: ServiceBooks.error; size: 13; customColor: Colors.errorContainerText }
            M3IconButton { icon: "close"; tip: "Dismiss"; onClicked: ServiceBooks.error = "" }
        }
    }
}
