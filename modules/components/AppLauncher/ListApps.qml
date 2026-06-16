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

ListView {
    id: appList
    width: parent.width
    height: parent.height
    orientation: Qt.Vertical
    spacing: 3
    clip: true
    property int activeIndex: 0
    property bool animationsEnabled: false

    model: ScriptModel {
        values: appLauncher.filteredApps
        onValuesChanged: appList.animationsEnabled = true
    }

    add: Transition {
        enabled: appList.animationsEnabled
        ParallelAnimation {
            NumberAnimation { property: "x";       from: 60;  to: 0; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0;   to: 1; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale";   from: 0.9; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.4 }
        }
    }
    move: Transition {
        NumberAnimation { property: "y"; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.3 }
    }
    addDisplaced: Transition {
        ParallelAnimation {
            NumberAnimation { property: "y";       duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.3 }
            NumberAnimation { property: "opacity"; to: 1;         duration: 120 }
        }
    }
    displaced: Transition {
        ParallelAnimation {
            NumberAnimation { property: "y";       duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.3 }
            NumberAnimation { property: "opacity"; to: 1;         duration: 120 }
        }
    }

    delegate: Rectangle {
        id: item
        implicitWidth: appList.width
        implicitHeight: 62
        radius: 16

        readonly property bool isActive: appList.activeIndex === index
        readonly property bool hovered: appArea.containsMouse
        readonly property bool isPinned: ServiceApps.isPinned(modelData)

        color: isActive
            ? Colors.primaryContainer
            : hovered ? Qt.alpha(Colors.primary, 0.08) : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            // Icon
            Rectangle {
                width: 44; height: 44; radius: 13
                color: item.isActive
                    ? Qt.alpha(Colors.primary, 0.25)
                    : Qt.alpha(Colors.surfaceText, 0.06)
                Behavior on color { ColorAnimation { duration: 100 } }

                Image {
                    anchors.centerIn: parent
                    width: 30; height: 30
                    sourceSize: Qt.size(width, height)
                    source: IconUtil.getIconPath(modelData.icon)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                // Pin indicator
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -2
                    anchors.rightMargin: -2
                    width: 8; height: 8; radius: 4
                    color: Colors.primary
                    visible: item.isPinned
                }
            }

            // Name + description
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                CustomText {
                    Layout.fillWidth: true
                    content: modelData.name
                    size: 15
                    weight: 600
                    customColor: item.isActive ? Colors.primaryContainerText : Colors.surfaceText
                    elide: Text.ElideRight
                    Behavior on customColor { ColorAnimation { duration: 100 } }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: modelData.genericName || modelData.comment || ""
                    size: 12
                    customColor: item.isActive
                        ? Qt.alpha(Colors.primaryContainerText, 0.65)
                        : Colors.outline
                    elide: Text.ElideRight
                    visible: (modelData.genericName || modelData.comment || "").length > 0
                }
            }
        }

        MouseArea {
            id: appArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: appList.activeIndex = index

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    var pos = mapToItem(appLauncher, event.x, event.y)
                    appLauncher.showContextMenu(pos.x, pos.y, modelData)
                } else {
                    if (modelData) {
                        modelData.execute()
                        appLauncher.closed()
                    }
                }
            }
        }

        // ── Remove animation ──────────────────────────────────────────────
        SequentialAnimation {
            id: removeAnim
            PropertyAction  { target: item; property: "ListView.delayRemove"; value: true }
            ParallelAnimation {
                NumberAnimation { target: item; property: "x";       to: appList.width + 24; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { target: item; property: "opacity"; to: 0;                  duration: 180; easing.type: Easing.InQuad  }
            }
            NumberAnimation  { target: item; property: "implicitHeight"; to: 0; duration: 160; easing.type: Easing.InCubic }
            PropertyAction  { target: item; property: "ListView.delayRemove"; value: false }
        }
        ListView.onRemove: removeAnim.start()
    }
}
