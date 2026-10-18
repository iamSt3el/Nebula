import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings

Item {
    id: root
    property bool isListClicked: false
    property var currentVal: null
    property var objectVal: null
    property var list: []
    property color color: Colors.surfaceContainerHigh
    z: isListClicked ? 1000 : 0
    signal listClicked
    signal listChildClicked(var child)
    height: 30

    property var _picked: null
    readonly property string shownName: root._picked ?? root.currentVal ?? root.objectVal?.name ?? ""
    onCurrentValChanged: root._picked = null
    onObjectValChanged: root._picked = null

    Timer {
        id: pickedTimer
        interval: 1500
        onTriggered: root._picked = null
    }
    readonly property int selectedIndex: {
        const l = root.list ?? []
        for (let i = 0; i < l.length; i++)
            if (l[i]?.name === root.shownName)
                return i
        return -1
    }
    readonly property real outerRadius: root.isListClicked ? 8 : height / 2

    function open() {
        if (root.isListClicked || (root.list ?? []).length === 0)
            return
        root.isListClicked = true
        root.listClicked()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 2

        Rectangle {
            id: labelSeg
            Layout.fillWidth: true
            Layout.fillHeight: true
            topLeftRadius: root.outerRadius
            bottomLeftRadius: root.outerRadius
            topRightRadius: 4
            bottomRightRadius: 4
            color: root.color
            clip: true
            Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
            Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                bottomLeftRadius: parent.bottomLeftRadius
                topRightRadius: 4
                bottomRightRadius: 4
                color: Colors.surfaceText
                opacity: fieldArea.pressed ? 0.12 : fieldArea.containsMouse || root.isListClicked ? 0.08 : 0
                Behavior on opacity { EffectsAnim { speed: "fast" } }
            }

            CustomText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                content: root.shownName
                size: 12
                weight: 600
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 36
            topLeftRadius: 4
            bottomLeftRadius: 4
            topRightRadius: root.outerRadius
            bottomRightRadius: root.outerRadius
            color: root.isListClicked ? Colors.secondaryContainer : root.color
            Behavior on color { EffectsColorAnim {} }
            Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
            Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: 4
                bottomLeftRadius: 4
                topRightRadius: parent.topRightRadius
                bottomRightRadius: parent.bottomRightRadius
                color: Colors.surfaceText
                opacity: fieldArea.pressed ? 0.12 : fieldArea.containsMouse ? 0.08 : 0
                Behavior on opacity { EffectsAnim { speed: "fast" } }
            }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "keyboard_arrow_down"
                iconSize: 20
                customColor: root.isListClicked ? Colors.secondaryContainerText : Colors.surfaceText
                rotation: root.isListClicked ? 180 : 0
                Behavior on rotation { SpatialAnim { speed: "fast" } }
            }
        }
    }

    MouseArea {
        id: fieldArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (root.list ?? []).length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.open()
    }

    Loader {
        id: listLoader
        active: root.isListClicked
        sourceComponent: PopupWindow {
            id: popup

            readonly property real shadowPad: 14
            readonly property real itemH: 36
            readonly property real gap: 2
            readonly property real pad: 4
            readonly property int count: (root.list ?? []).length
            readonly property real fullH: Math.min(popup.count * (popup.itemH + popup.gap) - popup.gap + popup.pad * 2, 284)
            property bool closing: false
            property real reveal: 0

            anchor.window: root.QsWindow.window
            anchor.rect.x: root.mapToItem(null, 0, 0).x - popup.shadowPad
            anchor.rect.y: root.mapToItem(null, 0, 0).y + (popup.shadowPad - 4)
            anchor.rect.width: root.width + popup.shadowPad * 2
            anchor.rect.height: Math.max(1, root.height - 2 * (popup.shadowPad - 4))
            anchor.edges: Edges.Bottom | Edges.Left
            anchor.gravity: Edges.Bottom | Edges.Right
            anchor.adjustment: PopupAdjustment.FlipY | PopupAdjustment.SlideX

            visible: true
            color: "transparent"
            implicitWidth: root.width + popup.shadowPad * 2
            implicitHeight: popup.fullH + popup.shadowPad * 2

            function close() {
                if (popup.closing)
                    return
                popup.closing = true
                closeAnim.start()
            }

            function choose(i) {
                const l = root.list ?? []
                if (i < 0 || i >= l.length)
                    return
                root._picked = l[i].name
                pickedTimer.restart()
                root.listChildClicked(l[i])
                popup.close()
            }

            HyprlandFocusGrab {
                active: true
                windows: [QsWindow.window]
                onCleared: popup.close()
            }

            NumberAnimation on reveal {
                id: openAnim
                from: 0
                to: 1
                duration: M3Motion.spatialDuration("fast")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                running: true
            }

            NumberAnimation {
                id: closeAnim
                target: popup
                property: "reveal"
                to: 0
                duration: M3Motion.effectsDuration("default")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1, 1]
                onFinished: root.isListClicked = false
            }

            Item {
                id: frame
                x: popup.shadowPad
                y: popup.shadowPad
                width: root.width
                height: popup.fullH
                opacity: Math.min(1, popup.reveal * 1.6)

                RectangularShadow {
                    anchors.fill: menu
                    radius: menu.radius
                    blur: 12
                    spread: 0
                    offset.y: 3
                    color: Qt.alpha(Colors.shadow ?? "#000000", 0.35)
                    opacity: popup.reveal
                }

                Rectangle {
                    id: menu
                    width: parent.width
                    height: Math.max(popup.itemH * 0.5, popup.fullH * (0.35 + 0.65 * popup.reveal))
                    radius: 16
                    color: Colors.surfaceContainerLow
                    clip: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: popup.pad
                        model: root.list
                        spacing: popup.gap
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.selectedIndex
                        keyNavigationEnabled: true
                        focus: true

                        Component.onCompleted: {
                            if (root.selectedIndex >= 0)
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            listView.forceActiveFocus()
                        }

                        Keys.onReturnPressed: popup.choose(listView.currentIndex)
                        Keys.onEnterPressed: popup.choose(listView.currentIndex)
                        Keys.onEscapePressed: popup.close()

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool selected: row.index === root.selectedIndex
                            readonly property bool first: row.index === 0
                            readonly property bool last: row.index === popup.count - 1
                            readonly property bool keyed: listView.activeFocus && row.index === listView.currentIndex && !row.selected
                            readonly property real outer: row.selected ? 12 : 12
                            readonly property real inner: row.selected ? 12 : 4

                            width: ListView.view.width
                            height: popup.itemH
                            readonly property real delay: Math.min(8, Math.max(0, (row.y - listView.contentY) / (popup.itemH + popup.gap))) * 0.06
                            opacity: Math.max(0, Math.min(1, (popup.reveal - row.delay) / 0.5))

                            Rectangle {
                                anchors.fill: parent
                                topLeftRadius: row.first ? row.outer : row.inner
                                topRightRadius: row.first ? row.outer : row.inner
                                bottomLeftRadius: row.last ? row.outer : row.inner
                                bottomRightRadius: row.last ? row.outer : row.inner
                                color: row.selected ? Colors.tertiaryContainer : Colors.surfaceContainer
                                Behavior on color { EffectsColorAnim {} }
                                Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
                                Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
                                Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }
                                Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: parent.topLeftRadius
                                    topRightRadius: parent.topRightRadius
                                    bottomLeftRadius: parent.bottomLeftRadius
                                    bottomRightRadius: parent.bottomRightRadius
                                    color: row.selected ? Colors.tertiaryContainerText : Colors.surfaceText
                                    opacity: itemArea.pressed ? 0.12 : itemArea.containsMouse || row.keyed ? 0.08 : 0
                                    Behavior on opacity { EffectsAnim { speed: "fast" } }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialIconSymbol {
                                    visible: (row.modelData?.icon ?? "") !== ""
                                    content: row.modelData?.icon ?? ""
                                    iconSize: 18
                                    customColor: row.selected ? Colors.tertiaryContainerText : Colors.surfaceVariantText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: row.modelData?.name ?? ""
                                    size: 13
                                    weight: row.selected ? 600 : 500
                                    elide: Text.ElideRight
                                    customColor: row.selected ? Colors.tertiaryContainerText : Colors.surfaceText
                                }

                                MaterialIconSymbol {
                                    visible: row.selected
                                    content: "check"
                                    iconSize: 18
                                    customColor: Colors.tertiaryContainerText
                                }
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: listView.currentIndex = row.index
                                onClicked: popup.choose(row.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
