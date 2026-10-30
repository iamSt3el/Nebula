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

    readonly property DashWeather wx: DashWeather {}
    readonly property real battery: Math.max(0, Math.min(1, ServiceUPower.powerLevel ?? 0))

    readonly property var lines: [
        { icon: root.wx.icon, tint: Colors.tertiary,
          text: !root.wx.ok ? "No weather right now"
              : root.wx.desc + " and " + root.wx.temp + " now, " + (root.wx.night ? root.wx.lo + " by morning" : "high of " + root.wx.hi + " today") },
        { icon: ServiceUPower.isCharging ? "battery_charging_full" : "battery_full", tint: Colors.primary,
          text: ServiceUPower.isCharging ? "Charging, " + Math.round(root.battery * 100) + "%"
              : root.battery >= 0.99 ? "Battery full and plugged in" : "Battery at " + Math.round(root.battery * 100) + "%" },
        { icon: "schedule", tint: Colors.primary, text: "Up for " + ServiceProfile.uptimeText },
        { icon: "memory", tint: Colors.primary,
          text: "CPU at " + Math.round(ServiceSystemInfo.cpuUsage * 100) + "%, " + ServiceSystemInfo.memUsedGb.toFixed(1) + " of "
              + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB memory in use" }
    ]

    implicitWidth: 980
    implicitHeight: 540

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        CustomCard {
            id: poster
            Layout.fillWidth: true
            Layout.fillHeight: true
            autoRadius: false
            topRadius: 28
            bottomRadius: 28
            color: Colors.surfaceContainer

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                Layout.topMargin: 12
                Layout.bottomMargin: 8
                spacing: 0

                DashDisplayClock {
                    size: 150
                    maxWidth: poster.width - 60
                }

                CustomText {
                    Layout.topMargin: 20
                    content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month
                    size: 26
                    weight: 700
                }

                ColumnLayout {
                    Layout.topMargin: 18
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.lines.length

                        RowLayout {
                            id: line
                            required property int index
                            readonly property var modelData: root.lines[index] ?? ({})
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 18
                                color: Colors.surfaceContainerHighest

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: line.modelData.icon
                                    iconSize: 20
                                    fill: 1
                                    customColor: line.modelData.tint
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: line.modelData.text
                                size: 17
                                weight: 500
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.actions ? root.actions.pick(["wifi", "bluetooth"]) : []

                        DashToggle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 160
                            Layout.maximumWidth: 180
                            Layout.preferredHeight: 48
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
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            variant: "icon"
                            offColor: Colors.surfaceContainerHighest
                            info: modelData
                            onClicked: root.actions.fire(modelData.key)
                        }
                    }

                    Repeater {
                        model: [{ icon: "power_settings_new", label: "Power", act: "power" }]

                        M3IconButton {
                            required property var modelData
                            implicitWidth: 48
                            implicitHeight: 48
                            icon: modelData.icon
                            iconSize: 22
                            color: Colors.surfaceContainerHighest
                            onClicked: if (root.actions) root.actions[modelData.act]()
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 356
            Layout.maximumWidth: 356
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: cal.implicitHeight + 32
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: cal
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: ServiceClock.month; size: 17; weight: 700 }
                        CustomText { content: ServiceClock.year; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    DashMonth {
                        Layout.fillWidth: true
                        cellH: 36
                        textSize: 14
                        cookie: true
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
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        MusicArtwork {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            cornerRadius: 16
                            placeholderIconSize: 28
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2
                            CustomText { Layout.fillWidth: true; content: ServiceMusic.activeTrack?.title || "Nothing playing"; size: 15; weight: 700 }
                            CustomText {
                                Layout.fillWidth: true
                                content: (ServiceMusic.activeTrack?.artist ?? "") + (ServiceMusic.activeTrack?.identity ? ", in " + ServiceMusic.activeTrack.identity : "")
                                size: 13
                                weight: 500
                                customColor: Colors.surfaceVariantText
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 16
                        color: Colors.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol { content: "speaker"; iconSize: 20; customColor: Colors.surfaceVariantText }
                            CustomText {
                                Layout.maximumWidth: 96
                                content: ServicePipewire.sink?.description || ServicePipewire.sink?.nickname || "Output"
                                size: 13
                                weight: 500
                            }
                            DashSliderRow { Layout.fillWidth: true; kind: "volume" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3IconButton {
                            implicitWidth: 48
                            implicitHeight: 48
                            square: true
                            squareRadius: 16
                            icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                            iconSize: 26
                            color: Colors.primary
                            iconColor: Colors.primaryText
                            iconHoverColor: Colors.primaryText
                            onClicked: if (ServiceMusic.canTogglePlaying) ServiceMusic.togglePlaying()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            MusicSeekBar { Layout.fillWidth: true; trackColor: Colors.surfaceContainerHighest }
                            RowLayout {
                                Layout.fillWidth: true
                                CustomText { Layout.fillWidth: true; content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0); size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                                CustomText { content: ServiceMusic.formatTime(ServiceMusic.trackLength); size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                            }
                        }

                        M3IconButton {
                            implicitWidth: 40
                            implicitHeight: 40
                            icon: "skip_next"
                            iconSize: 22
                            color: Colors.surfaceContainerHighest
                            opacity: ServiceMusic.canGoNext ? 1 : 0.4
                            onClicked: if (ServiceMusic.canGoNext) ServiceMusic.next()
                        }
                    }
                }
            }
        }
    }
}
