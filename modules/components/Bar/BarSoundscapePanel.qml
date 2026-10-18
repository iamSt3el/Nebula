import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property real maxHeight: 640

    readonly property var presets: [
        { name: "Rainy study",  icon: "menu_book",  levels: { rain: 60, window: 35, fire: 20 } },
        { name: "Café corner",  icon: "local_cafe", levels: { cafe: 60, rain: 25 } },
        { name: "Cabin night",  icon: "cabin",      levels: { fire: 55, cat: 35, night: 30 } },
        { name: "Seaside",      icon: "beach_access", levels: { waves: 65, stream: 15 } },
        { name: "Zen garden",   icon: "spa",        levels: { stream: 40, chimes: 45, night: 15 } },
        { name: "Breezy porch", icon: "deck",       levels: { chimes: 50, night: 30, rain: 15 } }
    ]

    implicitWidth: 360
    implicitHeight: Math.min(root.maxHeight, column.implicitHeight + 24)

    component SectionTitle: CustomText {
        Layout.topMargin: 8
        Layout.leftMargin: 4
        Layout.bottomMargin: 2
        size: 12
        weight: 600
        customColor: Colors.primary
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: CustomScrollBar {}

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 3

            CustomCard {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        CustomText {
                            content: "Soundscape"
                            size: 16
                            weight: 600
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: ServiceSoundscape.playing ? ServiceSoundscape.summary
                                   : ServiceSoundscape.active.length ? "Paused, " + ServiceSoundscape.summary.toLowerCase()
                                   : "Pick a mix below"
                            size: 12
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                    }

                    M3IconButton {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        icon: ServiceSoundscape.playing ? "pause" : "play_arrow"
                        iconSize: 24
                        iconFill: 1
                        square: ServiceSoundscape.playing
                        squareRadius: 16
                        color: Colors.primary
                        iconColor: Colors.primaryText
                        iconHoverColor: Colors.primaryText
                        onClicked: ServiceSoundscape.toggle()
                    }
                }
            }

            SectionTitle { content: "Mixes" }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.presets
                    Rectangle {
                        id: preset
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 44
                        radius: 14
                        color: presetArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8
                            MaterialIconSymbol {
                                content: preset.modelData.icon
                                iconSize: 18
                                fill: 1
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: preset.modelData.name
                                size: 13
                                weight: 500
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceSoundscape.preset(preset.modelData.levels)
                        }
                    }
                }
            }

            SectionTitle { content: "Sounds" }

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ServiceSoundscape.channels
                        RowLayout {
                            id: ch
                            required property var modelData
                            readonly property real lvl: ServiceSoundscape.level(ch.modelData.key)
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 12
                                color: ch.lvl > 0 ? Colors.secondaryContainer : Colors.surfaceContainerHighest
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: ch.modelData.icon
                                    iconSize: 18
                                    fill: 1
                                    customColor: ch.lvl > 0 ? Colors.primary : Colors.outline
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                CustomText {
                                    content: ch.modelData.name
                                    size: 12
                                    weight: 500
                                    customColor: ch.lvl > 0 ? Colors.surfaceText : Colors.surfaceVariantText
                                }
                                M3Slider {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    progress: ch.lvl / 100
                                    showValueLabel: false
                                    onMoved: v => ServiceSoundscape.setLevel(ch.modelData.key, v * 100)
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { content: "Overall" }

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIconSymbol {
                            content: "volume_up"
                            iconSize: 18
                            customColor: Colors.surfaceVariantText
                        }
                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            progress: ServiceSoundscape.master / 100
                            onMoved: v => ServiceSoundscape.setMaster(v * 100)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            CustomText { content: "Quieter while music plays"; size: 13 }
                            CustomText { content: "Drops to a third when a song starts"; size: 11; customColor: Colors.outline }
                        }
                        CustomToogle {
                            isToggleOn: ServiceSoundscape.duckWithMusic
                            onToggled: state => ServiceSoundscape.setDuck(state)
                        }
                    }
                }
            }

            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.leftMargin: 4
                content: "Recordings from Wikimedia Commons, credits in assets/soundscape"
                size: 10
                customColor: Colors.outline
                wrapMode: Text.WordWrap
            }
        }
    }
}
