import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12
        visible: root.hasTrack

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            MusicShapeArt {
                Layout.preferredWidth: 74
                Layout.preferredHeight: 74
                decode: 160
                round: !ServiceMusic.isPlaying
                dim: ServiceMusic.isPlaying ? 0 : 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: ServiceMusic.activeTrack?.title ?? ""
                    font.family: root.displayFamily
                    font.pixelSize: 26
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                    color: Colors.surfaceText
                }
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceMusic.activeTrack?.artist ?? ""
                    size: 13
                    customColor: Colors.surfaceVariantText
                }
            }

            RowLayout {
                spacing: 6
                MusicRoundButton {
                    icon: "skip_previous"
                    side: 44
                    usable: ServiceMusic.canGoPrevious
                    onTapped: ServiceMusic.previous()
                }
                MusicRoundButton {
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    side: 54
                    filled: true
                    cornerRadius: ServiceMusic.isPlaying ? 18 : 27
                    usable: ServiceMusic.canTogglePlaying
                    onTapped: ServiceMusic.togglePlaying()
                }
                MusicRoundButton {
                    icon: "skip_next"
                    side: 44
                    usable: ServiceMusic.canGoNext
                    onTapped: ServiceMusic.next()
                }
            }
        }

        Item {
            id: beads
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            readonly property int count: Math.max(8, Math.floor(beads.width / 28))
            readonly property real step: beads.width / beads.count
            readonly property int current: Math.min(beads.count - 1, Math.floor(seek.shown * beads.count))

            Repeater {
                model: beads.count

                MaterialShapes.ShapeCanvas {
                    id: bead
                    required property int index
                    readonly property bool now: bead.index === beads.current
                    readonly property bool played: bead.index < beads.current
                    readonly property real side: bead.now ? 32 : 22

                    width: bead.side
                    height: bead.side
                    x: bead.index * beads.step + (beads.step - bead.side) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: bead.index * 11
                    roundedPolygon: bead.now ? "sunny" : "clover4"
                    color: bead.now ? Colors.tertiary : bead.played ? Colors.primary : "transparent"
                    borderWidth: bead.played || bead.now ? 0 : 2
                    borderColor: Colors.outlineVariant
                    Behavior on width { SpatialAnim { speed: "fast" } }
                    Behavior on height { SpatialAnim { speed: "fast" } }
                }
            }

            MusicSeekArea {
                id: seek
                anchors.fill: parent
            }
        }

        RowLayout {
            Layout.fillWidth: true
            CustomText {
                content: ServiceMusic.formatTime(seek.shown * ServiceMusic.trackLength)
                size: 11
                weight: 600
                customColor: Colors.primary
            }
            Item { Layout.fillWidth: true }
            MusicIconToggle { side: 28; kind: "shuffle" }
            MusicIconToggle { side: 28; kind: "repeat" }
            Item { Layout.fillWidth: true }
            CustomText {
                content: ServiceMusic.formatTime(ServiceMusic.trackLength)
                size: 11
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }
    }
}
