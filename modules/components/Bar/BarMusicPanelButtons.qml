import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property real total: ServiceMusic.trackLength
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property string subtitle: {
        const a = ServiceMusic.activeTrack?.artist ?? ""
        const b = ServiceMusic.activeTrack?.album ?? ""
        if (a !== "" && b !== "" && a !== b)
            return a + ", " + b
        return a !== "" ? a : b
    }
    readonly property var sink: ServicePipewire.sink

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0
        visible: root.hasTrack

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            MusicArtwork {
                Layout.preferredWidth: 116
                Layout.preferredHeight: 116
                cornerRadius: 28
                interactive: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: ServiceMusic.activeTrack?.title ?? ""
                    font.family: root.displayFamily
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                    color: Colors.surfaceText
                }
                CustomText {
                    Layout.fillWidth: true
                    content: root.subtitle
                    size: 13
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
                RowLayout {
                    Layout.topMargin: 4
                    spacing: 8

                    Chip {
                        icon: "music_note"
                        iconColor: Colors.tertiary
                        label: ServiceMusic.activeTrack?.identity ?? ""
                        visible: label !== ""
                    }
                    Chip {
                        id: outChip
                        readonly property var sinks: ServicePipewire.sinks
                        icon: "speaker"
                        label: root.sink?.description ?? ""
                        visible: label !== ""
                        clickable: outChip.sinks.length > 1
                        onTapped: {
                            const list = outChip.sinks
                            const i = list.indexOf(root.sink)
                            ServicePipewire.setAudioSink(list[(i + 1) % list.length])
                        }
                    }
                }
            }
        }

        Item {
            id: slider
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.preferredHeight: 32

            M3Slider {
                anchors.fill: parent
                progress: seek.shown
                interactive: false
                trackHeight: 16
                handleHeight: 32
                showValueLabel: false
            }

            MusicSeekArea {
                id: seek
                anchors.fill: parent
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            CustomText {
                content: ServiceMusic.formatTime(seek.shown * root.total)
                size: 11
                weight: 400
                customColor: Colors.outline
            }
            Item { Layout.fillWidth: true }
            CustomText {
                content: ServiceMusic.formatTime(root.total)
                size: 11
                weight: 400
                customColor: Colors.outline
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 2

            Group {
                icon: "shuffle"
                first: true
                baseWidth: 60
                toggled: ServiceMusic.hasShuffle
                usable: ServiceMusic.shuffleSupported
                onTapped: ServiceMusic.setShuffle(!ServiceMusic.hasShuffle)
            }
            Group {
                icon: "skip_previous"
                baseWidth: 72
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            Group {
                Layout.fillWidth: true
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                label: ServiceMusic.isPlaying ? "Pause" : "Play"
                accent: true
                usable: ServiceMusic.canTogglePlaying
                onTapped: ServiceMusic.togglePlaying()
            }
            Group {
                icon: "skip_next"
                baseWidth: 72
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
            Group {
                icon: ServiceMusic.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                last: true
                baseWidth: 60
                toggled: ServiceMusic.loopState !== MprisLoopState.None
                usable: ServiceMusic.loopSupported
                onTapped: {
                    const s = ServiceMusic.loopState
                    ServiceMusic.setLoopState(s === MprisLoopState.None ? MprisLoopState.Playlist
                                            : s === MprisLoopState.Playlist ? MprisLoopState.Track
                                            : MprisLoopState.None)
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property color iconColor: Colors.surfaceVariantText
        property bool clickable: false
        signal tapped

        implicitWidth: Math.min(170, chipRow.implicitWidth + 20)
        implicitHeight: 28
        radius: 8
        color: chipArea.containsMouse && chip.clickable ? Colors.surfaceContainerHigh : "transparent"
        border.width: 1
        border.color: Colors.outlineVariant

        RowLayout {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            width: chip.width - 18
            spacing: 6
            MaterialIconSymbol {
                content: chip.icon
                iconSize: 16
                fill: 1
                customColor: chip.iconColor
            }
            CustomText {
                Layout.fillWidth: true
                content: chip.label
                size: 11
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.tapped()
        }
    }

    component Group: Rectangle {
        id: grp
        property string icon: ""
        property string label: ""
        property bool first: false
        property bool last: false
        property bool accent: false
        property bool toggled: false
        property bool usable: true
        property real baseWidth: 60
        signal tapped

        readonly property bool down: grpArea.pressed
        readonly property real inner: grp.down ? 28 : 8

        property real growW: grp.down ? 12 : 0
        Behavior on growW { SpatialAnim { speed: "fast" } }

        Layout.preferredWidth: grp.baseWidth + grp.growW
        Layout.preferredHeight: 56
        topLeftRadius: grp.first ? 28 : grp.inner
        bottomLeftRadius: grp.first ? 28 : grp.inner
        topRightRadius: grp.last ? 28 : grp.inner
        bottomRightRadius: grp.last ? 28 : grp.inner
        opacity: grp.usable ? 1 : 0.4
        color: grp.accent ? (grpArea.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
             : grp.toggled ? Colors.secondaryContainer
             : grpArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

        Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim {} }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            MaterialIconSymbol {
                content: grp.icon
                iconSize: grp.accent ? 26 : 24
                fill: 1
                customColor: grp.accent ? Colors.primaryText
                           : grp.toggled ? Colors.secondaryContainerText : Colors.surfaceText
            }
            CustomText {
                visible: grp.label !== ""
                content: grp.label
                size: 14
                weight: 600
                customColor: Colors.primaryText
            }
        }

        MouseArea {
            id: grpArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: grp.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: grp.tapped()
        }
    }
}
