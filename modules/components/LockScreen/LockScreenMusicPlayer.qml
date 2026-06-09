import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import Quickshell.Widgets
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services


Item{
    RowLayout{
        anchors.fill: parent
        anchors.margins: 10
        ClippingWrapperRectangle{
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: 10
            color: Colors.surfaceContainerHigh
            Image{
                anchors.fill: parent
                sourceSize: Qt.size(width, height)
                source: ServiceMusic.activeTrack?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
            }
        }

        ColumnLayout{
            Layout.fillHeight: true
            spacing: 5
            CustomText{
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.title ?? "Unknown Title"
                size: 12
            }
            CustomText{
                Layout.fillWidth: true
                content: ServiceMusic.activeTrack?.artist ?? "Unknown Artist"
                color: Colors.outline
                size: 10
            }
        }

        MaterialIconSymbol{
            content: ServiceMusic.isPlaying ? "pause" : "play_arrow"
            iconSize: 24

            CustomMouseArea{
                radius: parent.radius
                id: loopArea
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked:{
                    ServiceMusic.togglePlaying()
                }
            }
        }

        MaterialIconSymbol{
            content: "skip_next"
            iconSize: 24

            CustomMouseArea{
                radius: parent.radius
                id: nArea
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked:{
                    ServiceMusic.next()
                }
            }
        }
    }
}
