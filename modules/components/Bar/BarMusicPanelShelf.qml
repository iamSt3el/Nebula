import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property real elapsed: ServiceMusic.activePlayer?.position ?? 0
    readonly property real total: ServiceMusic.trackLength
    readonly property var sink: ServicePipewire.sink
    readonly property bool roomy: root.width >= 760

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
        hint: ""
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 22
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 18
        visible: root.hasTrack

        MusicArtwork {
            Layout.preferredWidth: 76
            Layout.preferredHeight: 76
            cornerRadius: 18
            placeholderIconSize: 28
            interactive: true
        }

        ColumnLayout {
            Layout.preferredWidth: 140
            Layout.maximumWidth: 140
            spacing: 2

            CustomMarqueeText {
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.title ?? ""
                size: 15
                weight: 600
                customColor: Colors.surfaceText
                scrolling: ServiceMusic.isPlaying
            }
            CustomText {
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 12
                weight: 500
                customColor: Colors.surfaceVariantText
            }
            MusicSourceChip { Layout.topMargin: 4 }
        }

        RowLayout {
            spacing: 6
            MusicRoundButton {
                icon: "skip_previous"
                side: 40
                tone: "transparent"
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            MusicRoundButton {
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                side: 52
                filled: true
                usable: ServiceMusic.canTogglePlaying
                onTapped: ServiceMusic.togglePlaying()
            }
            MusicRoundButton {
                icon: "skip_next"
                side: 40
                tone: "transparent"
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            CustomText {
                content: ServiceMusic.formatTime(root.elapsed)
                size: 11
                weight: 500
                customColor: Colors.primary
            }
            MusicSeekBar { Layout.fillWidth: true }
            CustomText {
                content: ServiceMusic.formatTime(root.total)
                size: 11
                weight: 400
                customColor: Colors.outline
            }
        }

        Rectangle {
            visible: root.roomy
            Layout.preferredWidth: 1
            Layout.preferredHeight: 44
            color: Colors.surfaceContainerHigh
        }

        RowLayout {
            visible: root.roomy
            spacing: 6

            MaterialIconSymbol {
                content: ServicePipewire.muted ? "volume_off" : "volume_down"
                iconSize: 18
                customColor: Colors.surfaceVariantText

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServicePipewire.toggleMute()
                }
            }
            M3Slider {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 24
                progress: Math.min(1, ServicePipewire.volume)
                showValueLabel: false
                showStopIndicator: false
                inactiveColor: Colors.surfaceContainerHighest
                onMoved: v => ServicePipewire.setVolume(v)
            }
        }

        Rectangle {
            id: outChip
            readonly property var sinks: ServicePipewire.sinks
            readonly property bool many: outChip.sinks.length > 1
            visible: root.roomy && (root.sink?.description ?? "") !== ""
            Layout.preferredWidth: Math.min(150, outRow.implicitWidth + 22)
            Layout.preferredHeight: 32
            radius: 16
            color: outArea.containsMouse && outChip.many ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
            Behavior on color { EffectsColorAnim {} }

            RowLayout {
                id: outRow
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                width: outChip.width - 20
                spacing: 6
                MaterialIconSymbol {
                    content: "speaker"
                    iconSize: 16
                    fill: 1
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.fillWidth: true
                    content: root.sink?.description ?? ""
                    size: 11
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }

            MouseArea {
                id: outArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: outChip.many
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const list = outChip.sinks
                    const i = list.indexOf(root.sink)
                    ServicePipewire.setAudioSink(list[(i + 1) % list.length])
                }
            }
        }
    }
}
