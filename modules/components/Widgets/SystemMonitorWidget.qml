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
    width: 265
    height: 288

    property bool editMode: false

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
        id: saveTimer
        interval: 500
        repeat: false
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
        onDoubleClicked: root.editMode = !root.editMode
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.editMode ? "#aaffffff" : "transparent"
        border.width: 2
        radius: 24
        visible: root.editMode
    }

    Connections {
        target: ServiceSystemInfo
        function onNetDownloadBpsChanged() {
            netSparkline.addValue(ServiceSystemInfo.netDownloadBps / 1024)
        }
    }

    // ── Card background ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Colors.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                spacing: 8

                MaterialShapes.ShapeCanvas {
                    implicitWidth: 28
                    implicitHeight: 28
                    roundedPolygon: MaterialShapeFn.getCookie6Sided()
                    color: Colors.primaryContainer

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "memory"
                        iconSize: 14
                        customColor: Colors.primaryText
                    }
                }

                CustomText { content: "System"; size: 13; weight: 600; customColor: Colors.primary }

                Item { Layout.fillWidth: true }

                CustomText {
                    content: ServiceSystemInfo.cpuName.length > 0
                        ? ServiceSystemInfo.cpuName.split(" ").slice(0, 3).join(" ")
                        : ""
                    size: 9
                    customColor: Colors.outline
                }
            }

            // ── Three arc gauges ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // ── CPU ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 76

                        CustomGaugeProgress {
                            anchors.fill: parent
                            progress: ServiceSystemInfo.cpuUsage
                            thickness: 5
                            gap: 0.3
                            showData: false
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -2

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: "developer_board"
                                iconSize: 13
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
                                size: 15
                                weight: 700
                                customColor: Colors.primary
                            }
                        }
                    }

                    CustomText { Layout.alignment: Qt.AlignHCenter; content: "CPU"; size: 11; customColor: Colors.outline }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: Math.round(ServiceSystemInfo.cpuTemp) + "°C"
                        size: 11
                        customColor: ServiceSystemInfo.cpuTemp > 80 ? Colors.error : Colors.surfaceText
                    }
                }

                // ── RAM ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 76

                        CustomGaugeProgress {
                            anchors.fill: parent
                            progress: ServiceSystemInfo.memUsage
                            thickness: 5
                            gap: 0.3
                            showData: false
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -2

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: "ad_units"
                                iconSize: 13
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: Math.round(ServiceSystemInfo.memUsage * 100) + "%"
                                size: 15
                                weight: 700
                                customColor: Colors.primary
                            }
                        }
                    }

                    CustomText { Layout.alignment: Qt.AlignHCenter; content: "RAM"; size: 11; customColor: Colors.outline }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceSystemInfo.memUsedGb.toFixed(1) + " GB"
                        size: 11
                        customColor: Colors.surfaceText
                    }
                }

                // ── GPU ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 76

                        CustomGaugeProgress {
                            anchors.fill: parent
                            progress: ServiceSystemInfo.gpuUsage
                            thickness: 5
                            gap: 0.3
                            showData: false
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -2

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: "display_settings"
                                iconSize: 13
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: Math.round(ServiceSystemInfo.gpuUsage * 100) + "%"
                                size: 15
                                weight: 700
                                customColor: Colors.primary
                            }
                        }
                    }

                    CustomText { Layout.alignment: Qt.AlignHCenter; content: "GPU"; size: 11; customColor: Colors.outline }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: Math.round(ServiceSystemInfo.gpuTemp) + "°C"
                        size: 11
                        customColor: ServiceSystemInfo.gpuTemp > 85 ? Colors.error : Colors.surfaceText
                    }
                }
            }

            // ── Separator ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.outlineVariant
                opacity: 0.4
            }

            // ── Network ───────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIconSymbol { content: "arrow_downward"; iconSize: 12; customColor: Colors.primary }
                    CustomText {
                        content: ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netDownloadBps)
                        size: 11
                        customColor: Colors.surfaceText
                    }
                    Item { Layout.fillWidth: true }
                    CustomText {
                        content: ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netUploadBps)
                        size: 11
                        customColor: Colors.surfaceText
                    }
                    MaterialIconSymbol { content: "arrow_upward"; iconSize: 12; customColor: Colors.tertiary }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    CustomSparkline {
                        id: netSparkline
                        anchors.fill: parent
                        lineColor: Colors.primary
                        fillColor: Qt.rgba(
                            Qt.color(Colors.primary).r,
                            Qt.color(Colors.primary).g,
                            Qt.color(Colors.primary).b,
                            0.12
                        )
                        maxPoints: 30
                        lineWidth: 1.5
                        filled: true
                    }
                }
            }

            // ── Disk ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialIconSymbol { content: "hard_drive"; iconSize: 12; customColor: Colors.outline }
                CustomText {
                    content: ServiceSystemInfo.diskUsedGb.toFixed(0) + " / " + ServiceSystemInfo.diskTotalGb.toFixed(0) + " GB"
                    size: 11
                    customColor: Colors.surfaceText
                }
                Item { Layout.fillWidth: true }

                // Pill progress bar
                Item {
                    implicitWidth: 60
                    implicitHeight: 6

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Colors.surfaceContainerHighest
                    }
                    Rectangle {
                        width: Math.max(6, parent.width * ServiceSystemInfo.diskUsage)
                        height: parent.height
                        radius: 3
                        color: ServiceSystemInfo.diskUsage > 0.9 ? Colors.error : Colors.primary

                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
