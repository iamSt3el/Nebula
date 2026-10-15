import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    required property Item launcher
    readonly property Item appView: root.launcher.searching ? results
        : root.openFolder && folderLoader.item ? folderLoader.item : null

    property var openFolder: null
    readonly property int tile: Math.max(44, ServiceLauncher.iconSize + 22)

    function reset() {
        root.openFolder = null
        pager.currentIndex = 0
    }

    function handleEscape() {
        if (!root.openFolder) return false
        root.openFolder = null
        return true
    }

    readonly property var items: {
        const buckets = {}
        const loose = []
        for (const a of root.launcher.filteredApps) {
            const c = root.launcher.categoryOf(a)
            if (c === "") { loose.push({ app: a }); continue }
            if (!buckets[c]) buckets[c] = []
            buckets[c].push(a)
        }
        const folders = []
        for (const c of Object.keys(buckets).sort()) {
            if (buckets[c].length >= 3) folders.push({ folder: true, label: c, apps: buckets[c] })
            else for (const a of buckets[c]) loose.push({ app: a })
        }
        loose.sort((x, y) => x.app.name.localeCompare(y.app.name))
        return folders.concat(loose)
    }

    readonly property int cols: Math.max(3, Math.floor(pager.width / (root.tile + 36)))
    readonly property int cellH: root.tile + 40
    readonly property int rowsPer: Math.max(1, Math.floor(pager.height / root.cellH))
    readonly property int pageSize: root.cols * root.rowsPer
    readonly property int pages: Math.max(1, Math.ceil(root.items.length / root.pageSize))

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        LauncherSearch {
            launcher: root.launcher
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
        }

        Rectangle {
            id: dock
            readonly property var apps: Array.prototype.slice.call(ServiceApps.pinnedApps, 0,
                Math.max(1, Math.floor((dock.width - 16) / 52)))
            visible: root.launcher.isApps && !root.launcher.searching && dock.apps.length > 0 && root.height >= 460
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 24
            color: Colors.surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Math.max(6, Math.min(20, (dock.width - 16 - dock.apps.length * 44) / Math.max(1, dock.apps.length)))

                Repeater {
                    model: dock.apps
                    delegate: Item {
                        id: pin
                        required property var modelData
                        width: 44
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: pinArea.containsMouse ? Qt.alpha(Colors.primary, 0.12) : "transparent"
                        }
                        LauncherIcon {
                            anchors.centerIn: parent
                            app: pin.modelData
                            size: 34
                        }
                        MouseArea {
                            id: pinArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: event => {
                                if (event.button === Qt.RightButton) root.launcher.openMenu(pinArea, event.x, event.y, pin.modelData)
                                else root.launcher.launch(pin.modelData)
                            }
                        }
                        CustomToolTip {
                            content: pin.modelData.name
                            visible: pinArea.containsMouse
                        }
                    }
                }
            }
        }

        LauncherModeArea {
            launcher: root.launcher
            visible: !root.launcher.isApps
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        LauncherGrid {
            id: results
            visible: root.launcher.isApps && root.launcher.searching
            launcher: root.launcher
            Layout.fillWidth: true
            Layout.fillHeight: true
            apps: root.launcher.filteredApps
            iconSize: root.tile
            minCell: root.tile + 36
            plate: "none"
            labelSize: 12
        }

        ListView {
            id: pager
            visible: root.launcher.isApps && !root.launcher.searching
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 280
            clip: true
            model: root.pages

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y < 0 || event.angleDelta.x < 0) pager.incrementCurrentIndex()
                    else pager.decrementCurrentIndex()
                }
            }

            delegate: Item {
                id: pageItem
                required property int index
                width: pager.width
                height: pager.height

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: root.cols
                    rowSpacing: 0
                    columnSpacing: 0

                    Repeater {
                        model: root.items.slice(pageItem.index * root.pageSize, (pageItem.index + 1) * root.pageSize)
                        delegate: Item {
                            id: cell
                            required property var modelData
                            width: Math.floor(pager.width / root.cols)
                            height: root.cellH

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 16
                                color: cellArea.containsMouse ? Qt.alpha(Colors.primary, 0.08) : "transparent"
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                spacing: 6

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.tile
                                    Layout.preferredHeight: root.tile
                                    radius: root.tile * 0.32
                                    color: cell.modelData.folder ? Colors.surfaceContainerHigh : "transparent"

                                    Grid {
                                        visible: !!cell.modelData.folder
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 3
                                        Repeater {
                                            model: cell.modelData.folder ? cell.modelData.apps.slice(0, 4) : []
                                            delegate: LauncherIcon {
                                                required property var modelData
                                                app: modelData
                                                size: Math.round((root.tile - 18) / 2)
                                            }
                                        }
                                    }

                                    LauncherIcon {
                                        visible: !cell.modelData.folder
                                        anchors.centerIn: parent
                                        app: cell.modelData.app ?? null
                                        size: root.tile
                                    }
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    content: cell.modelData.folder ? cell.modelData.label : (cell.modelData.app?.name ?? "")
                                    size: 12
                                    weight: cell.modelData.folder ? 600 : 500
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: event => {
                                    if (cell.modelData.folder) {
                                        root.openFolder = cell.modelData
                                    } else if (event.button === Qt.RightButton) {
                                        root.launcher.openMenu(cellArea, event.x, event.y, cell.modelData.app)
                                    } else {
                                        root.launcher.launch(cell.modelData.app)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            visible: pager.visible && root.pages > 1
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: root.pages
                delegate: Rectangle {
                    required property int index
                    width: index === pager.currentIndex ? 20 : 6
                    height: 6
                    radius: 3
                    color: index === pager.currentIndex ? Colors.primary : Colors.surfaceContainerHighest
                    Behavior on width { SpatialAnim { speed: "fast" } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pager.currentIndex = parent.index
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.openFolder !== null
        color: Qt.alpha(Colors.surface, 0.6)
        topLeftRadius: root.launcher.innerCorner("tl")
        topRightRadius: root.launcher.innerCorner("tr")
        bottomLeftRadius: root.launcher.innerCorner("bl")
        bottomRightRadius: root.launcher.innerCorner("br")

        MouseArea {
            anchors.fill: parent
            onClicked: root.openFolder = null
        }
    }

    Rectangle {
        id: folderCard
        visible: root.openFolder !== null
        anchors.centerIn: parent
        width: Math.min(root.width - 16, 460)
        height: Math.min(root.height - 40, folderHead.height + 40
            + Math.ceil((root.openFolder ? root.openFolder.apps.length : 0) / Math.max(1, Math.floor((width - 36) / (root.tile + 40))))
              * (root.tile + 54))
        radius: 30
        color: Colors.surfaceContainerHigh

        MouseArea { anchors.fill: parent }

        RowLayout {
            id: folderHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            height: 28
            CustomText {
                Layout.fillWidth: true
                content: root.openFolder ? root.openFolder.label : ""
                size: 18
                weight: 700
            }
            CustomText {
                content: root.openFolder ? root.openFolder.apps.length + " apps" : ""
                size: 12
                customColor: Colors.outline
            }
        }

        Loader {
            id: folderLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: folderHead.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 12
            active: root.openFolder !== null
            sourceComponent: LauncherGrid {
                launcher: root.launcher
                apps: root.openFolder ? root.openFolder.apps : []
                iconSize: root.tile - 4
                minCell: root.tile + 40
                plate: "none"
            }
        }
    }
}
