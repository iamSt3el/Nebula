import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property var currentPage: 0
    signal settingClosed

    Connections {
        target: GlobalStates
        function onSettingsPageChanged() { root.currentPage = GlobalStates.settingsPage }
    }

    opacity: 0
    scale: 0.7

    NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true }
    NumberAnimation on scale   { from: 0.7; to: 1; duration: 100; running: true }

    // Section → page-index mapping
    readonly property var navSections: [
        { label: "System",  indices: [0, 12, 1, 2, 3, 4, 11] },
        { label: "Connect", indices: [5, 6] },
        { label: "Apps",    indices: [7, 8, 9] },
        { label: "Info",    indices: [10] }
    ]

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.surface

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: 20
            color: Colors.surfaceContainer

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ── Sidebar ──────────────────────────────────────
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 160
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 0

                        // Original header — unchanged
                        CustomText {
                            content: "Nebula"
                            size: 22
                            weight: 700
                        }
                        CustomText {
                            content: "v0.2.0-beta"
                            size: 12
                            customColor: Colors.outline
                        }

                        Item { Layout.preferredHeight: 14 }

                        // ── Nav sections ──────────────────────────
                        Repeater {
                            model: root.navSections

                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Separator between sections (skip first)
                                Rectangle {
                                    visible: index !== 0
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    Layout.bottomMargin: 4
                                    implicitHeight: 1
                                    color: Colors.surfaceContainerHighest
                                }

                                // Items in this section
                                Repeater {
                                    model: modelData.indices

                                    delegate: Item {
                                        id: navDelegate
                                        readonly property int pageIndex: modelData
                                        readonly property bool active: root.currentPage === pageIndex
                                        readonly property var pageData: Settings.pages[pageIndex]
                                        Layout.fillWidth: true
                                        implicitWidth: parent ? parent.width : 0
                                        implicitHeight: 38

                                        // Active / hover background
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            color: (navDelegate.active || navMouse.containsMouse)
                                                   ? Colors.primary
                                                   : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            scale: navDelegate.active ? 1.0 : 0.96
                                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            MaterialIconSymbol {
                                                content: navDelegate.pageData?.icon ?? ""
                                                iconSize: 18
                                                fill: navDelegate.active ? 1 : 0
                                                customColor: (navDelegate.active || navMouse.containsMouse) ? Colors.primaryText : Colors.surfaceVariantText
                                                Behavior on fill        { NumberAnimation { duration: 180 } }
                                                Behavior on customColor { ColorAnimation  { duration: 150 } }
                                            }

                                            CustomText {
                                                Layout.fillWidth: true
                                                content: navDelegate.pageData?.name ?? ""
                                                size: 15
                                                weight: navDelegate.active ? 700 : 500
                                                customColor: (navDelegate.active || navMouse.containsMouse) ? Colors.primaryText : Colors.surfaceVariantText
                                                Behavior on customColor { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            id: navMouse
                                            anchors.fill: parent
                                            cursorShape: GlobalStates.fileDialogOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            hoverEnabled: !GlobalStates.fileDialogOpen
                                            enabled: !GlobalStates.fileDialogOpen
                                            onClicked: root.currentPage = navDelegate.pageIndex
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Edit Config button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 15
                            color: Colors.primary

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol {
                                    content: "edit"
                                    iconSize: 18
                                    customColor: Colors.primaryText
                                }
                                CustomText {
                                    content: "Edit Config"
                                    size: 14
                                    customColor: Colors.primaryText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["kitty", "-e", "nvim",
                                    Quickshell.env("HOME") + "/.config/quickshell"])
                            }
                        }
                    }
                }

                // ── Content area ──────────────────────────────────
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Loader { anchors.fill: parent; active: root.currentPage === 0;  visible: active; sourceComponent: General{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 1;  visible: active; sourceComponent: Theme{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 2;  visible: active; sourceComponent: Sound{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 3;  visible: active; sourceComponent: Notifications{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 4;  visible: active; sourceComponent: Widgets{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 5;  visible: active; sourceComponent: Networking{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 6;  visible: active; sourceComponent: Bluetooth{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 7;  visible: active; sourceComponent: Ai{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 8;  visible: active; sourceComponent: WeatherSettings{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 9;  visible: active; sourceComponent: MediaSettings{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 10; visible: active; sourceComponent: About{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 11; visible: active; sourceComponent: Display{} }
                    Loader { anchors.fill: parent; active: root.currentPage === 12; visible: active; sourceComponent: AppearanceSettings{} }

                }
            }

            // Close button
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.rightMargin: 10
                implicitWidth: 30; implicitHeight: 30
                radius: 10
                color: closeArea.containsMouse ? Colors.primary : Colors.primaryContainer
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "close"; iconSize: 16
                    customColor: closeArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    Behavior on customColor { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.settingClosed()
                }
            }
        }
    }
}
