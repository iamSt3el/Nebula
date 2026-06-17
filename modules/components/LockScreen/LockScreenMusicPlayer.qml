import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import Quickshell.Widgets
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

Item {
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Album art
        ClippingWrapperRectangle {
            Layout.preferredWidth: height
            Layout.fillHeight: true
            radius: 12
            color: Colors.surfaceContainerHigh

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(width, height)
                source: ServiceMusic.activeTrack?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: (ServiceMusic.activeTrack?.artUrl?.length ?? 0) > 0
            }
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "music_note"; iconSize: 18; customColor: Colors.outline
                visible: (ServiceMusic.activeTrack?.artUrl?.length ?? 0) === 0
            }
        }

        // Track info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3

            CustomText {
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.title ?? "Nothing playing"
                size: 12; weight: 600; elide: Text.ElideRight
            }
            CustomText {
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 10; customColor: Colors.outline; elide: Text.ElideRight
            }
        }

        // Controls
        RowLayout {
            spacing: 4

            Rectangle {
                width: 30; height: 30; radius: 10
                color: Colors.surfaceContainerHighest
                opacity: ServiceMusic.canGoPrevious ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
                MaterialIconSymbol { anchors.centerIn: parent; content: "skip_previous"; iconSize: 16 }
                CustomMouseArea {
                    anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceMusic.previous()
                }
            }

            Rectangle {
                width: 34; height: 34; radius: 11
                color: Colors.primary
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: 18; customColor: Colors.primaryText
                }
                CustomMouseArea {
                    anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceMusic.togglePlaying()
                }
            }

            Rectangle {
                width: 30; height: 30; radius: 10
                color: Colors.surfaceContainerHighest
                opacity: ServiceMusic.canGoNext ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
                MaterialIconSymbol { anchors.centerIn: parent; content: "skip_next"; iconSize: 16 }
                CustomMouseArea {
                    anchors.fill: parent; radius: parent.radius; cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceMusic.next()
                }
            }
        }
    }
}
