import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

ColumnLayout {
    id: root

    property real artSize: 104
    property bool compact: false
    readonly property bool hasPlayer: !!ServiceMusic.activePlayer
    readonly property string title: ServiceMusic.activeTrack?.title || "Nothing playing"
    readonly property string artist: ServiceMusic.activeTrack?.artist ?? ""
    readonly property string album: ServiceMusic.activeTrack?.album ?? ""

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        MusicArtwork {
            Layout.preferredWidth: root.artSize
            Layout.preferredHeight: root.artSize
            cornerRadius: root.artSize > 80 ? 18 : 14
            placeholderIconSize: root.artSize * 0.32
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            MusicSourceChip { visible: root.hasPlayer }

            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                content: root.title
                size: root.compact ? 15 : 18
                weight: 800
            }

            CustomText {
                Layout.fillWidth: true
                visible: root.artist !== ""
                content: root.album !== "" && !root.compact ? root.artist + " • " + root.album : root.artist
                size: 12
                weight: 500
                customColor: Colors.surfaceVariantText
            }

            MusicTransport {
                visible: !root.compact
                Layout.fillWidth: true
                Layout.topMargin: 6
                playSize: 42
                sideSize: 34
            }
        }

        MusicTransport {
            visible: root.compact
            playSize: 40
            sideSize: 32
            showToggles: false
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        CustomText {
            content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0)
            size: 11
            weight: 700
            customColor: Colors.surfaceVariantText
        }
        MusicSeekBar { Layout.fillWidth: true; trackColor: Colors.surfaceContainerHighest }
        CustomText {
            content: ServiceMusic.formatTime(ServiceMusic.trackLength)
            size: 11
            weight: 700
            customColor: Colors.surfaceVariantText
        }
    }
}
