import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Bar
import "../../MatrialShapes/" as MaterialShapes

WidgetHost {
    id: root
    configKey: "musicDisc"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(2))
    defaultPos: Qt.point(475, 165)

    MusicNow { id: m; preview: root.preview }

    WidgetCard {
        anchors.fill: parent

        Item {
            id: disc
            width: 140
            height: 140
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10

            MaterialShapes.ShapeCanvas {
                anchors.fill: parent
                roundedPolygon: art.shape
                color: "transparent"
                strokeProgress: m.progress
                strokeWidth: 4
                strokeColor: m.playing ? Colors.primary : Colors.outline
                strokeTrackColor: Colors.surfaceContainerHighest
            }

            MusicShapeArt {
                id: art
                anchors.centerIn: parent
                width: 116
                height: 116
                decode: 256
                round: !m.playing
                dim: m.playing ? 0 : 1
            }

            MouseArea {
                anchors.fill: art
                enabled: m.playing && m.hasTrack
                cursorShape: Qt.PointingHandCursor
                onClicked: m.toggle()
            }

            MusicShapeButton {
                anchors.centerIn: parent
                visible: !m.playing && m.hasTrack
                icon: "play_arrow"
                shape: "sunny"
                pressShape: "cookie9"
                side: 56
                iconSize: 28
                tone: Colors.primary
                iconColor: Colors.primaryText
                onTapped: m.toggle()
            }
        }

        MusicShapeButton {
            x: 12
            y: parent.height - 44
            icon: "skip_previous"
            shape: "clover4"
            side: 34
            iconSize: 18
            tone: Colors.secondaryContainer
            iconColor: Colors.secondaryContainerText
            usable: m.hasTrack
            onTapped: m.previous()
        }

        Column {
            x: 50
            y: parent.height - 42
            width: parent.width - 100
            spacing: 1

            CustomText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                content: m.hasTrack ? m.title : "Nothing playing"
                size: 13
                weight: 600
                customColor: m.playing ? Colors.surfaceText : Colors.surfaceVariantText
            }
            CustomText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                content: !m.hasTrack ? "" : m.playing ? m.artist : "Paused · " + m.elapsedText
                size: 11
                customColor: m.playing ? Colors.surfaceVariantText : Colors.outline
            }
        }

        MusicShapeButton {
            x: parent.width - 46
            y: parent.height - 44
            icon: "skip_next"
            shape: "clover4"
            side: 34
            iconSize: 18
            tone: Colors.secondaryContainer
            iconColor: Colors.secondaryContainerText
            usable: m.hasTrack
            onTapped: m.next()
        }
    }
}
