pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property var actions: null
    signal opened(string key)

    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property DashWeather wx: DashWeather {}
    readonly property real battery: Math.max(0, Math.min(1, ServiceUPower.powerLevel ?? 0))
    readonly property var cores: ServiceSystemInfo.cpuCores ?? []
    readonly property var cpuHist: ServiceDashData.cpuHist
    readonly property real cpuPeak: root.cpuHist.length ? Math.max(...root.cpuHist) : 0
    readonly property var procs: ServiceDashData.processes.slice().sort((a, b) => b.mem - a.mem).slice(0, 7)
    readonly property real procMax: root.procs.length ? Math.max(0.1, root.procs[0].mem) : 1

    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return Math.round(bps / 1024) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    function memText(pct) {
        const gb = pct / 100 * ServiceSystemInfo.memTotalGb
        return gb >= 1 ? gb.toFixed(1) + " GB" : Math.round(gb * 1024) + " MB"
    }

    Component.onCompleted: ServiceDashData.retainProcesses()
    Component.onDestruction: ServiceDashData.releaseProcesses()

    readonly property var chips: [
                    { icon: root.wx.icon, text: root.wx.temp + ", " + root.wx.desc.toLowerCase() },
                    { icon: ServiceUPower.isCharging ? "battery_charging_full" : "battery_full", text: Math.round(root.battery * 100) + "%" },
                    { icon: "schedule", text: "Up " + ServiceProfile.uptimeText },
                    { icon: ServiceNetwork.activeInterface && ServiceNetwork.activeInterface.startsWith("e") ? "lan" : "wifi", text: ServiceNetwork.connectionLabel || "Offline" }
                ]
    readonly property var gauges: [
                    { label: "CPU", icon: "memory", value: ServiceSystemInfo.cpuUsage, v: Math.round(ServiceSystemInfo.cpuUsage * 100), unit: "percent", tint: Colors.primary,
                      rows: [{ k: "Threads", v: String(root.cores.length || ServiceDashData.cores) }, { k: "Recent peak", v: Math.round(root.cpuPeak * 100) + "%" }, { k: "Busiest thread", v: Math.round(Math.max(0, ...root.cores) * 100) + "%" }] },
                    { label: "Memory", icon: "memory_alt", value: ServiceSystemInfo.memUsage, v: Math.round(ServiceSystemInfo.memUsage * 100), unit: "percent", tint: Colors.primary,
                      rows: [{ k: "Used", v: ServiceSystemInfo.memUsedGb.toFixed(1) + " / " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB" }, { k: "Cached", v: (ServiceSystemInfo.memCacheFrac * ServiceSystemInfo.memTotalGb).toFixed(1) + " GB" }, { k: "Free", v: Math.max(0, ServiceSystemInfo.memTotalGb - ServiceSystemInfo.memUsedGb).toFixed(1) + " GB" }] },
                    { label: "Disk", icon: "hard_drive", value: ServiceSystemInfo.diskUsage, v: Math.round(ServiceSystemInfo.diskUsage * 100), unit: "percent", tint: Colors.primary,
                      rows: [{ k: "Used", v: ServiceSystemInfo.diskUsedGb.toFixed(0) + " GB" }, { k: "Free", v: Math.max(0, ServiceSystemInfo.diskTotalGb - ServiceSystemInfo.diskUsedGb).toFixed(0) + " GB" }, { k: "Size", v: ServiceSystemInfo.diskTotalGb.toFixed(0) + " GB" }] },
                    { label: "Temperature", icon: "thermostat", value: ServiceSystemInfo.cpuTemp / 100, v: Math.round(ServiceSystemInfo.cpuTemp), unit: "°C", tint: Colors.tertiary,
                      rows: [{ k: "CPU", v: Math.round(ServiceSystemInfo.cpuTemp) + " °C" }, { k: "GPU", v: ServiceSystemInfo.gpuTemp > 0 ? Math.round(ServiceSystemInfo.gpuTemp) + " °C" : "—" }, { k: "Recent peak", v: ServiceDashData.tempHist.length ? Math.round(Math.max(...ServiceDashData.tempHist)) + " °C" : "—" }] }
                ]

    implicitWidth: 980
    implicitHeight: 540

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 8
            Layout.rightMargin: 4
            spacing: 14

            DashDisplayClock { size: 38 }

            CustomText {
                content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month
                size: 15
                weight: 500
                customColor: Colors.surfaceVariantText
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: 4

                Rectangle {
                    id: chip
                    required property int index
                    readonly property var modelData: root.chips[index] ?? ({})
                    implicitWidth: chipRow.implicitWidth + 26
                    implicitHeight: 36
                    radius: 18
                    color: Colors.surfaceContainer

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 7
                        MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: chip.modelData.icon; iconSize: 18; fill: 1; customColor: Colors.tertiary }
                        CustomText { anchors.verticalCenter: parent.verticalCenter; content: chip.modelData.text; size: 13; weight: 600 }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 184
            Layout.maximumHeight: 184
            spacing: 10

            Repeater {
                model: 4

                CustomCard {
                    id: gauge
                    required property int index
                    readonly property var modelData: root.gauges[index] ?? ({})
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    autoRadius: false
                    topRadius: 28
                    bottomRadius: 28
                    color: Colors.surfaceContainer

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 2
                        spacing: 0

                        RowLayout {
                            Layout.leftMargin: 4
                            spacing: 8
                            MaterialIconSymbol { content: gauge.modelData.icon; iconSize: 18; customColor: Colors.surfaceVariantText }
                            CustomText { content: gauge.modelData.label; size: 14; weight: 700 }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 112
                                Layout.preferredHeight: 112

                                CustomGaugeProgress {
                                    anchors.fill: parent
                                    progress: Math.max(0, Math.min(1, gauge.modelData.value))
                                    thickness: 11
                                    showData: false
                                    baseColor: Colors.surfaceContainerHighest
                                    lineColor: gauge.modelData.tint
                                }

                                Column {
                                    anchors.centerIn: parent
                                    CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: String(gauge.modelData.v); family: root.displayFamily; size: 26; weight: 400 }
                                    CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: gauge.modelData.unit; size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 7

                                Repeater {
                                    model: (gauge.modelData.rows ?? []).length

                                    Column {
                                        id: row
                                        required property int index
                                        readonly property var modelData: gauge.modelData.rows[index] ?? ({})
                                        Layout.fillWidth: true
                                        CustomText { width: parent.width; content: row.modelData.k; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                                        CustomText { width: parent.width; content: row.modelData.v; size: 13; weight: 700 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: false
                Layout.preferredWidth: 562
                Layout.fillHeight: true
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin: 2
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: "CPU, last few minutes"; size: 14; weight: 700 }
                        CustomText { content: "Peak " + Math.round(root.cpuPeak * 100) + "%"; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Colors.surfaceContainerHigh

                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    x: 0
                                    y: parent.height * (index + 1) / 4
                                    width: parent.width
                                    height: 1
                                    color: Colors.surfaceContainerHighest
                                }
                            }

                            CustomSparkline {
                                anchors.fill: parent
                                anchors.topMargin: 8
                                values: root.cpuHist
                                maxPoints: ServiceDashData.historyPoints
                                maxOverride: Math.max(0.2, Math.ceil(root.cpuPeak * 5) / 5)
                                lineWidth: 2
                                cornerRadius: 14
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: false
                            Layout.preferredWidth: 150
                            Layout.maximumWidth: 150
                            Layout.fillHeight: true
                            spacing: 6

                            CustomText { content: "Per thread"; size: 12; weight: 500; customColor: Colors.surfaceVariantText }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 5

                                Repeater {
                                    model: root.cores.length

                                    Rectangle {
                                        id: coreBar
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 6
                                        color: Colors.surfaceContainerHighest

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Math.max(6, parent.height * Math.max(0, Math.min(1, root.cores[coreBar.index] ?? 0)))
                                            radius: 6
                                            color: Colors.primary
                                            Behavior on height { SpatialAnim {} }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18
                        MaterialIconSymbol { content: "download"; iconSize: 18; customColor: Colors.tertiary }
                        CustomText { Layout.leftMargin: -12; content: root.rate(ServiceSystemInfo.netDownloadBps); size: 13; weight: 600 }
                        MaterialIconSymbol { content: "upload"; iconSize: 18; customColor: Colors.surfaceVariantText }
                        CustomText { Layout.leftMargin: -12; content: root.rate(ServiceSystemInfo.netUploadBps); size: 13; weight: 600 }
                        Item { Layout.fillWidth: true }
                        CustomText { content: ServiceSystemInfo.netInterface || "No network"; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                    }
                }
            }

            CustomCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin: 2
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: "Top processes"; size: 14; weight: 700 }
                        CustomText { content: "by memory"; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    Repeater {
                        model: root.procs.length

                        RowLayout {
                            id: proc
                            required property int index
                            readonly property var p: root.procs[proc.index] ?? ({ name: "", mem: 0, cpu: 0 })
                            Layout.fillWidth: true
                            spacing: 10

                            CustomText { Layout.preferredWidth: 78; content: proc.p.name; size: 13; weight: 600 }
                            MeterSplitTrack { Layout.fillWidth: true; value: proc.p.mem / root.procMax; trackColor: Colors.surfaceContainerHighest }
                            CustomText { Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight; content: root.memText(proc.p.mem); size: 13; weight: 500 }
                            CustomText { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; content: (proc.p.cpu < 10 ? proc.p.cpu.toFixed(1) : Math.round(proc.p.cpu)) + "%"; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
