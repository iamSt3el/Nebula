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
    readonly property var week: root.wx.week(7)
    readonly property var agenda: root.ev.upcoming(4)
    readonly property int maxRain: root.week.length ? Math.max(...root.week.map(d => d.rain)) : 0

    readonly property var semis: [
                                    { label: "CPU", value: ServiceSystemInfo.cpuUsage },
                                    { label: "Memory", value: ServiceSystemInfo.memUsage },
                                    { label: "Disk", value: ServiceSystemInfo.diskUsage }
                                ]

    implicitWidth: 980
    implicitHeight: 540

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 296
            Layout.maximumWidth: 296
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: clockCol.implicitHeight + 34
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.tertiaryContainer

                ColumnLayout {
                    id: clockCol
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    spacing: 10

                    DashDisplayClock {
                        size: 62
                        maxWidth: 220
                        ink: Colors.tertiaryContainerText
                        accent: Colors.tertiaryText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month; size: 15; weight: 700; customColor: Colors.tertiaryContainerText }
                        CustomText { content: "Up " + ServiceProfile.uptimeText; size: 12; weight: 600; customColor: Colors.tertiaryContainerText }
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
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: ServiceClock.month; size: 17; weight: 700 }
                        CustomText { content: ServiceClock.year; size: 13; weight: 500; customColor: Colors.surfaceVariantText }
                    }

                    DashMonth {
                        Layout.fillWidth: true
                        cellH: 42
                        dots: true
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 226
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
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        CustomText { Layout.fillWidth: true; content: "Next seven days"; size: 14; weight: 700 }
                        CustomText {
                            content: root.maxRain < 20 ? "Dry all week" : "Up to " + root.maxRain + "% chance of rain"
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    DashForecast {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        days: root.week
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

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
                        Layout.bottomMargin: 2
                        spacing: 10

                        CustomText { content: "Coming up"; size: 14; weight: 700 }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Repeater {
                                model: root.agenda.length

                                Rectangle {
                                    id: item
                                    required property int index
                                    readonly property var e: root.agenda[item.index] ?? ({})
                                    readonly property bool first: item.index === 0
                                    readonly property bool last: item.index === root.agenda.length - 1
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    topLeftRadius: item.first ? 18 : 6
                                    topRightRadius: item.first ? 18 : 6
                                    bottomLeftRadius: item.last ? 18 : 6
                                    bottomRightRadius: item.last ? 18 : 6
                                    color: Colors.surfaceContainerHigh

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 11
                                            color: item.e.today ? Colors.tertiaryContainer : Colors.surfaceContainerHighest

                                            Column {
                                                anchors.centerIn: parent
                                                CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: item.e.day ?? ""; size: 14; weight: 800; customColor: item.e.today ? Colors.tertiaryContainerText : Colors.surfaceText }
                                                CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: item.e.mon ?? ""; size: 9; weight: 600; customColor: item.e.today ? Colors.tertiaryContainerText : Colors.surfaceVariantText }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 0
                                            CustomText { Layout.fillWidth: true; content: item.e.title ?? ""; size: 13; weight: 700 }
                                            CustomText { Layout.fillWidth: true; content: item.e.when ?? ""; size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                                        }
                                    }
                                }
                            }

                            CustomText {
                                visible: root.agenda.length === 0
                                Layout.fillWidth: true
                                content: "Nothing in the next 60 days"
                                size: 13
                                weight: 500
                                customColor: Colors.outline
                            }
                        }

                        Item { Layout.fillHeight: true }
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
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 18
                            color: Colors.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 10

                                MusicArtwork {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    cornerRadius: 12
                                    placeholderIconSize: 18
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 0
                                    CustomText { Layout.fillWidth: true; content: ServiceMusic.activeTrack?.title || "Nothing playing"; size: 13; weight: 700 }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: (ServiceMusic.activeTrack?.artist ?? "") + (ServiceMusic.trackLength > 0 ? ", " + ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0) + " of " + ServiceMusic.formatTime(ServiceMusic.trackLength) : "")
                                        size: 11
                                        weight: 500
                                        customColor: Colors.surfaceVariantText
                                    }
                                }

                                M3IconButton {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    square: true
                                    squareRadius: 14
                                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                                    iconSize: 22
                                    color: Colors.primary
                                    iconColor: Colors.primaryText
                                    iconHoverColor: Colors.primaryText
                                    onClicked: if (ServiceMusic.canTogglePlaying) ServiceMusic.togglePlaying()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 14
                            spacing: 0

                            Repeater {
                                model: 3

                                ColumnLayout {
                                    id: semi
                                    required property int index
                                    readonly property var modelData: root.semis[index] ?? ({})
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 4

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 68
                                        Layout.preferredHeight: 68

                                        CustomGaugeProgress {
                                            anchors.fill: parent
                                            progress: Math.max(0, Math.min(1, semi.modelData.value))
                                            thickness: 7
                                            showData: false
                                            baseColor: Colors.surfaceContainerHighest
                                            lineColor: Colors.primary
                                        }

                                        CustomText {
                                            anchors.centerIn: parent
                                            content: Math.round(semi.modelData.value * 100) + "%"
                                            size: 14
                                            weight: 700
                                        }
                                    }

                                    CustomText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; content: semi.modelData.label; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.actions ? root.actions.pick(["wifi", "bluetooth", "dnd", "reading", "caffeine"]) : []

                                DashToggle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
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
}
