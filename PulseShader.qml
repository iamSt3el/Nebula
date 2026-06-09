import QtQuick
import Quickshell

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    aboveWindows: true

    visible: true

    property real animProgress: 0.0

    NumberAnimation {
        id: chargeAnim
        target: root
        property: "animProgress"
        from:     0.0
        to:       1.0
        duration: 1500
        easing.type: Easing.InOutSine
    }

    function playAnimation() {
        root.animProgress = 0.0
        chargeAnim.restart()
    }

    ShaderEffect {
        anchors.fill: parent

        vertexShader:   "shaders/hex_pulse.vert.qsb"
        fragmentShader: "shaders/hex_pulse.frag.qsb"

        property real     iTime:       root.animProgress
        property real     iHexSize:    0.055
        property real     iSpeed:      1.0
        property real     iEdgeSoft:   0.008
        property real     iRandomness: 0.04
        property vector2d iResolution: Qt.vector2d(width, height)
    }

    Row {
        anchors {
            bottom:           parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin:     40
        }
        spacing: 16

        Rectangle {
            width: 120; height: 40; radius: 8
            color: playArea.containsMouse ? "#2a2a2a" : "#1a1a1a"
            border.color: "#00bfff"; border.width: 1
            Text {
                anchors.centerIn: parent
                text:  "Play"
                color: "#00bfff"
                font.pixelSize: 14
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.playAnimation()
            }
        }

        Rectangle {
            width: 120; height: 40; radius: 8
            color: exitArea.containsMouse ? "#2a2a2a" : "#1a1a1a"
            border.color: "#ff4444"; border.width: 1
            Text {
                anchors.centerIn: parent
                text:  "Exit"
                color: "#ff4444"
                font.pixelSize: 14
            }
            MouseArea {
                id: exitArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Qt.quit()
            }
        }
    }
}
