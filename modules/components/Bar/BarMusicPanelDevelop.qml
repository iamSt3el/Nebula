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

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 20
        visible: root.hasTrack

        Item {
            id: cover
            Layout.preferredWidth: 194
            Layout.preferredHeight: 194
            Layout.alignment: Qt.AlignVCenter

            MusicDevelopArt {
                anchors.fill: parent
                cornerRadius: 24
                decode: 400
                progress: seek.shown
                showSeam: false
            }

            Rectangle {
                x: Math.round(cover.width * seek.shown) - 1
                width: 1
                height: cover.height
                color: Qt.alpha(Colors.primary, 0.75)
                visible: seek.shown > 0.005 && seek.shown < 0.995
            }

            Rectangle {
                x: Math.round(cover.width * seek.shown) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: seek.active ? 6 : 5
                height: seek.active ? 72 : 60
                radius: width / 2
                color: Colors.primary
                border.width: 3
                border.color: Qt.alpha(Colors.scrim, 0.35)
                Behavior on height { SpatialAnim { speed: "fast" } }
            }

            Rectangle {
                id: bubble
                x: Math.max(8, Math.min(cover.width - bubble.width - 8, cover.width * seek.shown + 10))
                y: 12
                implicitWidth: bubbleText.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                color: Colors.primary

                CustomText {
                    id: bubbleText
                    anchors.centerIn: parent
                    content: ServiceMusic.formatTime(seek.shown * root.total)
                    size: 11
                    weight: 600
                    customColor: Colors.primaryText
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                implicitWidth: totalText.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                color: Qt.alpha(Colors.scrim, 0.6)

                CustomText {
                    id: totalText
                    anchors.centerIn: parent
                    content: ServiceMusic.formatTime(root.total)
                    size: 11
                    weight: 500
                    customColor: "white"
                }
            }

            MusicSeekArea {
                id: seek
                anchors.fill: parent
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
                font.pixelSize: 24
                lineHeight: 0.95
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                renderType: Text.QtRendering
                color: Colors.surfaceText
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 13
                weight: 500
                customColor: Colors.surfaceVariantText
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                content: ServiceMusic.activeTrack?.album ?? ""
                visible: content !== ""
                size: 12
                weight: 400
                customColor: Colors.outline
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MusicSourceChip {}
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceMusic.formatTime(Math.max(0, root.total - seek.shown * root.total)) + " left"
                    size: 11
                    weight: 400
                    customColor: Colors.outline
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MusicRoundButton {
                    icon: "skip_previous"
                    usable: ServiceMusic.canGoPrevious
                    onTapped: ServiceMusic.previous()
                }
                MusicRoundButton {
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    side: 60
                    filled: true
                    cornerRadius: ServiceMusic.isPlaying ? 20 : 30
                    usable: ServiceMusic.canTogglePlaying
                    onTapped: ServiceMusic.togglePlaying()
                }
                MusicRoundButton {
                    icon: "skip_next"
                    usable: ServiceMusic.canGoNext
                    onTapped: ServiceMusic.next()
                }
                Item { Layout.fillWidth: true }
                MusicIconToggle { kind: "shuffle" }
            }
        }
    }
}
