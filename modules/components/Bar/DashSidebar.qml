pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root

    property var actions: null
    property string page: "home"
    readonly property bool passwordPrompt: sub.item ? (sub.item.passwordPrompt ?? false) : false
    readonly property var fans: ServiceSystemInfo.fanRpms ?? []
    readonly property var cfg: SettingsConfig.general
    readonly property bool showProfile: root.cfg.dashProfile ?? true
    readonly property bool showToggles: root.cfg.dashToggles ?? true
    readonly property bool showSliders: root.cfg.dashSliders ?? true
    readonly property bool showMedia: root.cfg.dashMedia ?? true
    readonly property bool showStats: root.cfg.dashStats ?? true
    readonly property bool showNotifs: root.cfg.dashNotifs ?? true
    readonly property real notifH: ServiceNotification.notificationsNumber > 0
        ? Math.max(120, Math.min(420, notifList.contentHeight)) : 150
    readonly property real homeH: Math.max(96, homeCol.implicitHeight + 36)

    implicitWidth: 460
    implicitHeight: root.page === "home" ? root.homeH : Math.max(root.homeH, 620)

    Item {
        id: home
        anchors.fill: parent
        opacity: root.page === "home" ? 1 : 0
        visible: opacity > 0.01
        transform: Translate { x: root.page === "home" ? 0 : -40; Behavior on x { SpatialAnim {} } }
        Behavior on opacity { EffectsAnim {} }

        ColumnLayout {
            id: homeCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                visible: root.showProfile
                spacing: 8

                DashProfile {
                    Layout.fillWidth: true
                    big: false
                    avatarSize: 44
                    detail: Qt.formatDate(new Date(), "dddd d MMMM") + ", up " + ServiceProfile.uptimeText
                }
                M3IconButton { Layout.preferredWidth: 40; Layout.preferredHeight: 40; icon: "settings"; iconSize: 20; onClicked: root.actions.settings() }
                M3IconButton { Layout.preferredWidth: 40; Layout.preferredHeight: 40; icon: "power_settings_new"; iconSize: 20; iconColor: Colors.error; onClicked: root.actions.power() }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.showToggles
                columns: 2
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.actions ? root.actions.pick(["wifi", "bluetooth", "dnd", "caffeine"]) : []
                    DashToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        variant: "wide"
                        info: modelData
                        expandable: modelData.key === "wifi" || modelData.key === "bluetooth"
                        onClicked: root.actions.fire(modelData.key)
                        onOpened: root.page = modelData.key
                    }
                }
            }

            CustomCard {
                visible: root.showSliders
                autoRadius: false
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    DashSliderRow { Layout.fillWidth: true; kind: "volume"; showIcon: true }
                    DashSliderRow { Layout.fillWidth: true; kind: "brightness"; showIcon: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.showMedia
                implicitHeight: media.implicitHeight + 24
                radius: 20
                color: Colors.surfaceContainerHigh

                DashMediaRow {
                    id: media
                    x: 12
                    y: 12
                    width: parent.width - 24
                    artSize: 60
                    compact: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.showStats
                implicitHeight: statCol.implicitHeight + 24
                radius: 20
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: statCol
                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialIconSymbol { content: "monitoring"; iconSize: 16; customColor: Colors.primary }
                        CustomText { Layout.fillWidth: true; content: "System"; size: 12; weight: 800; customColor: Colors.surfaceVariantText }
                        MaterialIconSymbol { content: "device_thermostat"; iconSize: 15; customColor: Colors.surfaceVariantText }
                        CustomText {
                            content: Math.round(ServiceSystemInfo.cpuTemp) + "°C"
                            size: 12
                            weight: 800
                            customColor: ServiceSystemInfo.cpuTemp >= 85 ? Colors.error : Colors.surfaceVariantText
                        }
                        MaterialIconSymbol { visible: root.fans.length > 0; content: "mode_fan"; iconSize: 15; customColor: Colors.surfaceVariantText }
                        CustomText { visible: root.fans.length > 0; content: root.fans[0] + " rpm"; size: 12; weight: 800; customColor: Colors.surfaceVariantText }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        DashShapeStat { Layout.fillWidth: true; Layout.preferredWidth: 1; shape: "cookie12"; icon: "memory"; label: "CPU"; value: ServiceSystemInfo.cpuUsage }
                        DashShapeStat { Layout.fillWidth: true; Layout.preferredWidth: 1; shape: "cookie9"; icon: "memory_alt"; label: "RAM"; value: ServiceSystemInfo.memUsage }
                        DashShapeStat { Layout.fillWidth: true; Layout.preferredWidth: 1; shape: "cookie6"; icon: "developer_board"; label: "GPU"; value: ServiceSystemInfo.gpuUsage }
                        DashShapeStat { Layout.fillWidth: true; Layout.preferredWidth: 1; shape: "squircle"; icon: "hard_drive"; label: "Disk"; value: ServiceSystemInfo.diskUsage }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showNotifs
                Layout.leftMargin: 4
                Layout.topMargin: 2
                spacing: 6
                CustomText { content: "Notifications"; size: 15; weight: 800 }
                CustomText { content: String(ServiceNotification.notificationsNumber); size: 12; weight: 700; customColor: Colors.outline }
                Item { Layout.fillWidth: true }
                CustomText {
                    visible: ServiceNotification.notificationsNumber > 0
                    content: "Clear all"
                    size: 12
                    weight: 800
                    customColor: Colors.primary
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceNotification.clear()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.notifH
                visible: root.showNotifs

                NotificationList {
                    id: notifList
                    anchors.fill: parent
                    visible: ServiceNotification.notificationsNumber > 0
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: ServiceNotification.notificationsNumber === 0
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 56
                        implicitHeight: 56
                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MatrialShapeFn.getCookie9Sided()
                            color: Colors.surfaceContainerHigh
                        }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "done_all"
                            iconSize: 22
                            customColor: Colors.primary
                        }
                    }
                    CustomText { Layout.alignment: Qt.AlignHCenter; content: "You're all caught up"; size: 13; weight: 800 }
                    CustomText { Layout.alignment: Qt.AlignHCenter; content: "New notifications will show up here"; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                }
            }
        }
    }

    Loader {
        id: sub
        anchors.fill: parent
        active: root.page !== "home"
        opacity: active ? 1 : 0
        Behavior on opacity { EffectsAnim {} }
        transform: Translate { x: sub.active ? 0 : 40; Behavior on x { SpatialAnim {} } }
        sourceComponent: root.page === "wifi" ? wifiComp : root.page === "bluetooth" ? btComp : null
    }

    Component {
        id: wifiComp
        Wifi {
            showBack: true
            onBackClicked: root.page = "home"
        }
    }

    Component {
        id: btComp
        Bluetooth {
            showBack: true
            onBackClicked: root.page = "home"
        }
    }
}
