import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    width: 240
    height: 210

    property bool editMode: false

    scale: root.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: root.editMode
    layer.smooth: true
    layer.textureSize: root.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.sysMonitorX ?? 120
        root.y = SettingsConfig.widgets.sysMonitorY ?? 120
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.sysMonitorX ?? 120
                root.y = SettingsConfig.widgets.sysMonitorY ?? 120
            }
        }
    }

    onXChanged: if (editMode) saveTimer.restart()
    onYChanged: if (editMode) saveTimer.restart()

    Timer {
        id: saveTimer; interval: 500; repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                sysMonitorX: root.x, sysMonitorY: root.y
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        drag.target: root.editMode ? root : undefined
        cursorShape: root.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        onDoubleClicked: root.editMode = true
        onReleased: if (root.editMode) root.editMode = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Colors.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                spacing: 8
                MaterialShapes.ShapeCanvas {
                    implicitWidth: 26; implicitHeight: 26
                    roundedPolygon: MaterialShapeFn.getCookie6Sided()
                    color: Colors.primaryContainer
                    MaterialIconSymbol {
                        anchors.centerIn: parent; content: "memory"
                        iconSize: 13; customColor: Colors.primaryText
                    }
                }
                CustomText { content: "System"; size: 13; weight: 600; customColor: Colors.primary }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceSystemInfo.cpuName.length > 0
                        ? ServiceSystemInfo.cpuName.split(" ").slice(0, 2).join(" ") : ""
                    size: 9; customColor: Colors.outline
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.outlineVariant; opacity: 0.4 }

            // ── Stat rows ─────────────────────────────────────────────
            // CPU
            RowLayout { Layout.fillWidth: true; spacing: 8
                MaterialIconSymbol { content: "developer_board"; iconSize: 13; customColor: Colors.primary }
                CustomText { content: "CPU"; size: 11; customColor: Colors.outline; Layout.preferredWidth: 26 }
                Item {
                    Layout.fillWidth: true; implicitHeight: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Colors.surfaceContainerHighest }
                    Rectangle {
                        width: Math.max(6, parent.width * ServiceSystemInfo.cpuUsage)
                        height: parent.height; radius: 3; color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    }
                }
                CustomText {
                    content: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
                    size: 11; weight: 600; customColor: Colors.primary; Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                CustomText {
                    content: Math.round(ServiceSystemInfo.cpuTemp) + "°"
                    size: 11; Layout.preferredWidth: 26
                    customColor: ServiceSystemInfo.cpuTemp > 80 ? Colors.error : Colors.outline
                }
            }

            // RAM
            RowLayout { Layout.fillWidth: true; spacing: 8
                MaterialIconSymbol { content: "ad_units"; iconSize: 13; customColor: Colors.primary }
                CustomText { content: "RAM"; size: 11; customColor: Colors.outline; Layout.preferredWidth: 26 }
                Item {
                    Layout.fillWidth: true; implicitHeight: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Colors.surfaceContainerHighest }
                    Rectangle {
                        width: Math.max(6, parent.width * ServiceSystemInfo.memUsage)
                        height: parent.height; radius: 3; color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    }
                }
                CustomText {
                    content: Math.round(ServiceSystemInfo.memUsage * 100) + "%"
                    size: 11; weight: 600; customColor: Colors.primary; Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                CustomText {
                    content: ServiceSystemInfo.memUsedGb.toFixed(1) + "G"
                    size: 11; customColor: Colors.outline; Layout.preferredWidth: 26
                }
            }

            // GPU
            RowLayout { Layout.fillWidth: true; spacing: 8
                MaterialIconSymbol { content: "display_settings"; iconSize: 13; customColor: Colors.primary }
                CustomText { content: "GPU"; size: 11; customColor: Colors.outline; Layout.preferredWidth: 26 }
                Item {
                    Layout.fillWidth: true; implicitHeight: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Colors.surfaceContainerHighest }
                    Rectangle {
                        width: Math.max(6, parent.width * ServiceSystemInfo.gpuUsage)
                        height: parent.height; radius: 3; color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    }
                }
                CustomText {
                    content: Math.round(ServiceSystemInfo.gpuUsage * 100) + "%"
                    size: 11; weight: 600; customColor: Colors.primary; Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                CustomText {
                    content: Math.round(ServiceSystemInfo.gpuTemp) + "°"
                    size: 11; Layout.preferredWidth: 26
                    customColor: ServiceSystemInfo.gpuTemp > 85 ? Colors.error : Colors.outline
                }
            }

            // Disk
            RowLayout { Layout.fillWidth: true; spacing: 8
                MaterialIconSymbol { content: "hard_drive"; iconSize: 13; customColor: Colors.primary }
                CustomText { content: "Disk"; size: 11; customColor: Colors.outline; Layout.preferredWidth: 26 }
                Item {
                    Layout.fillWidth: true; implicitHeight: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Colors.surfaceContainerHighest }
                    Rectangle {
                        width: Math.max(6, parent.width * ServiceSystemInfo.diskUsage)
                        height: parent.height; radius: 3
                        color: ServiceSystemInfo.diskUsage > 0.9 ? Colors.error : Colors.primary
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    }
                }
                CustomText {
                    content: ServiceSystemInfo.diskUsedGb.toFixed(0) + "G"
                    size: 11; weight: 600; customColor: Colors.primary; Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                CustomText {
                    content: "/" + ServiceSystemInfo.diskTotalGb.toFixed(0) + "G"
                    size: 11; customColor: Colors.outline; Layout.preferredWidth: 30
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.outlineVariant; opacity: 0.4 }

            // ── Network ───────────────────────────────────────────────
            RowLayout { Layout.fillWidth: true; spacing: 4
                MaterialIconSymbol { content: "arrow_downward"; iconSize: 11; customColor: Colors.primary }
                CustomText {
                    content: ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netDownloadBps)
                    size: 11; customColor: Colors.surfaceText
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netUploadBps)
                    size: 11; customColor: Colors.surfaceText
                }
                MaterialIconSymbol { content: "arrow_upward"; iconSize: 11; customColor: Colors.tertiary }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
