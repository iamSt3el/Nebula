import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: page

    property string folderLabel: ""

    signal folderRequested

    readonly property int columns: 4
    readonly property int firstVisible: Math.min(Math.max(0, grid.count - 1),
        Math.round(grid.contentY / Math.max(1, grid.cellHeight)) * page.columns)
    readonly property int choices: Math.min(8, Math.max(0, grid.count - page.firstVisible))
    readonly property int keyFrom: 1
    readonly property int keyTo: page.choices

    function pick(n) {
        const i = page.firstVisible + n - 1
        if (n < 1 || n > page.choices || i >= grid.count)
            return false
        ServiceWallpaper.setWallpaper(ServiceWallpaper.wallpapers[i])
        return true
    }

    function chosenIndex() {
        const list = ServiceWallpaper.wallpapers
        for (let i = 0; i < list.length; i++)
            if (ServiceWallpaper.getOriginalPath(list[i]) === Colors.sourceWallpaper)
                return i
        return -1
    }

    property bool positioned: false

    function positionOnChosen() {
        if (page.positioned || grid.count === 0 || grid.height <= 0)
            return
        const i = page.chosenIndex()
        const row = Math.floor(i / page.columns)
        const maxY = Math.max(0, grid.contentHeight - grid.height)
        if (row >= 2)
            grid.contentY = Math.min(maxY, (row - 1) * grid.cellHeight)
        page.positioned = true
    }

    spacing: 12

    GridView {
        id: grid

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: ServiceWallpaper.wallpapers
        cellWidth: Math.floor(width / page.columns)
        cellHeight: Math.round(cellWidth * 10 / 16)
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500
        maximumFlickVelocity: 8000
        cacheBuffer: grid.cellHeight * 2
        activeFocusOnTab: false
        ScrollBar.vertical: CustomScrollBar {}

        onCountChanged: Qt.callLater(page.positionOnChosen)
        onHeightChanged: Qt.callLater(page.positionOnChosen)

        delegate: Item {
            id: cell

            required property string modelData
            required property int index

            readonly property bool chosen: ServiceWallpaper.getOriginalPath(cell.modelData) === Colors.sourceWallpaper
            readonly property int keyNumber: cell.index - page.firstVisible + 1

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: ring
                anchors.fill: parent
                anchors.margins: 3
                radius: cell.chosen ? 26 : 16
                color: "transparent"
                border.width: 3
                border.color: cell.chosen ? Colors.primary : "transparent"
                Behavior on radius { SpatialAnim { speed: "fast" } }
                Behavior on border.color { EffectsColorAnim {} }
            }

            RoundedImage {
                id: thumb
                anchors.fill: parent
                anchors.margins: cell.chosen ? 9 : 5
                radius: cell.chosen ? 20 : 14
                source: "file://" + cell.modelData
                sourceSize.width: 320
                sourceSize.height: 200
                asynchronous: true
                Behavior on anchors.margins { SpatialAnim { speed: "fast" } }
                Behavior on radius { SpatialAnim { speed: "fast" } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceContainerHigh
                    visible: thumb.status !== Image.Ready
                }
            }

            Rectangle {
                anchors.right: thumb.right
                anchors.top: thumb.top
                anchors.margins: 8
                width: 26
                height: 26
                radius: 13
                visible: cell.chosen
                color: Colors.primary

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "check"
                    iconSize: 17
                    customColor: Colors.primaryText
                }
            }

            Rectangle {
                anchors.left: thumb.left
                anchors.bottom: thumb.bottom
                anchors.margins: 8
                width: 24
                height: 24
                radius: 8
                visible: cell.keyNumber >= 1 && cell.keyNumber <= page.choices
                color: Qt.alpha(Colors.scrim, 0.55)

                CustomText {
                    anchors.centerIn: parent
                    content: String(cell.keyNumber)
                    size: 12
                    weight: 600
                    customColor: "white"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ServiceWallpaper.setWallpaper(cell.modelData)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        M3Button {
            size: "xsmall"
            variant: "tonal"
            icon: "folder_open"
            label: "Folder"
            onClicked: page.folderRequested()
        }

        CustomText {
            Layout.fillWidth: true
            content: page.folderLabel
            size: 12
            weight: 400
            customColor: Colors.outline
            elide: Text.ElideMiddle
        }

        CustomText {
            content: grid.count === 1 ? "1 wallpaper" : grid.count + " wallpapers"
            size: 12
            weight: 400
            customColor: Colors.outline
        }
    }
}
