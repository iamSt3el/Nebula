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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        anchors.topMargin: 20
        anchors.bottomMargin: 22
        spacing: 0
        visible: root.hasTrack

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 152
            Layout.preferredHeight: 152
            radius: 76
            color: Colors.surfaceContainer

            MusicArtwork {
                anchors.centerIn: parent
                width: 140
                height: 140
                cornerRadius: 70
                interactive: true
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 18
            text: ServiceMusic.activeTrack?.title ?? ""
            font.family: root.displayFamily
            font.pixelSize: 22
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            renderType: Text.QtRendering
            color: Colors.surfaceText
        }
        CustomText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            content: ServiceMusic.activeTrack?.artist ?? ""
            horizontalAlignment: Text.AlignHCenter
            size: 13
            weight: 500
            customColor: Colors.surfaceVariantText
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.preferredHeight: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Colors.surfaceContainerHighest
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * seek.shown
                height: 4
                radius: 2
                color: Colors.primary
            }
            Rectangle {
                x: track.width * seek.shown - width / 2
                y: (track.height - height) / 2 - 1
                width: seek.active ? 18 : 15
                height: width
                rotation: -45
                topLeftRadius: width / 2
                topRightRadius: width / 2
                bottomRightRadius: width / 2
                bottomLeftRadius: 0
                color: Colors.primary
                Behavior on width { SpatialAnim { speed: "fast" } }
            }

            MusicSeekArea {
                id: seek
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            CustomText {
                content: ServiceMusic.formatTime(seek.shown * root.total)
                size: 11
                weight: 500
                customColor: Colors.primary
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
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            MusicIconToggle { kind: "shuffle"; side: 40 }
            MusicRoundButton {
                icon: "skip_previous"
                side: 48
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            MusicRoundButton {
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                side: 66
                filled: true
                usable: ServiceMusic.canTogglePlaying
                onTapped: ServiceMusic.togglePlaying()
            }
            MusicRoundButton {
                icon: "skip_next"
                side: 48
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
            MusicIconToggle { kind: "repeat"; side: 40 }
        }
    }
}
