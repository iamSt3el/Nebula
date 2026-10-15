import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property real maxHeight: 640
    property int iconIndex: 0
    readonly property var liveApps: Hyprland.toplevels.values.filter(t => (t.lastIpcObject?.workspace?.id ?? 0) > 0)
    readonly property int liveWs: new Set(root.liveApps.map(t => t.lastIpcObject.workspace.id)).size

    implicitWidth: 360
    implicitHeight: Math.min(root.maxHeight, column.implicitHeight + 24)

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        GlobalStates.scenesPanelOpen = root.visible
    }
    Component.onDestruction: GlobalStates.scenesPanelOpen = false
    onVisibleChanged: GlobalStates.scenesPanelOpen = root.visible

    function iconFor(cls) {
        return IconUtil.themeIcon(DesktopEntries.heuristicLookup(cls)?.icon ?? "", true)
    }

    component SectionTitle: CustomText {
        Layout.topMargin: 8
        Layout.leftMargin: 4
        Layout.bottomMargin: 2
        size: 12
        weight: 600
        customColor: Colors.primary
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: CustomScrollBar {}

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 3

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText { content: "Scenes"; size: 16; weight: 600 }
                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceScenes.status !== "" ? ServiceScenes.status
                               : "Bring back a whole desk of apps, each on its workspace"
                        size: 12
                        customColor: ServiceScenes.restoring ? Colors.primary : Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SectionTitle { content: "Saved"; visible: ServiceScenes.scenes.length > 0 }

            Repeater {
                model: ServiceScenes.scenes

                CustomCard {
                    id: sc
                    required property var modelData
                    required property int index
                    autoRadius: false
                    topRadius: sc.index === 0 ? 20 : 5
                    bottomRadius: sc.index === ServiceScenes.scenes.length - 1 ? 20 : 5

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 13
                                color: Colors.secondaryContainer
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: sc.modelData.icon
                                    iconSize: 20
                                    fill: 1
                                    customColor: Colors.primary
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                CustomText {
                                    Layout.fillWidth: true
                                    content: sc.modelData.name
                                    size: 14
                                    weight: 600
                                    elide: Text.ElideRight
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: ServiceScenes.summaryOf(sc.modelData.apps)
                                    size: 11
                                    customColor: Colors.outline
                                }
                            }
                            M3IconButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                icon: "delete"
                                iconSize: 17
                                onClicked: ServiceScenes.remove(sc.modelData.id)
                            }
                            Rectangle {
                                Layout.preferredWidth: restoreRow.implicitWidth + 22
                                Layout.preferredHeight: 34
                                radius: 12
                                opacity: ServiceScenes.restoring ? 0.5 : 1
                                color: restoreArea.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                                Row {
                                    id: restoreRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialIconSymbol { content: "play_arrow"; iconSize: 16; fill: 1; customColor: Colors.primaryText; anchors.verticalCenter: parent.verticalCenter }
                                    CustomText { content: "Restore"; size: 12; weight: 600; customColor: Colors.primaryText; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea {
                                    id: restoreArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !ServiceScenes.restoring
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceScenes.restore(sc.modelData.id)
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: sc.modelData.apps
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    width: chipRow.implicitWidth + 12
                                    height: 24
                                    radius: 8
                                    color: Colors.surfaceContainerHighest
                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        CustomText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            content: chip.modelData.ws.toString()
                                            size: 10
                                            weight: 700
                                            customColor: Colors.primary
                                        }
                                        IconImage {
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: 14
                                            source: root.iconFor(chip.modelData.cls)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { content: "Save this desk" }

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: 13
                            color: Colors.surfaceContainerHighest
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: ServiceScenes.icons[root.iconIndex]
                                iconSize: 20
                                fill: 1
                                customColor: Colors.primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.iconIndex = (root.iconIndex + 1) % ServiceScenes.icons.length
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 12
                            color: Colors.surfaceContainerHighest
                            TextInput {
                                id: nameIn
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.family: "Rubik"
                                clip: true
                                onAccepted: saveBtn.go()
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12
                                visible: nameIn.text === "" && !nameIn.activeFocus
                                content: "Name it, like Work or Evening"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText {
                            Layout.fillWidth: true
                            content: root.liveApps.length + (root.liveApps.length === 1 ? " window" : " windows") + " on " + root.liveWs + (root.liveWs === 1 ? " workspace" : " workspaces") + " right now"
                            size: 11
                            customColor: Colors.outline
                        }
                        Rectangle {
                            id: saveBtn
                            function go() {
                                ServiceScenes.captureCurrent(nameIn.text.trim(), ServiceScenes.icons[root.iconIndex])
                                nameIn.text = ""
                            }
                            Layout.preferredWidth: saveRow.implicitWidth + 22
                            Layout.preferredHeight: 34
                            radius: 12
                            color: saveArea.containsMouse ? Colors.surfaceBright : Colors.secondaryContainer
                            Row {
                                id: saveRow
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIconSymbol { content: "bookmark_add"; iconSize: 16; customColor: Colors.secondaryContainerText; anchors.verticalCenter: parent.verticalCenter }
                                CustomText { content: "Save current"; size: 12; weight: 600; customColor: Colors.secondaryContainerText; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: saveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: saveBtn.go()
                            }
                        }
                    }
                }
            }
        }
    }
}
