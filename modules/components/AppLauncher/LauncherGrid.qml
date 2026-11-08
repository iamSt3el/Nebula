import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

GridView {
    id: grid

    required property Item launcher
    property var apps: []
    property int iconSize: ServiceLauncher.iconSize + 8
    property int minCell: grid.iconSize + 50
    property string plate: "soft"
    property int labelSize: 11
    property bool showLabels: true

    property int activeIndex: 0
    property bool animationsEnabled: false
    readonly property int columns: Math.max(1, Math.floor(grid.width / grid.minCell))
    readonly property int navCount: grid.count

    function activateIndex(i) {
        grid.launcher.launch(grid.apps[i], grid.itemAtIndex(i))
    }

    onAppsChanged: Qt.callLater(() => {
        if (grid.activeIndex === 0)
            grid.positionViewAtBeginning()
    })

    cellWidth: Math.floor(grid.width / grid.columns)
    cellHeight: grid.iconSize + (grid.plate === "none" ? 20 : 34) + (grid.showLabels ? grid.labelSize + 12 : 0)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
        values: grid.apps
        onValuesChanged: grid.animationsEnabled = true
    }

    add: Transition {
        enabled: grid.animationsEnabled
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool active: grid.activeIndex === cell.index
        readonly property bool pinned: ServiceApps.isPinned(cell.modelData)
        readonly property real box: grid.iconSize + (grid.plate === "none" ? 8 : 20)

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 16
            color: cell.active ? Colors.primaryContainer
                 : area.containsMouse ? Qt.alpha(Colors.primary, 0.08) : "transparent"
            border.width: cell.active ? 2 : 0
            border.color: Colors.primary
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 10
            spacing: 6

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: cell.box
                Layout.preferredHeight: cell.box

                Rectangle {
                    anchors.fill: parent
                    visible: grid.plate !== "none"
                    radius: grid.plate === "shape" ? (cell.index % 3 === 0 ? width * 0.34 : width / 2) : Math.round(width * 0.3)
                    color: cell.active ? Qt.alpha(Colors.primary, 0.2)
                         : grid.plate === "shape" ? Colors.surfaceContainer : Qt.alpha(Colors.surfaceText, 0.05)
                }

                LauncherIcon {
                    anchors.centerIn: parent
                    app: cell.modelData
                    size: grid.iconSize
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 8
                    height: 8
                    radius: 4
                    color: Colors.primary
                    visible: cell.pinned
                }
            }

            CustomText {
                Layout.fillWidth: true
                visible: grid.showLabels
                horizontalAlignment: Text.AlignHCenter
                content: cell.modelData.name
                size: grid.labelSize
                weight: 500
                elide: Text.ElideRight
                customColor: cell.active ? Colors.primaryContainerText : Colors.surfaceText
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: grid.activeIndex = cell.index
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    grid.launcher.openMenu(area, event.x, event.y, cell.modelData)
                else
                    grid.launcher.launch(cell.modelData, cell)
            }
        }

        Loader {
            anchors.fill: parent
            active: !grid.showLabels
            sourceComponent: CustomToolTip {
                content: cell.modelData.name
                visible: area.containsMouse
            }
        }
    }
}
