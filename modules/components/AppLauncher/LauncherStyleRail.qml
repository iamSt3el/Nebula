import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    required property Item launcher
    readonly property Item appView: grid
    readonly property bool labels: root.width >= 460
    readonly property var active: grid.apps[grid.activeIndex] ?? null

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.preferredWidth: root.labels ? 84 : 60
            Layout.fillHeight: true
            radius: 22
            topLeftRadius: root.launcher.innerCorner("tl")
            bottomLeftRadius: root.launcher.innerCorner("bl")
            color: Colors.surfaceContainerLow

            ListView {
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.launcher.availableCategories

                delegate: Item {
                    id: cat
                    required property var modelData
                    readonly property bool on: root.launcher.selectedCategory === cat.modelData.value
                    width: ListView.view.width
                    height: root.labels ? 58 : 44

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.labels ? 4 : 6
                        width: 52
                        height: 32
                        radius: 16
                        color: cat.on ? Colors.secondaryContainer
                             : catArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: root.launcher.categoryIcon(cat.modelData.label)
                            iconSize: 20
                            customColor: cat.on ? Colors.secondaryContainerText : Colors.outline
                        }
                    }

                    CustomText {
                        visible: root.labels
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        content: cat.modelData.label
                        size: 11
                        weight: cat.on ? 700 : 500
                        customColor: cat.on ? Colors.surfaceText : Colors.outline
                    }

                    MouseArea {
                        id: catArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launcher.selectCategory(cat.modelData.value)
                    }

                    CustomToolTip {
                        content: cat.modelData.label
                        visible: !root.labels && catArea.containsMouse
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            LauncherSearch {
                launcher: root.launcher
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                placeholder: root.launcher.selectedCategory === "All" ? "" : "Search in " + root.launcher.selectedLabel
            }

            LauncherModeArea {
                launcher: root.launcher
                visible: !root.launcher.isApps
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {
                visible: root.launcher.isApps
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                CustomText {
                    content: root.launcher.searching ? "Results" : root.launcher.selectedLabel
                    size: 20
                    weight: 700
                }
                CustomText {
                    Layout.fillWidth: true
                    content: grid.count + (grid.count === 1 ? " app" : " apps")
                    size: 12
                    customColor: Colors.outline
                }
                CustomText {
                    visible: root.width >= 420
                    content: ServiceLauncher.sortMode === "used" ? "Most used first" : "A to Z"
                    size: 12
                    weight: 600
                    customColor: Colors.primary
                }
            }

            LauncherGrid {
                id: grid
                visible: root.launcher.isApps
                launcher: root.launcher
                Layout.fillWidth: true
                Layout.fillHeight: true
                apps: root.launcher.filteredApps
                iconSize: ServiceLauncher.iconSize + 12
                minCell: iconSize + 54
                labelSize: 12
            }

            Rectangle {
                visible: root.launcher.isApps && root.active !== null && root.height >= 520
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 18
                color: Colors.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    LauncherIcon {
                        app: root.active
                        size: 28
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        CustomText {
                            Layout.fillWidth: true
                            content: root.active?.name ?? ""
                            size: 12
                            weight: 600
                            elide: Text.ElideRight
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: root.active?.comment || root.active?.genericName || root.launcher.categoryOf(root.active)
                            size: 11
                            elide: Text.ElideRight
                            customColor: Colors.outline
                        }
                    }
                    LauncherKey { label: "↵" }
                }
            }
        }
    }
}
