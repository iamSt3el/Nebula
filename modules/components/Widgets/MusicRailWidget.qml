import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Bar
import "../../MatrialShapes/" as MaterialShapes

WidgetHost {
    id: root
    configKey: "musicRail"
    tile: Qt.size(WidgetSizes.span(1), WidgetSizes.span(3))
    defaultPos: Qt.point(35, 165)
    turnable: true
    backdropRadius: Math.min(root.width, root.height) / 2

    MusicNow { id: m; preview: root.preview }

    WidgetCard {
        anchors.fill: parent
        radius: Math.min(width, height) / 2

        GridLayout {
            anchors.fill: parent
            anchors.topMargin: root.turned ? 0 : 12
            anchors.bottomMargin: root.turned ? 0 : 12
            anchors.leftMargin: root.turned ? 12 : 0
            anchors.rightMargin: root.turned ? 16 : 0
            flow: root.turned ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rows: root.turned ? 1 : 11
            columns: root.turned ? 11 : 1
            rowSpacing: 0
            columnSpacing: 0

            Item {
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: 66
                Layout.preferredHeight: 66

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    roundedPolygon: "circle"
                    color: "transparent"
                    strokeProgress: m.progress
                    strokeWidth: 3.5
                    strokeColor: m.playing ? Colors.primary : Colors.outline
                    strokeTrackColor: Colors.surfaceContainerHighest
                }

                MusicShapeArt {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    decode: 128
                    round: true
                    dim: m.playing ? 0 : 1
                }
            }

            Item { Layout.fillHeight: !root.turned; Layout.fillWidth: root.turned }

            CustomText {
                Layout.alignment: Qt.AlignCenter
                content: m.hasTrack ? m.elapsedText : "--:--"
                size: 11
                weight: 600
                customColor: m.playing ? Colors.primary : Colors.outline
            }

            Item { Layout.fillHeight: !root.turned; Layout.fillWidth: root.turned }

            MusicShapeButton {
                Layout.alignment: Qt.AlignCenter
                icon: "skip_previous"
                shape: "clover4"
                side: 44
                iconSize: 20
                tone: Colors.secondaryContainer
                iconColor: Colors.secondaryContainerText
                usable: m.hasTrack
                onTapped: m.previous()
            }

            Item { Layout.fillHeight: !root.turned; Layout.fillWidth: root.turned }

            MusicShapeButton {
                Layout.alignment: Qt.AlignCenter
                icon: m.playing ? "pause" : "play_arrow"
                shape: m.playing ? "sunny" : "circle"
                pressShape: "cookie9"
                side: 64
                iconSize: 28
                tone: Colors.primary
                iconColor: Colors.primaryText
                usable: m.hasTrack
                onTapped: m.toggle()
            }

            Item { Layout.fillHeight: !root.turned; Layout.fillWidth: root.turned }

            MusicShapeButton {
                Layout.alignment: Qt.AlignCenter
                icon: "skip_next"
                shape: "clover4"
                side: 44
                iconSize: 20
                tone: Colors.secondaryContainer
                iconColor: Colors.secondaryContainerText
                usable: m.hasTrack
                onTapped: m.next()
            }

            Item { Layout.fillHeight: !root.turned; Layout.fillWidth: root.turned }

            MusicIconToggle {
                Layout.alignment: Qt.AlignCenter
                kind: "shuffle"
                side: 30
            }
        }
    }
}
