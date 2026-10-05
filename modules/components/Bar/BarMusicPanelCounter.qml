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
    readonly property real at: seek.shown * root.total

    readonly property int tickSec: {
        const steps = [4, 5, 10, 15, 30, 60, 120, 300, 600]
        for (const s of steps) {
            if (root.total / s <= 64)
                return s
        }
        return 900
    }
    readonly property int majorSec: root.tickSec < 60 ? 60 : root.tickSec < 300 ? 600 : 3600
    readonly property int tickCount: Math.max(1, Math.ceil(root.total / root.tickSec))
    readonly property int majorCount: Math.floor(root.total / root.majorSec) + 1

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 20
        spacing: 0
        visible: root.hasTrack

        RowLayout {
            spacing: 14

            Text {
                text: ServiceMusic.formatTime(root.at)
                font.family: root.displayFamily
                font.pixelSize: 92
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                color: ServiceMusic.isPlaying ? Colors.primary : Colors.outline
                Behavior on color { EffectsColorAnim {} }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 18
                spacing: 2
                CustomText {
                    content: "of " + ServiceMusic.formatTime(root.total)
                    size: 14
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    content: ServiceMusic.isPlaying
                        ? ServiceMusic.formatTime(Math.max(0, root.total - root.at)) + " left"
                        : "Paused"
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }
        }

        Item {
            id: ruler
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 28

            readonly property real step: ruler.width / root.tickCount

            Repeater {
                model: root.tickCount
                delegate: Rectangle {
                    required property int index
                    readonly property bool major: (index * root.tickSec) % root.majorSec === 0
                    x: Math.round(index * ruler.step)
                    y: ruler.height - height
                    width: 2
                    height: major ? 24 : 14
                    radius: 1
                    color: index * root.tickSec <= root.at ? Colors.primary : Colors.outlineVariant
                }
            }

            Rectangle {
                x: Math.round(ruler.width * seek.shown) - 1
                width: 3
                height: ruler.height
                radius: 1.5
                color: Colors.primary
                visible: root.total > 0
            }

            MusicSeekArea {
                id: seek
                anchors.fill: parent
                anchors.topMargin: -6
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 14

            Repeater {
                model: root.total > 0 ? root.majorCount : 0
                delegate: CustomText {
                    required property int index
                    x: Math.round(ruler.width * (index * root.majorSec) / root.total)
                    visible: x + implicitWidth <= ruler.width
                    content: ServiceMusic.formatTime(index * root.majorSec)
                    size: 10
                    weight: 400
                    customColor: Colors.outline
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MusicArtwork {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                cornerRadius: 14
                placeholderIconSize: 22
                interactive: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceMusic.activeTrack?.title ?? ""
                    size: 14
                    weight: 600
                    customColor: Colors.surfaceText
                }
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceMusic.activeTrack?.artist ?? ""
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }
            MusicRoundButton {
                icon: "skip_previous"
                side: 40
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            MusicRoundButton {
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                side: 52
                filled: true
                cornerRadius: ServiceMusic.isPlaying ? 18 : 26
                usable: ServiceMusic.canTogglePlaying
                onTapped: ServiceMusic.togglePlaying()
            }
            MusicRoundButton {
                icon: "skip_next"
                side: 40
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
        }
    }
}
