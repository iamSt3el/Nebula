import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.utils

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Normal

    // ── Charging wave shader ─────────────────────────────────────────────────
    property real animProgress: 0.0

    NumberAnimation {
        id: chargeAnim
        target: root
        property: "animProgress"
        from: 0.0; to: 1.0
        duration: 3000
        easing.type: Easing.Linear
    }

    ShaderEffect {
        anchors.fill: parent

        vertexShader:   "shaders/charging_wave.vert.qsb"
        fragmentShader: "shaders/charging_wave.frag.qsb"

        blending: true

        property real iTime:   root.animProgress
        property real iR:      Colors.primary.r
        property real iG:      Colors.primary.g
        property real iB:      Colors.primary.b
        property real iAspect: width / height
    }

    // ── Controls ─────────────────────────────────────────────────────────────
    Row {
        anchors {
            bottom:           parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin:     48
        }
        spacing: 14

        Rectangle {
            width: 110; height: 40
            radius: 20
            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, playArea.containsMouse ? 0.9 : 0.7)
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: playArea.pressed ? 0.91 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "▶"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Play";  color: "white"; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.animProgress = 0.0; chargeAnim.restart() }
            }
        }

        Rectangle {
            width: 110; height: 40
            radius: 20
            color: exitArea.containsMouse ? "#cc2222" : Qt.rgba(0.5, 0.1, 0.1, 0.75)
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: exitArea.pressed ? 0.91 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "✕"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Exit";  color: "white"; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                id: exitArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }
    }
}
