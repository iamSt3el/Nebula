pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property var actions: null
    signal opened(string key)

    readonly property DashWeather wx: DashWeather {}
    readonly property DashEvents ev: DashEvents {}
    readonly property real battery: Math.max(0, Math.min(1, ServiceUPower.powerLevel ?? 0))
    readonly property var next: root.ev.upcoming(1)[0] ?? null

    readonly property var bars: [
                            { label: "CPU", note: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%, " + Math.round(ServiceSystemInfo.cpuTemp) + " °C", value: ServiceSystemInfo.cpuUsage },
                            { label: "Memory", note: ServiceSystemInfo.memUsedGb.toFixed(1) + " of " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB", value: ServiceSystemInfo.memUsage },
                            { label: "Disk", note: Math.round(ServiceSystemInfo.diskUsage * 100) + "% used", value: ServiceSystemInfo.diskUsage },
                            { label: "Battery", note: Math.round(root.battery * 100) + "%" + (ServiceUPower.isCharging ? ", charging" : root.battery >= 0.99 ? ", on AC" : ""), value: root.battery }
                        ]

    implicitWidth: 980
    implicitHeight: 540

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        CustomCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 194
            autoRadius: false
            topRadius: 28
            bottomRadius: 28
            color: Colors.surfaceContainer

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 10
                Layout.rightMargin: 6
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                spacing: 20

                ColumnLayout {
                    Layout.preferredWidth: 214
                    Layout.fillHeight: true
                    spacing: 0

                    DashDisplayClock {
                        size: 66
                        maxWidth: 214
                    }

                    CustomText {
                        Layout.topMargin: 12
                        content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month
                        size: 16
                        weight: 600
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        spacing: 10
                        MaterialIconSymbol { content: root.wx.icon; iconSize: 30; fill: 1; customColor: Colors.tertiary }
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: root.wx.desc + ", " + root.wx.temp; size: 15; weight: 700 }
                            CustomText { content: "High " + root.wx.hi + ", low " + root.wx.lo; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                        }
                    }
                }

                DashDayRibbon {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    wx: root.wx
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: false
                Layout.preferredWidth: 368
                Layout.fillHeight: true
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        MusicArtwork {
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            cornerRadius: 18
                            placeholderIconSize: 36
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4

                            MusicSourceChip { visible: !!ServiceMusic.activePlayer }

                            CustomText {
                                Layout.fillWidth: true
                                content: ServiceMusic.activeTrack?.title || "Nothing playing"
                                size: 17
                                weight: 700
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                lineHeight: 1.1
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: ServiceMusic.activeTrack?.artist ?? ""
                                size: 13
                                weight: 500
                                customColor: Colors.surfaceVariantText
                            }
                        }
                    }

                    MusicSeekBar { Layout.fillWidth: true; Layout.topMargin: 14; trackColor: Colors.surfaceContainerHighest }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        CustomText { Layout.fillWidth: true; content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                        CustomText { content: ServiceMusic.formatTime(ServiceMusic.trackLength); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    DashPlayGroup {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        buttonHeight: 44
                        showToggles: false
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 18
                        color: Colors.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol { content: "speaker"; iconSize: 20; customColor: Colors.surfaceVariantText }
                            CustomText {
                                Layout.maximumWidth: 100
                                content: ServicePipewire.sink?.description || ServicePipewire.sink?.nickname || "Output"
                                size: 13
                                weight: 500
                            }
                            DashSliderRow { Layout.fillWidth: true; kind: "volume" }
                        }
                    }
                }
            }

            CustomCard {
                Layout.fillWidth: false
                Layout.preferredWidth: 290
                Layout.fillHeight: true
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    Layout.topMargin: 2
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: ServiceClock.month; size: 17; weight: 700 }
                        CustomText { content: ServiceClock.year; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    DashMonth {
                        Layout.fillWidth: true
                        cellH: 30
                        dots: true
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: 16
                        color: Colors.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol { content: root.next?.holiday ? "celebration" : "event"; iconSize: 20; fill: 1; customColor: Colors.tertiary }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0
                                CustomText { Layout.fillWidth: true; content: root.next ? root.next.title : "Nothing coming up"; size: 13; weight: 700 }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.next ? root.next.when : "Your next 60 days are clear"
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                        }
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
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 12

                    Repeater {
                        model: 4

                        ColumnLayout {
                            id: bar
                            required property int index
                            readonly property var modelData: root.bars[index] ?? ({})
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                CustomText { Layout.fillWidth: true; content: bar.modelData.label; size: 13; weight: 700 }
                                CustomText { content: bar.modelData.note; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                            }

                            MeterSplitTrack { Layout.fillWidth: true; value: bar.modelData.value; trackColor: Colors.surfaceContainerHighest }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.actions ? root.actions.pick(["wifi", "bluetooth", "dnd", "reading"]) : []

                            DashToggle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: "icon"
                                offColor: Colors.surfaceContainerHighest
                                info: modelData
                                onClicked: root.actions.fire(modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
