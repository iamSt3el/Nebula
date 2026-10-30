import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Bar

WidgetHost {
    id: root
    configKey: "musicPulse"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(1))
    defaultPos: Qt.point(145, 935)
    turnable: true
    backdropRadius: Math.min(root.width, root.height) / 2

    MusicNow { id: m; preview: root.preview }

    readonly property var frames: ["softBurst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]
    property int frame: 0

    Timer {
        interval: 650
        repeat: true
        running: m.playing && !root.preview && root.visible
        onTriggered: root.frame = (root.frame + 1) % root.frames.length
    }

    WidgetCard {
        anchors.fill: parent
        radius: Math.min(width, height) / 2

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin: root.turned ? 10 : 12
            anchors.rightMargin: root.turned ? 10 : 16
            anchors.topMargin: root.turned ? 12 : 0
            anchors.bottomMargin: root.turned ? 18 : 0
            flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.turned ? 2 : 1
            columns: root.turned ? 1 : 2
            rowSpacing: 10
            columnSpacing: 12

            MusicShapeButton {
                Layout.alignment: Qt.AlignCenter
                icon: m.playing ? "pause" : "play_arrow"
                shape: m.playing ? root.frames[root.frame] : "circle"
                pressShape: "cookie12"
                side: 66
                iconSize: 28
                tone: m.playing ? Colors.primaryContainer : Colors.primary
                iconColor: m.playing ? Colors.primaryContainerText : Colors.primaryText
                usable: m.hasTrack
                onTapped: m.toggle()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignCenter
                spacing: 1

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    wrapMode: root.turned ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: root.turned ? 2 : 1
                    content: m.hasTrack ? m.title : "Nothing playing"
                    size: 14
                    weight: 600
                    customColor: m.playing ? Colors.surfaceText : Colors.surfaceVariantText
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: m.hasTrack
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    content: m.artist
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: m.hasTrack
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    content: root.turned ? m.elapsedText
                        : m.playing ? m.elapsedText + " / " + m.lengthText : "Paused · " + m.elapsedText
                    size: 11
                    weight: 600
                    customColor: m.playing ? Colors.primary : Colors.outline
                }
            }
        }
    }
}
