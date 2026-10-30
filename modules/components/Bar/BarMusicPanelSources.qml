import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property var shapes: ["cookie9", "clover4", "pentagon", "sunny", "gem", "flower"]

    function iconFor(identity) {
        const s = (identity ?? "").toLowerCase()
        if (s.indexOf("spotify") >= 0)
            return "graphic_eq"
        if (/firefox|zen|chrom|brave|vivaldi|librewolf|floorp|edge/.test(s))
            return "language"
        if (/mpv|vlc|celluloid|totem|haruna/.test(s))
            return "movie"
        return "music_note"
    }

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14
        visible: root.hasTrack

        Rectangle {
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            radius: 26
            color: Colors.surfaceContainer

            Flickable {
                anchors.fill: parent
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                clip: true
                contentHeight: rail.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rail
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: Mpris.players

                        Item {
                            id: src
                            required property var modelData
                            required property int index
                            readonly property bool current: src.modelData === ServiceMusic.activePlayer
                            readonly property real side: src.current ? 58 : 46

                            width: rail.width
                            height: src.side + 22

                            MaterialShapes.ShapeCanvas {
                                id: srcShape
                                width: src.side
                                height: src.side
                                anchors.horizontalCenter: parent.horizontalCenter
                                roundedPolygon: root.shapes[src.index % root.shapes.length]
                                color: src.current ? Colors.primary
                                     : srcArea.containsMouse ? Colors.surfaceContainerHighest : Colors.secondaryContainer
                                Behavior on width { SpatialAnim { speed: "fast" } }
                                Behavior on height { SpatialAnim { speed: "fast" } }
                                Behavior on color { EffectsColorAnim { speed: "fast" } }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: root.iconFor(src.modelData.identity)
                                    iconSize: src.current ? 26 : 22
                                    fill: 1
                                    customColor: src.current ? Colors.primaryText : Colors.secondaryContainerText
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Colors.tertiary
                                    border.width: 2
                                    border.color: Colors.surfaceContainer
                                    visible: src.modelData.isPlaying
                                }
                            }

                            CustomText {
                                anchors.top: srcShape.bottom
                                anchors.topMargin: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: rail.width - 10
                                horizontalAlignment: Text.AlignHCenter
                                content: src.modelData.identity ?? ""
                                size: 10
                                weight: src.current ? 600 : 500
                                customColor: src.current ? Colors.primary : Colors.surfaceVariantText
                            }

                            MouseArea {
                                id: srcArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceMusic.setActivePlayer(src.modelData)
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            MusicShapeArt {
                Layout.preferredWidth: 146
                Layout.preferredHeight: 146
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                decode: 300
                round: !ServiceMusic.isPlaying
                dim: ServiceMusic.isPlaying ? 0 : 1
            }

            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 12
                horizontalAlignment: Text.AlignHCenter
                content: ServiceMusic.activeTrack?.title ?? ""
                size: 18
                weight: 600
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                horizontalAlignment: Text.AlignHCenter
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 13
                customColor: Colors.surfaceVariantText
            }

            Item {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                Layout.topMargin: 10

                readonly property real split: Math.round(track.width * seek.shown)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, track.split - 6)
                    height: 10
                    radius: 5
                    topRightRadius: 2
                    bottomRightRadius: 2
                    color: Colors.primary
                    visible: width > 0
                }
                Rectangle {
                    x: track.split - 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: seek.active ? 26 : 22
                    radius: 2
                    color: Colors.primary
                    Behavior on height { SpatialAnim { speed: "fast" } }
                }
                Rectangle {
                    x: track.split + 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, track.width - x)
                    height: 10
                    radius: 5
                    topLeftRadius: 2
                    bottomLeftRadius: 2
                    color: Colors.surfaceContainerHighest
                    visible: width > 0
                }
                MusicSeekArea {
                    id: seek
                    anchors.fill: parent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                CustomText {
                    content: ServiceMusic.formatTime(seek.shown * ServiceMusic.trackLength)
                    size: 11
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceMusic.formatTime(ServiceMusic.trackLength)
                    size: 11
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                MusicRoundButton {
                    icon: "skip_previous"
                    side: 46
                    usable: ServiceMusic.canGoPrevious
                    onTapped: ServiceMusic.previous()
                }
                MusicRoundButton {
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    side: 58
                    filled: true
                    cornerRadius: ServiceMusic.isPlaying ? 20 : 29
                    usable: ServiceMusic.canTogglePlaying
                    onTapped: ServiceMusic.togglePlaying()
                }
                MusicRoundButton {
                    icon: "skip_next"
                    side: 46
                    usable: ServiceMusic.canGoNext
                    onTapped: ServiceMusic.next()
                }
            }
        }
    }
}
