import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, 0, 0)
    readonly property bool shown: true

    readonly property string phase: ServiceFocus.phase
    readonly property bool idle: root.phase === "idle"
    readonly property bool breakTime: root.phase === "break"
    readonly property bool done: ServiceFocus.finished
    readonly property bool showDots: BarLayout.opt(root.itemId, "dots") !== false

    readonly property color fillColor: root.done ? Colors.primaryContainer
        : root.breakTime ? Colors.tertiaryContainer
        : root.idle ? (hov.containsMouse && !root.plateless ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0))
        : Colors.surfaceContainerHigh
    readonly property color ink: root.done ? Colors.primaryContainerText
        : root.breakTime ? Colors.tertiaryContainerText
        : root.idle && hov.containsMouse ? Colors.primaryContainerText
        : Colors.surfaceText

    implicitWidth: root.idle ? 28 : row.implicitWidth + 20
    implicitHeight: 28
    radius: height / 2
    color: root.fillColor
    Behavior on color { EffectsColorAnim {} }
    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

    MaterialIconSymbol {
        anchors.centerIn: parent
        visible: root.idle
        content: "timer"
        iconSize: 18
        customColor: root.ink
    }

    Row {
        id: row
        anchors.centerIn: parent
        visible: !root.idle
        spacing: 7

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.phase === "focus"
            width: 20
            height: 20

            CustomCircularProgressBar {
                anchors.fill: parent
                progress: ServiceFocus.progress
                thickness: 2.5
                showText: false
                baseColor: Colors.surfaceContainerHighest
                lineColor: ServiceFocus.running ? Colors.primary : Colors.outline
            }

            MaterialIconSymbol {
                anchors.centerIn: parent
                visible: !ServiceFocus.running
                content: "pause"
                iconSize: 11
                customColor: Colors.outline
            }
        }

        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.phase !== "focus"
            content: root.breakTime ? (ServiceFocus.running ? "coffee" : "pause") : "check_circle"
            iconSize: 17
            customColor: root.ink
        }

        CustomText {
            id: timeText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.done
            width: Math.max(timeText.implicitWidth, probe.advanceWidth)
            content: ServiceFocus.clock
            size: 13
            weight: 700
            font.features: { "tnum": 1 }
            customColor: ServiceFocus.running ? root.ink : Colors.outline

            TextMetrics {
                id: probe
                font: timeText.font
                text: "88:88"
            }
        }

        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.breakTime || root.done
            content: root.breakTime ? "break"
                : root.phase === "focusDone" ? "Focus done · start break" : "Break over · focus"
            size: 12
            weight: root.done ? 700 : 500
            customColor: root.ink
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDots && root.phase === "focus"
            spacing: 3

            Repeater {
                model: ServiceFocus.rounds
                delegate: Rectangle {
                    required property int index
                    width: 5
                    height: 5
                    radius: 2.5
                    color: index <= ServiceFocus.sessionInRound ? Colors.primary : Colors.surfaceContainerHighest
                }
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                ServiceFocus.skip()
            else if (mouse.button === Qt.RightButton)
                ServiceFocus.reset()
            else
                ServiceFocus.toggle()
        }
    }

    CustomToolTip {
        content: root.idle ? "Start a " + ServiceFocus.focusMin + " min focus session"
            : "Click to " + (root.done ? "continue" : ServiceFocus.running ? "pause" : "resume")
              + " · middle-click to skip · right-click to reset"
        visible: hov.containsMouse
    }
}
