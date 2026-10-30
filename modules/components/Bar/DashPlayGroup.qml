import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

RowLayout {
    id: root

    property real buttonHeight: 48
    property bool showToggles: true
    property bool cookie: false

    readonly property string playIcon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
    readonly property string repeatIcon: ServiceMusic.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"

    readonly property var lead: root.showToggles
        ? [{ value: "shuffle", icon: "shuffle" }, { value: "previous", icon: "skip_previous" }]
        : [{ value: "previous", icon: "skip_previous" }]
    readonly property var tail: root.showToggles
        ? [{ value: "next", icon: "skip_next" }, { value: "repeat", icon: root.repeatIcon }]
        : [{ value: "next", icon: "skip_next" }]

    function lit(value) {
        if (value === "play") return true
        if (value === "shuffle") return ServiceMusic.hasShuffle
        if (value === "repeat") return ServiceMusic.loopState !== MprisLoopState.None
        return false
    }

    function act(value) {
        switch (value) {
        case "shuffle":
            if (ServiceMusic.shuffleSupported) ServiceMusic.setShuffle(!ServiceMusic.hasShuffle)
            break
        case "previous":
            if (ServiceMusic.canGoPrevious) ServiceMusic.previous()
            break
        case "play":
            if (ServiceMusic.canTogglePlaying) ServiceMusic.togglePlaying()
            break
        case "next":
            if (ServiceMusic.canGoNext) ServiceMusic.next()
            break
        case "repeat": {
            const s = ServiceMusic.loopState
            if (ServiceMusic.loopSupported)
                ServiceMusic.setLoopState(s === MprisLoopState.None ? MprisLoopState.Playlist
                    : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
            break
        }
        }
    }

    spacing: 6

    M3ButtonGroup {
        visible: !root.cookie
        Layout.fillWidth: true
        height: root.buttonHeight
        Layout.preferredHeight: root.buttonHeight
        fillWidth: true
        iconSize: Math.round(root.buttonHeight * 0.48)
        inactiveColor: Colors.surfaceContainerHighest
        model: root.lead.concat([{ value: "play", icon: root.playIcon }]).concat(root.tail)
        activeCheck: value => root.lit(value)
        onSegmentClicked: value => root.act(value)
    }

    M3ButtonGroup {
        visible: root.cookie
        Layout.fillWidth: true
        height: root.buttonHeight
        Layout.preferredHeight: root.buttonHeight
        fillWidth: true
        iconSize: Math.round(root.buttonHeight * 0.44)
        inactiveColor: Colors.surfaceContainerHighest
        model: root.lead
        activeCheck: value => root.lit(value)
        onSegmentClicked: value => root.act(value)
    }

    Item {
        visible: root.cookie
        Layout.preferredWidth: root.buttonHeight + 14
        Layout.preferredHeight: root.buttonHeight + 14

        MaterialShapes.ShapeCanvas {
            anchors.fill: parent
            roundedPolygon: "cookie12"
            color: Colors.tertiaryContainer
            rotation: ServiceMusic.isPlaying ? 30 : 0
            Behavior on rotation { SpatialAnim {} }
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: root.playIcon
            iconSize: Math.round(root.buttonHeight * 0.56)
            fill: 1
            customColor: Colors.tertiaryContainerText
        }

        RippleEffect {
            anchors.fill: parent
            radius: width / 2
            hoverColor: Qt.alpha(Colors.tertiaryContainerText, 0.08)
            rippleColor: Qt.alpha(Colors.tertiaryContainerText, 0.16)
            onClicked: root.act("play")
        }
    }

    M3ButtonGroup {
        visible: root.cookie
        Layout.fillWidth: true
        height: root.buttonHeight
        Layout.preferredHeight: root.buttonHeight
        fillWidth: true
        iconSize: Math.round(root.buttonHeight * 0.44)
        inactiveColor: Colors.surfaceContainerHighest
        model: root.tail
        activeCheck: value => root.lit(value)
        onSegmentClicked: value => root.act(value)
    }
}
