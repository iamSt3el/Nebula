import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    implicitHeight: parent.height
    implicitWidth: dockRow.implicitWidth
    visible: false

    signal contextMenuRequested(real px, real py, var appEntry)
    property bool showPreview: false
    property bool iconHovered: false
    property bool previewHovered: false
    property point previewPos: Qt.point(0, 0)
    property var hoveredAppEntry: null

    Timer {
        id: hidePreviewTimer
        interval: 150
        onTriggered: {
            if (!root.iconHovered && !root.previewHovered)
                root.showPreview = false
        }
    }

    Timer {
        id: dockTimer
        interval: 300
        running: true
        onTriggered: root.visible = true
    }

    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: 400
    }

    NumberAnimation on scale {
        from: 0.8
        to: 1
        duration: 400
    }

    Loader {
        id: previewLoader
        active: root.showPreview
        sourceComponent: DockPreview {
            anchorPoint: root.previewPos
            appEntry: root.hoveredAppEntry
            onHoverEntered: {
                hidePreviewTimer.stop()
                root.previewHovered = true
            }
            onHoverExited: {
                root.previewHovered = false
                if (!root.iconHovered)
                    hidePreviewTimer.restart()
            }
        }
    }


    RowLayout {
        id: dockRow
        anchors.fill: parent
        spacing: 10
        anchors.margins: 10

        Repeater {
            id: dockRepeater
            model: ServiceApps.dockModel
            delegate: Rectangle {
                id: dockItem
                required property var modelData
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(dockItem.modelData.appId)?.icon, "image-missing")
                    width: 40
                    height: 40
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    id: dockIconArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: {
                        if (modelData.toplevels.length > 0) {
                            hidePreviewTimer.stop()
                            root.iconHovered = true
                            root.hoveredAppEntry = dockItem.modelData
                            root.showPreview = true
                            var globalPos = dockItem.mapToItem(panelWindow.container, 0, 0)
                            root.previewPos = Qt.point(globalPos.x, globalPos.y)
                        }
                    }

                    onExited: {
                        root.iconHovered = false
                        if (!root.previewHovered)
                        hidePreviewTimer.restart()
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton && dockItem.modelData.toplevels.length > 0)
                        dockItem.modelData.toplevels[0].activate()
                        else if (mouse.button === Qt.LeftButton)
                        modelData.execute()

                        if (mouse.button === Qt.RightButton) {
                            const pos = dockIconArea.mapToItem(root, mouse.x, mouse.y)
                            root.contextMenuRequested(pos.x, root.y, dockItem.modelData)
                        }
                    }
                }



                Loader {
                    active: dockItem.modelData.toplevels.length > 0
                    width: parent.width
                    anchors.bottom: parent.bottom
                    sourceComponent: Item {
                        y: 4
                        RowLayout {
                            anchors.centerIn: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            spacing: 2
                            Repeater {
                                model: Math.min(dockItem.modelData.toplevels.length, 4)
                                Rectangle {
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 4
                                    radius: height
                                    color: Colors.surfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }

        
        Loader{ 
            active: SettingsConfig.general.dockMusicPlayer
            visible: active
            Layout.fillHeight: true
            Layout.preferredWidth: 160
            sourceComponent:
            DockMusicPlayer{}
        }

        // Rectangle {
        //     Layout.fillHeight: true
        //     Layout.preferredWidth: 2
        //     color: Colors.outline
        //     radius: 4
        // }
    }
}
