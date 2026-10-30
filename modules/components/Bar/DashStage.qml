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
    readonly property var history: ServiceMusicHistory.entries.slice(0, 2)
    readonly property real remaining: Math.max(0, ServiceMusic.trackLength - (ServiceMusic.activePlayer?.position ?? 0))

    readonly property var rings: [
                            { label: "CPU", value: ServiceSystemInfo.cpuUsage },
                            { label: "Memory", value: ServiceSystemInfo.memUsage },
                            { label: "Disk", value: ServiceSystemInfo.diskUsage },
                            { label: "Battery", value: root.battery }
                        ]

    implicitWidth: 980
    implicitHeight: 540

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        CustomCard {
            Layout.fillWidth: false
            Layout.preferredWidth: 590
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
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 196
                    spacing: 20

                    MusicArtwork {
                        Layout.preferredWidth: 196
                        Layout.preferredHeight: 196
                        cornerRadius: 28
                        placeholderIconSize: 72
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 4
                        spacing: 0

                        MusicSourceChip { visible: !!ServiceMusic.activePlayer }

                        CustomText {
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            content: ServiceMusic.activeTrack?.title || "Nothing playing"
                            size: 26
                            weight: 700
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            lineHeight: 1.1
                        }

                        CustomText {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            content: ServiceMusic.activeTrack?.artist ?? ""
                            size: 15
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }

                        Item { Layout.fillHeight: true }

                        MusicSeekBar { Layout.fillWidth: true; trackColor: Colors.surfaceContainerHighest }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            CustomText { Layout.fillWidth: true; content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                            CustomText { content: "-" + ServiceMusic.formatTime(root.remaining); size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                        }
                    }
                }

                DashPlayGroup {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    buttonHeight: 56
                    cookie: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    implicitHeight: 48
                    radius: 18
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10
                        MaterialIconSymbol { content: "speaker"; iconSize: 20; customColor: Colors.surfaceVariantText }
                        CustomText {
                            Layout.maximumWidth: 180
                            content: ServicePipewire.sink?.description || ServicePipewire.sink?.nickname || "Output"
                            size: 13
                            weight: 500
                        }
                        DashSliderRow { Layout.fillWidth: true; kind: "volume" }
                    }
                }

                CustomText {
                    Layout.topMargin: 12
                    content: "Played earlier"
                    size: 13
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 4

                    Repeater {
                        model: root.history.length

                        Rectangle {
                            id: played
                            required property int index
                            readonly property var e: root.history[played.index] ?? ({})
                            Layout.fillWidth: true
                            implicitHeight: 50
                            topLeftRadius: played.index === 0 ? 16 : 6
                            topRightRadius: played.index === 0 ? 16 : 6
                            bottomLeftRadius: played.index === root.history.length - 1 ? 16 : 6
                            bottomRightRadius: played.index === root.history.length - 1 ? 16 : 6
                            color: Colors.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: 10
                                    color: Colors.surfaceContainerHighest
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: status === Image.Ready
                                        source: played.e.artUrl ?? ""
                                        sourceSize: Qt.size(72, 72)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        visible: !(played.e.artUrl)
                                        content: "music_note"
                                        iconSize: 18
                                        customColor: Colors.outline
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 0
                                    CustomText { Layout.fillWidth: true; content: played.e.title ?? ""; size: 13; weight: 600 }
                                    CustomText { Layout.fillWidth: true; content: played.e.artist ?? ""; size: 11; weight: 500; customColor: Colors.surfaceVariantText }
                                }

                                CustomText {
                                    content: played.e.at ? ServiceMusicHistory.ago(played.e.at) : ""
                                    size: 11
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                        }
                    }

                    CustomText {
                        visible: root.history.length === 0
                        Layout.fillWidth: true
                        content: "Songs you play show up here"
                        size: 13
                        weight: 500
                        customColor: Colors.outline
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: clockCol.implicitHeight + 34
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: clockCol
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        DashDisplayClock { Layout.alignment: Qt.AlignBottom; size: 58; maxWidth: 190 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.alignment: Qt.AlignBottom
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
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: ServiceClock.day + ", " + parseInt(ServiceClock.date) + " " + ServiceClock.month; size: 14; weight: 600 }
                        CustomText { content: SettingsConfig.profileName; size: 14; weight: 500; customColor: Colors.surfaceVariantText }
                    }
                }
            }

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 14

                    MaterialIconSymbol { content: root.wx.icon; iconSize: 40; fill: 1; customColor: Colors.tertiary }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        RowLayout {
                            spacing: 8
                            CustomText { content: root.wx.temp; family: root.displayFamily; size: 28; weight: 400 }
                            CustomText { content: root.wx.desc; size: 15; weight: 700 }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: "High " + root.wx.hi + ", low " + root.wx.lo + (root.wx.sunset ? ", sunset " + root.wx.sunset : "")
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
            }

            CustomCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                autoRadius: false
                topRadius: 28
                bottomRadius: 28
                color: Colors.surfaceContainer

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Repeater {
                        model: 4

                        ColumnLayout {
                            id: ring
                            required property int index
                            readonly property var modelData: root.rings[index] ?? ({})
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 6

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 58

                                CustomCircularProgressBar {
                                    anchors.fill: parent
                                    progress: Math.max(0, Math.min(1, ring.modelData.value))
                                    thickness: 6
                                    radius: width / 2 - thickness / 2
                                    showText: false
                                    baseColor: Colors.surfaceContainerHighest
                                    lineColor: Colors.primary
                                }

                                CustomText {
                                    anchors.centerIn: parent
                                    content: Math.round(ring.modelData.value * 100) + "%"
                                    size: 13
                                    weight: 700
                                }
                            }

                            CustomText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; content: ring.modelData.label; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
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
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.actions ? root.actions.pick(["wifi", "bluetooth"]) : []

                            DashToggle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 52
                                variant: "wide"
                                offColor: Colors.surfaceContainerHighest
                                info: modelData
                                expandable: true
                                onClicked: root.actions.fire(modelData.key)
                                onOpened: root.opened(modelData.key)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.actions ? root.actions.pick(["dnd", "reading", "caffeine", "mic"]) : []

                            DashToggle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 48
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
