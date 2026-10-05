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
    readonly property real elapsed: ServiceMusic.activePlayer?.position ?? 0
    readonly property real total: ServiceMusic.trackLength
    readonly property real progress: root.total > 0 ? Math.max(0, Math.min(1, root.elapsed / root.total)) : 0
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 22
        visible: root.hasTrack

        Item {
            Layout.preferredWidth: 196
            Layout.preferredHeight: 196
            Layout.alignment: Qt.AlignVCenter

            MaterialShapes.ShapeCanvas {
                anchors.fill: parent
                roundedPolygon: art.shape
                color: "transparent"
                strokeProgress: root.progress
                strokeWidth: 4
                strokeColor: Colors.primary
                strokeTrackColor: Colors.surfaceContainerHighest
            }

            MusicShapeArt {
                id: art
                anchors.centerIn: parent
                width: 176
                height: 176
                decode: 360
                round: !ServiceMusic.isPlaying
                dim: ServiceMusic.isPlaying ? 0 : 1
            }

            MouseArea {
                anchors.fill: art
                cursorShape: Qt.PointingHandCursor
                enabled: ServiceMusic.canTogglePlaying
                onClicked: ServiceMusic.togglePlaying()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: ServiceMusic.activeTrack?.title ?? ""
                font.family: root.displayFamily
                font.pixelSize: 22
                lineHeight: 0.95
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                renderType: Text.QtRendering
                color: Colors.surfaceText
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 5
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 13
                weight: 500
                customColor: Colors.surfaceVariantText
            }
            Text {
                Layout.topMargin: 6
                textFormat: Text.StyledText
                text: "<font color=\"" + Colors.primary + "\">" + ServiceMusic.formatTime(root.elapsed)
                    + "</font> of " + ServiceMusic.formatTime(root.total)
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                font.pixelSize: 12
                color: Colors.outline
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                spacing: 8
                MusicRoundButton {
                    icon: "skip_previous"
                    side: 42
                    usable: ServiceMusic.canGoPrevious
                    onTapped: ServiceMusic.previous()
                }
                MusicRoundButton {
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    side: 60
                    filled: true
                    cornerRadius: ServiceMusic.isPlaying ? 22 : 30
                    usable: ServiceMusic.canTogglePlaying
                    onTapped: ServiceMusic.togglePlaying()
                }
                MusicRoundButton {
                    icon: "skip_next"
                    side: 42
                    usable: ServiceMusic.canGoNext
                    onTapped: ServiceMusic.next()
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                MusicIconToggle { kind: "shuffle" }
                MusicIconToggle { kind: "repeat" }
                Item { Layout.fillWidth: true }
                MusicSourceChip {}
            }
        }
    }
}
