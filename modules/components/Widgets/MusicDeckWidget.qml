import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "musicDeck"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(1))
    resizable: true
    minSpan: Qt.size(3, 1)
    maxSpan: Qt.size(6, 1)
    turnable: true
    turnedMin: Qt.size(1, 4)
    defaultPos: Qt.point(585, 825)
    backdrop: false
    outlined: false

    MusicNow { id: m; preview: root.preview }

    readonly property real cap: Math.min(root.width, root.height) / 2
    readonly property real inner: 14

    component Side: Rectangle {
        id: side
        property string icon: ""
        property bool leading: true
        signal tapped

        Layout.preferredWidth: root.turned ? -1 : Math.round(root.height * 0.85)
        Layout.preferredHeight: root.turned ? Math.round(root.width * 0.85) : -1
        Layout.fillHeight: !root.turned
        Layout.fillWidth: root.turned
        topLeftRadius: side.leading ? root.cap : root.inner
        topRightRadius: (side.leading && root.turned) || (!side.leading && !root.turned) ? root.cap : root.inner
        bottomLeftRadius: (side.leading && !root.turned) || (!side.leading && root.turned) ? root.cap : root.inner
        bottomRightRadius: side.leading ? root.inner : root.cap
        color: sideArea.containsMouse ? Qt.lighter(Colors.secondaryContainer, 1.15) : Colors.secondaryContainer
        opacity: m.hasTrack ? 1 : 0.5
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: side.icon
            iconSize: 28
            fill: 1
            customColor: Colors.secondaryContainerText
        }

        MouseArea {
            id: sideArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: m.hasTrack
            cursorShape: Qt.PointingHandCursor
            onClicked: side.tapped()
        }
    }

    GridLayout {
        anchors.fill: parent
        flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.turned ? 3 : 1
        columns: root.turned ? 1 : 3
        rowSpacing: 6
        columnSpacing: 6

        Side {
            icon: "skip_previous"
            leading: true
            onTapped: m.previous()
        }

        ClippingRectangle {
            id: center
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: m.playing ? root.inner : root.cap
            color: m.playing ? Colors.surfaceContainerHigh : Colors.primary
            Behavior on radius { SpatialAnim {} }
            Behavior on color { EffectsColorAnim {} }

            readonly property color ink: m.playing ? Colors.surfaceText : Colors.primaryText
            readonly property color sub: m.playing ? Colors.surfaceVariantText : Qt.alpha(Colors.primaryText, 0.75)

            Rectangle {
                y: root.turned ? center.height - height : 0
                width: root.turned ? center.width : center.width * m.progress
                height: root.turned ? center.height * m.progress : center.height
                color: m.playing ? Colors.primaryContainer : Qt.darker(Colors.primary, 1.1)
                Behavior on width { enabled: !root.turned; SpatialAnim { speed: "slow" } }
                Behavior on height { enabled: root.turned; SpatialAnim { speed: "slow" } }
            }

            GridLayout {
                anchors.fill: parent
                anchors.leftMargin: root.turned ? 8 : 16
                anchors.rightMargin: root.turned ? 8 : 18
                anchors.topMargin: root.turned ? 16 : 0
                anchors.bottomMargin: root.turned ? 16 : 0
                flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rows: root.turned ? 3 : 1
                columns: root.turned ? 1 : 3
                rowSpacing: 10
                columnSpacing: 12

                MusicArt {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: Math.round(Math.min(root.width, root.height) * 0.62)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    source: m.artUrl
                    opacity: m.playing ? 1 : 0.8
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: root.turned
                    spacing: 2

                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                        wrapMode: root.turned ? Text.WordWrap : Text.NoWrap
                        maximumLineCount: root.turned ? 3 : 1
                        content: m.hasTrack ? m.title : "Nothing playing"
                        size: root.turned ? 13 : 15
                        weight: 600
                        customColor: center.ink
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                        wrapMode: root.turned ? Text.WordWrap : Text.NoWrap
                        maximumLineCount: root.turned ? 2 : 1
                        content: !m.hasTrack ? "" : root.turned ? m.artist
                            : m.playing ? m.artist + " · " + m.elapsedText : "Paused at " + m.elapsedText
                        size: 12
                        customColor: center.sub
                    }
                }

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignCenter
                    visible: m.hasTrack
                    content: m.playing ? "pause" : "play_arrow"
                    iconSize: m.playing ? 26 : 30
                    fill: 1
                    customColor: center.ink
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: m.hasTrack
                cursorShape: Qt.PointingHandCursor
                onClicked: m.toggle()
            }
        }

        Side {
            icon: "skip_next"
            leading: false
            onTapped: m.next()
        }
    }
}
