import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property int stepCount:   4
    property int currentStep: 0
    property var stepLabels:  []

    signal stepChanged(int step)

    implicitHeight: 32
    implicitWidth:  160

    readonly property real _progress: stepCount > 1 ? currentStep / (stepCount - 1) : 0

    // usable track width — 12px padding each side so handler never clips
    readonly property real _trackW: width - 24
    readonly property real _handlerX: 12 + _trackW * _progress

    // ── Value bubble ───────────────────────────────────────────────────────
    Rectangle {
        visible: dragArea.pressed
        width:  Math.max(28, bubbleTxt.implicitWidth + 14)
        height: 20
        radius: 4
        color:  Colors.primary
        x:      root._handlerX - width / 2
        y:      (root.height - trackRect.height) / 2 - height - 6
        z:      10

        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

        CustomText {
            id: bubbleTxt
            anchors.centerIn: parent
            content: root.stepLabels.length > root.currentStep
                ? root.stepLabels[root.currentStep]
                : root.currentStep.toString()
            size:   9
            weight: 700
            customColor: Colors.primaryText
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: -3
            width: 6; height: 6
            rotation: 45
            color: Colors.primary
        }
    }

    // ── Track ──────────────────────────────────────────────────────────────
    // gap on each side of the handler so it floats free of the track
    readonly property real _gap: 4
    readonly property real _handlerHalf: 2  // handler.width / 2

    Item {
        id: trackRect
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.leftMargin:  12
        anchors.rightMargin: 12
        height: 6

        // Left (active) segment — stops before handler
        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, root._trackW * root._progress - root._handlerHalf - root._gap)
            radius: 3
            color: Colors.primary
            Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        // Right (inactive) segment — starts after handler
        Rectangle {
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, root._trackW * (1 - root._progress) - root._handlerHalf - root._gap)
            radius: 3
            color: Qt.alpha(Colors.primary, 0.22)
            Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        // Stop indicator dots
        Repeater {
            model: root.stepCount
            Rectangle {
                required property int index
                x:      root._trackW * (root.stepCount > 1 ? index / (root.stepCount - 1) : 0) - width / 2
                width:  4; height: 4; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: index <= root.currentStep
                    ? Qt.alpha(Colors.primaryText, 0.45)
                    : Qt.alpha(Colors.primaryText, 0.3)
                visible: index !== root.currentStep
                z: 1
            }
        }
    }

    // ── Handler ────────────────────────────────────────────────────────────
    Rectangle {
        id: handler
        width:  4
        height: 20
        radius: 2
        color:  Colors.primary
        anchors.verticalCenter: parent.verticalCenter
        x: root._handlerX - width / 2

        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    // ── Interaction ────────────────────────────────────────────────────────
    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        preventStealing: true

        onPressed:         event => snap(event.x)
        onPositionChanged: event => { if (pressed) snap(event.x) }

        function snap(mouseX) {
            if (root.stepCount < 2) return
            var pos  = Math.max(0, Math.min(mouseX - 12, root._trackW))
            var step = Math.round(pos / root._trackW * (root.stepCount - 1))
            step = Math.max(0, Math.min(step, root.stepCount - 1))
            if (step !== root.currentStep) {
                root.currentStep = step
                root.stepChanged(step)
            }
        }
    }
}
