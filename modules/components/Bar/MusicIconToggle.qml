import Quickshell.Services.Mpris
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property string kind: "shuffle"
    property real side: 34

    readonly property bool isShuffle: root.kind === "shuffle"
    readonly property bool on: root.isShuffle ? ServiceMusic.hasShuffle : ServiceMusic.loopState !== MprisLoopState.None
    readonly property bool usable: root.isShuffle ? ServiceMusic.shuffleSupported : ServiceMusic.loopSupported

    implicitWidth: root.side
    implicitHeight: root.side
    radius: root.side / 2
    opacity: root.usable ? 1 : 0.3
    color: root.on ? Qt.alpha(Colors.primary, 0.16) : area.containsMouse ? Colors.surfaceContainerHigh : "transparent"
    Behavior on color { EffectsColorAnim {} }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.isShuffle ? "shuffle"
            : ServiceMusic.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
        iconSize: Math.round(root.side * 0.55)
        customColor: root.on ? Colors.primary : area.containsMouse ? Colors.surfaceText : Colors.outline
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.isShuffle) {
                ServiceMusic.setShuffle(!ServiceMusic.hasShuffle)
                return
            }
            const s = ServiceMusic.loopState
            ServiceMusic.setLoopState(s === MprisLoopState.None ? MprisLoopState.Playlist
                                    : s === MprisLoopState.Playlist ? MprisLoopState.Track
                                    : MprisLoopState.None)
        }
    }
}
