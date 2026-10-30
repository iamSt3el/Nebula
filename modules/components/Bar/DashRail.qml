pragma ComponentBehavior: Bound

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    property var actions: null
    signal opened(string key)

    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property DashWeather wx: DashWeather {}
    readonly property real battery: Math.max(0, Math.min(1, ServiceUPower.powerLevel ?? 0))
    readonly property bool sunsetPast: { ServiceClock.minute; return root.wx.sunsetH >= 0 && new Date().getHours() + new Date().getMinutes() / 60 >= root.wx.sunsetH }

    readonly property var stats: [
                        { label: "CPU", icon: "memory", value: ServiceSystemInfo.cpuUsage, big: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%",
                          ctx: Math.round(ServiceSystemInfo.cpuTemp) + " °C", hist: ServiceDashData.cpuHist },
                        { label: "Memory", icon: "memory_alt", value: ServiceSystemInfo.memUsage, big: ServiceSystemInfo.memUsedGb.toFixed(1) + " GB",
                          ctx: Math.round(ServiceSystemInfo.memUsage * 100) + "% of " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB", hist: ServiceDashData.memHist },
                        { label: "Disk", icon: "hard_drive", value: ServiceSystemInfo.diskUsage, big: Math.round(ServiceSystemInfo.diskUsage * 100) + "%",
                          ctx: Math.max(0, ServiceSystemInfo.diskTotalGb - ServiceSystemInfo.diskUsedGb).toFixed(0) + " GB free", hist: null }
                    ]

    implicitWidth: 980
    implicitHeight: 540

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        CustomCard {
            Layout.fillWidth: false
            Layout.preferredWidth: 272
            Layout.fillHeight: true
            autoRadius: false
            topRadius: 28
            bottomRadius: 28
            color: Colors.surfaceContainer

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 12
                Layout.bottomMargin: 4
                spacing: 0

                DashDisplayClock {
                    size: 84
                    maxWidth: 228
                }

                CustomText {
                    Layout.topMargin: 16
                    content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month
                    size: 17
                    weight: 600
                }

                RowLayout {
                    Layout.topMargin: 12
                    spacing: 8

                    Rectangle {
                        implicitWidth: upText.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: Colors.tertiaryContainer

                        CustomText {
                            id: upText
                            anchors.centerIn: parent
                            content: "Up " + ServiceProfile.uptimeText
                            size: 12
                            weight: 700
                            customColor: Colors.tertiaryContainerText
                        }
                    }

                    CustomText {
                        content: SettingsConfig.profileName
                        size: 13
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: "cookie9"
                            color: Colors.tertiaryContainer
                        }

                        CustomText {
                            anchors.centerIn: parent
                            content: root.wx.temp
                            family: root.displayFamily
                            size: 26
                            weight: 400
                            customColor: Colors.tertiaryContainerText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 3

                        CustomText { Layout.fillWidth: true; content: root.wx.desc; size: 18; weight: 700 }
                        CustomText {
                            Layout.fillWidth: true
                            content: "High " + root.wx.hi + ", low " + root.wx.lo
                            size: 13
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                        CustomText {
                            Layout.fillWidth: true
                            visible: root.wx.sunset !== ""
                            content: (root.sunsetPast ? "Sunset was " : "Sunset at ") + root.wx.sunset
                            size: 13
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    implicitHeight: 78
                    radius: 18
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 0

                        Repeater {
                            model: root.wx.ok ? root.wx.upcomingHours(4) : []

                            ColumnLayout {
                                id: hr
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 5

                                CustomText { Layout.alignment: Qt.AlignHCenter; content: hr.modelData.label; size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                                MaterialIconSymbol { Layout.alignment: Qt.AlignHCenter; content: hr.modelData.icon; iconSize: 18; fill: 1; customColor: Colors.tertiary }
                                CustomText { Layout.alignment: Qt.AlignHCenter; content: hr.modelData.temp; size: 13; weight: 700 }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: 58
                    radius: 18
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        BatteryGlyph {
                            Layout.alignment: Qt.AlignVCenter
                            kind: "pill"
                            size: 26
                            showNumber: false
                            level: root.battery
                            charging: ServiceUPower.isCharging
                            plugged: !ServiceUPower.isCharging && !UPower.onBattery && UPower.displayDevice.isPresent
                            ground: Colors.surfaceContainerHigh
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            CustomText { content: Math.round(root.battery * 100) + "%"; size: 15; weight: 700 }
                            CustomText {
                                Layout.fillWidth: true
                                content: ServiceUPower.isCharging ? "Charging" : root.battery >= 0.99 ? "Full, on AC" : "On battery"
                                size: 12
                                weight: 500
                                customColor: Colors.surfaceVariantText
                            }
                        }

                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                id: media
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 228
                Layout.minimumHeight: 200
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    MusicArtwork {
                        Layout.preferredWidth: Math.min(media.height - 28, 240)
                        Layout.preferredHeight: Math.min(media.height - 28, 240)
                        cornerRadius: 22
                        placeholderIconSize: 64
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 4
                        spacing: 0

                        MusicSourceChip { visible: !!ServiceMusic.activePlayer }

                        CustomText {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            content: ServiceMusic.activeTrack?.title || "Nothing playing"
                            size: 22
                            weight: 700
                        }

                        CustomText {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            content: ServiceMusic.activeTrack?.artist ?? ""
                            size: 14
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }

                        Item { Layout.fillHeight: true }

                        MusicSeekBar { Layout.fillWidth: true; trackColor: Colors.surfaceContainerHighest }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            CustomText { Layout.fillWidth: true; content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                            CustomText { content: ServiceMusic.formatTime(ServiceMusic.trackLength); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                        }

                        DashPlayGroup {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            buttonHeight: 48
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 132
                Layout.maximumHeight: 132
                spacing: 10

                Repeater {
                    model: 3

                    CustomCard {
                        id: stat
                        required property int index
                        readonly property var modelData: root.stats[index] ?? ({})
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        autoRadius: false
                        topRadius: 24
                        bottomRadius: 24
                        color: Colors.surfaceContainer

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Item {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 60

                                    CustomGaugeProgress {
                                        anchors.fill: parent
                                        progress: stat.modelData.value
                                        thickness: 6
                                        showData: false
                                        baseColor: Colors.surfaceContainerHighest
                                        lineColor: Colors.primary
                                    }

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: stat.modelData.icon
                                        iconSize: 22
                                        customColor: Colors.surfaceVariantText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 0
                                    CustomText { content: stat.modelData.label; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                                    CustomText { content: stat.modelData.big; family: root.displayFamily; size: 22; weight: 400 }
                                    CustomText { Layout.fillWidth: true; content: stat.modelData.ctx; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                                }
                            }

                            CustomSparkline {
                                visible: !!stat.modelData.hist
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                values: stat.modelData.hist ?? []
                                maxPoints: ServiceDashData.historyPoints
                                maxOverride: 1
                                lineWidth: 2
                            }

                            Item {
                                visible: !stat.modelData.hist
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                MeterSplitTrack {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    height: 8
                                    value: stat.modelData.value
                                    trackColor: Colors.surfaceContainerHighest
                                }
                            }
                        }
                    }
                }
            }

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: controls.implicitHeight + 28
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: controls
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.actions ? root.actions.pick(["wifi", "bluetooth"]) : []

                            DashToggle {
                                required property var modelData
                                Layout.fillWidth: true
                                variant: "wide"
                                offColor: Colors.surfaceContainerHighest
                                info: modelData
                                expandable: true
                                onClicked: root.actions.fire(modelData.key)
                                onOpened: root.opened(modelData.key)
                            }
                        }

                        Repeater {
                            model: root.actions ? root.actions.pick(["dnd", "reading", "caffeine"]) : []

                            DashToggle {
                                required property var modelData
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                variant: "icon"
                                offColor: Colors.surfaceContainerHighest
                                info: modelData
                                onClicked: root.actions.fire(modelData.key)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        DashSliderRow { Layout.fillWidth: true; kind: "volume"; showIcon: true }
                        DashSliderRow { Layout.fillWidth: true; kind: "brightness"; showIcon: true }
                    }
                }
            }
        }
    }
}
