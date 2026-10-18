pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: compass

    property QtObject editor: null
    property Item drawerHost: null
    property bool live: false

    readonly property bool shown: compass.live && !!compass.editor && compass.editor.drawerMode === "" && compass.editor.mode === ""
        && compass.editor.selectedItem === "" && compass.editor.selectedBlock === "" && !compass.editor.panelStage
        && !EditSession.peek && BarLayout.gapDragT < 0.01

    property real showT: compass.shown ? 1 : 0
    Behavior on showT { SpatialAnim { speed: "fast" } }

    visible: compass.showT > 0.01
    opacity: compass.showT
    width: 340
    height: 220

    function open(side, from) {
        if (!compass.editor)
            return
        if (compass.drawerHost) {
            if (side !== "")
                compass.drawerHost.edgeSide = side
            compass.drawerHost.tab = side === "" ? "general" : "edges"
        }
        compass.editor.drawerFrom = from
        compass.editor.drawerMode = "settings"
    }

    function countFor(side) {
        return BarLayout.allBlocks.filter(b => b.edge === side).length
    }

    Rectangle {
        id: hub
        anchors.centerIn: parent
        width: 64
        height: 64
        radius: 32
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.3)

        color: hubArea.containsMouse ? Colors.secondaryContainer : Colors.surfaceContainerHigh

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "border_outer"
            iconSize: 26
            customColor: hubArea.containsMouse ? Colors.secondaryContainerText : Colors.surfaceVariantText
        }

        MouseArea {
            id: hubArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: compass.open("", hub.mapToItem(compass.parent, 0, 0, hub.width, hub.height))
        }

        CustomToolTip {
            content: "All edges"
            detail: "Border, shadow, panels and pinned apps"
            visible: hubArea.containsMouse
        }
    }

    Repeater {
        model: [
            { side: "top", icon: "arrow_upward", label: "Top" },
            { side: "right", icon: "arrow_forward", label: "Right" },
            { side: "bottom", icon: "arrow_downward", label: "Bottom" },
            { side: "left", icon: "arrow_back", label: "Left" }
        ]

        Rectangle {
            id: dir
            required property var modelData
            readonly property bool off: BarLayout.edge(dir.modelData.side).hidden === true
            readonly property int count: compass.countFor(dir.modelData.side)
            readonly property real dist: 18 + compass.showT * 10

            width: dirRow.implicitWidth + 28
            height: 48
            radius: 24
            x: dir.modelData.side === "left" ? hub.x - width - dir.dist
                : dir.modelData.side === "right" ? hub.x + hub.width + dir.dist
                : compass.width / 2 - width / 2
            y: dir.modelData.side === "top" ? hub.y - height - dir.dist
                : dir.modelData.side === "bottom" ? hub.y + hub.height + dir.dist
                : compass.height / 2 - height / 2
            color: dirArea.containsMouse ? Colors.secondaryContainer : Colors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colors.outline, dirArea.containsMouse ? 0 : 0.3)
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            Row {
                id: dirRow
                anchors.centerIn: parent
                spacing: 8

                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: dir.modelData.icon
                    iconSize: 20
                    customColor: dirArea.containsMouse ? Colors.secondaryContainerText : Colors.primary
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    CustomText {
                        content: dir.modelData.label
                        size: 13
                        weight: 600
                        customColor: dirArea.containsMouse ? Colors.secondaryContainerText : Colors.surfaceText
                    }
                    CustomText {
                        content: dir.off ? "Hidden" : dir.count === 0 ? "Empty" : dir.count === 1 ? "1 block" : dir.count + " blocks"
                        size: 10
                        customColor: Colors.outline
                    }
                }
            }

            MouseArea {
                id: dirArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: compass.open(dir.modelData.side, dir.mapToItem(compass.parent, 0, 0, dir.width, dir.height))
            }
        }
    }
}
