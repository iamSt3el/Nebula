import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.services
import qs.modules.utils

Item {
    id: root

    property real iconPx: 18
    property real plate: 30
    property int limit: -1
    property int offset: 0
    property int columns: 0
    property real spacing: 2

    readonly property int total: ServiceSystemTray.items ? ServiceSystemTray.items.values.length : 0
    readonly property bool overflowing: root.limit >= 0 && root.total > root.limit
    readonly property int hiddenCount: root.overflowing ? root.total - root.limit : 0

    signal menuRequested(var trayItem, Item source)
    signal activated
    signal overflowHovered(Item source)
    signal overflowClicked(Item source)

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: root.columns > 0 ? root.columns : -1
        rowSpacing: root.spacing
        columnSpacing: root.spacing

        Repeater {
            model: ServiceSystemTray.items

            delegate: Rectangle {
                id: trayItem
                required property var modelData
                required property int index

                visible: trayItem.index >= root.offset && (!root.overflowing || trayItem.index < root.limit)
                implicitWidth: root.plate
                implicitHeight: root.plate
                radius: root.plate / 2
                color: iconArea.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
                Behavior on color { ColorAnimation { duration: 150 } }

                CustomIconImage {
                    anchors.centerIn: parent
                    isColor: false
                    source: trayItem.modelData.icon
                    size: root.iconPx
                }

                CustomToolTip {
                    content: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id || ""
                    visible: root.columns > 0 && iconArea.containsMouse && content !== ""
                }

                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton

                    onClicked: event => {
                        const it = trayItem.modelData
                        if (event.button === Qt.RightButton) {
                            if (it.hasMenu)
                                root.menuRequested(it, trayItem)
                            else
                                it.secondaryActivate()
                        } else if (event.button === Qt.MiddleButton) {
                            it.secondaryActivate()
                        } else if (it.onlyMenu && it.hasMenu) {
                            root.menuRequested(it, trayItem)
                        } else {
                            it.activate()
                            root.activated()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: moreChip
            visible: root.overflowing
            implicitWidth: Math.max(root.plate, moreText.implicitWidth + 12)
            implicitHeight: root.plate
            radius: root.plate / 2
            color: moreArea.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHigh
            Behavior on color { ColorAnimation { duration: 150 } }

            CustomText {
                id: moreText
                anchors.centerIn: parent
                content: "+" + root.hiddenCount
                size: 11
                weight: 700
                customColor: moreArea.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
            }

            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.overflowHovered(moreChip)
                onClicked: root.overflowClicked(moreChip)
            }
        }
    }
}
