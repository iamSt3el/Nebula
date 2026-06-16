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

    Component.onCompleted: { searchInput.forceActiveFocus() }
    signal closed

    property bool isGrid: SettingsConfig.general.appGrid
    property var appList: isGrid ? gridLoader.item : listLoader.item

    // ── Category filter ───────────────────────────────────────────────────
    property string selectedCategory: "All"

    readonly property var _categoryMap: ({
        "AudioVideo": "Media",   "Audio": "Media",    "Video": "Media",
        "Development": "Dev",    "Education": "Education",
        "Game": "Games",         "Graphics": "Graphics",
        "Network": "Internet",   "Office": "Office",
        "Science": "Science",    "Settings": "Settings",
        "System": "System",      "Utility": "Utilities"
    })

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

    // Applies both search and category filter
    property var filteredApps: {
        var base = ServiceApps.filteredApps
        if (selectedCategory === "All") return base
        var catKey = selectedCategory
        return base.filter(function(app) {
            return (app.categories ?? []).some(function(c) {
                return _categoryMap[c] === _categoryMap[catKey] || c === catKey
            })
        })
    }

    onClosed: {
        col.visible = false
        searchInput.text = ""
        ServiceApps.reset()
        appList.activeIndex = 0
        appList.animationsEnabled = false
        selectedCategory = "All"
    }

    // ── Context menu ──────────────────────────────────────────────────────
    function showContextMenu(clickX, clickY, app) {
        ctxMenu.targetApp = app
        ctxMenu.x = Math.max(4, Math.min(clickX, width - ctxMenu.width - 4))
        ctxMenu.y = clickY
    }

    Connections {
        target: loader
        function onAnimationChanged() {
            if (loader.animation) timer.start()
            else col.visible = false
        }
    }

    Timer {
        id: timer
        interval: 300
        onTriggered: col.visible = true
    }

    // ── Main content ──────────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        visible: false

        NumberAnimation on opacity { from: 0; to: 1; duration: 120; running: col.visible }
        NumberAnimation on scale   { from: 0.92; to: 1; duration: 180; easing.type: Easing.OutCubic; running: col.visible }

        // ── Search bar ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: 16
            color: Colors.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                MaterialIconSymbol {
                    content: "search"
                    iconSize: 20
                    customColor: Colors.primary
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: "Search apps…"
                        size: 15
                        customColor: Colors.outline
                        visible: searchInput.text.length === 0
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        font.pixelSize: 15
                        font.weight: 600
                        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                        color: Colors.surfaceText
                        focus: true

                        onTextChanged: ServiceApps.updateSearch(text)

                        onAccepted: {
                            if (appLauncher.filteredApps[appList.activeIndex]) {
                                appLauncher.filteredApps[appList.activeIndex].execute()
                                appLauncher.closed()
                            }
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                if (!isGrid && appList.activeIndex < appList.count - 1) {
                                    appList.activeIndex++
                                    appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                } else if (isGrid && appList.activeIndex < appList.count - 5) {
                                    appList.activeIndex += 4
                                    appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                }
                            } else if (event.key === Qt.Key_Up) {
                                if (!isGrid && appList.activeIndex > 0) {
                                    appList.activeIndex--
                                    appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                } else if (isGrid && appList.activeIndex > 4) {
                                    appList.activeIndex -= 4
                                    appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                }
                            } else if (event.key === Qt.Key_Right && isGrid) {
                                if (appList.activeIndex < appList.count - 1) {
                                    appList.activeIndex++
                                    appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                }
                            } else if (event.key === Qt.Key_Left && isGrid) {
                                if (appList.activeIndex > 0) {
                                    appList.activeIndex--
                                    appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                }
                            } else if (event.key === Qt.Key_Escape) {
                                appLauncher.closed()
                            }
                        }
                    }
                }

                // Clear button
                Rectangle {
                    width: 28; height: 28; radius: 10
                    color: Colors.surfaceContainerHighest
                    visible: searchInput.text.length > 0

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"; iconSize: 14
                        customColor: Colors.outline
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        // ── Category chips ────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            implicitHeight: 30
            contentWidth: catGroup.implicitWidth
            contentHeight: height
            clip: true
            interactive: contentWidth > width

            ButtonGroup {
                id: catGroup
                height: 30
                model: appLauncher.availableCategories
                activeCheck: function(value) { return value === appLauncher.selectedCategory }
                onSegmentClicked: value => {
                    appLauncher.selectedCategory = value
                    if (appList) appList.activeIndex = 0
                }
                inactiveColor: Colors.surfaceContainerHigh
            }
        }

        // ── Count + view toggle row ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            spacing: 0

            MaterialIconSymbol { content: "apps"; iconSize: 14; customColor: Colors.outline }
            CustomText {
                Layout.leftMargin: 4
                content: appLauncher.filteredApps.length + " apps"
                size: 12
                customColor: Colors.outline
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 62; height: 26; radius: 10
                color: Colors.surfaceContainerHigh

                Rectangle {
                    x: appLauncher.isGrid ? 33 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 20; radius: 7
                    color: Colors.primary
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent; anchors.margins: 3; spacing: 0

                    Item {
                        Layout.preferredWidth: 26; Layout.fillHeight: true
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "lists"; iconSize: 15
                            customColor: !appLauncher.isGrid ? Colors.primaryText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsConfig.general = Object.assign({}, SettingsConfig.general, { appGrid: false })
                        }
                    }
                    Item {
                        Layout.preferredWidth: 26; Layout.fillHeight: true
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "grid_view"; iconSize: 15
                            customColor: appLauncher.isGrid ? Colors.primaryText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsConfig.general = Object.assign({}, SettingsConfig.general, { appGrid: true })
                        }
                    }
                }
            }
        }

        // ── App list ──────────────────────────────────────────────────
        ClippingWrapperRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "transparent"

            Item {
                anchors.fill: parent

                Loader {
                    id: gridLoader
                    active: appLauncher.isGrid
                    visible: active
                    anchors.fill: parent
                    sourceComponent: GridApps {}
                }
                Loader {
                    id: listLoader
                    active: !appLauncher.isGrid
                    visible: active
                    anchors.fill: parent
                    sourceComponent: ListApps {}
                }
            }
        }
    }

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
                            source: IconUtil.getIconPath(ctxMenu.targetApp?.icon ?? "")
                            sourceSize: Qt.size(width, height)
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
                                ctxMenu.targetApp.execute()
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
